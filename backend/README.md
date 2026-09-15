# Sipi — Backend API

API REST de la plataforma Sipi (recompensas por tareas). Node.js + Express + SQLite (`node:sqlite`, sin dependencias nativas).

## Arranque

```bash
npm install
npm run seed   # crea admin@sipi.app / admin123 + tareas de ejemplo
npm start      # http://localhost:3000
```

Variables de entorno: `PORT`, `JWT_SECRET` (¡definir en producción!), `DB_PATH`.

## Diseño

- **Ledger inmutable**: el saldo siempre se deriva de `SUM(points)` en la tabla `ledger`.
  No existen endpoints de modificación/eliminación de movimientos.
- **El cliente nunca envía montos**: todos los puntos y conversiones los calcula el servidor.
- **Conversión configurable**: `PUT /api/admin/config` (`points_per_usd`, por defecto 50).
- **Anti doble acreditación**: aprobar dos veces devuelve 409; constraint único en el ledger + `max_completions_per_user` por tarea.
- **Verificación**: `manual` (admin aprueba) o `auto` (encuestas: la respuesta válida acredita de inmediato).
- **Logros**: se evalúan dentro de la transacción de cada evento (primera tarea, 10 tareas, 100/500 pts, primera encuesta, primer canje) y pagan bonus vía ledger.

## Endpoints principales

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/register`, `/api/auth/login` | Alta e inicio de sesión (JWT) |
| GET | `/api/balance`, `/api/ledger` | Saldo (pts + USD) e historial |
| GET | `/api/tasks?category=&q=` | Tareas activas con filtros |
| POST | `/api/tasks/:id/submit` | Enviar tarea a verificación |
| GET/POST | `/api/tasks/:id/survey` | Obtener / responder encuesta |
| POST/GET | `/api/redemptions` | Solicitar canje / historial |
| GET | `/api/achievements`, `/api/notifications` | Logros y notificaciones |
| GET | `/api/admin/stats`, `/api/admin/users` | Dashboard y usuarios |
| POST/PUT | `/api/admin/tasks` | Crear / editar tareas |
| POST | `/api/admin/tasks/:id/survey` | Adjuntar encuesta a tarea |
| GET/POST | `/api/admin/completions` | Revisar y aprobar/rechazar |
| GET/POST | `/api/admin/redemptions/:id/complete`, `.../reject` | Procesar canjes (reject → REVERSAL) |
| PUT | `/api/admin/config` | Cambiar conversión puntos→USD |

## Tests

```bash
npm test   # 22 pruebas (jest + supertest, SQLite en memoria)
```
