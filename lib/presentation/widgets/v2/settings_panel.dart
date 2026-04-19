import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/atalaya_localizations.dart';
import '../../../core/security/session_secure_storage.dart';
import '../../../core/theme/pro_palette.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/well_variable.dart';
import '../../providers/alert_settings_controller.dart';
import '../../providers/app_settings_controller.dart';
import '../../providers/dashboard_controller.dart';

class AtalayaSettingsPanel extends ConsumerStatefulWidget {
  const AtalayaSettingsPanel({super.key, this.onLogout, this.onOpenLayoutControls});

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
    final colors = context.atalayaColors;
    final settings = ref.watch(appSettingsControllerProvider);
    final text = AtalayaTexts.of(settings.language);
    final alertSettings = ref.watch(alertSettingsControllerProvider);
    final dashboard = ref.watch(dashboardControllerProvider).value;
    final variables = dashboard?.payload.variables.where((item) => item.configured).toList(growable: false) ?? const <WellVariable>[];
    _selectedAlarmTag ??= variables.isNotEmpty ? variables.first.tag : null;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.grid)),
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
                      color: colors.textSecondary.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        text.settingsTitle,
                        style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: text.close,
                      icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(text.settingsSubtitle, style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: text.interfacePreferences,
                  icon: Icons.palette_outlined,
                  children: <Widget>[
                    _ThemeSelector(selected: settings.themePreference, text: text),
                    _LanguageSelector(selected: settings.language, text: text),
                    if (widget.onOpenLayoutControls != null)
                      _ActionTile(
                        icon: Icons.dashboard_customize_outlined,
                        title: text.dashboardLayout,
                        subtitle: text.dashboardLayoutSubtitle,
                        actionLabel: text.open,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Future<void>.delayed(const Duration(milliseconds: 160));
                          widget.onOpenLayoutControls?.call();
                        },
                      ),
                  ],
                ),
                _SettingsSection(
                  title: text.operationalParameters,
                  icon: Icons.tune_rounded,
                  children: <Widget>[
                    _ChoiceRow<AtalayaUnitSystem>(
                      label: text.unitSystem,
                      selected: settings.unitSystem,
                      values: AtalayaUnitSystem.values,
                      labelBuilder: text.unitLabel,
                      subtitle: text.unitDescription(settings.unitSystem),
                      onChanged: ref.read(appSettingsControllerProvider.notifier).setUnitSystem,
                    ),
                    _PollingSelector(selectedSeconds: settings.pollingIntervalSeconds, text: text),
                  ],
                ),
                _SettingsSection(
                  title: text.alarmsAndNotifications,
                  icon: Icons.notifications_active_outlined,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.pushAlertsEnabled && alertSettings.enabled,
                      activeColor: colors.safe,
                      title: Text(text.pushAlerts, style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text(text.pushAlertsSubtitle, style: TextStyle(color: colors.textSecondary)),
                      onChanged: (value) async {
                        await ref.read(appSettingsControllerProvider.notifier).setPushAlertsEnabled(value);
                        await ref.read(alertSettingsControllerProvider.notifier).setEnabled(value);
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: alertSettings.visual,
                      activeColor: colors.safe,
                      title: Text(text.visualAlert, style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text(text.visualAlertSubtitle, style: TextStyle(color: colors.textSecondary)),
                      onChanged: ref.read(alertSettingsControllerProvider.notifier).setVisual,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: alertSettings.sound,
                      activeColor: colors.safe,
                      title: Text(text.soundAlert, style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text(text.soundAlertSubtitle, style: TextStyle(color: colors.textSecondary)),
                      onChanged: ref.read(alertSettingsControllerProvider.notifier).setSound,
                    ),
                    const SizedBox(height: 12),
                    _AlarmEditor(
                      text: text,
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
                      onAdd: () => _addOperationalAlarm(variables, text),
                    ),
                    const SizedBox(height: 10),
                    _AlarmList(alarms: settings.operationalAlarms, text: text),
                  ],
                ),
                _SettingsSection(
                  title: text.integration,
                  icon: Icons.hub_outlined,
                  children: <Widget>[_SyncStatusCard(dashboard: dashboard, text: text)],
                ),
                _SettingsSection(
                  title: text.accountAndSession,
                  icon: Icons.account_circle_outlined,
                  children: <Widget>[
                    _UserProfileCard(text: text),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                      title: Text(text.logout, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
                      onTap: () {
                        Navigator.of(context).maybePop();
                        widget.onLogout?.call();
                      },
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

  Future<void> _addOperationalAlarm(List<WellVariable> variables, AtalayaTexts text) async {
    final tag = _selectedAlarmTag;
    final threshold = double.tryParse(_alarmThresholdController.text.trim().replaceAll(',', '.'));
    if (tag == null || tag.trim().isEmpty || threshold == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.invalidAlarm)));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.alarmCreated(alarm.variableLabel))));
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.grid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: colors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({required this.selected, required this.text});

  final AtalayaThemePreference selected;
  final AtalayaTexts text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.atalayaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.visualTheme, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(text.visualThemeHelp, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          ...AtalayaThemePreference.values.map((item) {
            return _OptionTile(
              active: selected == item,
              icon: item.icon,
              title: text.themeLabel(item),
              subtitle: text.themeDescription(item),
              onTap: () => ref.read(appSettingsControllerProvider.notifier).setThemePreference(item),
            );
          }),
        ],
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({required this.selected, required this.text});

  final AtalayaLanguage selected;
  final AtalayaTexts text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.atalayaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.appLanguage, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(text.appLanguageHelp, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: AtalayaLanguage.values.map((language) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: language == AtalayaLanguage.es ? 8 : 0),
                  child: _LanguageTile(
                    active: selected == language,
                    label: text.languageLabel(language),
                    subtitle: text.languageDescription(language),
                    onTap: () async {
                      await ref.read(appSettingsControllerProvider.notifier).setLanguage(language);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AtalayaTexts.of(language).languageChanged(language)), duration: const Duration(milliseconds: 1200)),
                      );
                    },
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.active, required this.label, required this.subtitle, required this.onTap});

  final bool active;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.14) : colors.plotArea,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? colors.primary : colors.grid, width: active ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.translate_rounded, size: 18, color: active ? colors.primary : colors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800))),
                if (active) Icon(Icons.check_circle_rounded, color: colors.primary, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.active, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? colors.primary.withValues(alpha: 0.12) : colors.plotArea,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? colors.primary : colors.grid, width: active ? 1.3 : 1),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: active ? colors.primary : colors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (active) Icon(Icons.check_circle_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow<T extends Object> extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.selected, required this.values, required this.labelBuilder, required this.onChanged, this.subtitle});

  final String label;
  final T selected;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: values.map((value) => ButtonSegment<T>(value: value, label: Text(labelBuilder(value)))).toList(growable: false),
              selected: <T>{selected},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.first);
              },
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _PollingSelector extends ConsumerWidget {
  const _PollingSelector({required this.selectedSeconds, required this.text});

  final int selectedSeconds;
  final AtalayaTexts text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.atalayaColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(text.pollingRate, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(text.pollingHelp, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppSettings.pollingOptionsSeconds.map((seconds) {
            return ChoiceChip(
              label: Text('${seconds}s'),
              selected: seconds == selectedSeconds,
              showCheckmark: false,
              onSelected: (_) async {
                await ref.read(appSettingsControllerProvider.notifier).setPollingIntervalSeconds(seconds);
                ref.invalidate(dashboardControllerProvider);
              },
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.actionLabel, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: TextStyle(color: colors.textSecondary)),
      trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
    );
  }
}

class _AlarmEditor extends StatelessWidget {
  const _AlarmEditor({
    required this.text,
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

  final AtalayaTexts text;
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
    final colors = context.atalayaColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.plotArea, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.grid)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.newAlarm, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedTag,
            decoration: InputDecoration(labelText: text.variable),
            items: variables.map((item) => DropdownMenuItem<String>(value: item.tag, child: Text('${item.label} (${item.tag})'))).toList(growable: false),
            onChanged: onTagChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<AtalayaAlarmOperator>(
                  value: operator,
                  decoration: InputDecoration(labelText: text.condition),
                  items: AtalayaAlarmOperator.values.map((item) => DropdownMenuItem<AtalayaAlarmOperator>(value: item, child: Text(item.symbol))).toList(growable: false),
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
                  decoration: InputDecoration(labelText: text.threshold),
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: visual, activeColor: colors.safe, title: Text(text.visual, style: TextStyle(color: colors.textSecondary)), onChanged: (value) => onVisualChanged(value ?? true)),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: sound, activeColor: colors.safe, title: Text(text.sound, style: TextStyle(color: colors.textSecondary)), onChanged: (value) => onSoundChanged(value ?? false)),
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: variables.isEmpty ? null : onAdd, icon: const Icon(Icons.add_alert_rounded), label: Text(text.createAlarm))),
        ],
      ),
    );
  }
}

class _AlarmList extends ConsumerWidget {
  const _AlarmList({required this.alarms, required this.text});

  final List<OperationalAlarmRule> alarms;
  final AtalayaTexts text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.atalayaColors;
    if (alarms.isEmpty) return Text(text.noAlarms, style: TextStyle(color: colors.textSecondary));

    return Column(
      children: alarms.map((alarm) {
        final threshold = alarm.threshold.toStringAsFixed(alarm.threshold.truncateToDouble() == alarm.threshold ? 0 : 2);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: colors.plotArea, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.grid)),
          child: Row(
            children: <Widget>[
              Icon(alarm.enabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined, color: alarm.enabled ? const Color(0xFFF59E0B) : colors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(alarm.variableLabel, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                    Text('${alarm.operator.symbol} $threshold · ${text.soundLabel(alarm.sound)}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch.adaptive(value: alarm.enabled, activeColor: colors.safe, onChanged: (value) => ref.read(appSettingsControllerProvider.notifier).toggleOperationalAlarm(alarm.id, value)),
              IconButton(onPressed: () => ref.read(appSettingsControllerProvider.notifier).removeOperationalAlarm(alarm.id), icon: Icon(Icons.delete_outline_rounded, color: colors.textSecondary)),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.dashboard, required this.text});

  final DashboardViewState? dashboard;
  final AtalayaTexts text;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    final latest = dashboard?.payload.latestSampleAt?.toLocal();
    final statusText = text.connectionStatusLabel(dashboard?.connectionStatus);
    final latencyText = latest == null ? text.noRecentSample : text.latestSample(DateFormat('dd/MM HH:mm:ss').format(latest), DateTime.now().difference(latest).inSeconds);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.plotArea, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.grid)),
      child: Row(
        children: <Widget>[
          Icon(Icons.circle, size: 12, color: colors.safe),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(statusText, style: TextStyle(color: colors.safe, fontWeight: FontWeight.w800)), Text(latencyText, style: TextStyle(color: colors.textSecondary, fontSize: 12))])),
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({required this.text});

  final AtalayaTexts text;

  @override
  Widget build(BuildContext context) {
    final colors = context.atalayaColors;
    return FutureBuilder<String?>(
      future: _readUserLabel(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? text.operatorConnected;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colors.plotArea, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.grid)),
          child: Row(
            children: <Widget>[
              Icon(Icons.verified_user_outlined, color: colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(user, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)), Text(text.protectedSession, style: TextStyle(color: colors.textSecondary, fontSize: 12))])),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _readUserLabel() async {
    final token = await SessionSecureStorage().readToken();
    if (token == null || token.trim().isEmpty) return null;
    return _decodeSubject(token) ?? text.operatorConnected;
  }

  String? _decodeSubject(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      if (token.startsWith('sid:')) {
        final sidParts = token.split(':');
        return sidParts.length >= 2 ? sidParts[1] : null;
      }
      return null;
    }
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is Map) return (decoded['sub'] ?? decoded['username'] ?? decoded['email'])?.toString();
    } catch (_) {
      return null;
    }
    return null;
  }
}
