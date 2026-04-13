import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atalaya_mobile/presentation/providers/layout_order_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LayoutOrderController', () {
    test('persists and reads order by well/job context', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(layoutOrderControllerProvider.notifier);
      await controller.setOrder(
        well: 'Ixachi-45',
        job: 'Monitoreo',
        slotOrder: const <int>[3, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      );

      final stored = controller.getOrder(well: 'IXACHI-45', job: 'MONITOREO');
      expect(stored, isNotNull);
      expect(stored!.take(4).toList(), <int>[3, 1, 2, 4]);
    });

    test('reset removes only target context order', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(layoutOrderControllerProvider.notifier);
      await controller.setOrder(
        well: 'Ixachi-45',
        job: 'Monitoreo',
        slotOrder: const <int>[2, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      );
      await controller.setOrder(
        well: 'Ixachi-46',
        job: 'Monitoreo',
        slotOrder: const <int>[1, 3, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      );

      await controller.resetOrder(well: 'Ixachi-45', job: 'Monitoreo');

      expect(controller.getOrder(well: 'Ixachi-45', job: 'Monitoreo'), isNull);
      expect(controller.getOrder(well: 'Ixachi-46', job: 'Monitoreo'), isNotNull);
    });
  });
}
