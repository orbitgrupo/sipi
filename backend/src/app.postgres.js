const express = require('express');

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

  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));

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
            AND NOT (
              t.category = 'social'
              AND EXISTS (
                SELECT 1
                  FROM ${SCHEMA}.task_completions done
                 WHERE done.task_id = t.id
                   AND done.user_id = ${userParam}
                   AND done.status = 'approved'
              )
            )
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

      const responseResult = await client.query(
        `INSERT INTO ${SCHEMA}.survey_responses
           (survey_id, user_id, answers)
         VALUES ($1, $2, $3::jsonb)
         ON CONFLICT (survey_id, user_id) DO NOTHING
         RETURNING *`,
        [survey.id, req.user.id, JSON.stringify(answers)]
      );

      if (!responseResult.rowCount) {
        throw httpError(409, 'SURVEY_ALREADY_ANSWERED');
      }

      let autoApproved = false;

      if (survey.verification === 'auto') {
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
      };
    });

    return res.status(201).json({
      response: result.response,
      auto_approved: result.autoApproved,
    });
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
    const [users, tasks, completions, redemptions, popular] =
      await Promise.all([
        db.query(`SELECT COUNT(*)::int AS total FROM ${SCHEMA}.profiles`),
        db.query(`SELECT COUNT(*)::int AS total FROM ${SCHEMA}.tasks WHERE active = true`),
        db.query(`SELECT COUNT(*)::int AS total FROM ${SCHEMA}.task_completions`),
        db.query(
          `SELECT COUNT(*)::int AS total
             FROM ${SCHEMA}.redemptions
            WHERE status = 'pending'`
        ),
        db.query(
          `SELECT t.id, t.title, COUNT(c.id)::int AS completions
             FROM ${SCHEMA}.tasks t
             LEFT JOIN ${SCHEMA}.task_completions c ON c.task_id = t.id
            GROUP BY t.id, t.title
            ORDER BY completions DESC, t.id DESC
            LIMIT 5`
        ),
      ]);

    return res.json({
      users: users.rows[0].total,
      active_tasks: tasks.rows[0].total,
      total_completions: completions.rows[0].total,
      pending_redemptions: redemptions.rows[0].total,
      popular_tasks: popular.rows,
    });
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

    const networks = [
      'instagram', 'tiktok', 'facebook', 'x', 'youtube',
    ];

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
          created_by)
       VALUES
         ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
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

  app.patch('/api/notifications/:id/read', requireAuth, asyncRoute(async (req, res) => {
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
  }));

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
