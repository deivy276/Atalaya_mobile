import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/security/session_secure_storage.dart';
import '../../../core/theme/layout_tokens.dart';
import '../../../core/theme/pro_palette.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/well_variable.dart';
import '../../providers/alert_settings_controller.dart';
import '../../providers/app_settings_controller.dart';
import '../../providers/dashboard_controller.dart';

class AtalayaSettingsPanel extends ConsumerStatefulWidget {
  const AtalayaSettingsPanel({
    super.key,
    this.onLogout,
    this.onOpenLayoutControls,
  });

  final VoidCallback? onLogout;
  final VoidCallback? onOpenLayoutControls;

  @override
  ConsumerState<AtalayaSettingsPanel> createState() => _AtalayaSettingsPanelState();
}

class _AtalayaSettingsPanelState extends ConsumerState<AtalayaSettingsPanel> {
  final TextEditingController _alarmThresholdController = TextEditingController(text: '2000');
  String? _selectedAlarmTag;
  AtalayaAlarmOperator _alarmOperator = AtalayaAlarmOperator.greaterOrEqual;
  bool _alarmVisual = true;
  bool _alarmSound = true;

  @override
  void dispose() {
    _alarmThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(appSettingsControllerProvider);
    final alertSettings = ref.watch(alertSettingsControllerProvider);
    final dashboard = ref.watch(dashboardControllerProvider).value;
    final variables = dashboard?.payload.variables.where((item) => item.configured).toList(growable: false) ??
        const <WellVariable>[];

    _selectedAlarmTag ??= variables.isNotEmpty ? variables.first.tag : null;

    return Container(
      decoration: const BoxDecoration(
        color: LayoutTokens.bgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: LayoutTokens.dividerSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.55,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: LayoutTokens.textMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Configuración',
                        style: TextStyle(
                          color: LayoutTokens.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close_rounded, color: LayoutTokens.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Preferencias locales para operación en campo.',
                  style: TextStyle(color: LayoutTokens.textMuted),
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Preferencias de interfaz',
                  icon: Icons.palette_outlined,
                  children: <Widget>[
                    _ThemePreferenceSelector(
                      selected: appSettings.themePreference,
                      onChanged: ref.read(appSettingsControllerProvider.notifier).setThemePreference,
                    ),
                    _SettingsSegmentedRow<AtalayaLanguage>(
                      label: 'Idioma de la app',
                      selected: appSettings.language,
                      values: AtalayaLanguage.values,
                      labelBuilder: (value) => value.label,
                      onChanged: ref.read(appSettingsControllerProvider.notifier).setLanguage,
                    ),
                    if (widget.onOpenLayoutControls != null)
                      _SettingsActionTile(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Layout del dashboard',
                        subtitle: 'Densidad y vista de tarjetas.',
                        actionLabel: 'Abrir',
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Future<void>.delayed(const Duration(milliseconds: 160));
                          widget.onOpenLayoutControls?.call();
                        },
                      ),
                  ],
                ),
                _SettingsSection(
                  title: 'Parámetros operativos',
                  icon: Icons.tune_rounded,
                  children: <Widget>[
                    _SettingsSegmentedRow<AtalayaUnitSystem>(
                      label: 'Sistema de unidades',
                      selected: appSettings.unitSystem,
                      values: AtalayaUnitSystem.values,
                      labelBuilder: (value) => value.label,
                      subtitleBuilder: (value) => value.description,
                      onChanged: ref.read(appSettingsControllerProvider.notifier).setUnitSystem,
                    ),
                    _PollingSelector(
                      selectedSeconds: appSettings.pollingIntervalSeconds,
                      onChanged: (seconds) async {
                        await ref.read(appSettingsControllerProvider.notifier).setPollingIntervalSeconds(seconds);
                        ref.invalidate(dashboardControllerProvider);
                      },
                    ),
                  ],
                ),
                _SettingsSection(
                  title: 'Alarmas y notificaciones',
                  icon: Icons.notifications_active_outlined,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: appSettings.pushAlertsEnabled && alertSettings.enabled,
                      activeColor: LayoutTokens.accentGreen,
                      title: const Text('Alertas push', style: TextStyle(color: LayoutTokens.textPrimary)),
                      subtitle: const Text(
                        'Activa eventos críticos del pozo en el teléfono.',
                        style: TextStyle(color: LayoutTokens.textMuted),
                      ),
                      onChanged: (value) async {
                        await ref.read(appSettingsControllerProvider.notifier).setPushAlertsEnabled(value);
                        await ref.read(alertSettingsControllerProvider.notifier).setEnabled(value);
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: alertSettings.visual,
                      activeColor: LayoutTokens.accentGreen,
                      title: const Text('Alerta visual', style: TextStyle(color: LayoutTokens.textPrimary)),
                      subtitle: const Text('Banner/modal cuando llegue un evento notificado.', style: TextStyle(color: LayoutTokens.textMuted)),
                      onChanged: ref.read(alertSettingsControllerProvider.notifier).setVisual,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: alertSettings.sound,
                      activeColor: LayoutTokens.accentGreen,
                      title: const Text('Alerta sonora', style: TextStyle(color: LayoutTokens.textPrimary)),
                      subtitle: const Text('Preparado para integración con notificaciones nativas.', style: TextStyle(color: LayoutTokens.textMuted)),
                      onChanged: ref.read(alertSettingsControllerProvider.notifier).setSound,
                    ),
                    const SizedBox(height: 12),
                    _AlarmEditor(
                      variables: variables,
                      selectedTag: _selectedAlarmTag,
                      operator: _alarmOperator,
                      thresholdController: _alarmThresholdController,
                      visual: _alarmVisual,
                      sound: _alarmSound,
                      onTagChanged: (value) => setState(() => _selectedAlarmTag = value),
                      onOperatorChanged: (value) => setState(() => _alarmOperator = value),
                      onVisualChanged: (value) => setState(() => _alarmVisual = value),
                      onSoundChanged: (value) => setState(() => _alarmSound = value),
                      onAdd: () => _addOperationalAlarm(variables),
                    ),
                    const SizedBox(height: 10),
                    _AlarmList(alarms: appSettings.operationalAlarms),
                  ],
                ),
                _SettingsSection(
                  title: 'Integración del ecosistema Atalaya',
                  icon: Icons.hub_outlined,
                  children: <Widget>[
                    _SyncStatusCard(dashboard: dashboard),
                  ],
                ),
                _SettingsSection(
                  title: 'Cuenta y sesión',
                  icon: Icons.account_circle_outlined,
                  children: <Widget>[
                    const _UserProfileCard(),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LayoutTokens.accentRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: widget.onLogout == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onLogout?.call();
                            },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addOperationalAlarm(List<WellVariable> variables) async {
    final tag = _selectedAlarmTag;
    final threshold = double.tryParse(_alarmThresholdController.text.trim().replaceAll(',', '.'));
    if (tag == null || tag.trim().isEmpty || threshold == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una variable y un umbral válido.')),
      );
      return;
    }

    WellVariable? variable;
    for (final item in variables) {
      if (item.tag == tag) {
        variable = item;
        break;
      }
    }

    final alarm = OperationalAlarmRule(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      variableTag: tag,
      variableLabel: variable?.label ?? tag,
      operator: _alarmOperator,
      threshold: threshold,
      enabled: true,
      visual: _alarmVisual,
      sound: _alarmSound,
    );

    await ref.read(appSettingsControllerProvider.notifier).addOperationalAlarm(alarm);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarma creada para ${alarm.variableLabel}.')),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LayoutTokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: LayoutTokens.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: LayoutTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ThemePreferenceSelector extends StatelessWidget {
  const _ThemePreferenceSelector({
    required this.selected,
    required this.onChanged,
  });

  final AtalayaThemePreference selected;
  final ValueChanged<AtalayaThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<AtalayaVisualPalette>() ?? AtalayaVisualPalette.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tema visual',
            style: TextStyle(color: visual.textSecondary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona la paleta de operación. Sistema aplica automáticamente oscuro o claro según Android/iOS.',
            style: TextStyle(color: visual.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Column(
            children: AtalayaThemePreference.values.map((item) {
              return _ThemePreferenceTile(
                preference: item,
                selected: selected == item,
                onTap: () => onChanged(item),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ThemePreferenceTile extends StatelessWidget {
  const _ThemePreferenceTile({
    required this.preference,
    required this.selected,
    required this.onTap,
  });

  final AtalayaThemePreference preference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context).extension<AtalayaVisualPalette>() ?? AtalayaVisualPalette.dark;
    final preview = switch (preference) {
      AtalayaThemePreference.dark => AtalayaVisualPalette.dark,
      AtalayaThemePreference.light => AtalayaVisualPalette.light,
      AtalayaThemePreference.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? AtalayaVisualPalette.dark
          : AtalayaVisualPalette.light,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? current.primary.withValues(alpha: 0.12) : current.plotArea,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? current.primary : current.grid,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              _ThemePreviewSwatch(palette: preview),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(preference.icon, size: 18, color: selected ? current.primary : current.textSecondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            preference.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: current.textPrimary, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preference.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: current.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: selected
                    ? Icon(Icons.check_circle_rounded, key: const ValueKey('selected'), color: current.primary)
                    : Icon(Icons.circle_outlined, key: const ValueKey('idle'), color: current.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewSwatch extends StatelessWidget {
  const _ThemePreviewSwatch({required this.palette});

  final AtalayaVisualPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.grid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              _SwatchDot(color: palette.primary),
              const SizedBox(width: 4),
              _SwatchDot(color: palette.curveSecondaryA),
              const SizedBox(width: 4),
              _SwatchDot(color: palette.curveSecondaryB),
              const Spacer(),
              _SwatchDot(color: palette.scatter.withValues(alpha: 0.60), size: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SettingsSegmentedRow<T extends Object> extends StatelessWidget {
  const _SettingsSegmentedRow({
    required this.label,
    required this.selected,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
    this.subtitleBuilder,
  });

  final String label;
  final T selected;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final String Function(T value)? subtitleBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: LayoutTokens.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(LayoutTokens.textSecondary),
                backgroundColor: WidgetStateProperty.all(LayoutTokens.bgPrimary),
              ),
              segments: values
                  .map(
                    (value) => ButtonSegment<T>(
                      value: value,
                      label: Text(labelBuilder(value)),
                    ),
                  )
                  .toList(growable: false),
              selected: <T>{selected},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onChanged(selection.first);
                }
              },
            ),
          ),
          if (subtitleBuilder != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitleBuilder!(selected),
              style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: LayoutTokens.textSecondary),
      title: Text(title, style: const TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: LayoutTokens.textMuted)),
      trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
    );
  }
}

class _PollingSelector extends StatelessWidget {
  const _PollingSelector({required this.selectedSeconds, required this.onChanged});

  final int selectedSeconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Tasa de refresco', style: TextStyle(color: LayoutTokens.textSecondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AppSettings.pollingOptionsSeconds.map((seconds) {
            final selected = selectedSeconds == seconds;
            return ChoiceChip(
              label: Text('${seconds}s'),
              selected: selected,
              showCheckmark: false,
              selectedColor: const Color(0x4434D399),
              backgroundColor: LayoutTokens.bgPrimary,
              side: BorderSide(color: selected ? LayoutTokens.accentGreen : LayoutTokens.dividerSubtle),
              labelStyle: TextStyle(
                color: selected ? Colors.white : LayoutTokens.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(seconds),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 6),
        const Text(
          'Intervalos rápidos consumen más batería y datos móviles.',
          style: TextStyle(color: LayoutTokens.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _AlarmEditor extends StatelessWidget {
  const _AlarmEditor({
    required this.variables,
    required this.selectedTag,
    required this.operator,
    required this.thresholdController,
    required this.visual,
    required this.sound,
    required this.onTagChanged,
    required this.onOperatorChanged,
    required this.onVisualChanged,
    required this.onSoundChanged,
    required this.onAdd,
  });

  final List<WellVariable> variables;
  final String? selectedTag;
  final AtalayaAlarmOperator operator;
  final TextEditingController thresholdController;
  final bool visual;
  final bool sound;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<AtalayaAlarmOperator> onOperatorChanged;
  final ValueChanged<bool> onVisualChanged;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LayoutTokens.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Nueva alarma operacional', style: TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedTag,
            dropdownColor: LayoutTokens.surfaceCard,
            decoration: const InputDecoration(labelText: 'Variable'),
            items: variables
                .map((item) => DropdownMenuItem<String>(
                      value: item.tag,
                      child: Text('${item.label} (${item.tag})'),
                    ))
                .toList(growable: false),
            onChanged: onTagChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<AtalayaAlarmOperator>(
                  value: operator,
                  dropdownColor: LayoutTokens.surfaceCard,
                  decoration: const InputDecoration(labelText: 'Condición'),
                  items: AtalayaAlarmOperator.values
                      .map((item) => DropdownMenuItem<AtalayaAlarmOperator>(
                            value: item,
                            child: Text(item.symbol),
                          ))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onOperatorChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: thresholdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Umbral'),
                  style: const TextStyle(color: LayoutTokens.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: visual,
            activeColor: LayoutTokens.accentGreen,
            title: const Text('Visual', style: TextStyle(color: LayoutTokens.textSecondary)),
            onChanged: (value) => onVisualChanged(value ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: sound,
            activeColor: LayoutTokens.accentGreen,
            title: const Text('Sonora', style: TextStyle(color: LayoutTokens.textSecondary)),
            onChanged: (value) => onSoundChanged(value ?? false),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: variables.isEmpty ? null : onAdd,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Crear alarma'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmList extends ConsumerWidget {
  const _AlarmList({required this.alarms});

  final List<OperationalAlarmRule> alarms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alarms.isEmpty) {
      return const Text('No hay alarmas operacionales configuradas.', style: TextStyle(color: LayoutTokens.textMuted));
    }

    return Column(
      children: alarms.map((alarm) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: LayoutTokens.bgPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LayoutTokens.dividerSubtle),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                alarm.enabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                color: alarm.enabled ? LayoutTokens.accentOrange : LayoutTokens.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      alarm.variableLabel,
                      style: const TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${alarm.operator.symbol} ${alarm.threshold.toStringAsFixed(alarm.threshold.truncateToDouble() == alarm.threshold ? 0 : 2)} · ${alarm.sound ? 'sonora' : 'sin sonido'}',
                      style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: alarm.enabled,
                activeColor: LayoutTokens.accentGreen,
                onChanged: (value) => ref.read(appSettingsControllerProvider.notifier).toggleOperationalAlarm(alarm.id, value),
              ),
              IconButton(
                onPressed: () => ref.read(appSettingsControllerProvider.notifier).removeOperationalAlarm(alarm.id),
                icon: const Icon(Icons.delete_outline_rounded, color: LayoutTokens.textMuted),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.dashboard});

  final DashboardViewState? dashboard;

  @override
  Widget build(BuildContext context) {
    final latest = dashboard?.payload.latestSampleAt?.toLocal();
    final status = dashboard?.connectionStatus;
    final statusText = switch (status) {
      ConnectionStatus.connected => 'Conectado',
      ConnectionStatus.stale => 'Desactualizado',
      ConnectionStatus.retrying => 'Reintentando',
      ConnectionStatus.offline => 'Sin conexión',
      ConnectionStatus.waiting || null => 'Esperando',
    };
    final color = switch (status) {
      ConnectionStatus.connected => LayoutTokens.accentGreen,
      ConnectionStatus.stale || ConnectionStatus.retrying => LayoutTokens.accentOrange,
      ConnectionStatus.offline => LayoutTokens.accentRed,
      ConnectionStatus.waiting || null => LayoutTokens.textMuted,
    };

    final latencyText = latest == null
        ? 'Sin muestra reciente'
        : 'Última muestra ${DateFormat('dd/MM HH:mm:ss').format(latest)} · latencia ${DateTime.now().difference(latest).inSeconds}s';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LayoutTokens.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LayoutTokens.dividerSubtle),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                Text(latencyText, style: const TextStyle(color: LayoutTokens.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _readUserLabel(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? 'Operador conectado';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LayoutTokens.bgPrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LayoutTokens.dividerSubtle),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.verified_user_outlined, color: LayoutTokens.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(user, style: const TextStyle(color: LayoutTokens.textPrimary, fontWeight: FontWeight.w800)),
                    const Text('Sesión protegida', style: TextStyle(color: LayoutTokens.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _readUserLabel() async {
    final token = await SessionSecureStorage().readToken();
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return _decodeSubject(token) ?? 'Operador conectado';
  }

  String? _decodeSubject(String token) {
    try {
      final firstSegment = token.split('.').first;
      final normalized = base64Url.normalize(firstSegment);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is Map) {
        final sub = decoded['sub'] ?? decoded['username'] ?? decoded['email'];
        if (sub != null && sub.toString().trim().isNotEmpty) {
          return sub.toString();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
