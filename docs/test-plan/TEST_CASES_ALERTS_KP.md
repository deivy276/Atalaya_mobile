# Casos de prueba — Alertas, KP y conectividad

Fecha: 2026-04-13

## TC-KP-01 Polling periódico y refresh manual
1. Iniciar app con backend disponible.
2. Observar actualización periódica (~4s + backoff).
3. Ejecutar refresh manual desde AppBar.

**Esperado**
- No se congela UI.
- Refresco manual fuerza actualización inmediata.

## TC-KP-02 Backend caído y recuperación
1. Con app activa, detener backend 30–60 s.
2. Verificar transición a estado `retrying/offline`.
3. Restaurar backend.

**Esperado**
- Reintentos automáticos sin cerrar app.
- Reconexión y actualización normal al restaurar servicio.

## TC-KP-03 Mapeo de severidad
1. Inyectar alerta ATTENTION para variable visible.
2. Inyectar alerta CRITICAL para otra variable.

**Esperado**
- ATTENTION: borde/estado ámbar.
- CRITICAL: borde/estado rojo.

## TC-KP-04 Barra inferior autoexpandible
1. Iniciar con “sin alertas recientes”.
2. Publicar alerta nueva.

**Esperado**
- Barra inferior se expande automáticamente.
- Muestra recomendación asociada a severidad.

## TC-KP-05 Tendencias y unidades
1. Abrir trend bottom sheet de una variable.
2. Cambiar rango: 30m, 2h, 6h.
3. Cambiar unidad de visualización.

**Esperado**
- Serie se actualiza por rango.
- Conversión de unidad consistente y sin saltos erráticos.
