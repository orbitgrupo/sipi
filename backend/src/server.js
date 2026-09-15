// Sipi — arranque del servidor API.
const { openDb } = require('./db');
const { createApp } = require('./app');

const db = openDb(process.env.DB_PATH);
const app = createApp(db);
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`[sipi] API escuchando en http://localhost:${PORT}`);
});
