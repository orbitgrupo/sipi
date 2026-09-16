// Sipi — suite de pruebas del backend (Fase 1).
// Cubre: auth, tareas, verificación anti-doble-acreditación, ledger,
// canjes con fondos insuficientes, reversals, conversión configurable,
// encuestas y logros.
const request = require('supertest');
const { openDb } = require('../src/db');
const { createApp } = require('../src/app');

let db, app;
let adminToken, userToken, userId;

async function registerAndLogin(name, email, password) {
  const r = await request(app).post('/api/auth/register').send({ name, email, password });
  expect(r.status).toBe(201);
  return r.body.token;
}

beforeAll(async () => {
  db = openDb(':memory:');
  app = createApp(db);
  adminToken = await registerAndLogin('Admin', 'admin@sipi.app', 'admin123');
  db.prepare("UPDATE users SET role = 'admin' WHERE email = ?").run('admin@sipi.app');
  // Re-login para que el token incluya el rol admin
  const login = await request(app).post('/api/auth/login').send({ email: 'admin@sipi.app', password: 'admin123' });
  adminToken = login.body.token;
  userToken = await registerAndLogin('Alex', 'alex@mail.com', 'secret12');
  userId = db.prepare('SELECT id FROM users WHERE email = ?').get('alex@mail.com').id;
});

const auth = (t) => ({ Authorization: `Bearer ${t}` });

describe('auth', () => {
  test('registro duplicado falla con 409', async () => {
    const r = await request(app).post('/api/auth/register')
      .send({ name: 'Alex', email: 'alex@mail.com', password: 'secret12' });
    expect(r.status).toBe(409);
    expect(r.body.error).toBe('EMAIL_TAKEN');
  });
  test('login con clave incorrecta falla con 401', async () => {
    const r = await request(app).post('/api/auth/login').send({ email: 'alex@mail.com', password: 'nope' });
    expect(r.status).toBe(401);
  });
  test('ruta protegida sin token falla con 401', async () => {
    const r = await request(app).get('/api/balance');
    expect(r.status).toBe(401);
  });
  test('usuario no admin no accede a /api/admin', async () => {
    const r = await request(app).get('/api/admin/stats').set(auth(userToken));
    expect(r.status).toBe(403);
  });
});

describe('perfil', () => {
  test('actualiza nombre y correo', async () => {
    const r = await request(app).put('/api/users/me')
      .set(auth(userToken))
      .send({ name: 'Alex Nuevo', email: 'alexnuevo@mail.com' });
    expect(r.status).toBe(200);
    expect(r.body.user.name).toBe('Alex Nuevo');
    expect(r.body.user.email).toBe('alexnuevo@mail.com');
  });
  test('email duplicado falla con 409', async () => {
    const r = await request(app).put('/api/users/me')
      .set(auth(userToken))
      .send({ name: 'Alex', email: 'admin@sipi.app' });
    expect(r.status).toBe(409);
    expect(r.body.error).toBe('EMAIL_TAKEN');
  });
  test('email inválido falla con 400', async () => {
    const r = await request(app).put('/api/users/me')
      .set(auth(userToken))
      .send({ name: 'Alex', email: 'no-es-email' });
    expect(r.status).toBe(400);
  });
  test('cambia la contraseña y permite login con la nueva', async () => {
    const r = await request(app).put('/api/users/me/password')
      .set(auth(userToken))
      .send({ current_password: 'secret12', new_password: 'nueva123' });
    expect(r.status).toBe(200);
    const login = await request(app).post('/api/auth/login')
      .send({ email: 'alexnuevo@mail.com', password: 'nueva123' });
    expect(login.status).toBe(200);
  });
  test('contraseña actual incorrecta falla con 401', async () => {
    const r = await request(app).put('/api/users/me/password')
      .set(auth(userToken))
      .send({ current_password: 'errada', new_password: 'otra1234' });
    expect(r.status).toBe(401);
  });
  test('contraseña débil falla con 400', async () => {
    const r = await request(app).put('/api/users/me/password')
      .set(auth(userToken))
      .send({ current_password: 'nueva123', new_password: '123' });
    expect(r.status).toBe(400);
    expect(r.body.error).toBe('WEAK_PASSWORD');
  });
});

describe('tareas y verificación', () => {
  let taskId;
  test('admin crea tarea', async () => {
    const r = await request(app).post('/api/admin/tasks').set(auth(adminToken)).send({
      title: 'Seguir cuenta en Instagram', description: 'Sigue y mantén 7 días',
      category: 'social', points: 10, estimated_minutes: 2, verification: 'manual',
    });
    expect(r.status).toBe(201);
    taskId = r.body.task.id;
  });
  test('usuario ve la tarea en el listado', async () => {
    const r = await request(app).get('/api/tasks').set(auth(userToken));
    expect(r.body.tasks.some((t) => t.id === taskId)).toBe(true);
  });
  test('usuario envía la tarea para verificación', async () => {
    const r = await request(app).post(`/api/tasks/${taskId}/submit`).set(auth(userToken)).send({ evidence: 'screenshot.png' });
    expect(r.status).toBe(201);
    expect(r.body.completion.status).toBe('pending');
  });
  test('saldo pendiente refleja la tarea enviada', async () => {
    const r = await request(app).get('/api/balance').set(auth(userToken));
    expect(r.body.points).toBeGreaterThanOrEqual(0);
    expect(r.body.pending_points).toBe(10);
  });
  test('admin aprueba y se acreditan los puntos vía ledger', async () => {
    const pending = await request(app).get('/api/admin/completions?status=pending').set(auth(adminToken));
    const c = pending.body.completions.find((x) => x.task_id === taskId);
    const r = await request(app).post(`/api/admin/completions/${c.id}/approve`).set(auth(adminToken));
    expect(r.status).toBe(200);
    const bal = await request(app).get('/api/balance').set(auth(userToken));
    // 10 (tarea) + 5 (bonus logro primera tarea) = 15
    expect(bal.body.points).toBe(15);
    const ledger = await request(app).get('/api/ledger').set(auth(userToken));
    expect(ledger.body.movements.some((m) => m.type === 'EARN' && m.points === 10)).toBe(true);
  });
  test('doble aprobación NO duplica puntos (409)', async () => {
    const done = await request(app).get('/api/admin/completions?status=approved').set(auth(adminToken));
    const c = done.body.completions.find((x) => x.task_id === taskId);
    const r = await request(app).post(`/api/admin/completions/${c.id}/approve`).set(auth(adminToken));
    expect(r.status).toBe(409);
    const bal = await request(app).get('/api/balance').set(auth(userToken));
    expect(bal.body.points).toBe(15);
  });
  test('misma tarea no se puede acreditar dos veces (límite 1)', async () => {
    const r = await request(app).post(`/api/tasks/${taskId}/submit`).set(auth(userToken)).send({});
    expect(r.status).toBe(409);
    expect(r.body.error).toBe('TASK_LIMIT_REACHED');
  });
});

describe('canjes y conversión', () => {
  test('canje sin fondos suficientes falla con 400', async () => {
    const r = await request(app).post('/api/redemptions').set(auth(userToken)).send({ points: 99999 });
    expect(r.status).toBe(400);
    expect(r.body.error).toBe('INSUFFICIENT_POINTS');
  });
  test('canje válido debita del ledger (50 pts = $1.00)', async () => {
    // El usuario tiene 15 pts: acreditamos más vía ajuste de admin simulado con tarea
    const t = await request(app).post('/api/admin/tasks').set(auth(adminToken))
      .send({ title: 'Tarea grande', points: 100, category: 'otras', verification: 'manual' });
    const s = await request(app).post(`/api/tasks/${t.body.task.id}/submit`).set(auth(userToken)).send({});
    const c = s.body.completion.id;
    await request(app).post(`/api/admin/completions/${c}/approve`).set(auth(adminToken));
    const before = (await request(app).get('/api/balance').set(auth(userToken))).body.points;
    const r = await request(app).post('/api/redemptions').set(auth(userToken)).send({ points: 100 });
    expect(r.status).toBe(201);
    expect(r.body.redemption.amount_usd).toBe(2.0);
    expect(r.body.redemption.status).toBe('pending');
    const after = (await request(app).get('/api/balance').set(auth(userToken))).body.points;
    expect(after).toBe(before - 100 + 5); // -100 canje +5 bonus logro "Primer canje"
  });
  test('conversión configurable: 100 pts = $1.00 cambia el canje', async () => {
    const cfg = await request(app).put('/api/admin/config').set(auth(adminToken)).send({ points_per_usd: 100 });
    expect(cfg.body.points_per_usd).toBe(100);
    const bal = await request(app).get('/api/balance').set(auth(userToken));
    expect(bal.body.points_per_usd).toBe(100);
    expect(bal.body.usd).toBe(Math.floor((bal.body.points / 100) * 100) / 100);
    // Canjea el saldo restante (30 pts) con la nueva conversión → $0.30
    const r = await request(app).post('/api/redemptions').set(auth(userToken)).send({ points: 30 });
    expect(r.status).toBe(201);
    expect(r.body.redemption.amount_usd).toBe(0.3);
  });
  test('rechazar un canje devuelve los puntos (REVERSAL)', async () => {
    const list = await request(app).get('/api/redemptions').set(auth(userToken));
    const pending = list.body.redemptions.find((x) => x.status === 'pending');
    const before = (await request(app).get('/api/balance').set(auth(userToken))).body.points;
    const r = await request(app).post(`/api/admin/redemptions/${pending.id}/reject`).set(auth(adminToken));
    expect(r.status).toBe(200);
    const after = (await request(app).get('/api/balance').set(auth(userToken))).body.points;
    expect(after).toBe(before + pending.points);
    const ledger = await request(app).get('/api/ledger').set(auth(userToken));
    expect(ledger.body.movements.some((m) => m.type === 'REVERSAL' && m.points === pending.points)).toBe(true);
  });
});

describe('encuestas', () => {
  let surveyTaskId;
  test('admin crea tarea con encuesta auto-verificada', async () => {
    const t = await request(app).post('/api/admin/tasks').set(auth(adminToken)).send({
      title: 'Encuesta de productos', category: 'encuestas', points: 25, verification: 'auto',
    });
    surveyTaskId = t.body.task.id;
    const s = await request(app).post(`/api/admin/tasks/${surveyTaskId}/survey`).set(auth(adminToken)).send({
      title: 'Encuesta de productos',
      questions: [
        { id: 'q1', type: 'single', text: '¿Compras en línea?', options: ['Sí', 'No'], required: true },
        { id: 'q2', type: 'multiple', text: 'Categorías', options: ['A', 'B'], required: false },
        { id: 'q3', type: 'yesno', text: '¿Recomiendas?', required: true },
        { id: 'q4', type: 'scale', text: 'Satisfacción', min: 1, max: 5, required: true },
        { id: 'q5', type: 'text', text: 'Comentarios', required: false },
      ],
    });
    expect(s.status).toBe(201);
  });
  test('responder con pregunta requerida vacía falla', async () => {
    const r = await request(app).post(`/api/tasks/${surveyTaskId}/survey`).set(auth(userToken))
      .send({ answers: { q1: 'Sí' } });
    expect(r.status).toBe(400);
  });
  test('responder válido acredita automáticamente', async () => {
    const before = (await request(app).get('/api/balance').set(auth(userToken))).body.points;
    const r = await request(app).post(`/api/tasks/${surveyTaskId}/survey`).set(auth(userToken)).send({
      answers: { q1: 'Sí', q2: ['A'], q3: true, q4: 4, q5: 'todo bien' },
    });
    expect(r.status).toBe(201);
    expect(r.body.auto_approved).toBe(true);
    const after = (await request(app).get('/api/balance').set(auth(userToken))).body.points;
    // 25 encuesta + 5 bonus logro encuestador
    expect(after).toBe(before + 30);
  });
  test('no se puede responder dos veces', async () => {
    const r = await request(app).post(`/api/tasks/${surveyTaskId}/survey`).set(auth(userToken))
      .send({ answers: { q1: 'No', q3: false, q4: 2 } });
    expect(r.status).toBe(409);
  });
});

describe('logros', () => {
  test('logros de primera tarea y primera encuesta están ganados', async () => {
    const r = await request(app).get('/api/achievements').set(auth(userToken));
    const byCode = Object.fromEntries(r.body.achievements.map((a) => [a.code, a]));
    expect(byCode.first_task.earned).toBe(true);
    expect(byCode.first_survey.earned).toBe(true);
    expect(byCode.tasks_10.earned).toBe(false);
    expect(byCode.tasks_10.progress).toBeGreaterThanOrEqual(2);
  });
});

describe('admin', () => {
  test('stats del dashboard', async () => {
    const r = await request(app).get('/api/admin/stats').set(auth(adminToken));
    expect(r.status).toBe(200);
    expect(r.body.users).toBeGreaterThanOrEqual(2);
    expect(r.body.active_tasks).toBeGreaterThanOrEqual(3);
  });
  test('listado de usuarios con puntos y nivel', async () => {
    const r = await request(app).get('/api/admin/users').set(auth(adminToken));
    const alex = r.body.users.find((u) => u.name === 'Alex Nuevo');
    expect(alex.points).toBeGreaterThan(0);
    expect(alex.level).toBeGreaterThanOrEqual(1);
  });
});
