import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../data/models/operational_comment.dart';
import '../../data/services/comments_api_service.dart';
import '../providers/api_client_provider.dart';
import '../widgets/operational_comments_panel.dart';

class CommentsScreen extends ConsumerWidget {
  const CommentsScreen({
    super.key,
    required this.api,
    this.well = 'IXACHI-45',
    this.job,
  });

  final CommentsApiService api;
  final String well;
  final String? job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comentarios operativos')),
      body: RefreshIndicator(
        onRefresh: () async {
          // The panel owns its own refresh button. Pull-to-refresh can be wired
          // later through a controller if the project uses one.
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            OperationalCommentsPanel(
              api: api,
              well: well,
              job: job,
              limit: 50,
              onOpenAttachments: (comment) => _openCommentAttachments(context, ref, comment),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCommentAttachments(
    BuildContext context,
    WidgetRef ref,
    OperationalComment comment,
  ) async {
    final dio = ref.read(dioProvider);

    try {
      final response = await dio.get<dynamic>(
        '/api/v1/attachments',
        queryParameters: <String, String>{
          'entityType': 'comment',
          'entityId': comment.id,
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        options: Options(
          headers: const <String, String>{
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );

      final data = response.data;
      final rawItems = data is Map<String, dynamic> ? data['items'] : null;
      final items = (rawItems as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);

      if (!context.mounted) {
        return;
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay adjuntos para este comentario.')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = items[index];
                final id = '${item['id'] ?? ''}';
                final fileName = '${item['fileName'] ?? 'attachment'}';
                final contentType = '${item['contentType'] ?? ''}';
                final sizeBytes = item['sizeBytes'];

                return ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    <String>[
                      if (contentType.isNotEmpty) contentType,
                      if (sizeBytes != null) '$sizeBytes bytes',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.download_rounded),
                  onTap: id.isEmpty
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await _downloadCommentAttachment(context, ref, id, fileName);
                        },
                );
              },
            ),
          );
        },
      );
    } catch (err) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los adjuntos: $err')),
      );
    }
  }

  Future<void> _downloadCommentAttachment(
    BuildContext context,
    WidgetRef ref,
    String attachmentId,
    String fileName,
  ) async {
    final dio = ref.read(dioProvider);
    final safeName = _safeDownloadFileName(fileName);
    final targetDir = await Directory.systemTemp.createTemp('atalaya_attachment_');
    final targetPath = '${targetDir.path}${Platform.pathSeparator}$safeName';

    try {
      await dio.download(
        '/api/v1/attachments/$attachmentId/download',
        targetPath,
        options: Options(
          headers: const <String, String>{
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );

      final result = await OpenFilex.open(targetPath);
      if (!context.mounted) {
        return;
      }
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adjunto descargado en: $targetPath')),
        );
      }
    } catch (err) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el adjunto: $err')),
      );
    }
  }

  static String _safeDownloadFileName(String fileName) {
    final cleaned = fileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'attachment' : cleaned;
  }
}
