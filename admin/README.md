# Sipi — Panel de administración

Panel web administrativo (HTML + JS vanilla, sin build) contra la misma API del backend.
Diseño con barra lateral oscura y tarjetas, según el mockup del proyecto.

## Correr

1. Backend arriba: `cd ../backend && npm start` (puerto 3000).
2. Servir el panel: `python3 -m http.server 8080` dentro de esta carpeta.
3. Abrir `http://localhost:8080` y entrar con `admin@sipi.app / admin123`.

> El panel detecta el puerto 8080 y apunta la API a `http://localhost:3000`.
> Si sirves el panel desde otro origen, ajusta la constante `API` en `index.html`.

## Páginas

- **Panel**: tarjetas de Usuarios, Tareas activas, Encuestas activas y Pagos
  autorizados; gráfica de actividad de usuarios (30 días, SVG puro); dona de
  tipos de tareas por categoría; resumen general. Acceso directo a revisiones
  pendientes.
- **Usuarios**: buscador; tabla con avatar, puntos, nivel, rol y estado
  (Activo/Inactivo); acciones para hacer/quitar admin y activar/desactivar.
- **Tareas**: buscador + filtro por categoría; botón **Crear tarea**; tabla con
  Título, Categoría, Puntos, Estado y acciones (interruptor activar/pausar,
  editar, encuesta, pausar). Pestaña **Por revisar** para aprobar o rechazar
  envíos pendientes (al aprobar, el ledger acredita los puntos).
- **Encuestas**: editor de preguntas por tarea (única, múltiple, sí/no, escala,
  texto; opciones y obligatoriedad configurables).
- **Pagos**: buscador + filtro por estado; tabla de canjes (usuario, monto,
  puntos, fecha, estado); marcar como pagado o rechazar (el rechazo devuelve
  los puntos vía movimiento `REVERSAL`).
- **Reportes**: usuarios totales, puntos emitidos, pagado a usuarios,
  % de usuarios con puntos; crecimiento (30 días); top 5 por saldo; canjes por
  estado. Botón Imprimir.
- **Configuración**: conversión global puntos→USD (`PUT /api/admin/config`).
  La app la lee de `/api/config`; nunca está hardcodeada.

## Notas

- Gráficas dibujadas con SVG puro (sin dependencias externas).
- El token de admin se guarda en `localStorage` (`sipi_admin_token`).
- Todo el texto dinámico se escapa para evitar XSS.
