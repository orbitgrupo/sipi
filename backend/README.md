# Sipi — Backend API

API REST de la plataforma Sipi (recompensas por tareas).

- **Producción (Dokploy):** Node.js + Express + **PostgreSQL (Supabase)** con
  Supabase Auth. Punto de entrada: `src/server.js` → `src/app.postgres.js`.
- **Legado local:** Node.js + Express + SQLite con `node:sqlite`
  (`src/app.js`, `src/db.js`, `src/seed.js`). No se usa en producción.

## Arranque

```bash
npm install
npm run seed:pg  # PostgreSQL: crea 1 tarea por cada tipo (6) + encuesta de ejemplo
npm start        # http://localhost:3000 (usa app.postgres.js)
```

`npm run seed:pg` usa las mismas variables de entorno que el backend
(`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, opcional `DB_SCHEMA`).
Es idempotente: no duplica tareas que ya existan por título.

Variables de entorno: `PORT` (3000), `JWT_SECRET` (¡definir en producción!),
`SUPABASE_URL`, `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` según el módulo.

## Estructura

```
src/
├── server.js        # arranque (lee PORT, abre DB)
├── app.js           # Express: middlewares, rutas, manejo de errores
├── db.js            # esquema SQLite + seed de config y logros
├── auth.js          # hash bcrypt + JWT
├── ledger.js        # helper: acreditar movimientos (transaccional)
├── achievements.js  # evaluación de logros dentro de cada evento
└── seed.js          # datos demo (admin, tareas, encuesta)
tests/
└── api.test.js      # 32 pruebas (jest + supertest, SQLite en memoria)
```

## Diseño

- **Ledger inmutable**: el saldo siempre se deriva de `SUM(points)` en la
  tabla `ledger`. No existen endpoints de UPDATE/DELETE sobre movimientos.
- **El cliente nunca envía montos**: puntos y conversiones los calcula el
  servidor.
- **Conversión configurable**: `PUT /api/admin/config` (`points_per_usd`,
  por defecto 50). La app y el panel la leen de `GET /api/config`.
- **Anti doble acreditación**: constraint único en el ledger +
  `max_completions_per_user` por tarea; aprobar dos veces devuelve 409.
- **Aprobación de cuentas**: el registro no exige verificar el correo; las
  cuentas nuevas nacen con `approved = 0`. Un admin las aprueba con
  `PATCH /api/admin/users/:id` (`approved: 1`).
- **Verificación**: `manual` (un admin aprueba desde el panel) o `auto`
  (encuestas: la respuesta válida acredita de inmediato).
- **Logros**: se evalúan dentro de la transacción de cada evento (primera
  tarea, 10 tareas, 100/500 pts, primera encuesta, primer canje) y pagan
  bonus vía ledger (`BONUS`).
- **Sin transacciones anidadas**: `node:sqlite` no las soporta; se usa el
  helper `transaction(db, fn)` y el núcleo de aprobación se reusa dentro de
  la transacción de encuestas.

## Tablas (SQLite)

`users`, `config`, `tasks`, `task_completions`, `ledger`, `surveys`,
`survey_responses`, `achievements`, `user_achievements`, `redemptions`,
`notifications`. Esquema exacto en `src/db.js`.

Logros por defecto: Primera tarea (+5), Racha de 10 (+25), 100 puntos (+10),
500 puntos (+50), Encuestador (+5), Primer canje (+5).

Datos demo (`npm run seed`): admin `admin@sipi.app / admin123`, 8 tareas
(social, encuestas, opinión, promociones) y una encuesta de productos con
5 preguntas (única, múltiple, sí/no, escala, texto).

## Endpoints

Referencia completa en [../docs/API.md](../docs/API.md). Resumen:

| Área | Rutas |
|---|---|
| Auth | `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me` |
| Usuario | `GET /api/balance`, `GET /api/ledger`, `PUT /api/users/me`, `PUT /api/users/me/password`, `GET /api/notifications` |
| Tareas | `GET /api/tasks`, `GET /api/tasks/:id`, `POST /api/tasks/:id/submit`, `GET+POST /api/tasks/:id/survey` |
| Canjes | `POST /api/redemptions`, `GET /api/redemptions`, `GET /api/achievements` |
| Admin | `GET /api/admin/stats`, `GET /api/admin/users`, `PATCH /api/admin/users/:id`, `GET+POST /api/admin/tasks`, `PUT /api/admin/tasks/:id`, `POST /api/admin/tasks/:id/survey`, `GET /api/admin/completions`, `POST …/approve`, `POST …/reject`, `GET /api/admin/redemptions`, `POST …/complete`, `POST …/reject`, `PUT /api/admin/config` |

## Tests

```bash
npm test   # 32 pruebas (jest + supertest, SQLite en memoria)
```
