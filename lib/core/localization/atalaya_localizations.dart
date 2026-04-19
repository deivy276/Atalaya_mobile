import '../../data/models/app_settings.dart';

class AtalayaTexts {
  const AtalayaTexts._(this.language);

  final AtalayaLanguage language;
  bool get en => language == AtalayaLanguage.en;

  static AtalayaTexts of(AtalayaLanguage language) => AtalayaTexts._(language);

  String get appTitle => 'Atalaya Mobile';
  String get settingsTitle => en ? 'Settings' : 'Configuración';
  String get settingsSubtitle => en ? 'Local preferences for field operations.' : 'Preferencias locales para operaciones en campo.';
  String get close => en ? 'Close' : 'Cerrar';
  String get open => en ? 'Open' : 'Abrir';
  String get interfacePreferences => en ? 'Interface preferences' : 'Preferencias de interfaz';
  String get visualTheme => en ? 'Visual theme' : 'Tema visual';
  String get visualThemeHelp => en ? 'Dark for continuous monitoring, Light for high brightness, System to follow Android/iOS.' : 'Oscuro para monitoreo continuo, Claro para alta luminosidad y Sistema para seguir Android/iOS.';
  String get appLanguage => en ? 'App language' : 'Idioma de la aplicación';
  String get appLanguageHelp => en ? 'Tap a language to update this panel immediately.' : 'Toca un idioma para actualizar este panel inmediatamente.';
  String get dashboardLayout => en ? 'Dashboard layout' : 'Layout del dashboard';
  String get dashboardLayoutSubtitle => en ? 'Density and card view.' : 'Densidad y vista de tarjetas.';
  String get operationalParameters => en ? 'Operational parameters' : 'Parámetros operativos';
  String get unitSystem => en ? 'Unit system' : 'Sistema de unidades';
  String get pollingRate => en ? 'Polling rate' : 'Tasa de actualización';
  String get pollingHelp => en ? 'Faster intervals consume more battery and mobile data.' : 'Los intervalos rápidos consumen más batería y datos móviles.';
  String get alarmsAndNotifications => en ? 'Alarms and notifications' : 'Alarmas y notificaciones';
  String get pushAlerts => en ? 'Push alerts' : 'Alertas push';
  String get pushAlertsSubtitle => en ? 'Enables critical well events on the phone.' : 'Activa eventos críticos del pozo en el teléfono.';
  String get visualAlert => en ? 'Visual alert' : 'Alerta visual';
  String get visualAlertSubtitle => en ? 'Banner or modal when a notified event arrives.' : 'Banner o modal cuando llegue un evento notificado.';
  String get soundAlert => en ? 'Sound alert' : 'Alerta sonora';
  String get soundAlertSubtitle => en ? 'Ready for native notification integration.' : 'Preparada para integración con notificaciones nativas.';
  String get newAlarm => en ? 'New operational alarm' : 'Nueva alarma operacional';
  String get variable => en ? 'Variable' : 'Variable';
  String get condition => en ? 'Condition' : 'Condición';
  String get threshold => en ? 'Threshold' : 'Umbral';
  String get visual => en ? 'Visual' : 'Visual';
  String get sound => en ? 'Sound' : 'Sonora';
  String get createAlarm => en ? 'Create alarm' : 'Crear alarma';
  String get noAlarms => en ? 'No operational alarms configured.' : 'No hay alarmas operacionales configuradas.';
  String get invalidAlarm => en ? 'Select a variable and a valid threshold.' : 'Selecciona una variable y un umbral válido.';
  String alarmCreated(String label) => en ? 'Alarm created for $label.' : 'Alarma creada para $label.';
  String soundLabel(bool value) => en ? (value ? 'sound' : 'no sound') : (value ? 'sonora' : 'sin sonido');
  String get integration => en ? 'Atalaya ecosystem integration' : 'Integración del ecosistema Atalaya';
  String get noRecentSample => en ? 'No recent sample' : 'Sin muestra reciente';
  String latestSample(String date, int latency) => en ? 'Latest sample $date · latency ${latency}s' : 'Última muestra $date · latencia ${latency}s';
  String get accountAndSession => en ? 'Account and session' : 'Cuenta y sesión';
  String get operatorConnected => en ? 'Connected operator' : 'Operador conectado';
  String get protectedSession => en ? 'Protected session' : 'Sesión protegida';
  String get logout => en ? 'Log out' : 'Cerrar sesión';

  String languageChanged(AtalayaLanguage value) => value == AtalayaLanguage.en ? 'Language changed to English.' : 'Idioma cambiado a español.';

  String languageLabel(AtalayaLanguage value) => switch (value) {
        AtalayaLanguage.es => en ? 'Spanish' : 'Español',
        AtalayaLanguage.en => en ? 'English' : 'Inglés',
      };

  String languageDescription(AtalayaLanguage value) => switch (value) {
        AtalayaLanguage.es => en ? 'Spanish interface text.' : 'Texto de interfaz en español.',
        AtalayaLanguage.en => en ? 'English interface text.' : 'Texto de interfaz en inglés.',
      };

  String themeLabel(AtalayaThemePreference value) => switch (value) {
        AtalayaThemePreference.system => en ? 'System' : 'Sistema',
        AtalayaThemePreference.dark => en ? 'Dark' : 'Oscuro',
        AtalayaThemePreference.light => en ? 'Light' : 'Claro',
      };

  String themeDescription(AtalayaThemePreference value) => switch (value) {
        AtalayaThemePreference.system => en ? 'Automatically follows the device theme.' : 'Sigue automáticamente el tema del dispositivo.',
        AtalayaThemePreference.dark => en ? 'Midnight blues to reduce visual fatigue in the field.' : 'Azules medianoche para reducir la fatiga visual en campo.',
        AtalayaThemePreference.light => en ? 'High-contrast technical grays for bright environments.' : 'Grises técnicos de alto contraste para alta luminosidad.',
      };

  String unitLabel(AtalayaUnitSystem value) => switch (value) {
        AtalayaUnitSystem.field => en ? 'Field' : 'Campo',
        AtalayaUnitSystem.english => en ? 'English' : 'Inglés',
        AtalayaUnitSystem.metric => en ? 'Metric' : 'Métrico',
      };

  String unitDescription(AtalayaUnitSystem value) => switch (value) {
        AtalayaUnitSystem.field => en ? 'Source units' : 'Unidades de origen',
        AtalayaUnitSystem.english => 'psi · lbf · gpm · ft',
        AtalayaUnitSystem.metric => 'bar · kgf · lpm · m',
      };

  String connectionStatusLabel(Object? status) {
    final raw = status?.toString().split('.').last;
    return switch (raw) {
      'connected' => en ? 'Connected' : 'Conectado',
      'stale' => en ? 'Stale' : 'Desactualizado',
      'retrying' => en ? 'Retrying' : 'Reintentando',
      'offline' => en ? 'Offline' : 'Sin conexión',
      _ => en ? 'Waiting' : 'Esperando',
    };
  }
}
