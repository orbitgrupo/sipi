// Sipi — datos de demostración (admin, tareas del mockup y una encuesta).
const { openDb } = require('./db');
const { hashPassword } = require('./auth');

const db = openDb(process.env.DB_PATH);

const adminEmail = 'admin@sipi.app';
if (!db.prepare('SELECT id FROM users WHERE email = ?').get(adminEmail)) {
  db.prepare("INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, 'admin')")
    .run('Admin Sipi', adminEmail, hashPassword('admin123'));
  console.log('[seed] admin creado: admin@sipi.app / admin123');
}
const adminId = db.prepare('SELECT id FROM users WHERE email = ?').get(adminEmail).id;

const TASKS = [
  { title: 'Seguir una cuenta en Instagram', description: 'Sigue la cuenta indicada y mantén el seguimiento durante 7 días.', instructions: 'Sigue la cuenta indicada y no dejes de seguirla por 7 días.', category: 'social', points: 10, estimated_minutes: 2, verification: 'manual', target_url: 'https://instagram.com' },
  { title: 'Dar like a una publicación', description: 'Interactúa con la publicación indicada.', instructions: 'Abre el enlace y dale like a la publicación.', category: 'social', points: 5, estimated_minutes: 1, verification: 'auto', target_url: '' },
  { title: 'Ver un video en TikTok', description: 'Mira el video completo.', instructions: 'Reproduce el video hasta el final.', category: 'social', points: 10, estimated_minutes: 3, verification: 'auto', target_url: 'https://tiktok.com' },
  { title: 'Suscribirte en YouTube', description: 'Suscríbete al canal indicado.', instructions: 'Abre el canal y pulsa Suscribirse.', category: 'social', points: 15, estimated_minutes: 2, verification: 'manual', target_url: 'https://youtube.com' },
  { title: 'Completar encuesta de productos', description: 'Responde preguntas sobre productos que usas a diario.', instructions: 'Responde todas las preguntas con honestidad.', category: 'encuestas', points: 25, estimated_minutes: 5, verification: 'auto' },
  { title: 'Opinión sobre bebidas deportivas', description: 'Cuéntanos tu opinión en 5 minutos.', instructions: 'Completa la encuesta.', category: 'opinion', points: 25, estimated_minutes: 5, verification: 'auto' },
  { title: 'Probar una app', description: 'Instala la app y úsala por 5 minutos.', instructions: 'Descarga la app desde el enlace y explórala.', category: 'promociones', points: 30, estimated_minutes: 10, verification: 'manual', target_url: '' },
  { title: 'Unirse a un canal de Telegram', description: 'Únete al canal oficial.', instructions: 'Abre el enlace y únete al canal.', category: 'social', points: 10, estimated_minutes: 1, verification: 'manual', target_url: 'https://telegram.org' },
];

const insertTask = db.prepare(
  `INSERT INTO tasks (title, description, instructions, category, points, estimated_minutes, verification, target_url, created_by)
   VALUES (@title, @description, @instructions, @category, @points, @estimated_minutes, @verification, @target_url, @created_by)`
);
for (const t of TASKS) {
  const exists = db.prepare('SELECT id FROM tasks WHERE title = ?').get(t.title);
  if (!exists) insertTask.run({ target_url: '', description: '', instructions: '', ...t, created_by: adminId });
}

const surveyTask = db.prepare('SELECT id FROM tasks WHERE title = ?').get('Completar encuesta de productos');
if (surveyTask && !db.prepare('SELECT id FROM surveys WHERE task_id = ?').get(surveyTask.id)) {
  db.prepare('INSERT INTO surveys (task_id, title, questions) VALUES (?, ?, ?)').run(
    surveyTask.id,
    'Encuesta de productos',
    JSON.stringify([
      { id: 'q1', type: 'single', text: '¿Con qué frecuencia compras en línea?', options: ['Nunca', 'Rara vez', 'A veces', 'Frecuentemente'], required: true },
      { id: 'q2', type: 'multiple', text: '¿Qué categorías te interesan?', options: ['Tecnología', 'Ropa', 'Comida', 'Deportes'], required: true },
      { id: 'q3', type: 'yesno', text: '¿Recomendarías tus marcas favoritas?', required: true },
      { id: 'q4', type: 'scale', text: '¿Qué tan satisfecho estás con tus compras recientes?', min: 1, max: 5, required: true },
      { id: 'q5', type: 'text', text: '¿Algo más que quieras contarnos? (opcional)', required: false },
    ])
  );
  console.log('[seed] encuesta creada para "Completar encuesta de productos"');
}

console.log('[seed] listo.');
