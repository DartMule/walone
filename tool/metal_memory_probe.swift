import Foundation
import Metal

// Изолированный диагностический процесс, не код приложения.
// xcrun swiftc tool/metal_memory_probe.swift -o /tmp/walone-metal-probe
// /tmp/walone-metal-probe 1  (аргумент: предел числа command buffers)
// Второй аргумент: baseline, shared, untracked, unretained, metal4 или unoptimized.
// Дополнительные проверки Engine: tile16, tile32, transient-queue.
// Третий аргумент: фиксированная частота кадров (без него пауза после кадра).
// Этапы: 4 секунды простоя, 200 кадров по 50 мс, 6 секунд без кадров.
// Во время этапов снимать footprint -p <PID> и vmmap -summary <PID>.
// Для attach Instruments можно задержать создание Metal-ресурсов до появления
// файла WALONE_METAL_PROBE_START_FILE (максимум 90 секунд).
if let startFile = ProcessInfo.processInfo.environment["WALONE_METAL_PROBE_START_FILE"] {
  let deadline = Date().addingTimeInterval(90)
  print("waiting pid=\(ProcessInfo.processInfo.processIdentifier)")
  fflush(stdout)
  while !FileManager.default.fileExists(atPath: startFile) {
    precondition(Date() < deadline, "Instruments не начал запись за 90 секунд")
    Thread.sleep(forTimeInterval: 0.05)
  }
}
let device = MTLCreateSystemDefaultDevice()!
let count = Int(CommandLine.arguments.dropFirst().first ?? "64")!
let mode = CommandLine.arguments.dropFirst(2).first ?? "baseline"
let fps = Double(CommandLine.arguments.dropFirst(3).first ?? "0")!
precondition(fps >= 0 && fps <= 240)
precondition(["baseline", "shared", "untracked", "unretained", "metal4", "unoptimized",
  "tile16", "tile32", "transient-queue"].contains(mode))
let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
  width: 1840, height: 1640, mipmapped: false)
descriptor.usage = [.renderTarget]
descriptor.storageMode = ["shared", "unoptimized"].contains(mode) ? .shared : .private
if mode == "unoptimized" { descriptor.allowGPUOptimizedContents = false }
if mode == "untracked" { descriptor.hazardTrackingMode = .untracked }
let textures = [device.makeTexture(descriptor: descriptor)!, device.makeTexture(descriptor: descriptor)!]
// В Metal 4 аллокатор сбрасывается только после завершения GPU; те же два
// render targets, цвета и 200 кадров. Это проверка API, не замена Impeller.
@available(macOS 26.0, *)
func metal4Submitter() -> (Int) -> Void {
  let queue = device.makeMTL4CommandQueue()!
  let allocator = device.makeCommandAllocator()!
  let buffer = device.makeCommandBuffer()!
  let event = device.makeSharedEvent()!
  let residency = try! device.makeResidencySet(descriptor: MTLResidencySetDescriptor())
  for texture in textures { residency.addAllocation(texture) }
  residency.commit()
  queue.addResidencySet(residency)
  return { frame in
    allocator.reset()
    buffer.beginCommandBuffer(allocator: allocator)
    let pass = MTL4RenderPassDescriptor()
    pass.colorAttachments[0].texture = textures[frame % 2]
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(frame % 2), green: 0, blue: 0, alpha: 1)
    let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)!
    encoder.endEncoding()
    buffer.endCommandBuffer()
    queue.commit([buffer])
    queue.signalEvent(event, value: UInt64(frame + 1))
    precondition(event.wait(untilSignaledValue: UInt64(frame + 1), timeoutMS: 5000))
  }
}
let submit: (Int) -> Void
if mode == "metal4" {
  if #available(macOS 26.0, *) { submit = metal4Submitter() }
  else { fatalError("Metal 4 требует macOS 26+") }
} else {
  let persistentQueue = mode == "transient-queue" ? nil : device.makeCommandQueue(maxCommandBufferCount: count)
  submit = { frame in
    let queue = persistentQueue ?? device.makeCommandQueue(maxCommandBufferCount: count)!
    let pass = MTLRenderPassDescriptor()
    if mode == "tile16" || mode == "tile32" {
      let size = mode == "tile16" ? 16 : 32
      pass.tileWidth = size
      pass.tileHeight = size
    }
    pass.colorAttachments[0].texture = textures[frame % 2]
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(frame % 2), green: 0, blue: 0, alpha: 1)
    let buffer = mode == "unretained" ? queue.makeCommandBufferWithUnretainedReferences()! : queue.makeCommandBuffer()!
    let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)!
    encoder.endEncoding()
    buffer.commit()
    buffer.waitUntilCompleted()
    precondition(buffer.status == .completed)
  }
}
print("ready pid=\(ProcessInfo.processInfo.processIdentifier) mode=\(mode)")
fflush(stdout)
Thread.sleep(forTimeInterval: 4)
var durations = [Double]()
var missedBudgets = 0
for frame in 0..<200 {
  let start = ProcessInfo.processInfo.systemUptime
  autoreleasepool {
    submit(frame)
  }
  durations.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
  if frame == 100 {
    print("active allocated=\(device.currentAllocatedSize)")
    fflush(stdout)
  }
  if fps > 0 {
    let remaining = 1 / fps - (ProcessInfo.processInfo.systemUptime - start)
    if remaining > 0 { Thread.sleep(forTimeInterval: remaining) }
    else { missedBudgets += 1 }
  } else {
    Thread.sleep(forTimeInterval: 0.05)
  }
}
durations.sort()
print("stopped allocated=\(device.currentAllocatedSize) frames=\(durations.count) submit_wait_p95_ms=\(durations[189]) p99_ms=\(durations[197]) missed_budgets=\(missedBudgets) fps=\(fps)")
fflush(stdout)
Thread.sleep(forTimeInterval: 6)
// Readback после замеров: все режимы обязаны действительно записать те же
// пиксели. Отдельная blit-очередь не участвует в измерении активной RAM.
let readbackQueue = device.makeCommandQueue()!
let pixels = device.makeBuffer(length: 256, options: .storageModeShared)!
for (index, texture) in textures.enumerated() {
  let buffer = readbackQueue.makeCommandBuffer()!
  let blit = buffer.makeBlitCommandEncoder()!
  blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
    sourceOrigin: MTLOrigin(x: 920, y: 820, z: 0), sourceSize: MTLSize(width: 1, height: 1, depth: 1),
    to: pixels, destinationOffset: 0, destinationBytesPerRow: 256, destinationBytesPerImage: 256)
  blit.endEncoding()
  buffer.commit()
  buffer.waitUntilCompleted()
  precondition(buffer.status == .completed)
  let bytes = pixels.contents().assumingMemoryBound(to: UInt8.self)
  precondition(bytes[0] == 0 && bytes[1] == 0 && bytes[2] == UInt8(index * 255) && bytes[3] == 255)
}
print("pixels=PASS")
