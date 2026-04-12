# Reparación de `kp_state` para Atalaya

## Qué corrige

- elimina la fila corrupta `VAR_1_UNIT` que contiene CSS/blob
- deja de usar `VAR_1 = raw` como pseudo-tag
- carga un mapeo explícito `VAR_n_TAG` / `VAR_n_LABEL`
- alinea los slots del dashboard con tags reales detectadas en `atalaya_samples`

## Evidencia previa

Antes de aplicar este script, `kp_state` sólo tenía 4 filas útiles:
- `CURRENT_JOB`
- `CURRENT_WELL`
- `VAR_1 = raw`
- `VAR_1_UNIT = <blob CSS>`

Y las tags reales presentes en `atalaya_samples` eran:
- `RPMA.`
- `TQA.`
- `MFIA.`
- `SPPA.`
- `WOBA.`
- `HKLA.`
- `DBTM.`
- `DMEA.`
- `BPOS.`

## Aplicación

### Opción 1: desde pgAdmin / DBeaver / TablePlus

1. Abre tu conexión a PostgreSQL/Render.
2. Abre el archivo `atalaya_kp_state_repair.sql`.
3. Ejecuta el script completo.
4. Reinicia FastAPI.
5. Haz hot restart a Flutter.

### Opción 2: con `psql`

```powershell
psql "host=dpg-d5hbi64hg0os73ft22ng-a.oregon-postgres.render.com port=5432 dbname=atalaya_db user=atalaya_db_user sslmode=require" -f .\atalaya_kp_state_repair.sql
```

## Verificación

Después de aplicar el script:

```powershell
Invoke-RestMethod http://127.0.0.1:8010/api/v1/debug/kp-state | ConvertTo-Json -Depth 8
Invoke-RestMethod http://127.0.0.1:8010/api/v1/debug/slots | ConvertTo-Json -Depth 8
Invoke-RestMethod http://127.0.0.1:8010/api/v1/dashboard | ConvertTo-Json -Depth 8
```

Resultados esperados:
- `kp-state` ya no debe mostrar CSS en `VAR_1_UNIT`
- `slots[0].tag` debe ser `RPMA.`
- `dashboard.variables[0].configured` debe ser `true`
- `latestSampleAt` debe acercarse a las fechas recientes de `atalaya_samples`

## Mapeo cargado

| Slot | Tag   | Label                | Unit |
|------|-------|----------------------|------|
| 1    | RPMA. | RPM                  |      |
| 2    | TQA.  | Torque               |      |
| 3    | MFIA. | Mud Flow In          |      |
| 4    | SPPA. | Standpipe Pressure   | psi  |
| 5    | WOBA. | Weight on Bit        |      |
| 6    | HKLA. | Hook Load            |      |
| 7    | DBTM. | Bit Depth            |      |
| 8    | DMEA. | Measured Depth       |      |
| 9    | BPOS. | Block Position       |      |
| 10   |       | VAR 10               |      |
| 11   |       | VAR 11               |      |
| 12   |       | VAR 12               |      |

