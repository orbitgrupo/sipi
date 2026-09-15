// Sipi — motor de logros. Se evalúa después de cada evento que suma
// actividad (aprobar tarea, responder encuesta, crear canje).
// Debe llamarse DENTRO de la transacción del caso de uso.
const { addEntry } = require('./ledger');

function metricValue(db, userId, metric) {
  switch (metric) {
    case 'tasks_completed':
      return db
        .prepare("SELECT COUNT(*) AS c FROM task_completions WHERE user_id = ? AND status = 'approved'")
        .get(userId).c;
    case 'points_earned':
      return db
        .prepare("SELECT COALESCE(SUM(points),0) AS s FROM ledger WHERE user_id = ? AND type IN ('EARN','BONUS')")
        .get(userId).s;
    case 'surveys_completed':
      return db.prepare('SELECT COUNT(*) AS c FROM survey_responses WHERE user_id = ?').get(userId).c;
    case 'redemptions':
      return db.prepare('SELECT COUNT(*) AS c FROM redemptions WHERE user_id = ?').get(userId).c;
    default:
      return 0;
  }
}

function checkAndAward(db, userId) {
  const all = db.prepare('SELECT * FROM achievements').all();
  const earned = new Set(
    db.prepare('SELECT achievement_id FROM user_achievements WHERE user_id = ?').all(userId)
      .map((r) => r.achievement_id)
  );
  const newly = [];
  for (const a of all) {
    if (earned.has(a.id)) continue;
    if (metricValue(db, userId, a.metric) >= a.threshold) {
      db.prepare('INSERT INTO user_achievements (user_id, achievement_id) VALUES (?, ?)').run(userId, a.id);
      if (a.bonus_points > 0) {
        addEntry(db, {
          userId,
          type: 'BONUS',
          points: a.bonus_points,
          referenceType: 'achievement',
          referenceId: a.id,
          note: `Logro desbloqueado: ${a.name}`,
        });
      }
      db.prepare('INSERT INTO notifications (user_id, type, title, body) VALUES (?, ?, ?, ?)').run(
        userId, 'achievement', '¡Logro desbloqueado!', `${a.name}: +${a.bonus_points} pts`
      );
      newly.push(a);
    }
  }
  return newly;
}

module.exports = { checkAndAward, metricValue };
