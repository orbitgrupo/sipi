# Sipi — Arquitectura

Plataforma de recompensas por tareas: los usuarios ganan puntos completando
tareas (redes sociales, encuestas, promociones) y los canjean por dinero.

## Piezas del sistema

```
┌─────────────────┐         ┌─────────────────┐
│   app/ (Flutter)│         │ admin/ (web)    │
│  App móvil para │         │ Panel web para  │
│  usuarios finales│        │ administradores │
└────────┬────────┘         └────────┬────────┘
         │  HTTPS / JSON            │  HTTPS / JSON
         │  JWT (Bearer)            │  JWT (Bearer, localStorage)
         └──────────┬───────────────┘
                    ▼
         ┌─────────────────────┐
         │ backend/ (Node.js)  │
         │ Express + SQLite    │
         │  · Auth JWT         │
         │  · Ledger inmutable │
         │  · Verificación     │
         └──────────┬──────────┘
                    ▼
            SQLite (node:sqlite)
            backend/data/sipi.db
```

Las tres piezas viven en este mismo repositorio, cada una en su carpeta con
su propio `README.md`:

| Carpeta | Qué es | Stack | README |
|---|---|---|---|
| `app/` | App móvil para usuarios | Flutter (Dart) | [app/README.md](../app/README.md) |
| `admin/` | Panel web de administración | HTML + JS vanilla, sin build | [admin/README.md](../admin/README.md) |
| `backend/` | API REST + base de datos | Node.js + Express + SQLite | [backend/README.md](../backend/README.md) |

## Flujos principales

### Ganar puntos
1. La app pide `GET /api/tasks` y muestra las tareas activas.
2. El usuario envía una tarea: `POST /api/tasks/:id/submit`.
3. Verificación **manual** → queda `pending`; un admin la aprueba desde el
   panel (`POST /api/admin/completions/:id/approve`) y el servidor acredita
   los puntos en el ledger.
4. Verificación **auto** (encuestas) → al responder válido
   (`POST /api/tasks/:id/survey`), el servidor acredita de inmediato.

### Canjear puntos
1. La app lee `GET /api/config` → `points_per_usd` (por defecto 50).
2. El usuario solicita: `POST /api/redemptions` (solo envía puntos; el monto
   USD lo calcula el servidor).
3. El canje queda `pending`. El admin lo marca pagado
   (`POST /api/admin/redemptions/:id/complete`) o lo rechaza
   (`.../reject`, que devuelve los puntos con un movimiento `REVERSAL`).

### Logros
Al aprobar tareas, responder encuestas o canjear, el servidor evalúa los
logros dentro de la misma transacción y paga el bonus vía ledger (`BONUS`).
La app los muestra en `GET /api/achievements`.

## Reglas de negocio (se cumplen en el servidor, no en el cliente)

- **El saldo se calcula**: `SUM(ledger.points)` por usuario. No existe ningún
  campo de saldo editable ni endpoint que lo modifique.
- **El cliente nunca envía montos**: los puntos de cada tarea y la conversión
  a USD los define y calcula el servidor.
- **Ledger inmutable**: tipos `EARN`, `BONUS`, `REDEEM`, `REVERSAL`,
  `ADJUSTMENT`. No hay endpoints de UPDATE/DELETE sobre el ledger.
- **Sin doble acreditación**: constraint único en el ledger + límite
  `max_completions_per_user` por tarea; aprobar dos veces devuelve 409.
- **Aprobación de cuentas**: el registro no exige verificar el correo; las
  cuentas nuevas nacen con `approved = 0` y el perfil muestra "Cuenta
  pendiente de aprobación". Un admin las aprueba desde el panel
  (`PATCH /api/admin/users/:id` con `approved: 1`).
- **Conversión configurable**: `points_per_usd` en la tabla `config`,
  editable desde el panel. La app y el panel la leen del servidor.

## Documentos

- [API.md](API.md) — referencia completa de endpoints.
- [DISENO.md](DISENO.md) — sistema de diseño compartido (colores, tipografía).
- [preview-app.html](preview-app.html) — maqueta visual de las pantallas de la app.
- `img/` — capturas reales del panel administrativo.
