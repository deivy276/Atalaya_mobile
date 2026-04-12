import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:intl/intl.dart';

import '../../core/constants/trend_range.dart';
import '../../core/theme/pro_palette.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/alert.dart';
import '../../data/models/attachment.dart';
import '../../data/models/dashboard_payload.dart';
import '../../data/models/well_variable.dart';
import '../providers/alert_attachments_provider.dart';
import '../providers/dashboard_controller.dart';
import '../providers/trend_controller.dart';
import '../providers/unit_preferences_controller.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/trend_chart_widget.dart';
import '../widgets/variable_tile.dart';

final selectedTrendRangeProvider =
    StateProvider.autoDispose.family<TrendRange, String>((ref, tag) => TrendRange.h2);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Atalaya Mobile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
            icon: dashboardAsync.asData?.value.isRefreshing == true
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DashboardErrorState(
          message: error.toString(),
          onRetry: () => ref.read(dashboardControllerProvider.notifier).retryNow(),
        ),
        data: (viewState) {
          final payload = viewState.payload;
          final variables = _normalizeTo12Slots(payload.variables);

          return RefreshIndicator(
            color: ProPalette.accent,
            onRefresh: () => ref.read(dashboardControllerProvider.notifier).forceRefresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: _HeaderCard(viewState: viewState),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'LIVE VARIABLES (tap for trend)',
                      style: TextStyle(
                        color: ProPalette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final variable = variables[index];
                        return VariableTile(
                          variable: variable,
                          well: payload.well,
                          job: payload.job,
                          unitPreferences: unitPrefs,
                          onTap: () => _openTrendBottomSheet(
                            context: context,
                            ref: ref,
                            payload: payload,
                            variable: variable,
                          ),
                        );
                      },
                      childCount: variables.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'ALERTS & COMMENTS',
                      style: TextStyle(
                        color: ProPalette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ProPalette.panel,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ProPalette.stroke),
                      ),
                      child: payload.alerts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  'Sin alertas recientes.',
                                  style: TextStyle(
                                    color: ProPalette.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: payload.alerts
                                  .map(
                                    (alert) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: AlertCard(
                                        alert: alert,
                                        isNew: viewState.newAlertIds.contains(alert.id),
                                        onTap: () => _openAlertBottomSheet(
                                          context: context,
                                          alert: alert,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<WellVariable> _normalizeTo12Slots(List<WellVariable> variables) {
    final bySlot = <int, WellVariable>{
      for (final variable in variables) variable.slot: variable,
    };
    return List<WellVariable>.generate(
      12,
      (index) => bySlot[index + 1] ?? WellVariable.empty(index + 1),
      growable: false,
    );
  }

  Future<void> _openTrendBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required DashboardPayload payload,
    required WellVariable variable,
  }) async {
    if (!variable.configured || variable.tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta variable no está configurada.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrendBottomSheet(
        payload: payload,
        variable: variable,
      ),
    );
  }

  Future<void> _openAlertBottomSheet({
    required BuildContext context,
    required AtalayaAlert alert,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlertDetailBottomSheet(alert: alert),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.viewState});

  final DashboardViewState viewState;

  @override
  Widget build(BuildContext context) {
    final latest = viewState.payload.latestSampleAt;
    final lastDataText = latest == null
        ? '---'
        : '${DateFormat('yyyy-MM-dd HH:mm:ss').format(latest.toLocal())} • '
            '${DateTime.now().toUtc().difference(latest.toUtc()).inSeconds}s';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProPalette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.oil_barrel_rounded,
                  color: ProPalette.bg,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _HeaderInfoRow(label: 'Well:', value: viewState.payload.well, accent: true),
                    _HeaderInfoRow(label: 'Job:', value: viewState.payload.job),
                    _HeaderInfoRow(label: 'Last:', value: lastDataText, small: true),
                  ],
                ),
              ),
              StatusChip(status: viewState.connectionStatus),
            ],
          ),
          if (viewState.errorMessage != null && viewState.errorMessage!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ProPalette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ProPalette.stroke),
              ),
              child: Text(
                viewState.errorMessage!,
                style: const TextStyle(
                  color: ProPalette.warn,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderInfoRow extends StatelessWidget {
  const _HeaderInfoRow({
    required this.label,
    required this.value,
    this.small = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool small;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: ProPalette.muted,
              fontSize: small ? 10 : 11,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent ? ProPalette.accent : ProPalette.text,
                fontSize: small ? 10 : 12,
                fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBottomSheet extends ConsumerWidget {
  const _TrendBottomSheet({required this.payload, required this.variable});

  final DashboardPayload payload;
  final WellVariable variable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedTrendRangeProvider(variable.tag));
    final unitPrefs = ref.watch(unitPreferencesControllerProvider);
    final displayUnit = UnitConverter.resolveDisplayUnit(
      slotIndex: variable.slot - 1,
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      well: payload.well,
      job: payload.job,
      preferences: unitPrefs,
    );
    final unitOptions = UnitConverter.getUnitOptions(variable.rawUnit);
    final preferenceKey = UnitConverter.makePrefKey(
      slotIndex: variable.slot - 1,
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      well: payload.well,
      job: payload.job,
    );
    final selectedPreference = (unitPrefs[preferenceKey] ?? 'RAW').toUpperCase() == 'RAW'
        ? 'RAW'
        : UnitConverter.normUnit(unitPrefs[preferenceKey]);

    final trendRequest = TrendRequest(
      tag: variable.tag,
      rawUnit: variable.rawUnit,
      displayUnit: displayUnit,
      range: selectedRange,
    );
    final trendAsync = ref.watch(trendSeriesProvider(trendRequest));

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: ProPalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ProPalette.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'TREND ${selectedRange.label}',
                          style: const TextStyle(
                            color: ProPalette.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${variable.label}${displayUnit.isEmpty ? '' : ' ($displayUnit)'} • Tag: ${variable.tag}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ProPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Text(
                    'Units:',
                    style: TextStyle(
                      color: ProPalette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: unitOptions.contains(selectedPreference)
                          ? selectedPreference
                          : (unitOptions.isEmpty ? null : unitOptions.first),
                      items: unitOptions
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit == 'RAW' ? 'RAW (${variable.rawUnit})' : unit),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: unitOptions.isEmpty
                          ? null
                          : (selection) {
                              if (selection == null) return;
                              ref.read(unitPreferencesControllerProvider.notifier).setPreference(preferenceKey, selection);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TrendRangeSelector(
                selected: selectedRange,
                onChanged: (range) => ref.read(selectedTrendRangeProvider(variable.tag).notifier).state = range,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 14,
                runSpacing: 8,
                children: <Widget>[
                  _LegendItem(color: ProPalette.accent, label: 'Signal'),
                  _LegendItem(color: ProPalette.warn, label: 'Avg (last 30m)'),
                  _LegendItem(color: ProPalette.ok, label: 'Last'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: trendAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Error cargando tendencia: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ProPalette.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  data: (series) => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TrendChartWidget(series: series),
                        const SizedBox(height: 12),
                        TrendStatsWrap(series: series),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertDetailBottomSheet extends ConsumerWidget {
  const _AlertDetailBottomSheet({required this.alert});

  final AtalayaAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(alertAttachmentsProvider(alert.id));
    final severity = _severityVisual(alert.severity);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: ProPalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ProPalette.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'ALERT',
                      style: TextStyle(
                        color: ProPalette.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Text(
                    'Time:',
                    style: TextStyle(color: ProPalette.muted, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.createdAt.toLocal()),
                      style: const TextStyle(color: ProPalette.muted, fontSize: 11),
                    ),
                  ),
                  _SeverityChip(label: severity.label, color: severity.color),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(
                  color: ProPalette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ProPalette.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ProPalette.stroke),
                ),
                child: SelectableText(
                  alert.description,
                  style: const TextStyle(color: ProPalette.text, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Attachments (${alert.attachmentsCount})',
                style: const TextStyle(
                  color: ProPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ProPalette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ProPalette.stroke),
                  ),
                  child: attachmentsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text(
                        'Error cargando adjuntos: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ProPalette.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    data: (attachments) {
                      if (attachments.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay adjuntos disponibles para esta alerta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ProPalette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _AttachmentTile(attachment: attachments[index]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _AlertVisual _severityVisual(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const _AlertVisual(ProPalette.danger, 'CRIT');
      case AlertSeverity.attention:
        return const _AlertVisual(ProPalette.warn, 'ATTN');
      case AlertSeverity.ok:
        return const _AlertVisual(ProPalette.ok, 'OK');
    }
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final sizeText = _formatBytes(attachment.sizeBytes);
    final createdText = attachment.createdAt == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(attachment.createdAt!.toLocal());
    final meta = <String>[
      if (attachment.mimeType.trim().isNotEmpty) attachment.mimeType,
      if (sizeText.isNotEmpty) sizeText,
      if (createdText.isNotEmpty) createdText,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ProPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ProPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (meta.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ProPalette.muted, fontSize: 10),
            ),
          ],
          if (attachment.url.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            SelectableText(
              attachment.url,
              maxLines: 2,
              style: TextStyle(
                color: attachment.hasSecureUrl ? ProPalette.accent : ProPalette.warn,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int? value) {
    if (value == null || value <= 0) return '';
    if (value >= 1024 * 1024) return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '$value B';
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ProPalette.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProPalette.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: ProPalette.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.wifi_off_rounded, color: ProPalette.danger, size: 44),
            const SizedBox(height: 12),
            const Text(
              'No fue posible cargar el dashboard.',
              style: TextStyle(
                color: ProPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ProPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertVisual {
  const _AlertVisual(this.color, this.label);

  final Color color;
  final String label;
}
