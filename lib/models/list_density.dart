/// Density preference for list chrome (thread cards / post floors).
enum ListDensity {
  standard,
  compact;

  String get storageKey {
    switch (this) {
      case ListDensity.standard:
        return 'standard';
      case ListDensity.compact:
        return 'compact';
    }
  }

  String get backupKey => storageKey;

  /// Maps stored / backup values. Unknown / null → [standard].
  static ListDensity fromStored(String? value) {
    switch (value) {
      case 'compact':
        return ListDensity.compact;
      case 'standard':
      default:
        return ListDensity.standard;
    }
  }

  static ListDensity fromBackup(String? value) => fromStored(value);
}
