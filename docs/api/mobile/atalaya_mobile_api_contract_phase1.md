# Atalaya-Mobile ↔ Atalaya-Predictor — Phase 1 API Contract

## Goal

Define the minimum JSON API contract required for Atalaya-Mobile to connect to Atalaya-Predictor staging with real credentials and real dashboard/trend data.

This contract intentionally matches the current Atalaya-Mobile client paths as closely as possible:

- `POST /auth/login`
- `POST /auth/logout`
- `GET /api/v1/dashboard`
- `GET /api/v1/trends?tag=...&range=...`
- `GET /api/v1/alerts/{alertId}/attachments`
- Future: `GET /api/v1/predictor?type=...`

The current Predictor staging service is a Dash app with Flask under `app.server`; mobile API routes can be registered on that Flask server without creating a new Render service during staging.

---

## Authentication

### POST `/auth/login`

Mobile sends:

```json
{
  "username": "mobile_test@atalaya.local",
  "password": "AtalayaTest123!"
}
```

Backend returns `200`:

```json
{
  "access_token": "<jwt-or-signed-token>",
  "token_type": "bearer",
  "expires_in": 43200,
  "user": {
    "id": "mobile_test",
    "username": "mobile_test@atalaya.local",
    "role": "operator"
  }
}
```

Backend returns `401` for invalid credentials:

```json
{
  "detail": "Invalid username or password"
}
```

### POST `/auth/logout`

Headers:

```http
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true
}
```

Logout can be stateless for staging. Mobile will clear local secure storage either way.

---

## Auth Header for Protected Endpoints

Every `/api/v1/*` mobile endpoint must require:

```http
Authorization: Bearer <token>
```

Return `401` if missing, expired, malformed, or invalid.

---

## Dashboard Endpoint

### GET `/api/v1/dashboard`

Headers:

```http
Authorization: Bearer <token>
Accept: application/json
```

Response shape expected by Atalaya-Mobile:

```json
{
  "well": "IXACHI-45",
  "job": "Monitoreo de pozo",
  "latestSampleAt": "2026-04-18T18:00:00Z",
  "staleThresholdSeconds": 12,
  "variables": [
    {
      "slot": 1,
      "label": "RPM",
      "tag": "rpm",
      "rawUnit": "rpm",
      "value": 132.4,
      "sampleAt": "2026-04-18T18:00:00Z",
      "configured": true
    }
  ],
  "alerts": [
    {
      "id": "kp-001",
      "description": "KP: torque en tendencia ascendente.",
      "severity": "ATTENTION",
      "createdAt": "2026-04-18T17:58:00Z",
      "attachmentsCount": 0,
      "attachments": []
    }
  ]
}
```

### Variable object

Required fields:

| Field | Type | Notes |
|---|---:|---|
| `slot` | int | Visual order, 1-based. |
| `label` | string | Human readable label. |
| `tag` | string | Stable machine key, e.g. `rpm`, `hook_load`. |
| `rawUnit` or `raw_unit` | string | Unit before mobile conversion. |
| `value` | number/string/null | Numeric preferred. |
| `sampleAt` or `sample_at` | ISO datetime/null | UTC preferred. |
| `configured` | bool | `true` for active variables. |

Recommended initial tags:

```text
rpm
torque
mud_flow_in
standpipe_pressure
weight_on_bit
hook_load
rop
pump_pressure
```

### Alert object

Required fields:

| Field | Type | Notes |
|---|---:|---|
| `id` | string | Stable alert ID. |
| `description` | string | Message shown in mobile dock. |
| `severity` | string | `OK`, `ATTENTION`, or `CRITICAL`. |
| `createdAt` or `created_at` | ISO datetime | UTC preferred. |
| `attachmentsCount` or `attachments_count` | int | Number displayed by mobile. |
| `attachments` | array | Can be empty initially. |

---

## Trend Endpoint

### GET `/api/v1/trends`

Query parameters:

| Name | Required | Allowed values |
|---|---:|---|
| `tag` | yes | variable tag, e.g. `rpm` |
| `range` | yes | `30m`, `2h`, `6h` or mobile labels currently used by `TrendRange.label` |

Response:

```json
{
  "tag": "rpm",
  "range": "30m",
  "points": [
    {
      "timestamp": "2026-04-18T17:30:00Z",
      "value": 128.2
    },
    {
      "timestamp": "2026-04-18T18:00:00Z",
      "value": 132.4
    }
  ]
}
```

Atalaya-Mobile only requires `points` with `timestamp` and `value`.

---

## Alert Attachments Endpoint

### GET `/api/v1/alerts/{alertId}/attachments`

Response:

```json
{
  "attachments": [
    {
      "id": "att-001",
      "name": "kp_snapshot.png",
      "url": "https://...",
      "mimeType": "image/png",
      "sizeBytes": 123456,
      "createdAt": "2026-04-18T18:00:00Z"
    }
  ]
}
```

This endpoint may return an empty list during staging.

---

## Future Predictor Endpoint

### GET `/api/v1/predictor`

Query parameters:

| Name | Required | Allowed values |
|---|---:|---|
| `type` | yes | `hook_load`, `surface_torque`, `pump_pressure` |
| `well` | no | e.g. `IXACHI-45` |
| `job` | no | e.g. `Monitoreo de pozo` |

Response proposal:

```json
{
  "type": "hook_load",
  "title": "Hook Load",
  "unit": "ton",
  "xAxisLabel": "Hook Load (ton)",
  "yAxisLabel": "MD Depth (m)",
  "envelopes": [
    [
      {"x": 30.0, "y": 0.0},
      {"x": 80.0, "y": 1000.0}
    ]
  ],
  "warnLine": [
    {"x": 90.0, "y": 1000.0}
  ],
  "criticalLine": [
    {"x": 105.0, "y": 1000.0}
  ],
  "fieldDepths": [400.0, 820.0, 1240.0],
  "generatedAt": "2026-04-18T18:00:00Z"
}
```

This endpoint is not required for Phase 1 if the special predictor remains mock/read-only.

---

## Error Format

Use this shape consistently:

```json
{
  "detail": "Human readable error message"
}
```

Recommended status codes:

| Code | Meaning |
|---:|---|
| 200 | OK |
| 400 | Bad request / missing query param |
| 401 | Missing or invalid token |
| 404 | Resource not found |
| 500 | Unexpected backend error |

---

## Phase 1 Acceptance Criteria

- Contract is accepted by mobile and backend.
- Backend team confirms whether routes will be added to the existing Dash Flask server or a separate service.
- `POST /auth/login` response shape is agreed.
- `GET /api/v1/dashboard` response shape is agreed.
- `GET /api/v1/trends` response shape is agreed.
- No secrets or real passwords are committed to Git.

