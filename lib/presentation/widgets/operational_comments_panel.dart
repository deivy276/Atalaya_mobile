import 'package:flutter/material.dart';

import '../../data/models/operational_comment.dart';
import '../../data/services/comments_api_service.dart';

class OperationalCommentsPanel extends StatefulWidget {
  const OperationalCommentsPanel({
    super.key,
    required this.api,
    this.well = 'IXACHI-45',
    this.job,
    this.operationMode = 'drilling',
    this.limit = 20,
    this.compact = false,
    this.onOpenAttachments,
  });

  final CommentsApiService api;
  final String well;
  final String? job;
  final String operationMode;
  final int limit;
  final bool compact;

  /// Called when the user taps the attachment chip for a comment.
  ///
  /// The panel intentionally does not know how files are stored/opened.
  /// Wire this from the parent screen to:
  ///   GET /api/v1/attachments?entityType=comment&entityId=<comment.id>
  ///   GET /api/v1/attachments/<attachment.id>/download
  final ValueChanged<OperationalComment>? onOpenAttachments;

  @override
  State<OperationalCommentsPanel> createState() => _OperationalCommentsPanelState();
}

class _OperationalCommentsPanelState extends State<OperationalCommentsPanel> {
  late Future<List<OperationalComment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant OperationalCommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.well != widget.well ||
        oldWidget.job != widget.job ||
        oldWidget.operationMode != widget.operationMode ||
        oldWidget.limit != widget.limit ||
        oldWidget.api != widget.api) {
      _future = _load();
    }
  }

  Future<List<OperationalComment>> _load() {
    return widget.api.fetchComments(
      well: widget.well,
      job: widget.job,
      operationMode: widget.operationMode,
      limit: widget.limit,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openAllCommentsSheet(
    BuildContext context,
    List<OperationalComment> comments,
  ) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.90,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Todos los comentarios (${comments.length})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, index) => _CommentTile(
                      comment: comments[index],
                      onOpenAttachments: widget.onOpenAttachments,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.comment_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comentarios recientes',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar comentarios',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<OperationalComment>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return _MessageBox(
                    icon: Icons.warning_amber_outlined,
                    text: 'No se pudieron cargar los comentarios.\n${snapshot.error}',
                  );
                }

                final comments = snapshot.data ?? const <OperationalComment>[];
                if (comments.isEmpty) {
                  return const _MessageBox(
                    icon: Icons.chat_bubble_outline,
                    text: 'Sin comentarios recientes.',
                  );
                }

                final visible = widget.compact ? comments.take(3).toList(growable: false) : comments;
                return Column(
                  children: <Widget>[
                    for (final comment in visible)
                      _CommentTile(
                        comment: comment,
                        onOpenAttachments: widget.onOpenAttachments,
                      ),
                    if (widget.compact && comments.length > visible.length)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _openAllCommentsSheet(context, comments),
                          icon: const Icon(Icons.more_horiz),
                          label: Text('Ver ${comments.length - visible.length} más'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    this.onOpenAttachments,
  });

  final OperationalComment comment;
  final ValueChanged<OperationalComment>? onOpenAttachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = comment.createdAt;
    final subtitleParts = <String>[
      if (comment.author?.isNotEmpty == true) comment.author!,
      if (created != null) _formatDateTime(created),
      if (comment.job?.isNotEmpty == true) comment.job!,
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            comment.body,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitleParts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitleParts.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.72)),
            ),
          ],
          if (comment.tags.isNotEmpty || comment.attachmentsCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final tag in comment.tags.take(4)) Chip(label: Text(tag), visualDensity: VisualDensity.compact),
                if (comment.attachmentsCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.attach_file, size: 16),
                    label: Text('${comment.attachmentsCount}'),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Ver adjuntos',
                    onPressed: () {
                      final handler = onOpenAttachments;
                      if (handler != null) {
                        handler(comment);
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Adjuntos disponibles. Falta conectar el handler de descarga.'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
