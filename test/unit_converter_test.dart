import 'package:flutter_test/flutter_test.dart';

import 'package:atalaya_mobile/core/utils/unit_converter.dart';

void main() {
  group('UnitConverter', () {
    test('preserves legacy pressure coefficients', () {
      expect(UnitConverter.convertValue(1, 'psi', 'bar'), closeTo(0.0689475729, 1e-12));
      expect(UnitConverter.convertValue(1, 'psi', 'kPa'), closeTo(6.89475729, 1e-10));
      expect(UnitConverter.convertValue(1, 'psi', 'MPa'), closeTo(0.00689475729, 1e-12));
    });

    test('converts force through lbs baseline', () {
      expect(UnitConverter.convertValue(1, 'klbf', 'lbs'), closeTo(1000, 1e-9));
      expect(UnitConverter.convertValue(1, 'ton (US)', 'lbs'), closeTo(2000, 1e-9));
    });

    test('builds preference key with well and job context', () {
      final key = UnitConverter.makePrefKey(
        slotIndex: 0,
        tag: 'SPP.',
        rawUnit: 'psi',
        well: 'Ixachi-45',
        job: 'Drilling',
      );

      expect(key, 'IXACHI-45|DRILLING|SLOT1|SPP|psi');
    });
  });
}
