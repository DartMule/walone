import '../../../core/storage.dart';

const ambientTitles = <String, String>{
  'rain': 'Дождь',
  'ocean': 'Океан',
  'train': 'Поезд',
  'cafe': 'Кафе',
  'wind': 'Ветер',
  'birds': 'Птицы',
  'seagulls': 'Чайки',
  'white': 'Белый шум',
  'pink': 'Розовый шум',
  'brown': 'Коричневый шум',
};

class SoundLayer {
  const SoundLayer({this.enabled = false, this.volume = 0.35});
  final bool enabled;
  final double volume;
  SoundLayer copyWith({bool? enabled, double? volume}) => SoundLayer(
    enabled: enabled ?? this.enabled,
    volume: volume ?? this.volume,
  );
  factory SoundLayer.fromJson(Map<String, dynamic> row) => SoundLayer(
    enabled: row['enabled'] as bool,
    volume: finiteNumber(row['volume'], max: 1),
  );
  Map<String, dynamic> toJson() => {'enabled': enabled, 'volume': volume};
}

class AtmosphereMix {
  AtmosphereMix({
    this.keyboardID = 'brown',
    this.keyboard = const SoundLayer(),
    Map<String, SoundLayer> layers = const {},
  }) : layers = Map.unmodifiable(layers);
  final String keyboardID;
  final SoundLayer keyboard;
  final Map<String, SoundLayer> layers;
  AtmosphereMix copyWith({
    String? keyboardID,
    SoundLayer? keyboard,
    Map<String, SoundLayer>? layers,
  }) => AtmosphereMix(
    keyboardID: keyboardID ?? this.keyboardID,
    keyboard: keyboard ?? this.keyboard,
    layers: layers ?? this.layers,
  );
  factory AtmosphereMix.fromJson(Map<String, dynamic> row) {
    final layers = jsonMap(
      row['layers'],
    ).map((id, value) => MapEntry(id, SoundLayer.fromJson(jsonMap(value))));
    if (layers.keys.any((id) => !ambientTitles.containsKey(id))) {
      throw const FormatException('Неизвестный фоновый звук');
    }
    return AtmosphereMix(
      keyboardID: row['keyboardID'] as String,
      keyboard: SoundLayer.fromJson(jsonMap(row['keyboard'])),
      layers: layers,
    );
  }
  Map<String, dynamic> toJson() => {
    'keyboardID': keyboardID,
    'keyboard': keyboard.toJson(),
    'layers': layers.map((id, layer) => MapEntry(id, layer.toJson())),
  };
}

class AtmospherePreset {
  const AtmospherePreset({
    required this.id,
    required this.name,
    required this.mix,
  });
  final String id;
  final String name;
  final AtmosphereMix mix;
  factory AtmospherePreset.fromJson(Map<String, dynamic> row) =>
      AtmospherePreset(
        id: row['id'] as String,
        name: checkedName(row['name'] as String),
        mix: AtmosphereMix.fromJson(jsonMap(row['mix'])),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mix': mix.toJson(),
  };
}
