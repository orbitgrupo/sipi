// Sipi — API REST.
// Principios: el servidor calcula todos los montos; el cliente nunca envía
// cantidades de puntos. El saldo se deriva del ledger.
const express = require('express');
const { transaction } = require('./db');
const { hashPassword, verifyPassword, signToken, requireAuth, makeRequireAdmin } = require('./auth');
const { getBalance, addEntry, getMovements, httpError } = require('./ledger');
const { checkAndAward, metricValue } = require('./achievements');

const CATEGORIES = ['social', 'encuestas', 'productos', 'opinion', 'promociones', 'otras'];

function levelFor(pointsEarned) {
  return Math.floor(pointsEarned / 1000) + 1;
}

function validateTaskInput(b) {
  if (!b.title || typeof b.title !== 'string' || b.title.trim().length < 3) throw httpError(400, 'INVALID_TITLE');
  if (!Number.isInteger(b.points) || b.points <= 0) throw httpError(400, 'INVALID_POINTS');
  if (b.category && !CATEGORIES.includes(b.category)) throw httpError(400, 'INVALID_CATEGORY');
  if (b.verification && !['manual', 'auto'].includes(b.verification)) throw httpError(400, 'INVALID_VERIFICATION');
  if (b.max_completions_per_user !== undefined && (!Number.isInteger(b.max_completions_per_user) || b.max_completions_per_user < 1)) {
    throw httpError(400, 'INVALID_MAX_COMPLETIONS');
  }
}

function validateSurveyAnswers(questions, answers) {
  if (typeof answers !== 'object' || answers === null) throw httpError(400, 'INVALID_ANSWERS');
  for (const q of questions) {
    const v = answers[q.id];
    const empty = v === undefined || v === null || v === '' || (Array.isArray(v) && v.length === 0);
    if (q.required && empty) throw httpError(400, `REQUIRED_QUESTION:${q.id}`);
    if (empty) continue;
    switch (q.type) {
      case 'single':
        if (!q.options.includes(v)) throw httpError(400, `INVALID_ANSWER:${q.id}`);
        break;
      case 'multiple':
        if (!Array.isArray(v) || !v.every((x) => q.options.includes(x))) throw httpError(400, `INVALID_ANSWER:${q.id}`);
        break;
      case 'yesno':
        if (typeof v !== 'boolean') throw httpError(400, `INVALID_ANSWER:${q.id}`);
        break;
      case 'scale': {
        const n = Number(v);
        const min = q.min ?? 1, max = q.max ?? 5;
        if (!Number.isInteger(n) || n < min || n > max) throw httpError(400, `INVALID_ANSWER:${q.id}`);
        break;
      }
      case 'text':
        if (typeof v !== 'string') throw httpError(400, `INVALID_ANSWER:${q.id}`);
        break;
      default:
        throw httpError(400, `UNKNOWN_QUESTION_TYPE:${q.id}`);
    }
  }
}

function createApp(db) {
  const app = express();
  app.use(express.json());
  app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  const requireAdmin = makeRequireAdmin(db);
  const getPointsPerUsd = () => {
    const r = db.prepare("SELECT value FROM config WHERE key = 'points_per_usd'").get();
    return Math.max(1, parseInt(r.value, 10) || 50);
  };
  const toUsd = (points) => Math.floor((points / getPointsPerUsd()) * 100) / 100;

  // Aprueba una completion pendiente y acredita los puntos. Idempotente ante
  // doble aprobación: la segunda falla con 409 y no duplica el ledger.
  // Núcleo de aprobación SIN transacción propia: lo envuelven approveCompletionTx
  // o la transacción de respuesta de encuesta (no se pueden anidar BEGIN).
  const approveCompletionCore = (completionId, reviewerId) => {
    const c = db.prepare('SELECT * FROM task_completions WHERE id = ?').get(completionId);
    if (!c) throw httpError(404, 'COMPLETION_NOT_FOUND');
    if (c.status !== 'pending') throw httpError(409, 'ALREADY_REVIEWED');
    const t = db.prepare('SELECT * FROM tasks WHERE id = ?').get(c.task_id);
    const approvedCount = db
      .prepare("SELECT COUNT(*) AS c FROM task_completions WHERE task_id = ? AND user_id = ? AND status = 'approved'")
      .get(t.id, c.user_id).c;
    if (approvedCount >= t.max_completions_per_user) throw httpError(409, 'TASK_LIMIT_REACHED');
    db.prepare("UPDATE task_completions SET status = 'approved', reviewed_at = datetime('now'), reviewed_by = ? WHERE id = ?")
      .run(reviewerId, completionId);
    addEntry(db, {
      userId: c.user_id, type: 'EARN', points: t.points,
      referenceType: 'task_completion', referenceId: completionId,
      note: t.title, createdBy: reviewerId,
    });
    db.prepare('INSERT INTO notifications (user_id, type, title, body) VALUES (?, ?, ?, ?)').run(
      c.user_id, 'task', '¡Tarea completada!', `Ganaste ${t.points} puntos por "${t.title}".`
    );
    checkAndAward(db, c.user_id);
    return { completionId, points: t.points };
  };
  const approveCompletionTx = transaction(db, approveCompletionCore);

  // ---------------- Auth ----------------
  app.post('/api/auth/register', (req, res, next) => {
    try {
      const { name, email, password } = req.body || {};
      if (!name || !email || !password) throw httpError(400, 'MISSING_FIELDS');
      if (password.length < 6) throw httpError(400, 'WEAK_PASSWORD');
      const emailNorm = String(email).trim().toLowerCase();
      const exists = db.prepare('SELECT id FROM users WHERE email = ?').get(emailNorm);
      if (exists) throw httpError(409, 'EMAIL_TAKEN');
      const info = db.prepare('INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)').run(
        String(name).trim(), emailNorm, hashPassword(password)
      );
      const user = db.prepare('SELECT id, name, email, role FROM users WHERE id = ?').get(info.lastInsertRowid);
      res.status(201).json({ token: signToken(user), user });
    } catch (e) { next(e); }
  });

  app.post('/api/auth/login', (req, res, next) => {
    try {
      const { email, password } = req.body || {};
      const row = db.prepare('SELECT * FROM users WHERE email = ?').get(String(email || '').trim().toLowerCase());
      if (!row || row.status !== 'active' || !verifyPassword(password || '', row.password_hash)) {
        throw httpError(401, 'INVALID_CREDENTIALS');
      }
      const user = { id: row.id, name: row.name, email: row.email, role: row.role };
      res.json({ token: signToken(user), user });
    } catch (e) { next(e); }
  });

  app.get('/api/auth/me', requireAuth, (req, res) => {
    const row = db.prepare('SELECT id, name, email, role, created_at FROM users WHERE id = ?').get(req.user.id);
    const points = getBalance(db, req.user.id);
    res.json({ user: row, balance: { points, usd: toUsd(points), points_per_usd: getPointsPerUsd() } });
  });

  app.put('/api/users/me', requireAuth, (req, res, next) => {
    try {
      const { name, email } = req.body || {};
      const nameTrim = String(name || '').trim();
      const emailNorm = String(email || '').trim().toLowerCase();
      if (!nameTrim) throw httpError(400, 'MISSING_FIELDS');
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) throw httpError(400, 'INVALID_EMAIL');
      const taken = db.prepare('SELECT id FROM users WHERE email = ? AND id != ?').get(emailNorm, req.user.id);
      if (taken) throw httpError(409, 'EMAIL_TAKEN');
      db.prepare('UPDATE users SET name = ?, email = ? WHERE id = ?').run(nameTrim, emailNorm, req.user.id);
      const user = db.prepare('SELECT id, name, email, role FROM users WHERE id = ?').get(req.user.id);
      res.json({ user });
    } catch (e) { next(e); }
  });

  app.put('/api/users/me/password', requireAuth, (req, res, next) => {
    try {
      const { current_password, new_password } = req.body || {};
      if (!current_password || !new_password) throw httpError(400, 'MISSING_FIELDS');
      if (String(new_password).length < 6) throw httpError(400, 'WEAK_PASSWORD');
      const row = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(req.user.id);
      if (!row || !verifyPassword(String(current_password), row.password_hash)) {
        throw httpError(401, 'INVALID_CREDENTIALS');
      }
      db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(hashPassword(String(new_password)), req.user.id);
      res.json({ ok: true });
    } catch (e) { next(e); }
  });

  // ---------------- Config pública ----------------
  app.get('/api/config', (req, res) => {
    res.json({ points_per_usd: getPointsPerUsd() });
  });

  // ---------------- Saldo y ledger ----------------
  app.get('/api/balance', requireAuth, (req, res) => {
    const points = getBalance(db, req.user.id);
    const pending = db.prepare(
      `SELECT COALESCE(SUM(t.points),0) AS p FROM task_completions c
       JOIN tasks t ON t.id = c.task_id WHERE c.user_id = ? AND c.status = 'pending'`
    ).get(req.user.id).p;
    const earned = db.prepare(
      `SELECT COALESCE(SUM(points),0) AS s FROM ledger WHERE user_id = ? AND type IN ('EARN','BONUS')`
    ).get(req.user.id).s;
    const used = db.prepare(
      `SELECT COALESCE(SUM(-points),0) AS s FROM ledger WHERE user_id = ? AND type = 'REDEEM'`
    ).get(req.user.id).s;
    res.json({
      points, pending_points: pending, earned_points: earned, used_points: used,
      usd: toUsd(points), points_per_usd: getPointsPerUsd(), level: levelFor(earned),
    });
  });

  app.get('/api/ledger', requireAuth, (req, res) => {
    res.json({ movements: getMovements(db, req.user.id, 100) });
  });

  // ---------------- Tareas ----------------
  app.get('/api/tasks', requireAuth, (req, res) => {
    const { category, q } = req.query;
    let sql = `SELECT t.*, c.status AS my_status FROM tasks t
               LEFT JOIN task_completions c ON c.task_id = t.id AND c.user_id = ? AND c.status IN ('pending','approved')
               WHERE t.active = 1`;
    const params = [req.user.id];
    if (category && CATEGORIES.includes(category)) { sql += ' AND t.category = ?'; params.push(category); }
    if (q) { sql += ' AND (t.title LIKE ? OR t.description LIKE ?)'; params.push(`%${q}%`, `%${q}%`); }
    sql += ' ORDER BY t.id DESC';
    res.json({ tasks: db.prepare(sql).all(...params) });
  });

  app.get('/api/tasks/:id', requireAuth, (req, res, next) => {
    try {
      const t = db.prepare('SELECT * FROM tasks WHERE id = ? AND active = 1').get(req.params.id);
      if (!t) throw httpError(404, 'TASK_NOT_FOUND');
      const completions = db.prepare('SELECT id, status, submitted_at FROM task_completions WHERE task_id = ? AND user_id = ? ORDER BY id DESC')
        .all(t.id, req.user.id);
      res.json({ task: t, my_completions: completions });
    } catch (e) { next(e); }
  });

  app.post('/api/tasks/:id/submit', requireAuth, (req, res, next) => {
    try {
      const submitTx = transaction(db, (taskId, userId, evidence) => {
        const t = db.prepare('SELECT * FROM tasks WHERE id = ? AND active = 1').get(taskId);
        if (!t) throw httpError(404, 'TASK_NOT_FOUND');
        const counts = db.prepare(
          `SELECT
             SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved,
             SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending
           FROM task_completions WHERE task_id = ? AND user_id = ?`
        ).get(taskId, userId);
        if ((counts.approved || 0) >= t.max_completions_per_user) throw httpError(409, 'TASK_LIMIT_REACHED');
        if ((counts.pending || 0) >= t.max_completions_per_user) throw httpError(409, 'ALREADY_PENDING');
        const info = db.prepare('INSERT INTO task_completions (task_id, user_id, evidence) VALUES (?, ?, ?)')
          .run(taskId, userId, evidence || '');
        return db.prepare('SELECT * FROM task_completions WHERE id = ?').get(info.lastInsertRowid);
      });
      const completion = submitTx(req.params.id, req.user.id, (req.body || {}).evidence || '');
      res.status(201).json({ completion });
    } catch (e) { next(e); }
  });

  // ---------------- Encuestas ----------------
  app.get('/api/tasks/:id/survey', requireAuth, (req, res, next) => {
    try {
      const s = db.prepare('SELECT * FROM surveys WHERE task_id = ?').get(req.params.id);
      if (!s) throw httpError(404, 'SURVEY_NOT_FOUND');
      const answered = db.prepare('SELECT id FROM survey_responses WHERE survey_id = ? AND user_id = ?')
        .get(s.id, req.user.id);
      res.json({ survey: { ...s, questions: JSON.parse(s.questions) }, answered: !!answered });
    } catch (e) { next(e); }
  });

  app.post('/api/tasks/:id/survey', requireAuth, (req, res, next) => {
    try {
      const answerTx = transaction(db, (taskId, userId, answers) => {
        const t = db.prepare('SELECT * FROM tasks WHERE id = ? AND active = 1').get(taskId);
        if (!t) throw httpError(404, 'TASK_NOT_FOUND');
        const s = db.prepare('SELECT * FROM surveys WHERE task_id = ?').get(taskId);
        if (!s) throw httpError(404, 'SURVEY_NOT_FOUND');
        const dup = db.prepare('SELECT id FROM survey_responses WHERE survey_id = ? AND user_id = ?').get(s.id, userId);
        if (dup) throw httpError(409, 'SURVEY_ALREADY_ANSWERED');
        validateSurveyAnswers(JSON.parse(s.questions), answers);
        const rInfo = db.prepare('INSERT INTO survey_responses (survey_id, user_id, answers) VALUES (?, ?, ?)')
          .run(s.id, userId, JSON.stringify(answers));
        const counts = db.prepare(
          `SELECT SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved
           FROM task_completions WHERE task_id = ? AND user_id = ?`
        ).get(taskId, userId);
        if ((counts.approved || 0) >= t.max_completions_per_user) throw httpError(409, 'TASK_LIMIT_REACHED');
        const cInfo = db.prepare("INSERT INTO task_completions (task_id, user_id, evidence, status) VALUES (?, ?, ?, 'pending')")
          .run(taskId, userId, `survey_response:${rInfo.lastInsertRowid}`);
        let result = { response_id: rInfo.lastInsertRowid, completion_id: cInfo.lastInsertRowid, auto_approved: false };
        if (t.verification === 'auto') {
          // La verificación es la propia respuesta válida: se acredita de inmediato.
          // Usa el núcleo sin transacción propia (ya estamos dentro de una).
          const r = approveCompletionCore(cInfo.lastInsertRowid, null);
          result = { ...result, auto_approved: true, points: r.points };
        }
        checkAndAward(db, userId);
        return result;
      });
      res.status(201).json(answerTx(req.params.id, req.user.id, (req.body || {}).answers));
    } catch (e) { next(e); }
  });

  // ---------------- Canjes ----------------
  app.post('/api/redemptions', requireAuth, (req, res, next) => {
    try {
      const points = parseInt((req.body || {}).points, 10);
      if (!Number.isInteger(points) || points <= 0) throw httpError(400, 'INVALID_POINTS');
      const redeemTx = transaction(db, (userId, pts) => {
        const balance = getBalance(db, userId);
        if (pts > balance) throw httpError(400, 'INSUFFICIENT_POINTS');
        const amount = Math.floor((pts / getPointsPerUsd()) * 100) / 100;
        if (amount <= 0) throw httpError(400, 'AMOUNT_TOO_LOW');
        const info = db.prepare("INSERT INTO redemptions (user_id, points, amount_usd, status) VALUES (?, ?, ?, 'pending')")
          .run(userId, pts, amount);
        addEntry(db, {
          userId, type: 'REDEEM', points: -pts,
          referenceType: 'redemption', referenceId: info.lastInsertRowid,
          note: `Canje por $${amount.toFixed(2)} USD`,
        });
        db.prepare('INSERT INTO notifications (user_id, type, title, body) VALUES (?, ?, ?, ?)').run(
          userId, 'payment', 'Canje solicitado', `Tu canje de ${pts} pts ($${amount.toFixed(2)}) está en proceso.`
        );
        checkAndAward(db, userId);
        return db.prepare('SELECT * FROM redemptions WHERE id = ?').get(info.lastInsertRowid);
      });
      res.status(201).json({ redemption: redeemTx(req.user.id, points) });
    } catch (e) { next(e); }
  });

  app.get('/api/redemptions', requireAuth, (req, res) => {
    res.json({
      redemptions: db.prepare('SELECT * FROM redemptions WHERE user_id = ? ORDER BY id DESC').all(req.user.id),
    });
  });

  // ---------------- Logros ----------------
  app.get('/api/achievements', requireAuth, (req, res) => {
    const all = db.prepare('SELECT * FROM achievements ORDER BY threshold ASC').all();
    const earned = new Map(
      db.prepare('SELECT achievement_id, earned_at FROM user_achievements WHERE user_id = ?').all(req.user.id)
        .map((r) => [r.achievement_id, r.earned_at])
    );
    res.json({
      achievements: all.map((a) => ({
        ...a,
        earned: earned.has(a.id),
        earned_at: earned.get(a.id) || null,
        progress: metricValue(db, req.user.id, a.metric),
      })),
    });
  });

  // ---------------- Notificaciones ----------------
  app.get('/api/notifications', requireAuth, (req, res) => {
    res.json({
      notifications: db.prepare('SELECT * FROM notifications WHERE user_id = ? ORDER BY id DESC LIMIT 50').all(req.user.id),
    });
  });

  app.post('/api/notifications/:id/read', requireAuth, (req, res) => {
    db.prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?').run(req.params.id, req.user.id);
    res.json({ ok: true });
  });

  // ================= Admin =================
  app.get('/api/admin/stats', requireAuth, requireAdmin, (req, res) => {
    const users = db.prepare('SELECT COUNT(*) AS c FROM users').get().c;
    const activeTasks = db.prepare('SELECT COUNT(*) AS c FROM tasks WHERE active = 1').get().c;
    const pendingCompletions = db.prepare("SELECT COUNT(*) AS c FROM task_completions WHERE status = 'pending'").get().c;
    const pointsIssued = db.prepare("SELECT COALESCE(SUM(points),0) AS s FROM ledger WHERE type IN ('EARN','BONUS')").get().s;
    const pendingPayouts = db.prepare("SELECT COALESCE(SUM(amount_usd),0) AS s FROM redemptions WHERE status = 'pending'").get().s;
    res.json({ users, active_tasks: activeTasks, pending_completions: pendingCompletions, points_issued: pointsIssued, pending_payouts_usd: pendingPayouts });
  });

  app.get('/api/admin/users', requireAuth, requireAdmin, (req, res) => {
    const users = db.prepare('SELECT id, name, email, role, status, created_at FROM users ORDER BY id DESC').all();
    res.json({
      users: users.map((u) => {
        const earned = db.prepare("SELECT COALESCE(SUM(points),0) AS s FROM ledger WHERE user_id = ? AND type IN ('EARN','BONUS')").get(u.id).s;
        return { ...u, points: getBalance(db, u.id), level: levelFor(earned) };
      }),
    });
  });

  app.patch('/api/admin/users/:id', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const { status, role } = req.body || {};
      if (status && !['active', 'inactive'].includes(status)) throw httpError(400, 'INVALID_STATUS');
      if (role && !['user', 'admin'].includes(role)) throw httpError(400, 'INVALID_ROLE');
      if (Number(req.params.id) === req.user.id && (status === 'inactive' || role === 'user')) {
        throw httpError(400, 'CANNOT_DEMOTE_SELF');
      }
      const sets = [], params = [];
      if (status) { sets.push('status = ?'); params.push(status); }
      if (role) { sets.push('role = ?'); params.push(role); }
      if (!sets.length) throw httpError(400, 'NOTHING_TO_UPDATE');
      params.push(req.params.id);
      const info = db.prepare(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`).run(...params);
      if (!info.changes) throw httpError(404, 'USER_NOT_FOUND');
      res.json({ ok: true });
    } catch (e) { next(e); }
  });

  app.post('/api/admin/tasks', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const b = req.body || {};
      validateTaskInput(b);
      const info = db.prepare(
        `INSERT INTO tasks (title, description, instructions, category, points, estimated_minutes,
                            verification, requirements, target_url, max_completions_per_user, created_by)
         VALUES (@title, @description, @instructions, @category, @points, @estimated_minutes,
                 @verification, @requirements, @target_url, @max_completions_per_user, @created_by)`
      ).run({
        title: b.title.trim(),
        description: b.description || '',
        instructions: b.instructions || '',
        category: b.category || 'otras',
        points: b.points,
        estimated_minutes: b.estimated_minutes || 5,
        verification: b.verification || 'manual',
        requirements: b.requirements || '',
        target_url: b.target_url || '',
        max_completions_per_user: b.max_completions_per_user || 1,
        created_by: req.user.id,
      });
      res.status(201).json({ task: db.prepare('SELECT * FROM tasks WHERE id = ?').get(info.lastInsertRowid) });
    } catch (e) { next(e); }
  });

  app.put('/api/admin/tasks/:id', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const b = req.body || {};
      const row = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
      if (!row) throw httpError(404, 'TASK_NOT_FOUND');
      const m = { ...row, ...b };
      validateTaskInput(m);
      const info = db.prepare(
        `UPDATE tasks SET title=@title, description=@description, instructions=@instructions,
          category=@category, points=@points, estimated_minutes=@estimated_minutes,
          verification=@verification, requirements=@requirements, target_url=@target_url,
          max_completions_per_user=@max_completions_per_user, active=@active WHERE id=@id`
      ).run({
        id: req.params.id,
        title: String(m.title).trim(),
        description: m.description || '',
        instructions: m.instructions || '',
        category: m.category || 'otras',
        points: m.points,
        estimated_minutes: m.estimated_minutes ?? 5,
        verification: m.verification || 'manual',
        requirements: m.requirements || '',
        target_url: m.target_url || '',
        max_completions_per_user: m.max_completions_per_user ?? 1,
        active: b.active === undefined ? (row.active ? 1 : 0) : (b.active ? 1 : 0),
      });
      if (!info.changes) throw httpError(404, 'TASK_NOT_FOUND');
      res.json({ task: db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id) });
    } catch (e) { next(e); }
  });

  app.post('/api/admin/tasks/:id/survey', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const { title, questions } = req.body || {};
      if (!Array.isArray(questions) || !questions.length) throw httpError(400, 'INVALID_QUESTIONS');
      const t = db.prepare('SELECT id FROM tasks WHERE id = ?').get(req.params.id);
      if (!t) throw httpError(404, 'TASK_NOT_FOUND');
      db.prepare(`INSERT INTO surveys (task_id, title, questions) VALUES (?, ?, ?)
                  ON CONFLICT(task_id) DO UPDATE SET title = excluded.title, questions = excluded.questions`)
        .run(req.params.id, title || 'Encuesta', JSON.stringify(questions));
      res.status(201).json({ ok: true });
    } catch (e) { next(e); }
  });

  app.get('/api/admin/completions', requireAuth, requireAdmin, (req, res) => {
    const { status } = req.query;
    let sql = `SELECT c.*, t.title AS task_title, t.points AS task_points, u.name AS user_name, u.email AS user_email
               FROM task_completions c JOIN tasks t ON t.id = c.task_id JOIN users u ON u.id = c.user_id`;
    const params = [];
    if (status && ['pending', 'approved', 'rejected'].includes(status)) { sql += ' WHERE c.status = ?'; params.push(status); }
    sql += ' ORDER BY c.id DESC LIMIT 200';
    res.json({ completions: db.prepare(sql).all(...params) });
  });

  app.post('/api/admin/completions/:id/approve', requireAuth, requireAdmin, (req, res, next) => {
    try {
      res.json(approveCompletionTx(req.params.id, req.user.id));
    } catch (e) { next(e); }
  });

  app.post('/api/admin/completions/:id/reject', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const c = db.prepare('SELECT * FROM task_completions WHERE id = ?').get(req.params.id);
      if (!c) throw httpError(404, 'COMPLETION_NOT_FOUND');
      if (c.status !== 'pending') throw httpError(409, 'ALREADY_REVIEWED');
      db.prepare("UPDATE task_completions SET status = 'rejected', reviewed_at = datetime('now'), reviewed_by = ? WHERE id = ?")
        .run(req.user.id, req.params.id);
      res.json({ ok: true });
    } catch (e) { next(e); }
  });

  app.get('/api/admin/redemptions', requireAuth, requireAdmin, (req, res) => {
    res.json({
      redemptions: db.prepare(
        `SELECT r.*, u.name AS user_name, u.email AS user_email FROM redemptions r
         JOIN users u ON u.id = r.user_id ORDER BY r.id DESC LIMIT 200`
      ).all(),
    });
  });

  app.post('/api/admin/redemptions/:id/complete', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const r = db.prepare('SELECT * FROM redemptions WHERE id = ?').get(req.params.id);
      if (!r) throw httpError(404, 'REDEMPTION_NOT_FOUND');
      if (r.status !== 'pending') throw httpError(409, 'ALREADY_PROCESSED');
      db.prepare("UPDATE redemptions SET status = 'completed', processed_at = datetime('now') WHERE id = ?").run(r.id);
      db.prepare('INSERT INTO notifications (user_id, type, title, body) VALUES (?, ?, ?, ?)').run(
        r.user_id, 'payment', 'Pago enviado', `Tu canje de $${r.amount_usd.toFixed(2)} fue procesado.`
      );
      res.json({ ok: true });
    } catch (e) { next(e); }
  });

  app.post('/api/admin/redemptions/:id/reject', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const rejectTx = transaction(db, (redemptionId) => {
        const r = db.prepare('SELECT * FROM redemptions WHERE id = ?').get(redemptionId);
        if (!r) throw httpError(404, 'REDEMPTION_NOT_FOUND');
        if (r.status !== 'pending') throw httpError(409, 'ALREADY_PROCESSED');
        db.prepare("UPDATE redemptions SET status = 'rejected', processed_at = datetime('now') WHERE id = ?").run(r.id);
        // REVERSAL: devuelve los puntos al usuario mediante el ledger.
        addEntry(db, {
          userId: r.user_id, type: 'REVERSAL', points: r.points,
          referenceType: 'redemption', referenceId: r.id, note: 'Canje rechazado: puntos devueltos',
        });
        db.prepare('INSERT INTO notifications (user_id, type, title, body) VALUES (?, ?, ?, ?)').run(
          r.user_id, 'payment', 'Canje rechazado', `Tus ${r.points} puntos fueron devueltos a tu saldo.`
        );
        return { ok: true };
      });
      res.json(rejectTx(req.params.id));
    } catch (e) { next(e); }
  });

  app.put('/api/admin/config', requireAuth, requireAdmin, (req, res, next) => {
    try {
      const v = parseInt((req.body || {}).points_per_usd, 10);
      if (!Number.isInteger(v) || v <= 0) throw httpError(400, 'INVALID_CONVERSION');
      db.prepare("UPDATE config SET value = ?, updated_at = datetime('now') WHERE key = 'points_per_usd'").run(String(v));
      res.json({ points_per_usd: v });
    } catch (e) { next(e); }
  });

  // ---------------- Errores ----------------
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    const status = err.status || 500;
    if (status === 500) console.error('[sipi]', err);
    res.status(status).json({ error: err.message || 'INTERNAL_ERROR' });
  });

  return app;
}

module.exports = { createApp, CATEGORIES };
