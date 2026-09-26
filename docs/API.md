# Sipi — Referencia de la API

Base: `http://localhost:3000`. Auth: header `Authorization: Bearer <JWT>`.
Roles: `user` y `admin` (los endpoints `/api/admin/*` exigen admin).

## Auth

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/api/auth/register` | — | `{name, email, password}` → `{token, user}` |
| POST | `/api/auth/login` | — | `{email, password}` → `{token, user}` |
| GET | `/api/auth/me` | Sí | Usuario actual |

## Usuario

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/balance` | `{points, usd}` — saldo calculado del ledger |
| GET | `/api/ledger` | Historial de movimientos del usuario |
| GET | `/api/config` | Pública. `{points_per_usd}` (defecto 50) |
| PUT | `/api/users/me` | Editar nombre/email (valida duplicados) |
| PUT | `/api/users/me/password` | Cambiar contraseña (pide la actual) |
| GET | `/api/notifications` | Notificaciones del usuario |
| POST | `/api/notifications/:id/read` | Marcar notificación como leída |

## Tareas y encuestas

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/tasks?category=&q=` | Tareas activas, con filtros |
| GET | `/api/tasks/:id` | Detalle de tarea |
| POST | `/api/tasks/:id/submit` | Enviar a verificación `{evidence?}` |
| GET | `/api/tasks/:id/survey` | Encuesta de la tarea |
| POST | `/api/tasks/:id/survey` | Responder; si es válida acredita auto |

Categorías: `social`, `encuestas`, `productos`, `opinion`, `promociones`, `otras`.
Verificación: `manual` (aprueba un admin) o `auto` (encuestas).

## Canjes y logros

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/redemptions` | Solicitar canje `{points}` — el USD lo calcula el servidor |
| GET | `/api/redemptions` | Historial de canjes del usuario |
| GET | `/api/achievements` | Logros + estado del usuario |

Estados de canje: `pending` → `completed` | `rejected` (devuelve puntos vía `REVERSAL`).

## Administración (`/api/admin/*`, solo admin)

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/stats` | Usuarios, tareas activas, encuestas, puntos emitidos, USD pagado/pendiente, actividad 30 días, top tareas |
| GET | `/api/admin/activity` | Actividad reciente de usuarios |
| GET | `/api/admin/users` | Usuarios con puntos y nivel |
| PATCH | `/api/admin/users/:id` | Cambiar rol (`role`) o estado (`status`) |
| GET | `/api/admin/tasks` | Todas las tareas (activas e inactivas) |
| POST | `/api/admin/tasks` | Crear tarea |
| PUT | `/api/admin/tasks/:id` | Editar tarea (incluye activar/pausar) |
| POST | `/api/admin/tasks/:id/survey` | Crear/reemplazar encuesta de la tarea |
| GET | `/api/admin/completions` | Envíos pendientes de revisión |
| POST | `/api/admin/completions/:id/approve` | Aprobar → acredita puntos (idempotente: doble approve = 409) |
| POST | `/api/admin/completions/:id/reject` | Rechazar envío |
| GET | `/api/admin/redemptions` | Canjes con filtro por estado |
| POST | `/api/admin/redemptions/:id/complete` | Marcar canje como pagado |
| POST | `/api/admin/redemptions/:id/reject` | Rechazar canje → `REVERSAL` de puntos |
| PUT | `/api/admin/config` | `{points_per_usd}` — conversión global |

## Modelo de datos (SQLite)

Tablas: `users`, `config`, `tasks`, `task_completions`, `ledger`,
`surveys`, `survey_responses`, `achievements`, `user_achievements`,
`redemptions`, `notifications`.

- `ledger`: inmutable (`EARN`, `BONUS`, `REDEEM`, `REVERSAL`, `ADJUSTMENT`);
  el saldo es `SUM(points)`. Sin endpoints de UPDATE/DELETE.
- `task_completions`: `pending` → `approved` | `rejected`.
- `redemptions`: `pending` → `completed` | `rejected`.

Ver el esquema exacto en `backend/src/db.js` y las reglas en
[ARQUITECTURA.md](ARQUITECTURA.md).
