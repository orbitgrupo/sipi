// Sipi — seed de tipos de tareas para PostgreSQL (Supabase).
// Crea una tarea por cada categoría (tipo) si no existe, más la encuesta de ejemplo.
// Uso (con las mismas variables de entorno que el backend):
//   npm run seed:pg
// Requiere: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD.
const db = require('./postgres');

const SCHEMA = process.env.DB_SCHEMA || 'sipi_dev';

const TASKS = [
  {
    title: 'Seguir una cuenta en Instagram',
    description: 'Sigue la cuenta indicada y mantén el seguimiento durante 7 días.',
    instructions: 'Sigue la cuenta indicada y no dejes de seguirla por 7 días.',
    category: 'social', points: 10, estimated_minutes: 2, verification: 'manual',
    target_url: 'https://instagram.com', social_network: 'instagram', social_action: 'follow',
  },
  {
    title: 'Síguenos en TikTok',
    description: 'Sigue nuestra cuenta oficial en TikTok y mantén el seguimiento.',
    instructions: 'Sigue la cuenta indicada y no dejes de seguirla.',
    category: 'social', points: 10, estimated_minutes: 2, verification: 'manual',
    target_url: '', social_network: 'tiktok', social_action: 'follow',
  },
  {
    title: 'Dale Me gusta a nuestra página de Facebook',
    description: 'Visita nuestra página de Facebook y dale Me gusta.',
    instructions: 'Visita la página indicada y dale Me gusta.',
    category: 'social', points: 5, estimated_minutes: 1, verification: 'manual',
    target_url: '', social_network: 'facebook', social_action: 'like',
  },
  {
    title: 'Comparte nuestro post en X',
    description: 'Comparte la publicación indicada en tu perfil de X.',
    instructions: 'Comparte la publicación indicada en tu perfil.',
    category: 'social', points: 10, estimated_minutes: 2, verification: 'manual',
    target_url: '', social_network: 'x', social_action: 'share',
  },
  {
    title: 'Comenta nuestra publicación en Instagram',
    description: 'Deja un comentario en la publicación indicada de Instagram.',
    instructions: 'Deja un comentario en la publicación indicada.',
    category: 'social', points: 10, estimated_minutes: 3, verification: 'manual',
    target_url: '', social_network: 'instagram', social_action: 'comment',
  },
  {
    title: 'Completar encuesta de productos',    description: 'Responde preguntas sobre productos que usas a diario.',
    instructions: 'Responde todas las preguntas con honestidad.',
    category: 'encuestas', points: 25, estimated_minutes: 5, verification: 'auto',
    target_url: '',
  },
  {
    title: 'Probar un producto nuevo',
    description: 'Prueba el producto indicado y cuenta tu experiencia.',
    instructions: 'Sigue las instrucciones del enlace y envía tu reseña.',
    category: 'productos', points: 20, estimated_minutes: 10, verification: 'manual',
    target_url: '',
  },
  {
    title: 'Opinión sobre bebidas deportivas',
    description: 'Cuéntanos tu opinión en 5 minutos.',
    instructions: 'Completa la encuesta de opinión.',
    category: 'opinion', points: 25, estimated_minutes: 5, verification: 'auto',
    target_url: '',
  },
  {
    title: 'Probar una app recomendada',
    description: 'Instala la app y úsala por 5 minutos.',
    instructions: 'Descarga la app desde el enlace y explórala.',
    category: 'promociones', points: 30, estimated_minutes: 10, verification: 'manual',
    target_url: '',
  },
  {
    title: 'Completa tu perfil de Sipi',
    description: 'Agrega tu nombre y foto para personalizar tu cuenta.',
    instructions: 'Ve a tu perfil y completa los datos que falten.',
    category: 'otras', points: 5, estimated_minutes: 2, verification: 'auto',
    target_url: '',
  },
];

const SURVEY_QUESTIONS = [
  { id: 'q1', type: 'single', text: '¿Con qué frecuencia compras en línea?', options: ['Nunca', 'Rara vez', 'A veces', 'Frecuentemente'], required: true },
  { id: 'q2', type: 'multiple', text: '¿Qué categorías te interesan?', options: ['Tecnología', 'Ropa', 'Comida', 'Deportes'], required: true },
  { id: 'q3', type: 'yesno', text: '¿Recomendarías tus marcas favoritas?', required: true },
  { id: 'q4', type: 'scale', text: '¿Qué tan satisfecho estás con tus compras recientes?', min: 1, max: 5, required: true },
  { id: 'q5', type: 'text', text: '¿Algo más que quieras contarnos? (opcional)', required: false },
];

async function main() {
  const admin = await db.query(
    `SELECT id FROM ${SCHEMA}.profiles WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1`
  );
  const createdBy = admin.rows[0]?.id || null;
  if (!createdBy) {
    console.warn('[seed:pg] No hay perfil administrador; las tareas se crearán sin creador.');
  }

  // Columna de imagen (por si el seed corre antes que el arranque del API).

  for (const t of TASKS) {
    const exists = await db.query(
      `SELECT id FROM ${SCHEMA}.tasks WHERE title = $1`,
      [t.title]
    );
    if (exists.rowCount > 0) {
      console.log(`[seed:pg] existe: ${t.title}`);
      continue;
    }
    await db.query(
      `INSERT INTO ${SCHEMA}.tasks
         (title, description, instructions, category, points, estimated_minutes,
          verification, target_url, social_network, social_action, created_by, active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,true)`,
      [
        t.title, t.description, t.instructions, t.category, t.points,
        t.estimated_minutes, t.verification, t.target_url || '',
        t.social_network || null, t.social_action || null, createdBy,
      ]
    );
    console.log(`[seed:pg] creada: ${t.title} (${t.category})`);
  }

  // Las tareas de redes sociales sin imagen usan el logo de su red.
  const publicBase = process.env.PUBLIC_BASE_URL || 'https://api-sipi-dev.catalina.my';
  for (const net of ['instagram', 'tiktok', 'facebook', 'x', 'youtube']) {
    await db.query(
      `UPDATE ${SCHEMA}.tasks SET image_url = $1 WHERE social_network = $2 AND (image_url IS NULL OR image_url = '')`,
      [`${publicBase}/public/task-icons/${net}.png`, net]
    );
  }

  const surveyTask = await db.query(
    `SELECT id FROM ${SCHEMA}.tasks WHERE title = 'Completar encuesta de productos'`
  );
  if (surveyTask.rowCount > 0) {
    await db.query(
      `INSERT INTO ${SCHEMA}.surveys (task_id, title, questions)
       VALUES ($1, $2, $3::jsonb)
       ON CONFLICT (task_id) DO NOTHING`,
      [surveyTask.rows[0].id, 'Encuesta de productos', JSON.stringify(SURVEY_QUESTIONS)]
    );
    console.log('[seed:pg] encuesta verificada para "Completar encuesta de productos"');
  }

  console.log('[seed:pg] listo.');
  await db.close();
}

main().catch((err) => {
  console.error('[seed:pg] error:', err.message);
  process.exit(1);
});
