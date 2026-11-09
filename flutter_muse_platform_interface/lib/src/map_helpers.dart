// Helpers for decoding standard-codec values. Not exported.

/// Converts a platform-channel map (`Map<Object?, Object?>`) to a typed map.
Map<String, Object?> castMap(Object? value) => (value! as Map<Object?, Object?>).cast<String, Object?>();

/// Reads an enum sent as its index (the Java ordinal).
T enumAt<T extends Enum>(List<T> values, Object? index) => values[index! as int];

/// Reads an enum sent as its index that may be null.
T? enumAtOrNull<T extends Enum>(List<T> values, Object? index) => index == null ? null : values[index as int];
