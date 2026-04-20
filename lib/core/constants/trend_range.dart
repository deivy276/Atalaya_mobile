enum TrendRange {
  m30('30m', '30 min', Duration(minutes: 30)),
  h2('2h', '2 horas', Duration(hours: 2)),
  h6('6h', '6 horas', Duration(hours: 6)),
  h8('8h', '8 horas', Duration(hours: 8)),
  h12('12h', '12 horas', Duration(hours: 12)),
  h24('24h', '24 horas', Duration(hours: 24));

  const TrendRange(this.label, this.displayLabel, this.duration);

  final String label;
  final String displayLabel;
  final Duration duration;

  String get wireValue => label;

  static TrendRange fromWireValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case '30m':
      case '30min':
      case '30 min':
      case 'm30':
        return TrendRange.m30;
      case '2h':
      case '2hr':
      case '2 horas':
      case 'h2':
        return TrendRange.h2;
      case '6h':
      case '6hr':
      case '6 horas':
      case 'h6':
        return TrendRange.h6;
      case '8h':
      case '8hr':
      case '8 horas':
      case 'h8':
        return TrendRange.h8;
      case '12h':
      case '12hr':
      case '12 horas':
      case 'h12':
        return TrendRange.h12;
      case '24h':
      case '24hr':
      case '24 horas':
      case '1d':
      case 'h24':
        return TrendRange.h24;
      default:
        return TrendRange.m30;
    }
  }
}
