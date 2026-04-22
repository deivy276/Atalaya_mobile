import 'package:flutter/material.dart';

import '../../data/services/comments_api_service.dart';
import '../widgets/operational_comments_panel.dart';

class CommentsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            ),
          ],
        ),
      ),
    );
  }
}
