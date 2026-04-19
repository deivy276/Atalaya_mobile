class UnitConverter {
  const UnitConverter._();

  static const double psiToBar = 0.0689475729;
  static const double mToFt = 3.280839895;
  static const double m3ToBbl = 6.289810770432105;
  static const double lbfToN = 4.4482216152605;
  static const double lbfPerMetricTon = 2204.6226218487757;
  static const double lbfPerShortTon = 2000.0;
  static const double gpmToLpm = 3.785411784;
  static const double kgfToLbf = 2.2046226218487757;
  static const double ftLbfToNm = 1.3558179483314004;

  static String normKey(String raw) => raw.trim().toUpperCase();

  static String normTag(String raw) {
    var value = raw.trim();
    while (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
    return value.trim();
  }

  static String normUnit(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return '';

    var normalized = trimmed.toLowerCase();
    normalized = normalized.replaceAll('^', '');
    normalized = normalized.replaceAll(' ', '');

    if (normalized == 'lb' || normalized == 'lbs' || normalized == 'lbf') return 'lbs';
    if (normalized == 'klbf' || normalized == 'kips') return 'klbf';
    if (normalized == 'kn' || normalized == 'knf') return 'kN';
    if (normalized == 'kgf' || normalized == 'kilogramforce' || normalized == 'kilogram-force') return 'kgf';
    if (normalized.contains('ton(us') || normalized.contains('tonus') || normalized.contains('shortton')) return 'ton (US)';
    if (normalized == 'ton') return 'ton';

    if (normalized == 'psi' || normalized == 'psia') return 'psi';
    if (normalized == 'bar') return 'bar';
    if (normalized == 'kpa') return 'kPa';
    if (normalized == 'mpa') return 'MPa';

    if (normalized == 'm' || normalized == 'meter' || normalized == 'metre') return 'm';
    if (normalized == 'ft' || normalized == 'feet') return 'ft';

    if (normalized == 'm/min' || normalized == 'mpermin' || normalized == 'mmin') return 'm/min';
    if (normalized == 'ft/min' || normalized == 'ftpermin' || normalized == 'ftmin') return 'ft/min';

    if (normalized == 'm3/min' || normalized == 'm³/min' || normalized == 'm3min' || normalized == 'm3permin') return 'm3/min';
    if (normalized == 'bbl/min' || normalized == 'bblmin' || normalized == 'bblpermin' || normalized == 'bpm') return 'bbl/min';
    if (normalized == 'gpm' || normalized == 'gal/min' || normalized == 'gallon/min') return 'gpm';
    if (normalized == 'lpm' || normalized == 'l/min' || normalized == 'liter/min' || normalized == 'litre/min') return 'lpm';

    if (normalized == 'ft-lbf' || normalized == 'ftlb' || normalized == 'ft-lb' || normalized == 'lb-ft') return 'ft-lbf';
    if (normalized == 'nm' || normalized == 'n·m' || normalized == 'newtonmeter' || normalized == 'newton-meter') return 'N·m';

    if (normalized == 'c' || normalized == '°c' || normalized == 'degc') return '°C';
    if (normalized == 'f' || normalized == '°f' || normalized == 'degf') return '°F';

    return trimmed;
  }

  static String unitDimension(String? unit) {
    final normalized = normUnit(unit);
    if (normalized == 'psi' || normalized == 'bar' || normalized == 'kPa' || normalized == 'MPa') return 'pressure';
    if (normalized == 'm' || normalized == 'ft') return 'length';
    if (normalized == 'm/min' || normalized == 'ft/min') return 'velocity';
    if (normalized == 'm3/min' || normalized == 'bbl/min' || normalized == 'gpm' || normalized == 'lpm') return 'flow';
    if (normalized == 'lbs' || normalized == 'klbf' || normalized == 'kN' || normalized == 'kgf' || normalized == 'ton' || normalized == 'ton (US)') return 'force';
    if (normalized == 'ft-lbf' || normalized == 'N·m') return 'torque';
    if (normalized == '°C' || normalized == '°F') return 'temperature';
    return '';
  }

  static double convertValue(double value, String? fromUnit, String? toUnit) {
    final from = normUnit(fromUnit);
    final to = normUnit(toUnit);
    if (from.isEmpty || to.isEmpty || from == to) return value;

    final fromDimension = unitDimension(from);
    if (fromDimension != unitDimension(to)) return value;

    if (fromDimension == 'pressure') {
      if (from == 'psi' && to == 'bar') return value * psiToBar;
      if (from == 'bar' && to == 'psi') return value / psiToBar;
      if (from == 'psi' && to == 'kPa') return value * 6.89475729;
      if (from == 'kPa' && to == 'psi') return value / 6.89475729;
      if (from == 'psi' && to == 'MPa') return value * 0.00689475729;
      if (from == 'MPa' && to == 'psi') return value / 0.00689475729;
      if (from == 'bar' && to == 'kPa') return value * 100.0;
      if (from == 'kPa' && to == 'bar') return value / 100.0;
      if (from == 'bar' && to == 'MPa') return value / 10.0;
      if (from == 'MPa' && to == 'bar') return value * 10.0;
      if (from == 'kPa' && to == 'MPa') return value / 1000.0;
      if (from == 'MPa' && to == 'kPa') return value * 1000.0;
      return value;
    }

    if (fromDimension == 'length') {
      if (from == 'm' && to == 'ft') return value * mToFt;
      if (from == 'ft' && to == 'm') return value / mToFt;
      return value;
    }

    if (fromDimension == 'velocity') {
      if (from == 'm/min' && to == 'ft/min') return value * mToFt;
      if (from == 'ft/min' && to == 'm/min') return value / mToFt;
      return value;
    }

    if (fromDimension == 'flow') {
      if (from == 'm3/min' && to == 'bbl/min') return value * m3ToBbl;
      if (from == 'bbl/min' && to == 'm3/min') return value / m3ToBbl;
      if (from == 'gpm' && to == 'lpm') return value * gpmToLpm;
      if (from == 'lpm' && to == 'gpm') return value / gpmToLpm;
      return value;
    }

    if (fromDimension == 'force') {
      double? lbs;
      if (from == 'lbs') {
        lbs = value;
      } else if (from == 'klbf') {
        lbs = value * 1000.0;
      } else if (from == 'kN') {
        lbs = (value * 1000.0) / lbfToN;
      } else if (from == 'kgf') {
        lbs = value * kgfToLbf;
      } else if (from == 'ton') {
        lbs = value * lbfPerMetricTon;
      } else if (from == 'ton (US)') {
        lbs = value * lbfPerShortTon;
      }
      if (lbs == null) return value;
      if (to == 'lbs') return lbs;
      if (to == 'klbf') return lbs / 1000.0;
      if (to == 'kN') return (lbs * lbfToN) / 1000.0;
      if (to == 'kgf') return lbs / kgfToLbf;
      if (to == 'ton') return lbs / lbfPerMetricTon;
      if (to == 'ton (US)') return lbs / lbfPerShortTon;
      return value;
    }

    if (fromDimension == 'torque') {
      if (from == 'ft-lbf' && to == 'N·m') return value * ftLbfToNm;
      if (from == 'N·m' && to == 'ft-lbf') return value / ftLbfToNm;
      return value;
    }

    if (fromDimension == 'temperature') {
      if (from == '°C' && to == '°F') return (value * 9.0 / 5.0) + 32.0;
      if (from == '°F' && to == '°C') return (value - 32.0) * 5.0 / 9.0;
      return value;
    }

    return value;
  }

  static String makePrefKey({
    required int slotIndex,
    required String tag,
    required String rawUnit,
    required String well,
    required String job,
  }) {
    final slotKey = 'SLOT${slotIndex + 1}';
    return <String>[
      normKey(well),
      normKey(job),
      slotKey,
      normTag(tag),
      normUnit(rawUnit),
    ].join('|');
  }

  static List<String> getUnitOptions(String? rawUnit) {
    final normalized = normUnit(rawUnit);
    if (normalized.isEmpty) return const [];
    final dimension = unitDimension(normalized);
    late final List<String> options;
    if (dimension == 'pressure') {
      options = <String>['RAW', normalized, 'bar', 'psi', 'MPa', 'kPa'];
    } else if (dimension == 'length') {
      options = <String>['RAW', normalized, 'm', 'ft'];
    } else if (dimension == 'velocity') {
      options = <String>['RAW', normalized, 'm/min', 'ft/min'];
    } else if (dimension == 'flow') {
      options = <String>['RAW', normalized, 'm3/min', 'bbl/min', 'gpm', 'lpm'];
    } else if (dimension == 'force') {
      options = <String>['RAW', normalized, 'lbs', 'klbf', 'kgf', 'kN', 'ton', 'ton (US)'];
    } else if (dimension == 'torque') {
      options = <String>['RAW', normalized, 'ft-lbf', 'N·m'];
    } else if (dimension == 'temperature') {
      options = <String>['RAW', normalized, '°C', '°F'];
    } else {
      options = <String>['RAW', normalized];
    }

    final seen = <String>{};
    final unique = <String>[];
    for (final option in options) {
      final normalizedOption = option.toUpperCase() == 'RAW' ? 'RAW' : normUnit(option);
      if (normalizedOption.isEmpty || seen.contains(normalizedOption)) continue;
      seen.add(normalizedOption);
      unique.add(normalizedOption);
    }
    return unique;
  }

  static String resolveDisplayUnit({
    required int slotIndex,
    required String tag,
    required String rawUnit,
    required String well,
    required String job,
    required Map<String, String> preferences,
  }) {
    final normalizedRaw = normUnit(rawUnit);
    if (normalizedRaw.isEmpty) return '';
    final prefKey = makePrefKey(
      slotIndex: slotIndex,
      tag: tag,
      rawUnit: normalizedRaw,
      well: well,
      job: job,
    );
    final rawPreference = preferences[prefKey] ?? 'RAW';
    final normalizedPref = rawPreference.toUpperCase() == 'RAW' ? 'RAW' : normUnit(rawPreference);
    if (normalizedPref == 'RAW' || normalizedPref.isEmpty) return normalizedRaw;
    final validOptions = getUnitOptions(normalizedRaw);
    if (!validOptions.contains(normalizedPref)) return normalizedRaw;
    return normalizedPref;
  }

  static String formatNumber(num? value) {
    if (value == null) return '---';
    final number = value.toDouble();
    final absValue = number.abs();
    if (absValue >= 1000) return number.toStringAsFixed(0);
    if (absValue >= 100) return number.toStringAsFixed(0);
    if (absValue >= 1) return number.toStringAsFixed(1);
    return number.toStringAsFixed(3);
  }
}
