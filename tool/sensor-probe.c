#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <mach/mach_time.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <sys/qos.h>

// Undocumented SPU report layout, independently decoded here. See docs/feasibility.md.
// Default: passive. --activate explicitly changes only the matched accelerometer driver.
// No keyboard, filesystem writes or networking.
static volatile sig_atomic_t stopped;
static double scale;
static int stream;
static int activate;
static unsigned long count, invalid, nonmonotonic, dropped;
static double first, last, minGap = INFINITY, maxGap, sumGap, sumGapSquared;
static double minLag = INFINITY, maxLag, sumLag;
static double minZ = INFINITY, maxZ = -INFINITY;
static void stop(int sig) { (void)sig; stopped = 1; }

typedef struct {
    io_service_t driver;
    CFTypeRef original[3];
    int changed[3];
} Activation;

static CFStringRef property(int index) {
    switch (index) {
        case 0: return CFSTR("SensorPropertyReportingState");
        case 1: return CFSTR("SensorPropertyPowerState");
        default: return CFSTR("ReportInterval");
    }
}

static const char *property_name(int index) {
    return index == 0 ? "SensorPropertyReportingState" :
           index == 1 ? "SensorPropertyPowerState" : "ReportInterval";
}

static IOReturn set_number(io_service_t driver, int index, int value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    IOReturn result = IORegistryEntrySetCFProperty(driver, property(index), number);
    CFRelease(number);
    return result;
}

static int prepare_activation(io_service_t deviceService, Activation *state) {
    // Follow the actual matched device's child, rather than changing every SPU sensor.
    io_iterator_t children = 0;
    if (IORegistryEntryGetChildIterator(deviceService, kIOServicePlane, &children)) return 0;
    io_service_t child;
    while ((child = IOIteratorNext(children))) {
        io_service_t driver = 0;
        io_iterator_t descendants = 0;
        if (!IORegistryEntryGetChildIterator(child, kIOServicePlane, &descendants)) {
            while ((driver = IOIteratorNext(descendants))) {
                if (IOObjectConformsTo(driver, "AppleSPUHIDDriver")) {
                    state->driver = driver;
                    break;
                }
                IOObjectRelease(driver);
            }
            IOObjectRelease(descendants);
        }
        IOObjectRelease(child);
        if (state->driver) break;
    }
    IOObjectRelease(children);
    if (!state->driver) return 0;
    for (int i = 0; i < 3; i++) {
        state->original[i] = IORegistryEntryCreateCFProperty(state->driver, property(i), NULL, 0);
        int originalValue = 0;
        if (state->original[i] && CFGetTypeID(state->original[i]) == CFNumberGetTypeID() &&
            CFNumberGetValue(state->original[i], kCFNumberIntType, &originalValue))
            fprintf(stderr, "original_property=%s value=%d\n", property_name(i), originalValue);
        else if (state->original[i])
            fprintf(stderr, "original_property=%s value=nonnumeric original_preserved=true\n", property_name(i));
        else
            fprintf(stderr, "original_property=%s value=absent cleanup_fallback=0\n", property_name(i));
    }
    return 1;
}

static int cleanup_activation(Activation *state) {
    int failed = 0;
    // Restore reporting first. An absent value has no known exact inverse; reset to 0.
    const int order[3] = {0, 2, 1};
    for (int step = 0; step < 3; step++) {
        int i = order[step];
        if (state->changed[i]) {
            IOReturn result = state->original[i] ?
                IORegistryEntrySetCFProperty(state->driver, property(i), state->original[i]) :
                set_number(state->driver, i, 0);
            fprintf(stderr, "cleanup_property=%s result=0x%08x exact_original=%s\n",
                    property_name(i), result, state->original[i] ? "true" : "false");
            if (result) failed = 1;
        }
        if (state->original[i]) CFRelease(state->original[i]);
    }
    if (state->driver) IOObjectRelease(state->driver);
    return failed;
}

static int number(io_service_t service, CFStringRef key) {
    CFTypeRef value = IORegistryEntryCreateCFProperty(service, key, NULL, 0);
    int result = -1;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID())
        CFNumberGetValue(value, kCFNumberIntType, &result);
    if (value) CFRelease(value);
    return result;
}

static double axis(const uint8_t *data) {
    uint32_t bits = (uint32_t)data[0] | (uint32_t)data[1] << 8 |
                    (uint32_t)data[2] << 16 | (uint32_t)data[3] << 24;
    int32_t signedBits;
    memcpy(&signedBits, &bits, sizeof(bits));
    return signedBits / 65536.0;
}

static void report(void *context, IOReturn result, void *sender, IOHIDReportType type,
                   uint32_t reportID, uint8_t *bytes, CFIndex length, uint64_t timestamp) {
    (void)context; (void)sender; (void)type; (void)reportID;
    if (result != kIOReturnSuccess || length != 22 || timestamp == 0) { invalid++; return; }
    double time = timestamp * scale;
    double callbackTime = (double)mach_absolute_time() * scale;
    double lag = callbackTime - time;
    if (count && time <= last) { nonmonotonic++; return; }
    if (!count) first = time;
    else {
        double gap = time - last;
        minGap = fmin(minGap, gap); maxGap = fmax(maxGap, gap);
        sumGap += gap; sumGapSquared += gap * gap;
    }
    last = time; count++;
    minLag = fmin(minLag, lag); maxLag = fmax(maxLag, lag); sumLag += lag;
    double x = axis(bytes + 6), y = axis(bytes + 10), z = axis(bytes + 14);
    minZ = fmin(minZ, z); maxZ = fmax(maxZ, z);
    if (stream) {
        char line[160];
        int size = snprintf(line, sizeof(line), "%.9f,%.7f,%.7f,%.7f,%.9f\n", time, x, y, z, callbackTime);
        if (size <= 0 || size >= (int)sizeof(line) || write(STDOUT_FILENO, line, size) != size) dropped++;
    }
}

int main(int argc, char **argv) {
    int seconds = 10;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--stream")) stream = 1;
        else if (!strcmp(argv[i], "--activate")) activate = 1;
        else if (!strcmp(argv[i], "--seconds") && i + 1 < argc) {
            char *end; long value = strtol(argv[++i], &end, 10);
            if (*end || value < 1 || value > 120) { fprintf(stderr, "seconds must be 1..120\n"); return 64; }
            seconds = (int)value;
        } else { fprintf(stderr, "Usage: sensor-probe [--seconds 1..120] [--stream] [--activate]\n"); return 64; }
    }
    if (activate && (getuid() != 0 || seconds < 10)) {
        fprintf(stderr, "--activate requires root and at least 10 seconds\n"); return 64;
    }
    if (stream) {
        int qosResult = pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        fprintf(stderr, "stream_thread_qos=user_interactive result=%d\n", qosResult);
    }
    signal(SIGINT, stop); signal(SIGTERM, stop); signal(SIGPIPE, stop);
    mach_timebase_info_data_t base; mach_timebase_info(&base);
    scale = (double)base.numer / base.denom * 1e-9;
    io_iterator_t iterator = 0;
    IOReturn result = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSPUHIDDevice"), &iterator);
    if (result) { fprintf(stderr, "enumeration_error=0x%08x\n", result); return 2; }
    IOHIDDeviceRef device = NULL;
    io_service_t deviceService = 0;
    io_service_t service;
    while ((service = IOIteratorNext(iterator))) {
        if (number(service, CFSTR("PrimaryUsagePage")) == 0xff00 &&
            number(service, CFSTR("PrimaryUsage")) == 3) {
            device = IOHIDDeviceCreate(kCFAllocatorDefault, service);
            deviceService = service; break;
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    if (!device) {
        if (deviceService) IOObjectRelease(deviceService);
        fprintf(stderr, "accelerometer_not_found\n"); return 3;
    }
    fprintf(stderr, "accelerometer_found uid=%d passive_read=%s\n", getuid(), activate ? "false" : "true");
    result = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    fprintf(stderr, "open_result=0x%08x\n", result);
    if (result) { IOObjectRelease(deviceService); CFRelease(device); return 4; }
    Activation activation = {0};
    if (activate && !prepare_activation(deviceService, &activation)) {
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
        IOObjectRelease(deviceService); CFRelease(device);
        fprintf(stderr, "matched_accelerometer_driver_not_found; no properties changed\n"); return 6;
    }
    IOObjectRelease(deviceService);
    uint8_t buffer[4096];
    if (stream) {
        int flags = fcntl(STDOUT_FILENO, F_GETFL);
        if (flags >= 0) fcntl(STDOUT_FILENO, F_SETFL, flags | O_NONBLOCK);
    }
    IOHIDDeviceRegisterInputReportWithTimeStampCallback(device, buffer, sizeof(buffer), report, NULL);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    // A session expires across sleep too; sensor timestamps remain mach_absolute_time.
    double started = mach_continuous_time() * scale;
    double deadline = started + seconds;
    int phase = 0, activationFailed = 0;
    unsigned long phaseCount = 0;
    while (!stopped && mach_continuous_time() * scale < deadline) {
        if (activate && phase < 3 && mach_continuous_time() * scale - started >= (phase + 1) * 2) {
            fprintf(stderr, "phase=%d samples=%lu total_samples=%lu\n", phase, count - phaseCount, count);
            phaseCount = count;
            // Mark before setting so even a partially applied failing setter is rolled back.
            activation.changed[phase] = 1;
            IOReturn setResult = set_number(activation.driver, phase, phase == 2 ? 1000 : 1);
            fprintf(stderr, "activate_property=%s value=%d result=0x%08x\n",
                    property_name(phase), phase == 2 ? 1000 : 1, setResult);
            phase++;
            if (setResult) { activationFailed = 1; break; }
        }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
    }
    if (activate) fprintf(stderr, "phase=%d samples=%lu total_samples=%lu\n", phase, count - phaseCount, count);
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    CFRelease(device);
    int cleanupFailed = activate ? cleanup_activation(&activation) : 0;
    double mean = count > 1 ? sumGap / (count - 1) : 0;
    double deviation = count > 1 ? sqrt(fmax(0, sumGapSquared / (count - 1) - mean * mean)) : 0;
    FILE *output = stream ? stderr : stdout;
    fprintf(output, "{\"samples\":%lu,\"invalid_reports\":%lu,\"nonmonotonic\":%lu,\"stream_dropped\":%lu,"
                    "\"observation_elapsed_s\":%.6f,\"duration_s\":%.6f,\"rate_hz\":%.3f,\"gap_min_ms\":%.3f,\"gap_max_ms\":%.3f,"
                    "\"gap_stddev_ms\":%.3f,\"callback_lag_min_ms\":%.3f,\"callback_lag_mean_ms\":%.3f,"
                    "\"callback_lag_max_ms\":%.3f,\"z_min_g\":%.6f,\"z_max_g\":%.6f}\n",
            count, invalid, nonmonotonic, dropped, mach_continuous_time() * scale - started, count ? last - first : 0,
            mean > 0 ? 1 / mean : 0, count > 1 ? minGap * 1000 : 0, maxGap * 1000,
            deviation * 1000, count ? minLag * 1000 : 0, count ? sumLag / count * 1000 : 0,
            maxLag * 1000, count ? minZ : 0, count ? maxZ : 0);
    if (activationFailed || cleanupFailed) return 7;
    return count ? 0 : 5;
}
