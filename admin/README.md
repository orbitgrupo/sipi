# Sipi — Panel de administración

Panel web ligero (HTML + JS vanilla, sin build) contra la misma API del backend.

## Correr

1. Backend arriba: `cd ../backend && npm start` (puerto 3000).
2. Servir el panel: `python3 -m http.server 8080` dentro de esta carpeta.
3. Abrir `http://localhost:8080` y entrar con `admin@sipi.app / admin123`.

> El panel detecta el puerto 8080 y apunta la API a `http://localhost:3000`.
> Si sirves el panel desde otro origen, ajusta la constante `API` en `index.html`.

## Secciones

- **Resumen**: usuarios, tareas activas, verificaciones pendientes, puntos
  emitidos y pagos pendientes en USD.
- **Tareas**: crear, editar, activar/desactivar. Botón **Encuesta** para
  adjuntar preguntas (única, múltiple, sí/no, escala, texto) a una tarea.
- **Verificaciones**: aprobar o rechazar envíos pendientes. Al aprobar, el
  ledger acredita los puntos (más bonus de logros si aplica).
- **Usuarios**: saldo, nivel, cambiar rol admin/usuario, activar/desactivar.
- **Canjes**: marcar como pagado o rechazar (el rechazo devuelve los puntos
  vía movimiento `REVERSAL`).
- **Configuración**: conversión global puntos→USD (nunca hardcodeada en la
  app; la app la lee de `/api/config`).
