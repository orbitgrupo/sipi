// Sipi — arranque del servidor API sobre PostgreSQL.

require('dotenv').config();

const db = require('./postgres');
const { createApp } = require('./app.postgres');

const app = createApp(db);
const PORT = Number(process.env.PORT) || 3000;

const server = app.listen(PORT, () => {
  console.log(`[sipi] API escuchando en http://localhost:${PORT}`);
});

async function shutdown(signal) {
  console.log(`[sipi] ${signal}: cerrando servidor...`);

  server.close(async () => {
    try {
      await db.close();
      process.exit(0);
    } catch (error) {
      console.error('[sipi] Error cerrando PostgreSQL:', error.message);
      process.exit(1);
    }
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
