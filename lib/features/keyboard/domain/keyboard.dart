class KeyboardPack {
  const KeyboardPack({
    required this.id,
    required this.title,
    required this.detail,
    required this.author,
    required this.keyCount,
  });

  final String id;
  final String title;
  final String detail;
  final String author;
  final int keyCount;
}

class KeyboardStatus {
  const KeyboardStatus({
    this.hasPermission = false,
    this.listening = false,
    this.secureInput = false,
    this.enabled = false,
    this.receivedKeys = 0,
    this.error,
  });

  final bool hasPermission;
  final bool listening;
  final bool secureInput;
  final bool enabled;
  final int receivedKeys;
  final String? error;

  @override
  bool operator ==(Object other) =>
      other is KeyboardStatus &&
      hasPermission == other.hasPermission &&
      listening == other.listening &&
      secureInput == other.secureInput &&
      enabled == other.enabled &&
      receivedKeys == other.receivedKeys &&
      error == other.error;

  @override
  int get hashCode => Object.hash(
    hasPermission,
    listening,
    secureInput,
    enabled,
    receivedKeys,
    error,
  );
}

class KeyboardUsage {
  const KeyboardUsage({required this.packID, required this.lastUsed});
  final String packID;
  final DateTime lastUsed;

  factory KeyboardUsage.fromJson(Map<String, dynamic> row) => KeyboardUsage(
    packID: row['packID'] as String,
    lastUsed: DateTime.parse(row['lastUsed'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'packID': packID,
    'lastUsed': lastUsed.toUtc().toIso8601String(),
  };
}

abstract interface class KeyboardRepository {
  Future<List<KeyboardPack>> loadCatalog();
  Future<KeyboardStatus> initialize();
  Future<KeyboardStatus> status();
  Future<void> configure(KeyboardPack pack, bool enabled, double volume);
  Future<void> preview();
  Future<void> requestPermission();
  Future<void> dispose();
}
