# API REST sugerida para Atalaya

## 1) Dashboard

`GET /api/v1/dashboard`

```json
{
  "well": "IXACHI-45",
  "job": "Drilling",
  "latestSampleAt": "2026-04-10T15:12:20Z",
  "latestSampleAgeSeconds": 4,
  "staleThresholdSeconds": 10,
  "variables": [
    {
      "slot": 1,
      "label": "SPP",
      "tag": "SPP",
      "rawUnit": "psi",
      "value": 3320.5,
      "sampleAt": "2026-04-10T15:12:20Z",
      "configured": true
    }
  ],
  "alerts": [
    {
      "id": "4021",
      "description": "Standpipe pressure spike detected",
      "severity": "CRITICAL",
      "createdAt": "2026-04-10T15:12:15Z",
      "attachmentsCount": 2,
      "attachments": []
    }
  ]
}
```

### Recomendación crítica

Este endpoint **debe devolver el último valor por tag ya resuelto en backend**.
No conviene que el móvil intente reconstruirlo leyendo los últimos N samples globales.

## 2) Tendencias

`GET /api/v1/trends?tag=SPP&range=2h`

```json
{
  "tag": "SPP",
  "rawUnit": "psi",
  "points": [
    {"timestamp": "2026-04-10T13:12:20Z", "value": 3299.1},
    {"timestamp": "2026-04-10T13:12:24Z", "value": 3302.7}
  ]
}
```

Rangos permitidos:

- `30m`
- `2h`
- `6h`

## 3) Adjuntos por alerta

`GET /api/v1/alerts/{alertId}/attachments`

```json
{
  "attachments": [
    {
      "id": "a1",
      "name": "evidence_01.png",
      "url": "https://secure-cdn.example.com/evidence_01.png",
      "mimeType": "image/png",
      "sizeBytes": 124820,
      "createdAt": "2026-04-10T15:12:19Z"
    }
  ]
}
```

## 4) Health detallado

`GET /health/details`

```json
{
  "status": "ok",
  "dbStatus": "ok",
  "staleThresholdSeconds": 10,
  "latestSampleAt": "2026-04-10T15:12:20Z",
  "latestSampleAgeSeconds": 4,
  "latestSampleSource": "MATVIEW"
}
```

- `status`: `ok` o `degraded`.
- `dbStatus`: estado de conectividad a base de datos.
- `latestSampleSource`: `MATVIEW`, `BASE_TABLE`, `NONE` o `UNKNOWN`.

## 5) Reglas de contrato

- Todas las fechas en UTC ISO-8601.
- `severity` sólo puede ser `OK`, `ATTENTION` o `CRITICAL`.
- Toda alerta debe traer `id` consistente.
- Los URLs de adjuntos deberían ser `https://` y de dominios autorizados.
- El backend puede protegerse con `X-API-Key` o JWT; el cliente Flutter ya quedó listo para enviar `X-API-Key` por `--dart-define`.
