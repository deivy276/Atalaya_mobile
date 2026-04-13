# Casos de prueba — Drag & Drop de variables

Fecha: 2026-04-13

## Precondiciones
- Dashboard con al menos 6 variables visibles.
- Modo edición de layout habilitable desde Helpers Drawer.
- Persistencia local disponible (SharedPreferences).

## TC-DD-01 Reordenar variable en móvil (1 columna)
1. Abrir Dashboard en 360x640.
2. Activar modo edición.
3. Arrastrar variable A de posición 5 a posición 2.
4. Salir de modo edición.

**Esperado**
- La variable A queda en la nueva posición.
- El drag handle solo aparece en modo edición.

## TC-DD-02 Persistencia de orden tras reinicio
1. Ejecutar TC-DD-01.
2. Cerrar app completamente.
3. Reabrir Dashboard mismo pozo/job.

**Esperado**
- El orden modificado se mantiene.
- Clave sugerida: `layout_order::<well>::<job>`.

## TC-DD-03 Fallback sin layout previo
1. Borrar preferencias de layout.
2. Abrir Dashboard por primera vez para un pozo/job.

**Esperado**
- Se aplica orden por slot original sin errores.

## TC-DD-04 Restablecer layout
1. Partir de un layout personalizado.
2. Pulsar “Restablecer layout”.

**Esperado**
- Se recupera orden por defecto.
- Se limpia/actualiza preferencia local asociada.

## TC-DD-05 Cambio de contexto (pozo/job)
1. Reordenar variables en contexto A.
2. Cambiar a contexto B.
3. Volver a contexto A.

**Esperado**
- Contexto B mantiene su propio orden (o default).
- Contexto A conserva su orden personalizado.
