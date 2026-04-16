# Atalaya Flutter Migration

Migración propuesta de **Atalaya** desde Python/Flet a **Flutter (Dart)** con **Clean Architecture + Riverpod**.

## Decisiones aplicadas desde la revisión del programa original

1. **Sin PostgreSQL directo desde el cliente móvil.**
   La app consume una **API REST JSON**.
2. **Estado centralizado con Riverpod.**
   Nada de lógica de datos importante en widgets locales.
3. **Consulta correcta de último valor por tag.**
   El backend debe entregar el dashboard ya resuelto por tag/slot.
4. **Forma consistente de alertas.**
   Toda alerta llega con `id`, `severity`, `createdAt` y `attachmentsCount`.
5. **Polling seguro.**
   Los timers viven en providers y se cancelan al destruir la pantalla.
6. **Conversión de unidades 1:1 con el script original.**
   Se respetan exactamente las constantes de presión, longitud, flujo, fuerza y temperatura.
7. **Downsampling móvil a máximo 350 puntos.**
   Se replica la lógica del script original para evitar saturar el dispositivo.

## Estructura

```text
lib/
  main.dart
  core/
    constants/
      trend_range.dart
    theme/
      pro_palette.dart
    utils/
      downsampler.dart
      unit_converter.dart
  data/
    datasources/
      atalaya_api_client.dart
    models/
      alert.dart
      alert_settings.dart
      attachment.dart
      dashboard_payload.dart
      trend_point.dart
      well_variable.dart
    repositories/
      atalaya_repository_impl.dart
  domain/
    repositories/
      atalaya_repository.dart
  presentation/
    providers/
      api_client_provider.dart
      alert_settings_controller.dart
      dashboard_controller.dart
      trend_controller.dart
      unit_preferences_controller.dart
    screens/
      dashboard_screen.dart
    widgets/
      alert_card.dart
      status_chip.dart
      trend_chart_widget.dart
      variable_tile.dart
```

## API esperada

Ver `docs/api_contract.md`.

## Notas operativas

- El backend debería exponer un endpoint tipo `/api/v1/dashboard` que ya devuelva las 12 variables resueltas por slot.
- El endpoint de tendencias debe aceptar `tag` y `range` (`30m`, `2h`, `6h`).
- Las fechas deben viajar en UTC ISO-8601.
- Las preferencias de unidades y quiet hours se guardan localmente en `SharedPreferences`.
