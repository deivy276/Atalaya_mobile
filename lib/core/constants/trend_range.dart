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

  static TrendRange fromWireValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case '30m':
        return TrendRange.m30;
      case '2h':
        return TrendRange.h2;
      case '6h':
        return TrendRange.h6;
      case '8h':
        return TrendRange.h8;
      case '12h':
        return TrendRange.h12;
      case '24h':
        return TrendRange.h24;
      default:
        return TrendRange.m30;
    }
  }
}
