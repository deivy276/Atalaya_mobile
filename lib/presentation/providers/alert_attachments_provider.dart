import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attachment.dart';
import 'api_client_provider.dart';

final alertAttachmentsProvider =
    FutureProvider.autoDispose.family<List<Attachment>, String>((ref, alertId) async {
  final repository = ref.watch(atalayaRepositoryProvider);
  return repository.getAlertAttachments(alertId: alertId);
});
