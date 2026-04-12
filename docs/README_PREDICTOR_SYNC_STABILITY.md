# Predictor ⇄ Atalaya Mobile: propuesta de estabilidad de datos

## Objetivo
Reducir eventos falsos de `STALE` cuando hay latencia entre `Predictor` y Mobile.

## Arquitectura recomendada (Redis como estado global)
1. **Predictor writer (único)** publica snapshots procesados cada 2-4s en Redis:
   - `predictor:dashboard:latest` (JSON completo para Mobile).
   - `predictor:dashboard:updated_at` (epoch ms).
   - `predictor:alerts:latest` (lista de alertas normalizadas con `attachments[]`).
2. **FastAPI backend** deja de consultar tablas pesadas para cada request y solo:
   - Lee snapshot de Redis.
   - Hace fallback a DB si Redis no tiene dato reciente.
   - Expone headers: `X-Snapshot-Age-Ms`, `X-Snapshot-Source=REDIS|DB`.
3. **Mobile polling adaptativo**
   - Intervalo base 4s.
   - Backoff progresivo ante errores (6s, 8s, … 15s).
   - `stale grace` de 8s para evitar saltos transitorios a `STALE`.

## Contrato sugerido para snapshot
```json
{
  "well": "IXACHI-45",
  "job": "Drilling",
  "latestSampleAt": "2026-04-12T10:03:02Z",
  "staleThresholdSeconds": 10,
  "variables": [
    {"slot":1,"label":"RPM","tag":"RPM","rawUnit":"rpm","value":123.4,"sampleAt":"2026-04-12T10:03:02Z","configured":true}
  ],
  "alerts": [
    {
      "id":"KP-9921",
      "description":"Torque fuera de banda",
      "severity":"ATTENTION",
      "createdAt":"2026-04-12T10:02:59Z",
      "attachmentsCount":1,
      "attachments":[
        {"id":"a1","name":"snapshot.png","url":"https://...","mimeType":"image/png"}
      ]
    }
  ]
}
```

## Nota sobre adjuntos pesados
Para adjuntos (imágenes/documentos), usar ejecución desacoplada del request principal:
- Resolver metadata primero (`id`, `name`, `mimeType`, `url`).
- Descarga/render diferida desde Mobile.
- Si se migra a Dash web, usar **Background Callbacks** para no bloquear UI.
