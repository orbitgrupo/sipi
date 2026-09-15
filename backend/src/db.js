// Sipi — capa de base de datos (SQLite integrado de Node vía node:sqlite).
const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const path = require('path');

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('user','admin')),
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  instructions TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'otras' CHECK(category IN ('social','encuestas','productos','opinion','promociones','otras')),
  points INTEGER NOT NULL CHECK(points > 0),
  estimated_minutes INTEGER NOT NULL DEFAULT 5,
  verification TEXT NOT NULL DEFAULT 'manual' CHECK(verification IN ('manual','auto')),
  requirements TEXT NOT NULL DEFAULT '',
  target_url TEXT NOT NULL DEFAULT '',
  max_completions_per_user INTEGER NOT NULL DEFAULT 1,
  active INTEGER NOT NULL DEFAULT 1,
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS task_completions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES tasks(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
  evidence TEXT NOT NULL DEFAULT '',
  submitted_at TEXT NOT NULL DEFAULT (datetime('now')),
  reviewed_at TEXT,
  reviewed_by INTEGER REFERENCES users(id)
);

-- Ledger inmutable: el saldo SIEMPRE se deriva de SUM(points).
-- No existen endpoints de UPDATE/DELETE sobre esta tabla.
CREATE TABLE IF NOT EXISTS ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  type TEXT NOT NULL CHECK(type IN ('EARN','REDEEM','ADJUSTMENT','REVERSAL','BONUS')),
  points INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  reference_type TEXT,
  reference_id INTEGER,
  note TEXT NOT NULL DEFAULT '',
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(reference_type, reference_id, type)
);

CREATE TABLE IF NOT EXISTS surveys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL UNIQUE REFERENCES tasks(id),
  title TEXT NOT NULL,
  questions TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS survey_responses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  survey_id INTEGER NOT NULL REFERENCES surveys(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  answers TEXT NOT NULL DEFAULT '{}',
  submitted_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(survey_id, user_id)
);

CREATE TABLE IF NOT EXISTS achievements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  metric TEXT NOT NULL CHECK(metric IN ('tasks_completed','points_earned','surveys_completed','redemptions')),
  threshold INTEGER NOT NULL,
  bonus_points INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_achievements (
  user_id INTEGER NOT NULL REFERENCES users(id),
  achievement_id INTEGER NOT NULL REFERENCES achievements(id),
  earned_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS redemptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  points INTEGER NOT NULL CHECK(points > 0),
  amount_usd REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','completed','rejected')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  processed_at TEXT
);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  is_read INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
`;

const DEFAULT_ACHIEVEMENTS = [
  { code: 'first_task', name: 'Primera tarea', description: 'Completa tu primera tarea', metric: 'tasks_completed', threshold: 1, bonus_points: 5 },
  { code: 'tasks_10', name: 'Racha de 10', description: 'Completa 10 tareas', metric: 'tasks_completed', threshold: 10, bonus_points: 25 },
  { code: 'points_100', name: '100 puntos', description: 'Acumula 100 puntos ganados', metric: 'points_earned', threshold: 100, bonus_points: 10 },
  { code: 'points_500', name: '500 puntos', description: 'Acumula 500 puntos ganados', metric: 'points_earned', threshold: 500, bonus_points: 50 },
  { code: 'first_survey', name: 'Encuestador', description: 'Completa tu primera encuesta', metric: 'surveys_completed', threshold: 1, bonus_points: 5 },
  { code: 'first_redeem', name: 'Primer canje', description: 'Canjea puntos por primera vez', metric: 'redemptions', threshold: 1, bonus_points: 5 },
];

function seed(db) {
  db.prepare(`INSERT OR IGNORE INTO config (key, value) VALUES ('points_per_usd', '50')`).run();
  const insert = db.prepare(
    `INSERT OR IGNORE INTO achievements (code, name, description, metric, threshold, bonus_points)
     VALUES (@code, @name, @description, @metric, @threshold, @bonus_points)`
  );
  for (const a of DEFAULT_ACHIEVEMENTS) insert.run(a);
}

function openDb(dbPath) {
  const resolved = dbPath || path.join(__dirname, '..', 'data', 'sipi.db');
  if (resolved !== ':memory:') {
    fs.mkdirSync(path.dirname(resolved), { recursive: true });
  }
  const db = new DatabaseSync(resolved);
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec(SCHEMA);
  seed(db);
  return db;
}

/** Transacción manual (node:sqlite no trae helper): BEGIN/COMMIT/ROLLBACK. */
function transaction(db, fn) {
  return (...args) => {
    db.exec('BEGIN');
    try {
      const result = fn(...args);
      db.exec('COMMIT');
      return result;
    } catch (e) {
      try { db.exec('ROLLBACK'); } catch { /* noop */ }
      throw e;
    }
  };
}

module.exports = { openDb, transaction };
