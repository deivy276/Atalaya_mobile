# Atalaya Full Restore Bundle

Orden recomendado:
1. Extrae `Atalaya_Flutter_Core_Source` a una carpeta nueva.
2. Ejecuta los scripts de `Atalaya_Flutter_Recreate_Platforms_Scripts` para regenerar android/ios/linux/macos/web/windows.
3. Extrae `Atalaya_Backend_FastAPI_Stable` y crea un entorno virtual en `backend_fastapi`.
4. Instala `requirements.txt` y arranca el backend en `127.0.0.1:8010`.
5. Ejecuta el SQL necesario desde `Atalaya_DB_SQL_Benchmarks_Checks/sql`.
6. Valida con los benchmarks y checks.

Nota honesta: este bundle se reconstruyo a partir de los artefactos disponibles. No incluye todos los archivos temporales ni binarios generados del proyecto original, porque no son necesarios para restaurar una base limpia.
