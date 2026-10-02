const express = require('express');
const path = require('path');

const {
  requireAuth,
  maybeAuth,
  makeRequireAdmin,
} = require('./auth');

const {
  getBalance,
  addEntry,
  getMovements,
  httpError,
} = require('./ledger');

const {
  checkAndAward,
  metricValue,
} = require('./achievements');

const { supabaseAdmin } = require('./supabase');

const SCHEMA = 'sipi_dev';

// ─────────────────────────────────────────────
// SOPORTE — las tablas se crean solas al arrancar
// ─────────────────────────────────────────────

async function ensureSupportTables(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS ${SCHEMA}.support_threads (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID NOT NULL,
      subject TEXT NOT NULL DEFAULT '',
      kind TEXT NOT NULL DEFAULT 'pregunta',
      status TEXT NOT NULL DEFAULT 'open',
      unread_admin BOOLEAN NOT NULL DEFAULT TRUE,
      unread_user BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
  await db.query(`
    CREATE TABLE IF NOT EXISTS ${SCHEMA}.support_messages (
      id BIGSERIAL PRIMARY KEY,
      thread_id BIGINT NOT NULL REFERENCES ${SCHEMA}.support_threads(id) ON DELETE CASCADE,
      sender TEXT NOT NULL,
      sender_name TEXT NOT NULL DEFAULT '',
      body TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_support_threads_user ON ${SCHEMA}.support_threads(user_id)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_support_messages_thread ON ${SCHEMA}.support_messages(thread_id)`);
  // Por si las tablas ya existían sin la columna (creadas a mano):
  await db.query(`ALTER TABLE ${SCHEMA}.support_messages ADD COLUMN IF NOT EXISTS sender_name TEXT NOT NULL DEFAULT ''`);
  // Columnas para enlazar notificaciones con el chat (deep-link en la app).
  try {
    await db.query(`ALTER TABLE ${SCHEMA}.notifications ADD COLUMN IF NOT EXISTS reference_type TEXT NOT NULL DEFAULT ''`);
    await db.query(`ALTER TABLE ${SCHEMA}.notifications ADD COLUMN IF NOT EXISTS reference_id BIGINT`);
  } catch (e) {
    console.error('[sipi] No se pudieron agregar columnas a notifications:', e.message);
  }
  // Imagen de la tarea (logo de red social o URL personalizada).
  try {
    await db.query(`ALTER TABLE ${SCHEMA}.tasks ADD COLUMN IF NOT EXISTS image_url TEXT NOT NULL DEFAULT ''`);
  } catch (e) {
    console.error('[sipi] No se pudo agregar image_url a tasks:', e.message);
  }
}

function serializeThread(t) {
  return {
    id: Number(t.id),
    user_id: t.user_id,
    subject: t.subject || '',
    kind: t.kind || 'pregunta',
    status: t.status || 'open',
    unread_admin: !!t.unread_admin,
    unread_user: !!t.unread_user,
    created_at: t.created_at,
    updated_at: t.updated_at,
  };
}

function serializeSupportMessage(m) {
  return {
    id: Number(m.id),
    thread_id: Number(m.thread_id),
    sender: m.sender,
    sender_name: m.sender_name || '',
    body: m.body,
    created_at: m.created_at,
  };
}

// Si las tablas de soporte aún no existen (p. ej. el rol de la API no
// pudo crearlas al arrancar), intenta crearlas y reintenta una vez.
async function withSupportTables(db, fn) {
  try {
    return await fn();
  } catch (e) {
    if (e && e.code === '42P01') {
      await ensureSupportTables(db);
      return await fn();
    }
    throw e;
  }
}

// Notificación in-app al usuario. Intenta enlazarla al chat (deep-link);
// si las columnas de referencia no existen, guarda la notificación igual.
async function notifyUser(db, n) {
  try {
    await db.query(
      `INSERT INTO ${SCHEMA}.notifications (user_id, type, title, body, reference_type, reference_id)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [n.userId, n.type, n.title, n.body, n.refType || '', n.refId ?? null]
    );
  } catch (e) {
    if (e && e.code === '42703') {
      await db.query(
        `INSERT INTO ${SCHEMA}.notifications (user_id, type, title, body)
         VALUES ($1, $2, $3, $4)`,
        [n.userId, n.type, n.title, n.body]
      );
      return;
    }
    throw e;
  }
}

const SUPPORT_FAREWELL =
  '¡Gracias por conversar con nosotros! Esta conversación se cerró automáticamente por inactividad, pero queda guardada en tu historial. Si necesitas más ayuda, abre una nueva consulta cuando quieras. ¡Que tengas un excelente día!';

// Cierra los chats abiertos sin mensajes nuevos en 2 minutos: los archiva
// (status closed), deja una despedida del sistema y notifica al usuario.
async function closeInactiveSupportThreads(db) {
  let stale;

  try {
    stale = await db.query(
      `UPDATE ${SCHEMA}.support_threads
          SET status = 'closed', updated_at = now()
        WHERE status = 'open'
          AND updated_at < now() - interval '2 minutes'
        RETURNING id, user_id`
    );
  } catch (e) {
    if (e && e.code === '42P01') return; // tablas aún no creadas
    console.error('[sipi] auto-cierre de soporte:', e.message);
    return;
  }

  for (const t of stale.rows) {
    try {
      await db.query(
        `INSERT INTO ${SCHEMA}.support_messages (thread_id, sender, sender_name, body)
         VALUES ($1, 'system', '', $2)`,
        [t.id, SUPPORT_FAREWELL]
      );
      await notifyUser(db, {
        userId: t.user_id,
        type: 'support',
        title: 'Chat de soporte cerrado',
        body: 'La conversación se cerró por inactividad. Tu historial queda guardado y puedes abrir una nueva consulta cuando quieras.',
        refType: 'support_thread',
        refId: Number(t.id),
      });
    } catch (e) {
      console.error('[sipi] auto-cierre de soporte (mensaje):', e.message);
    }
  }
}

function asyncRoute(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function validEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function normalizeHandle(value) {
  return String(value || '').trim().replace(/^@+/, '');
}

function asInt(value, fallback = null) {
  const n = Number(value);
  return Number.isInteger(n) ? n : fallback;
}

function pgError(error) {
  if (error && error.status) return error;

  if (error && error.code === '23505') {
    return httpError(409, 'CONFLICT');
  }

  if (error && error.code === '23503') {
    return httpError(400, 'INVALID_REFERENCE');
  }

  if (error && error.code === '23514') {
    return httpError(400, 'INVALID_VALUE');
  }

  return error;
}

async function getProfile(db, userId, client = db) {
  const result = await client.query(
    `SELECT id, name, role, status, approved, created_at, updated_at
       FROM ${SCHEMA}.profiles
      WHERE id = $1`,
    [userId]
  );

  return result.rows[0] || null;
}

async function getAuthUser(userId) {
  const { data, error } = await supabaseAdmin.auth.admin.getUserById(userId);

  if (error || !data?.user) {
    return null;
  }

  return data.user;
}

async function userView(db, userId, client = db) {
  const profile = await getProfile(db, userId, client);

  if (!profile) return null;

  const authUser = await getAuthUser(userId);

  return {
    id: profile.id,
    name: profile.name,
    email: authUser?.email || null,
    role: profile.role,
    status: profile.status,
    approved: profile.approved,
    created_at: profile.created_at,
    updated_at: profile.updated_at,
  };
}

async function getPointsPerUsd(db, client = db) {
  const result = await client.query(
    `SELECT value
       FROM ${SCHEMA}.config
      WHERE key = 'points_per_usd'
      LIMIT 1`
  );

  const value = Number(result.rows[0]?.value);
  return Number.isFinite(value) && value > 0 ? value : 50;
}

async function lockProfile(client, userId) {
  const result = await client.query(
    `SELECT id
       FROM ${SCHEMA}.profiles
      WHERE id = $1
      FOR UPDATE`,
    [userId]
  );

  if (!result.rowCount) {
    throw httpError(404, 'USER_NOT_FOUND');
  }
}

function createApp(db) {
  const app = express();
  const requireAdmin = makeRequireAdmin(db);

  // Crea las tablas de soporte si aún no existen (idempotente).
  ensureSupportTables(db).catch((e) =>
    console.error('[sipi] No se pudieron crear las tablas de soporte:', e.message)
  );

  // Auto-cierre de chats de soporte por inactividad (2 min): revisa cada 30 s.
  setInterval(() => closeInactiveSupportThreads(db), 30 * 1000);
  closeInactiveSupportThreads(db);

  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));

  // Imágenes públicas de tareas (logos de redes sociales, etc.).
  app.use('/public', express.static(path.join(__dirname, '..', 'public')));

  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization'
    );
    res.setHeader(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    );

    if (req.method === 'OPTIONS') {
      return res.sendStatus(204);
    }

    next();
  });

  app.get('/api/health', asyncRoute(async (_req, res) => {
    const result = await db.query(
      'SELECT current_database() AS database, current_user AS user'
    );

    res.json({
      ok: true,
      database: result.rows[0].database,
      user: result.rows[0].user,
    });
  }));


  // ─────────────────────────────────────────────
  // AUTH — Registro con Supabase Auth
  // ─────────────────────────────────────────────

  app.post('/api/auth/register', asyncRoute(async (req, res) => {
    const name = String(req.body?.name || '').trim();
    const email = normalizeEmail(req.body?.email);
    const password = String(req.body?.password || '');

    if (!name || !validEmail(email)) {
      throw httpError(400, 'INVALID_INPUT');
    }

    if (password.length < 6) {
      throw httpError(400, 'WEAK_PASSWORD');
    }

    // Supabase Auth mantiene la identidad y contraseña.
    // Confirmamos Auth inmediatamente para conservar el flujo actual
    // de Sipi. La aprobación de la cuenta sigue siendo independiente
    // mediante sipi_dev.profiles.approved.
    const { data: createData, error: createError } =
      await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { name },
      });

    if (createError) {
      const message = String(createError.message || '').toLowerCase();

      if (
        message.includes('already') ||
        message.includes('registered') ||
        message.includes('exists')
      ) {
        throw httpError(409, 'EMAIL_TAKEN');
      }

      throw httpError(
        createError.status || 400,
        'AUTH_REGISTER_FAILED'
      );
    }

    const authUser = createData?.user;

    if (!authUser?.id) {
      throw httpError(500, 'AUTH_REGISTER_FAILED');
    }

    const { data: loginData, error: loginError } =
      await supabaseAdmin.auth.signInWithPassword({
        email,
        password,
      });

    if (loginError || !loginData?.session?.access_token) {
      try {
        await supabaseAdmin.auth.admin.deleteUser(authUser.id);
      } catch (_) {}

      throw httpError(500, 'AUTH_SESSION_FAILED');
    }

    try {
      await db.query(
        `INSERT INTO ${SCHEMA}.profiles
           (id, name, role, status, approved)
         VALUES ($1, $2, 'user', 'active', false)
         ON CONFLICT (id) DO UPDATE
           SET name = EXCLUDED.name,
               updated_at = now()`,
        [authUser.id, name]
      );
    } catch (error) {
      // Compensación: si falla el perfil, no dejamos
      // un usuario huérfano en Supabase Auth.
      try {
        await supabaseAdmin.auth.admin.deleteUser(authUser.id);
      } catch (_) {
        // El error original es el que importa.
      }

      throw error;
    }

    const profile = await getProfile(db, authUser.id);

    return res.status(201).json({
      token: loginData.session.access_token,
      user: {
        id: authUser.id,
        name: profile.name,
        email: authUser.email || email,
        role: profile.role,
        status: profile.status,
        approved: profile.approved,
      },
      email_confirmation_required: false,
    });
  }));

  // ─────────────────────────────────────────────
  // AUTH — Login con Supabase Auth
  // ─────────────────────────────────────────────

  app.post('/api/auth/login', asyncRoute(async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    const password = String(req.body?.password || '');

    if (!validEmail(email) || !password) {
      throw httpError(400, 'INVALID_INPUT');
    }

    const { data, error } =
      await supabaseAdmin.auth.signInWithPassword({
        email,
        password,
      });

    if (error || !data?.user || !data?.session) {
      throw httpError(401, 'INVALID_CREDENTIALS');
    }

    const profile = await getProfile(db, data.user.id);

    if (!profile) {
      throw httpError(403, 'SIPI_PROFILE_NOT_FOUND');
    }

    if (profile.status !== 'active') {
      throw httpError(403, 'ACCOUNT_INACTIVE');
    }

    return res.json({
      token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
      user: {
        id: data.user.id,
        name: profile.name,
        email: data.user.email || email,
        role: profile.role,
        status: profile.status,
        approved: profile.approved,
      },
    });
  }));

  // ─────────────────────────────────────────────
  // AUTH — Usuario actual
  // ─────────────────────────────────────────────

  app.get('/api/auth/me', requireAuth, asyncRoute(async (req, res) => {
    const user = await userView(db, req.user.id);

    if (!user) {
      throw httpError(404, 'SIPI_PROFILE_NOT_FOUND');
    }

    const points = await getBalance(db, req.user.id);

    return res.json({
      user,
      points,
    });
  }));


  // ─────────────────────────────────────────────
  // PERFIL
  // ─────────────────────────────────────────────

  app.put('/api/users/me', requireAuth, asyncRoute(async (req, res) => {
    const name = String(req.body?.name || '').trim();
    const email = normalizeEmail(req.body?.email);

    if (!name || !validEmail(email)) {
      throw httpError(400, 'INVALID_INPUT');
    }

    const current = await getAuthUser(req.user.id);

    if (!current) {
      throw httpError(404, 'USER_NOT_FOUND');
    }

    if (normalizeEmail(current.email) !== email) {
      const { error } =
        await supabaseAdmin.auth.admin.updateUserById(req.user.id, {
          email,
          email_confirm: true,
        });

      if (error) {
        const message = String(error.message || '').toLowerCase();

        if (
          message.includes('already') ||
          message.includes('registered') ||
          message.includes('exists')
        ) {
          throw httpError(409, 'EMAIL_TAKEN');
        }

        throw httpError(error.status || 400, 'EMAIL_UPDATE_FAILED');
      }
    }

    await db.query(
      `UPDATE ${SCHEMA}.profiles
          SET name = $1,
              updated_at = now()
        WHERE id = $2`,
      [name, req.user.id]
    );

    const user = await userView(db, req.user.id);

    return res.json({ user });
  }));

  app.put('/api/users/me/password', requireAuth, asyncRoute(async (req, res) => {
    const currentPassword = String(req.body?.current_password || '');
    const newPassword = String(req.body?.new_password || '');

    if (newPassword.length < 6) {
      throw httpError(400, 'WEAK_PASSWORD');
    }

    const authUser = await getAuthUser(req.user.id);

    if (!authUser?.email) {
      throw httpError(404, 'USER_NOT_FOUND');
    }

    const { error: verifyError } =
      await supabaseAdmin.auth.signInWithPassword({
        email: authUser.email,
        password: currentPassword,
      });

    if (verifyError) {
      throw httpError(401, 'INVALID_CURRENT_PASSWORD');
    }

    const { error: updateError } =
      await supabaseAdmin.auth.admin.updateUserById(req.user.id, {
        password: newPassword,
      });

    if (updateError) {
      throw httpError(
        updateError.status || 400,
        'PASSWORD_UPDATE_FAILED'
      );
    }

    return res.json({ ok: true });
  }));

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN, BALANCE Y LEDGER
  // ─────────────────────────────────────────────

  app.get('/api/config', asyncRoute(async (_req, res) => {
    const pointsPerUsd = await getPointsPerUsd(db);

    return res.json({
      points_per_usd: pointsPerUsd,
    });
  }));

  app.get('/api/balance', requireAuth, asyncRoute(async (req, res) => {
    const points = await getBalance(db, req.user.id);
    const pointsPerUsd = await getPointsPerUsd(db);

    const pendingResult = await db.query(
      `SELECT COALESCE(SUM(t.points), 0)::int AS pending_points
         FROM ${SCHEMA}.task_completions c
         JOIN ${SCHEMA}.tasks t ON t.id = c.task_id
        WHERE c.user_id = $1
          AND c.status = 'pending'`,
      [req.user.id]
    );

    const earnedResult = await db.query(
      `SELECT COALESCE(SUM(points), 0)::int AS earned_points
         FROM ${SCHEMA}.ledger
        WHERE user_id = $1
          AND points > 0`,
      [req.user.id]
    );

    const usedResult = await db.query(
      `SELECT COALESCE(ABS(SUM(points)), 0)::int AS used_points
         FROM ${SCHEMA}.ledger
        WHERE user_id = $1
          AND points < 0`,
      [req.user.id]
    );

    return res.json({
      points,
      pending_points: pendingResult.rows[0].pending_points,
      earned_points: earnedResult.rows[0].earned_points,
      used_points: usedResult.rows[0].used_points,
      points_per_usd: pointsPerUsd,
      usd: Math.floor((points / pointsPerUsd) * 100) / 100,
    });
  }));

  app.get('/api/ledger', requireAuth, asyncRoute(async (req, res) => {
    const limit = asInt(req.query.limit, 50);
    const movements = await getMovements(db, req.user.id, limit);

    return res.json({ movements });
  }));

  // ─────────────────────────────────────────────
  // TAREAS — listado y detalle
  // ─────────────────────────────────────────────

  app.get('/api/tasks', maybeAuth, asyncRoute(async (req, res) => {
    const category = String(req.query.category || '').trim();
    const q = String(req.query.q || '').trim();

    const params = [];
    const where = ['t.active = true'];

    if (category) {
      params.push(category);
      where.push(`t.category = $${params.length}`);
    }

    if (q) {
      params.push(`%${q}%`);
      where.push(
        `(t.title ILIKE $${params.length} OR t.description ILIKE $${params.length})`
      );
    }

    if (req.user?.id) {
      params.push(req.user.id);
      const userParam = `$${params.length}`;

      const result = await db.query(
        `SELECT t.*,
                (
                  SELECT c.status
                    FROM ${SCHEMA}.task_completions c
                   WHERE c.task_id = t.id
                     AND c.user_id = ${userParam}
                   ORDER BY c.submitted_at DESC
                   LIMIT 1
                ) AS my_status
           FROM ${SCHEMA}.tasks t
          WHERE ${where.join(' AND ')}
            AND (
              SELECT COUNT(*)
                FROM ${SCHEMA}.task_completions done
               WHERE done.task_id = t.id
                 AND done.user_id = ${userParam}
                 AND done.status = 'approved'
            ) < COALESCE(t.max_completions_per_user, 1)
          ORDER BY t.created_at DESC`,
        params
      );

      return res.json({ tasks: result.rows });
    }

    const result = await db.query(
      `SELECT t.*, NULL::text AS my_status
         FROM ${SCHEMA}.tasks t
        WHERE ${where.join(' AND ')}
        ORDER BY t.created_at DESC`,
      params
    );

    return res.json({ tasks: result.rows });
  }));

  // Historial de tareas completadas por el usuario (aprobadas).
  // Definido antes de /api/tasks/:id para que "history" no se tome como id.
  app.get('/api/tasks/history', requireAuth, asyncRoute(async (req, res) => {
    const result = await db.query(
      `SELECT t.*,
              COALESCE(c.reviewed_at, c.submitted_at) AS completed_at
         FROM ${SCHEMA}.task_completions c
         JOIN ${SCHEMA}.tasks t ON t.id = c.task_id
        WHERE c.user_id = $1
          AND c.status = 'approved'
        ORDER BY completed_at DESC
        LIMIT 100`,
      [req.user.id]
    );

    return res.json({ tasks: result.rows });
  }));

  app.get('/api/tasks/:id', maybeAuth, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);

    if (!taskId) {
      throw httpError(400, 'INVALID_TASK_ID');
    }

    const taskResult = await db.query(
      `SELECT *
         FROM ${SCHEMA}.tasks
        WHERE id = $1
          AND active = true`,
      [taskId]
    );

    const task = taskResult.rows[0];

    if (!task) {
      throw httpError(404, 'TASK_NOT_FOUND');
    }

    let myCompletions = [];

    if (req.user?.id) {
      const completionResult = await db.query(
        `SELECT *
           FROM ${SCHEMA}.task_completions
          WHERE task_id = $1
            AND user_id = $2
          ORDER BY submitted_at DESC`,
        [taskId, req.user.id]
      );

      myCompletions = completionResult.rows;
    }

    return res.json({
      task,
      my_completions: myCompletions,
    });
  }));

  // ─────────────────────────────────────────────
  // TAREAS — enviar para verificación
  // ─────────────────────────────────────────────

  app.post('/api/tasks/:id/submit', requireAuth, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);

    if (!taskId) {
      throw httpError(400, 'INVALID_TASK_ID');
    }

    const evidence = String(req.body?.evidence || '').trim();
    const suppliedHandle = normalizeHandle(req.body?.handle);

    const completion = await db.withTransaction(async (client) => {
      await lockProfile(client, req.user.id);

      const taskResult = await client.query(
        `SELECT *
           FROM ${SCHEMA}.tasks
          WHERE id = $1
            AND active = true`,
        [taskId]
      );

      const task = taskResult.rows[0];

      if (!task) {
        throw httpError(404, 'TASK_NOT_FOUND');
      }

      let handle = suppliedHandle || null;
      let network = null;

      if (task.category === 'social' && task.social_network) {
        if (!handle) {
          throw httpError(400, 'HANDLE_REQUIRED');
        }

        network = task.social_network;
      }

      const countResult = await client.query(
        `SELECT COUNT(*)::int AS total
           FROM ${SCHEMA}.task_completions
          WHERE task_id = $1
            AND user_id = $2
            AND status IN ('pending', 'approved')`,
        [taskId, req.user.id]
      );

      if (
        countResult.rows[0].total >=
        task.max_completions_per_user
      ) {
        throw httpError(409, 'TASK_LIMIT_REACHED');
      }

      const insertResult = await client.query(
        `INSERT INTO ${SCHEMA}.task_completions
           (task_id, user_id, status, evidence, handle, network)
         VALUES ($1, $2, 'pending', $3, $4, $5)
         RETURNING *`,
        [
          taskId,
          req.user.id,
          evidence,
          handle,
          network,
        ]
      );

      return insertResult.rows[0];
    });

    return res.status(201).json({ completion });
  }));

  // ─────────────────────────────────────────────
  // ENCUESTAS
  // ─────────────────────────────────────────────

  app.get('/api/tasks/:id/survey', maybeAuth, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);

    if (!taskId) {
      throw httpError(400, 'INVALID_TASK_ID');
    }

    const result = await db.query(
      `SELECT s.id, s.task_id, s.title, s.questions,
              s.created_at, s.updated_at
         FROM ${SCHEMA}.surveys s
         JOIN ${SCHEMA}.tasks t ON t.id = s.task_id
        WHERE s.task_id = $1
          AND t.active = true`,
      [taskId]
    );

    if (!result.rowCount) {
      throw httpError(404, 'SURVEY_NOT_FOUND');
    }

    return res.json({ survey: result.rows[0] });
  }));

  app.post('/api/tasks/:id/survey', requireAuth, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);
    const answers = req.body?.answers;

    if (!taskId) {
      throw httpError(400, 'INVALID_TASK_ID');
    }

    if (!answers || typeof answers !== 'object' || Array.isArray(answers)) {
      throw httpError(400, 'INVALID_ANSWERS');
    }

    const result = await db.withTransaction(async (client) => {
      await lockProfile(client, req.user.id);

      const surveyResult = await client.query(
        `SELECT s.*, t.points, t.verification, t.active
           FROM ${SCHEMA}.surveys s
           JOIN ${SCHEMA}.tasks t ON t.id = s.task_id
          WHERE s.task_id = $1
          FOR UPDATE OF s`,
        [taskId]
      );

      const survey = surveyResult.rows[0];

      if (!survey || !survey.active) {
        throw httpError(404, 'SURVEY_NOT_FOUND');
      }

      for (const question of survey.questions) {
        if (!question.required) continue;

        const value = answers[question.id];

        const missing =
          value === undefined ||
          value === null ||
          value === '' ||
          (Array.isArray(value) && value.length === 0);

        if (missing) {
          throw httpError(400, 'REQUIRED_QUESTION_MISSING');
        }
      }

      // Nota: no se usa ON CONFLICT porque la restricción UNIQUE(survey_id, user_id)
      // puede no existir en la base migrada a Postgres; se verifica con SELECT
      // dentro de la transacción (el perfil ya está bloqueado con lockProfile).
      const existingResponse = await client.query(
        `SELECT id FROM ${SCHEMA}.survey_responses WHERE survey_id = $1 AND user_id = $2`,
        [survey.id, req.user.id]
      );

      if (existingResponse.rowCount > 0) {
        throw httpError(409, 'SURVEY_ALREADY_ANSWERED');
      }

      const responseResult = await client.query(
        `INSERT INTO ${SCHEMA}.survey_responses
           (survey_id, user_id, answers)
         VALUES ($1, $2, $3::jsonb)
         RETURNING *`,
        [survey.id, req.user.id, JSON.stringify(answers)]
      );

      let autoApproved = false;

      // Las encuestas siempre otorgan los puntos al terminarlas:
      // no pasan por revisión del administrador.
      {
        const completionResult = await client.query(
          `INSERT INTO ${SCHEMA}.task_completions
             (task_id, user_id, status, evidence, reviewed_at)
           VALUES ($1, $2, 'approved', '', now())
           RETURNING *`,
          [taskId, req.user.id]
        );

        const completion = completionResult.rows[0];

        await addEntry(client, {
          userId: req.user.id,
          type: 'EARN',
          points: survey.points,
          referenceType: 'task_completion',
          referenceId: completion.id,
          note: `Encuesta: ${survey.title}`,
        });

        await checkAndAward(client, req.user.id);

        autoApproved = true;
      }

      return {
        response: responseResult.rows[0],
        autoApproved,
        points: survey.points,
      };
    });

    return res.status(201).json({
      response: result.response,
      auto_approved: result.autoApproved,
      points: result.points,
    });
  }));

  // ─────────────────────────────────────────────
  // SOPORTE — conversaciones del usuario
  // ─────────────────────────────────────────────

  const SUPPORT_KINDS = ['pregunta', 'queja', 'sugerencia'];

  app.get('/api/support/threads', requireAuth, asyncRoute(async (req, res) => {
    const result = await withSupportTables(db, () => db.query(
      `SELECT t.*,
              (SELECT m.body FROM ${SCHEMA}.support_messages m
                WHERE m.thread_id = t.id ORDER BY m.id DESC LIMIT 1) AS last_message
         FROM ${SCHEMA}.support_threads t
        WHERE t.user_id = $1
        ORDER BY t.updated_at DESC`,
      [req.user.id]
    ));

    return res.json({
      threads: result.rows.map((t) => ({
        ...serializeThread(t),
        last_message: t.last_message || '',
      })),
    });
  }));

  app.post('/api/support/threads', requireAuth, asyncRoute(async (req, res) => {
    const subject = String(req.body?.subject || '').trim().slice(0, 120);
    const kind = String(req.body?.kind || 'pregunta');
    const message = String(req.body?.message || '').trim();

    if (!SUPPORT_KINDS.includes(kind)) {
      throw httpError(400, 'INVALID_KIND');
    }

    if (!message) {
      throw httpError(400, 'MESSAGE_REQUIRED');
    }

    const thread = await withSupportTables(db, () => db.withTransaction(async (client) => {
      const t = await client.query(
        `INSERT INTO ${SCHEMA}.support_threads (user_id, subject, kind, unread_admin)
         VALUES ($1, $2, $3, true)
         RETURNING *`,
        [req.user.id, subject || message.slice(0, 60), kind]
      );

      await client.query(
        `INSERT INTO ${SCHEMA}.support_messages (thread_id, sender, body)
         VALUES ($1, 'user', $2)`,
        [t.rows[0].id, message]
      );

      return t.rows[0];
    }));

    await notifyUser(db, {
      userId: req.user.id,
      type: 'support',
      title: 'Chat abierto con soporte',
      body: 'Recibimos tu mensaje. Te avisaremos aquí mismo cuando el equipo de soporte te responda.',
      refType: 'support_thread',
      refId: Number(thread.id),
    });

    return res.status(201).json({ thread: serializeThread(thread) });
  }));

  app.get('/api/support/threads/:id', requireAuth, asyncRoute(async (req, res) => {
    const threadId = asInt(req.params.id);

    const t = await withSupportTables(db, () => db.query(
      `SELECT * FROM ${SCHEMA}.support_threads WHERE id = $1 AND user_id = $2`,
      [threadId, req.user.id]
    ));

    if (!t.rowCount) {
      throw httpError(404, 'THREAD_NOT_FOUND');
    }

    const msgs = await db.query(
      `SELECT * FROM ${SCHEMA}.support_messages WHERE thread_id = $1 ORDER BY id ASC`,
      [threadId]
    );

    await db.query(
      `UPDATE ${SCHEMA}.support_threads SET unread_user = false WHERE id = $1`,
      [threadId]
    );

    return res.json({
      thread: serializeThread(t.rows[0]),
      messages: msgs.rows.map(serializeSupportMessage),
    });
  }));

  app.post('/api/support/threads/:id/messages', requireAuth, asyncRoute(async (req, res) => {
    const threadId = asInt(req.params.id);
    const message = String(req.body?.message || '').trim();

    if (!message) {
      throw httpError(400, 'MESSAGE_REQUIRED');
    }

    const t = await withSupportTables(db, () => db.query(
      `SELECT * FROM ${SCHEMA}.support_threads WHERE id = $1 AND user_id = $2`,
      [threadId, req.user.id]
    ));

    const thread = t.rows[0];

    if (!thread) {
      throw httpError(404, 'THREAD_NOT_FOUND');
    }

    if (thread.status !== 'open') {
      throw httpError(409, 'THREAD_CLOSED');
    }

    const m = await db.query(
      `INSERT INTO ${SCHEMA}.support_messages (thread_id, sender, body)
       VALUES ($1, 'user', $2)
       RETURNING *`,
      [threadId, message]
    );

    await db.query(
      `UPDATE ${SCHEMA}.support_threads
          SET unread_admin = true, updated_at = now()
        WHERE id = $1`,
      [threadId]
    );

    return res.status(201).json({ message: serializeSupportMessage(m.rows[0]) });
  }));

  // ─────────────────────────────────────────────
  // CANJES
  // ─────────────────────────────────────────────

  app.get('/api/redemptions', requireAuth, asyncRoute(async (req, res) => {
    const result = await db.query(
      `SELECT id, user_id, points, amount_usd, status,
              created_at, processed_at
         FROM ${SCHEMA}.redemptions
        WHERE user_id = $1
        ORDER BY created_at DESC`,
      [req.user.id]
    );

    const redemptions = result.rows.map((row) => ({
      ...row,
      amount_usd: Number(row.amount_usd),
    }));

    return res.json({ redemptions });
  }));

  app.post('/api/redemptions', requireAuth, asyncRoute(async (req, res) => {
    const points = asInt(req.body?.points);

    if (!points || points <= 0) {
      throw httpError(400, 'INVALID_POINTS');
    }

    const redemption = await db.withTransaction(async (client) => {
      await lockProfile(client, req.user.id);

      const balance = await getBalance(client, req.user.id);

      if (balance < points) {
        throw httpError(400, 'INSUFFICIENT_POINTS');
      }

      const pointsPerUsd = await getPointsPerUsd(db, client);
      const amountUsd =
        Math.floor((points / pointsPerUsd) * 100) / 100;

      if (amountUsd <= 0) {
        throw httpError(400, 'INVALID_REDEMPTION_AMOUNT');
      }

      const insertResult = await client.query(
        `INSERT INTO ${SCHEMA}.redemptions
           (user_id, points, amount_usd, status)
         VALUES ($1, $2, $3, 'pending')
         RETURNING *`,
        [req.user.id, points, amountUsd]
      );

      const row = insertResult.rows[0];

      await addEntry(client, {
        userId: req.user.id,
        type: 'REDEEM',
        points: -points,
        referenceType: 'redemption',
        referenceId: row.id,
        note: `Canje de ${points} puntos`,
      });

      await checkAndAward(client, req.user.id);

      return {
        ...row,
        amount_usd: Number(row.amount_usd),
      };
    });

    return res.status(201).json({ redemption });
  }));

  // ─────────────────────────────────────────────
  // ADMIN — estadísticas, usuarios y configuración
  // ─────────────────────────────────────────────

  app.get('/api/admin/stats', requireAuth, requireAdmin, asyncRoute(async (_req, res) => {
    // Contrato esperado por el panel admin (igual que el backend SQLite).
    const [users, activeTasks, surveys, completions, redemptions, issued, popular] =
      await Promise.all([
        db.query(`SELECT COUNT(*)::int AS total FROM ${SCHEMA}.profiles`),
        db.query(
          `SELECT COUNT(*)::int AS total FROM ${SCHEMA}.tasks WHERE active = true`
        ),
        db.query(
          `SELECT COUNT(*)::int AS total
             FROM ${SCHEMA}.surveys s
             JOIN ${SCHEMA}.tasks t ON t.id = s.task_id
            WHERE t.active = true`
        ),
        db.query(
          `SELECT COUNT(*) FILTER (WHERE status = 'pending')::int AS pending,
                  COUNT(*) FILTER (WHERE status = 'approved')::int AS approved
             FROM ${SCHEMA}.task_completions`
        ),
        db.query(
          `SELECT COALESCE(SUM(amount_usd), 0)::float AS paid_out
             FROM ${SCHEMA}.redemptions
            WHERE status = 'completed'`
        ),
        db.query(
          `SELECT COALESCE(SUM(points), 0)::int AS issued
             FROM ${SCHEMA}.ledger
            WHERE type = 'EARN'`
        ),
        db.query(
          `SELECT t.id, t.title, COUNT(c.id)::int AS n
             FROM ${SCHEMA}.tasks t
             LEFT JOIN ${SCHEMA}.task_completions c
               ON c.task_id = t.id AND c.status = 'approved'
            GROUP BY t.id, t.title
            ORDER BY n DESC, t.id DESC
            LIMIT 4`
        ),
      ]);

    return res.json({
      users: users.rows[0].total,
      active_tasks: activeTasks.rows[0].total,
      surveys: surveys.rows[0].total,
      pending_completions: completions.rows[0].pending,
      points_issued: issued.rows[0].issued,
      paid_out_usd: redemptions.rows[0].paid_out,
      total_completions: completions.rows[0].approved,
      popular_tasks: popular.rows,
    });
  }));

  app.get('/api/admin/activity', requireAuth, requireAdmin, asyncRoute(async (_req, res) => {
    // Últimos 30 días: usuarios nuevos, tareas enviadas y puntos emitidos por día.
    // Los reportes del panel se van formando solos a medida que entra actividad.
    const result = await db.query(
      `SELECT d.day::date AS date,
              COUNT(DISTINCT p.id)::int AS users,
              COUNT(DISTINCT c.id)::int AS completions,
              COALESCE(l.pts, 0)::int AS points
         FROM generate_series(
                CURRENT_DATE - INTERVAL '29 days',
                CURRENT_DATE,
                INTERVAL '1 day'
              ) AS d(day)
         LEFT JOIN ${SCHEMA}.profiles p
           ON p.created_at::date = d.day::date
         LEFT JOIN ${SCHEMA}.task_completions c
           ON c.submitted_at::date = d.day::date
          AND c.status IN ('approved', 'pending')
         LEFT JOIN (
           SELECT created_at::date AS d, SUM(points)::int AS pts
             FROM ${SCHEMA}.ledger
            WHERE type = 'EARN'
            GROUP BY 1
         ) l ON l.d = d.day::date
        GROUP BY d.day, l.pts
        ORDER BY d.day`
    );

    return res.json({
      days: result.rows.map((r) => ({
        date: r.date instanceof Date ? r.date.toISOString().slice(0, 10) : String(r.date).slice(0, 10),
        users: r.users,
        completions: r.completions,
        points: r.points,
      })),
    });
  }));

  app.get('/api/admin/notifications', requireAuth, requireAdmin, asyncRoute(async (_req, res) => {
    // Contadores para la campana de notificaciones del panel.
    const [comp, red, usr] = await Promise.all([
      db.query(
        `SELECT COUNT(*)::int AS total FROM ${SCHEMA}.task_completions WHERE status = 'pending'`
      ),
      db.query(
        `SELECT COUNT(*)::int AS total FROM ${SCHEMA}.redemptions WHERE status = 'pending'`
      ),
      db.query(
        `SELECT COUNT(*)::int AS total FROM ${SCHEMA}.profiles WHERE approved = false`
      ),
    ]);

    const pending_completions = comp.rows[0].total;
    const pending_redemptions = red.rows[0].total;
    const pending_users = usr.rows[0].total;

    // Chats de soporte sin leer (la tabla se crea sola al arrancar).
    let support_unread = 0;
    try {
      const sup = await db.query(
        `SELECT COUNT(*)::int AS total FROM ${SCHEMA}.support_threads WHERE unread_admin = true`
      );
      support_unread = sup.rows[0].total;
    } catch (e) { /* tabla aún no creada */ }

    return res.json({
      pending_completions,
      pending_redemptions,
      pending_users,
      support_unread,
      total: pending_completions + pending_redemptions + pending_users + support_unread,
    });
  }));

  app.get('/api/admin/tasks', requireAuth, requireAdmin, asyncRoute(async (_req, res) => {
    const result = await db.query(
      `SELECT * FROM ${SCHEMA}.tasks ORDER BY id DESC`
    );

    return res.json({ tasks: result.rows });
  }));

  app.get('/api/admin/users', requireAuth, requireAdmin, asyncRoute(async (_req, res) => {
    const result = await db.query(
      `SELECT p.*,
              COALESCE(SUM(l.points), 0)::int AS points
         FROM ${SCHEMA}.profiles p
         LEFT JOIN ${SCHEMA}.ledger l ON l.user_id = p.id
        GROUP BY p.id
        ORDER BY p.created_at DESC`
    );

    const users = [];

    for (const profile of result.rows) {
      const authUser = await getAuthUser(profile.id);
      const points = Number(profile.points) || 0;

      users.push({
        id: profile.id,
        name: profile.name,
        email: authUser?.email || null,
        role: profile.role,
        status: profile.status,
        approved: profile.approved,
        points,
        level: Math.max(1, Math.floor(points / 100) + 1),
        created_at: profile.created_at,
      });
    }

    return res.json({ users });
  }));

  app.patch('/api/admin/users/:id', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const userId = String(req.params.id || '');

    const updates = [];
    const values = [];

    if (req.body.role !== undefined) {
      if (!['user', 'admin'].includes(req.body.role)) {
        throw httpError(400, 'INVALID_ROLE');
      }

      values.push(req.body.role);
      updates.push(`role = $${values.length}`);
    }

    if (req.body.status !== undefined) {
      if (!['active', 'inactive'].includes(req.body.status)) {
        throw httpError(400, 'INVALID_STATUS');
      }

      values.push(req.body.status);
      updates.push(`status = $${values.length}`);
    }

    if (req.body.approved !== undefined) {
      if (
        req.body.approved !== true &&
        req.body.approved !== false &&
        req.body.approved !== 1 &&
        req.body.approved !== 0
      ) {
        throw httpError(400, 'INVALID_APPROVED');
      }

      values.push(Boolean(req.body.approved));
      updates.push(`approved = $${values.length}`);
    }

    if (!updates.length) {
      throw httpError(400, 'NO_CHANGES');
    }

    if (
      userId === req.user.id &&
      (req.body.role === 'user' || req.body.status === 'inactive')
    ) {
      throw httpError(400, 'CANNOT_DISABLE_SELF');
    }

    values.push(userId);

    const result = await db.query(
      `UPDATE ${SCHEMA}.profiles
          SET ${updates.join(', ')},
              updated_at = now()
        WHERE id = $${values.length}
        RETURNING *`,
      values
    );

    if (!result.rowCount) {
      throw httpError(404, 'USER_NOT_FOUND');
    }

    const user = await userView(db, userId);

    return res.json({ user });
  }));

  app.put('/api/admin/config', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const pointsPerUsd = asInt(req.body?.points_per_usd);

    if (!pointsPerUsd || pointsPerUsd <= 0) {
      throw httpError(400, 'INVALID_POINTS_PER_USD');
    }

    await db.query(
      `INSERT INTO ${SCHEMA}.config (key, value)
       VALUES ('points_per_usd', $1)
       ON CONFLICT (key)
       DO UPDATE SET value = EXCLUDED.value`,
      [String(pointsPerUsd)]
    );

    return res.json({
      points_per_usd: pointsPerUsd,
    });
  }));

  // ─────────────────────────────────────────────
  // ADMIN — tareas
  // ─────────────────────────────────────────────

  app.post('/api/admin/tasks', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const title = String(req.body?.title || '').trim();
    const description = String(req.body?.description || '').trim();
    const instructions = String(req.body?.instructions || '').trim();
    const category = String(req.body?.category || 'otras');
    const points = asInt(req.body?.points);
    const estimatedMinutes = asInt(req.body?.estimated_minutes, 5);
    const verification = String(req.body?.verification || 'manual');
    const requirements = String(req.body?.requirements || '').trim();
    const targetUrl = String(req.body?.target_url || '').trim();
    const maxCompletions = asInt(req.body?.max_completions_per_user, 1);
    const socialNetwork = req.body?.social_network || null;
    const socialAction = req.body?.social_action || null;
    let imageUrl = String(req.body?.image_url || '').trim();
    // Si es tarea de red social y no se eligió imagen, usa el logo de la red.
    const networks = [
      'instagram', 'tiktok', 'facebook', 'x', 'youtube',
    ];
    if (!imageUrl && socialNetwork && networks.includes(socialNetwork)) {
      const publicBase = process.env.PUBLIC_BASE_URL || 'https://api-sipi-dev.catalina.my';
      imageUrl = `${publicBase}/public/task-icons/${socialNetwork}.png`;
    }

    if (!title || !points || points <= 0) {
      throw httpError(400, 'INVALID_TASK');
    }

    const categories = [
      'social', 'encuestas', 'productos',
      'opinion', 'promociones', 'otras',
    ];

    if (!categories.includes(category)) {
      throw httpError(400, 'INVALID_CATEGORY');
    }

    if (!['manual', 'auto'].includes(verification)) {
      throw httpError(400, 'INVALID_VERIFICATION');
    }

    if (socialNetwork && !networks.includes(socialNetwork)) {
      throw httpError(400, 'INVALID_SOCIAL_NETWORK');
    }

    const actions = [
      'follow', 'like', 'share', 'comment', 'subscribe',
    ];

    if (socialAction && !actions.includes(socialAction)) {
      throw httpError(400, 'INVALID_SOCIAL_ACTION');
    }

    const result = await db.query(
      `INSERT INTO ${SCHEMA}.tasks
         (title, description, instructions, category, points,
          estimated_minutes, verification, requirements, target_url,
          max_completions_per_user, social_network, social_action,
          image_url, created_by)
       VALUES
         ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       RETURNING *`,
      [
        title,
        description,
        instructions,
        category,
        points,
        estimatedMinutes,
        verification,
        requirements,
        targetUrl,
        maxCompletions,
        socialNetwork,
        socialAction,
        imageUrl,
        req.user.id,
      ]
    );

    return res.status(201).json({
      task: result.rows[0],
    });
  }));

  app.put('/api/admin/tasks/:id', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);

    if (!taskId) {
      throw httpError(400, 'INVALID_TASK_ID');
    }

    const allowed = {
      title: 'text',
      description: 'text',
      instructions: 'text',
      category: 'text',
      points: 'integer',
      estimated_minutes: 'integer',
      verification: 'text',
      requirements: 'text',
      target_url: 'text',
      max_completions_per_user: 'integer',
      active: 'boolean',
      social_network: 'nullable',
      social_action: 'nullable',
      image_url: 'text',
    };

    const updates = [];
    const values = [];

    for (const [field, type] of Object.entries(allowed)) {
      if (req.body[field] === undefined) continue;

      let value = req.body[field];

      if (type === 'integer') {
        value = asInt(value);

        if (!value || value <= 0) {
          throw httpError(400, 'INVALID_VALUE');
        }
      }

      if (type === 'boolean') {
        if (value !== true && value !== false) {
          throw httpError(400, 'INVALID_VALUE');
        }
      }

      if (type === 'text') {
        value = String(value);
      }

      if (type === 'nullable') {
        value = value ? String(value) : null;
      }

      values.push(value);
      updates.push(`${field} = $${values.length}`);
    }

    if (!updates.length) {
      throw httpError(400, 'NO_CHANGES');
    }

    values.push(taskId);

    const result = await db.query(
      `UPDATE ${SCHEMA}.tasks
          SET ${updates.join(', ')},
              updated_at = now()
        WHERE id = $${values.length}
        RETURNING *`,
      values
    );

    if (!result.rowCount) {
      throw httpError(404, 'TASK_NOT_FOUND');
    }

    return res.json({
      task: result.rows[0],
    });
  }));

  // ─────────────────────────────────────────────
  // ADMIN — encuesta asociada a una tarea
  // ─────────────────────────────────────────────

  app.post('/api/admin/tasks/:id/survey', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);
    const title = String(req.body?.title || '').trim();
    const questions = req.body?.questions;

    if (!taskId || !title || !Array.isArray(questions)) {
      throw httpError(400, 'INVALID_SURVEY');
    }

    const taskResult = await db.query(
      `SELECT id
         FROM ${SCHEMA}.tasks
        WHERE id = $1`,
      [taskId]
    );

    if (!taskResult.rowCount) {
      throw httpError(404, 'TASK_NOT_FOUND');
    }

    const result = await db.query(
      `INSERT INTO ${SCHEMA}.surveys
         (task_id, title, questions)
       VALUES ($1, $2, $3::jsonb)
       ON CONFLICT (task_id)
       DO UPDATE SET
         title = EXCLUDED.title,
         questions = EXCLUDED.questions,
         updated_at = now()
       RETURNING *`,
      [taskId, title, JSON.stringify(questions)]
    );

    return res.status(201).json({
      survey: result.rows[0],
    });
  }));

  // ─────────────────────────────────────────────
  // ADMIN — estadísticas de una encuesta (cómo va cada encuesta)
  // ─────────────────────────────────────────────

  app.get('/api/admin/tasks/:id/survey/stats', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const taskId = asInt(req.params.id);

    if (!taskId) {
      throw httpError(400, 'INVALID_TASK_ID');
    }

    const surveyResult = await db.query(
      `SELECT s.id, s.task_id, s.title, s.questions, t.points
         FROM ${SCHEMA}.surveys s
         JOIN ${SCHEMA}.tasks t ON t.id = s.task_id
        WHERE s.task_id = $1`,
      [taskId]
    );

    const survey = surveyResult.rows[0];

    if (!survey) {
      throw httpError(404, 'SURVEY_NOT_FOUND');
    }

    const responsesResult = await db.query(
      `SELECT answers
         FROM ${SCHEMA}.survey_responses
        WHERE survey_id = $1`,
      [survey.id]
    );

    const responses = responsesResult.rows;
    const questions = Array.isArray(survey.questions) ? survey.questions : [];

    const stats = questions.map((q) => {
      const base = {
        id: q.id,
        text: q.text || '',
        type: q.type,
        answers: 0,
      };

      const valueOf = (row) => row.answers?.[q.id];

      if (q.type === 'single' || q.type === 'multiple') {
        const options = Array.isArray(q.options) ? q.options : [];
        const counts = Object.fromEntries(options.map((o) => [o, 0]));

        for (const row of responses) {
          const v = valueOf(row);
          if (v === undefined || v === null || v === '') continue;
          base.answers += 1;
          const list = Array.isArray(v) ? v : [v];
          for (const item of list) {
            if (Object.prototype.hasOwnProperty.call(counts, item)) {
              counts[item] += 1;
            }
          }
        }

        return { ...base, options, counts };
      }

      if (q.type === 'yesno') {
        let yes = 0;
        let no = 0;

        for (const row of responses) {
          const v = valueOf(row);
          if (v === true) { yes += 1; base.answers += 1; }
          else if (v === false) { no += 1; base.answers += 1; }
        }

        return { ...base, counts: { 'Sí': yes, 'No': no } };
      }

      if (q.type === 'scale') {
        const min = Number.isInteger(q.min) ? q.min : 1;
        const max = Number.isInteger(q.max) ? q.max : 5;
        const counts = {};
        for (let v = min; v <= max; v++) counts[v] = 0;
        let sum = 0;

        for (const row of responses) {
          const v = valueOf(row);
          if (typeof v !== 'number') continue;
          base.answers += 1;
          sum += v;
          if (Object.prototype.hasOwnProperty.call(counts, v)) {
            counts[v] += 1;
          }
        }

        return {
          ...base,
          min,
          max,
          counts,
          average: base.answers ? Math.round((sum / base.answers) * 10) / 10 : null,
        };
      }

      const samples = [];

      for (const row of responses) {
        const v = valueOf(row);
        if (typeof v !== 'string' || !v.trim()) continue;
        base.answers += 1;
        if (samples.length < 5) samples.push(v.trim().slice(0, 140));
      }

      return { ...base, samples };
    });

    return res.json({
      survey: {
        id: Number(survey.id),
        task_id: Number(survey.task_id),
        title: survey.title,
        points: Number(survey.points),
      },
      total_responses: responses.length,
      questions: stats,
    });
  }));

  // ─────────────────────────────────────────────
  // ADMIN — soporte: administrar chats, preguntas y quejas
  // ─────────────────────────────────────────────

  app.get('/api/admin/support/threads', requireAuth, requireAdmin, asyncRoute(async (_req, res) => {
    const result = await withSupportTables(db, () => db.query(
      `SELECT t.*,
              p.name AS user_name,
              (SELECT m.body FROM ${SCHEMA}.support_messages m
                WHERE m.thread_id = t.id ORDER BY m.id DESC LIMIT 1) AS last_message,
              (SELECT COUNT(*)::int FROM ${SCHEMA}.support_messages m
                WHERE m.thread_id = t.id) AS message_count
         FROM ${SCHEMA}.support_threads t
         LEFT JOIN ${SCHEMA}.profiles p ON p.id = t.user_id
        ORDER BY t.unread_admin DESC, t.updated_at DESC`
    ));

    const threads = [];

    for (const t of result.rows) {
      const authUser = await getAuthUser(t.user_id);

      threads.push({
        ...serializeThread(t),
        user_name: t.user_name || 'Usuario',
        user_email: authUser?.email || '',
        last_message: t.last_message || '',
        message_count: t.message_count || 0,
      });
    }

    return res.json({ threads });
  }));

  app.get('/api/admin/support/threads/:id', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const threadId = asInt(req.params.id);

    const t = await withSupportTables(db, () => db.query(
      `SELECT t.*, p.name AS user_name
         FROM ${SCHEMA}.support_threads t
         LEFT JOIN ${SCHEMA}.profiles p ON p.id = t.user_id
        WHERE t.id = $1`,
      [threadId]
    ));

    if (!t.rowCount) {
      throw httpError(404, 'THREAD_NOT_FOUND');
    }

    const msgs = await db.query(
      `SELECT * FROM ${SCHEMA}.support_messages WHERE thread_id = $1 ORDER BY id ASC`,
      [threadId]
    );

    await db.query(
      `UPDATE ${SCHEMA}.support_threads SET unread_admin = false WHERE id = $1`,
      [threadId]
    );

    const authUser = await getAuthUser(t.rows[0].user_id);

    return res.json({
      thread: {
        ...serializeThread(t.rows[0]),
        user_name: t.rows[0].user_name || 'Usuario',
        user_email: authUser?.email || '',
      },
      messages: msgs.rows.map(serializeSupportMessage),
    });
  }));

  app.post('/api/admin/support/threads/:id/messages', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const threadId = asInt(req.params.id);
    const message = String(req.body?.message || '').trim();

    if (!message) {
      throw httpError(400, 'MESSAGE_REQUIRED');
    }

    const t = await withSupportTables(db, () => db.query(
      `SELECT id, user_id FROM ${SCHEMA}.support_threads WHERE id = $1`,
      [threadId]
    ));

    if (!t.rowCount) {
      throw httpError(404, 'THREAD_NOT_FOUND');
    }

    const threadUserId = t.rows[0].user_id;

    const m = await withSupportTables(db, async () => {
      const prof = await db.query(
        `SELECT name FROM ${SCHEMA}.profiles WHERE id = $1`,
        [req.user.id]
      );
      const adminName = prof.rows[0]?.name || 'Soporte';

      return db.query(
        `INSERT INTO ${SCHEMA}.support_messages (thread_id, sender, sender_name, body)
         VALUES ($1, 'admin', $2, $3)
         RETURNING *`,
        [threadId, adminName, message]
      );
    });

    // Responder reabre el caso y avisa al usuario.
    await db.query(
      `UPDATE ${SCHEMA}.support_threads
          SET unread_user = true, updated_at = now(), status = 'open'
        WHERE id = $1`,
      [threadId]
    );

    const adminName = m.rows[0].sender_name || 'Soporte';

    await notifyUser(db, {
      userId: threadUserId,
      type: 'support',
      title: 'Soporte te respondió',
      body: `${adminName}: ${message.length > 90 ? message.slice(0, 90) + '…' : message}`,
      refType: 'support_thread',
      refId: threadId,
    });

    return res.status(201).json({ message: serializeSupportMessage(m.rows[0]) });
  }));

  app.patch('/api/admin/support/threads/:id', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const threadId = asInt(req.params.id);
    const status = String(req.body?.status || '');

    if (!['open', 'closed'].includes(status)) {
      throw httpError(400, 'INVALID_STATUS');
    }

    const r = await withSupportTables(db, () => db.query(
      `UPDATE ${SCHEMA}.support_threads
          SET status = $1, updated_at = now()
        WHERE id = $2
        RETURNING *`,
      [status, threadId]
    ));

    if (!r.rowCount) {
      throw httpError(404, 'THREAD_NOT_FOUND');
    }

    return res.json({ thread: serializeThread(r.rows[0]) });
  }));

  // ─────────────────────────────────────────────
  // ADMIN — revisiones de tareas
  // ─────────────────────────────────────────────

  app.get('/api/admin/completions', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const status = String(req.query.status || 'pending');

    if (!['pending', 'approved', 'rejected'].includes(status)) {
      throw httpError(400, 'INVALID_STATUS');
    }

    const result = await db.query(
      `SELECT c.*,
              t.title AS task_title,
              t.points AS task_points,
              t.category,
              p.name AS user_name
         FROM ${SCHEMA}.task_completions c
         JOIN ${SCHEMA}.tasks t ON t.id = c.task_id
         JOIN ${SCHEMA}.profiles p ON p.id = c.user_id
        WHERE c.status = $1
        ORDER BY c.submitted_at DESC`,
      [status]
    );

    const completions = [];

    for (const row of result.rows) {
      const authUser = await getAuthUser(row.user_id);

      completions.push({
        ...row,
        user_email: authUser?.email || null,
      });
    }

    return res.json({ completions });
  }));

  app.post('/api/admin/completions/:id/approve', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const completionId = asInt(req.params.id);

    if (!completionId) {
      throw httpError(400, 'INVALID_COMPLETION_ID');
    }

    const completion = await db.withTransaction(async (client) => {
      const result = await client.query(
        `SELECT c.*, t.points, t.title
           FROM ${SCHEMA}.task_completions c
           JOIN ${SCHEMA}.tasks t ON t.id = c.task_id
          WHERE c.id = $1
          FOR UPDATE OF c`,
        [completionId]
      );

      const row = result.rows[0];

      if (!row) {
        throw httpError(404, 'COMPLETION_NOT_FOUND');
      }

      if (row.status !== 'pending') {
        throw httpError(409, 'COMPLETION_ALREADY_REVIEWED');
      }

      await client.query(
        `UPDATE ${SCHEMA}.task_completions
            SET status = 'approved',
                reviewed_at = now(),
                reviewed_by = $1
          WHERE id = $2`,
        [req.user.id, completionId]
      );

      await addEntry(client, {
        userId: row.user_id,
        type: 'EARN',
        points: row.points,
        referenceType: 'task_completion',
        referenceId: row.id,
        note: `Tarea aprobada: ${row.title}`,
        createdBy: req.user.id,
      });

      await checkAndAward(client, row.user_id);

      const updated = await client.query(
        `SELECT *
           FROM ${SCHEMA}.task_completions
          WHERE id = $1`,
        [completionId]
      );

      return updated.rows[0];
    });

    return res.json({ completion });
  }));

  app.post('/api/admin/completions/:id/reject', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const completionId = asInt(req.params.id);

    if (!completionId) {
      throw httpError(400, 'INVALID_COMPLETION_ID');
    }

    const completion = await db.withTransaction(async (client) => {
      const result = await client.query(
        `SELECT *
           FROM ${SCHEMA}.task_completions
          WHERE id = $1
          FOR UPDATE`,
        [completionId]
      );

      const row = result.rows[0];

      if (!row) {
        throw httpError(404, 'COMPLETION_NOT_FOUND');
      }

      if (row.status !== 'pending') {
        throw httpError(409, 'COMPLETION_ALREADY_REVIEWED');
      }

      const updated = await client.query(
        `UPDATE ${SCHEMA}.task_completions
            SET status = 'rejected',
                reviewed_at = now(),
                reviewed_by = $1
          WHERE id = $2
          RETURNING *`,
        [req.user.id, completionId]
      );

      return updated.rows[0];
    });

    return res.json({ completion });
  }));

  // ─────────────────────────────────────────────
  // LOGROS Y NOTIFICACIONES
  // ─────────────────────────────────────────────

  app.get('/api/achievements', requireAuth, asyncRoute(async (req, res) => {
    const achievementsResult = await db.query(
      `SELECT *
         FROM ${SCHEMA}.achievements
        ORDER BY id`
    );

    const earnedResult = await db.query(
      `SELECT achievement_id, earned_at
         FROM ${SCHEMA}.user_achievements
        WHERE user_id = $1`,
      [req.user.id]
    );

    const earnedMap = new Map(
      earnedResult.rows.map((row) => [
        row.achievement_id,
        row.earned_at,
      ])
    );

    const achievements = [];

    for (const achievement of achievementsResult.rows) {
      const progress = await metricValue(
        db,
        req.user.id,
        achievement.metric
      );

      achievements.push({
        ...achievement,
        earned: earnedMap.has(achievement.id),
        earned_at: earnedMap.get(achievement.id) || null,
        progress,
      });
    }

    return res.json({ achievements });
  }));

  app.get('/api/notifications', requireAuth, asyncRoute(async (req, res) => {
    const result = await db.query(
      `SELECT *
         FROM ${SCHEMA}.notifications
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 100`,
      [req.user.id]
    );

    return res.json({
      notifications: result.rows,
    });
  }));

  const markNotificationRead = asyncRoute(async (req, res) => {
    const notificationId = asInt(req.params.id);

    if (!notificationId) {
      throw httpError(400, 'INVALID_NOTIFICATION_ID');
    }

    const result = await db.query(
      `UPDATE ${SCHEMA}.notifications
          SET is_read = true
        WHERE id = $1
          AND user_id = $2
        RETURNING *`,
      [notificationId, req.user.id]
    );

    if (!result.rowCount) {
      throw httpError(404, 'NOTIFICATION_NOT_FOUND');
    }

    return res.json({
      notification: result.rows[0],
    });
  });

  // PATCH es el verbo REST correcto; POST se acepta por compatibilidad
  // con la app móvil.
  app.patch('/api/notifications/:id/read', requireAuth, markNotificationRead);
  app.post('/api/notifications/:id/read', requireAuth, markNotificationRead);

  // ─────────────────────────────────────────────
  // ADMIN — canjes
  // ─────────────────────────────────────────────

  app.get('/api/admin/redemptions', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const status = req.query.status
      ? String(req.query.status)
      : null;

    const params = [];
    let where = '';

    if (status) {
      if (!['pending', 'completed', 'rejected'].includes(status)) {
        throw httpError(400, 'INVALID_STATUS');
      }

      params.push(status);
      where = `WHERE r.status = $1`;
    }

    const result = await db.query(
      `SELECT r.*, p.name AS user_name
         FROM ${SCHEMA}.redemptions r
         JOIN ${SCHEMA}.profiles p ON p.id = r.user_id
         ${where}
        ORDER BY r.created_at DESC`,
      params
    );

    const redemptions = [];

    for (const row of result.rows) {
      const authUser = await getAuthUser(row.user_id);

      redemptions.push({
        ...row,
        amount_usd: Number(row.amount_usd),
        user_email: authUser?.email || null,
      });
    }

    return res.json({ redemptions });
  }));

  app.post('/api/admin/redemptions/:id/complete', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const redemptionId = asInt(req.params.id);

    if (!redemptionId) {
      throw httpError(400, 'INVALID_REDEMPTION_ID');
    }

    const redemption = await db.withTransaction(async (client) => {
      const result = await client.query(
        `SELECT *
           FROM ${SCHEMA}.redemptions
          WHERE id = $1
          FOR UPDATE`,
        [redemptionId]
      );

      const row = result.rows[0];

      if (!row) {
        throw httpError(404, 'REDEMPTION_NOT_FOUND');
      }

      if (row.status !== 'pending') {
        throw httpError(409, 'REDEMPTION_ALREADY_PROCESSED');
      }

      const updated = await client.query(
        `UPDATE ${SCHEMA}.redemptions
            SET status = 'completed',
                processed_at = now()
          WHERE id = $1
          RETURNING *`,
        [redemptionId]
      );

      await client.query(
        `INSERT INTO ${SCHEMA}.notifications
           (user_id, type, title, body)
         VALUES ($1, 'redemption', 'Canje completado', $2)`,
        [
          row.user_id,
          `Tu canje de ${row.points} puntos fue completado.`,
        ]
      );

      return updated.rows[0];
    });

    return res.json({
      redemption: {
        ...redemption,
        amount_usd: Number(redemption.amount_usd),
      },
    });
  }));

  app.post('/api/admin/redemptions/:id/reject', requireAuth, requireAdmin, asyncRoute(async (req, res) => {
    const redemptionId = asInt(req.params.id);

    if (!redemptionId) {
      throw httpError(400, 'INVALID_REDEMPTION_ID');
    }

    const redemption = await db.withTransaction(async (client) => {
      const result = await client.query(
        `SELECT *
           FROM ${SCHEMA}.redemptions
          WHERE id = $1
          FOR UPDATE`,
        [redemptionId]
      );

      const row = result.rows[0];

      if (!row) {
        throw httpError(404, 'REDEMPTION_NOT_FOUND');
      }

      if (row.status !== 'pending') {
        throw httpError(409, 'REDEMPTION_ALREADY_PROCESSED');
      }

      await addEntry(client, {
        userId: row.user_id,
        type: 'REVERSAL',
        points: row.points,
        referenceType: 'redemption',
        referenceId: row.id,
        note: `Reversión de canje #${row.id}`,
        createdBy: req.user.id,
      });

      const updated = await client.query(
        `UPDATE ${SCHEMA}.redemptions
            SET status = 'rejected',
                processed_at = now()
          WHERE id = $1
          RETURNING *`,
        [redemptionId]
      );

      await client.query(
        `INSERT INTO ${SCHEMA}.notifications
           (user_id, type, title, body)
         VALUES ($1, 'redemption', 'Canje rechazado', $2)`,
        [
          row.user_id,
          `Se devolvieron ${row.points} puntos a tu cuenta.`,
        ]
      );

      return updated.rows[0];
    });

    return res.json({
      redemption: {
        ...redemption,
        amount_usd: Number(redemption.amount_usd),
      },
    });
  }));

  // ─────────────────────────────────────────────
  // 404 + MANEJO DE ERRORES
  // ─────────────────────────────────────────────

  app.use((req, res) => {
    res.status(404).json({
      error: 'NOT_FOUND',
    });
  });

  app.use((error, req, res, next) => {
    const err = pgError(error);

    if (res.headersSent) {
      return next(err);
    }

    const status = Number(err?.status) || 500;
    const code =
      status >= 500
        ? 'INTERNAL_ERROR'
        : err?.message || 'REQUEST_FAILED';

    if (status >= 500) {
      console.error('[sipi]', error);
    }

    return res.status(status).json({
      error: code,
    });
  });

  return app;
}

module.exports = { createApp };
