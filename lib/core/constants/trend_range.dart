enum TrendRange {
  m30,
  h2,
  h6;

  String get label {
    switch (this) {
      case TrendRange.m30:
        return '30m';
      case TrendRange.h2:
        return '2h';
      case TrendRange.h6:
        return '6h';
    }
  }

  Duration get duration {
    switch (this) {
      case TrendRange.m30:
        return const Duration(minutes: 30);
      case TrendRange.h2:
        return const Duration(hours: 2);
      case TrendRange.h6:
        return const Duration(hours: 6);
    }
  }

  static TrendRange fromWireValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case '30m':
        return TrendRange.m30;
      case '6h':
        return TrendRange.h6;
      case '2h':
      default:
        return TrendRange.h2;
    }
  }
}
