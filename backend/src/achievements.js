// Sipi — motor de logros sobre PostgreSQL.
//
// Se ejecuta dentro de la misma transacción del caso de uso.
// Los bonus se registran como movimientos independientes del ledger.

const { addEntry } = require('./ledger');

const SCHEMA = 'sipi_dev';

async function metricValue(db, userId, metric) {
  let sql;

  switch (metric) {
    case 'tasks_completed':
      sql = `
        SELECT COUNT(*)::int AS value
        FROM ${SCHEMA}.task_completions
        WHERE user_id = $1
          AND status = 'approved'
      `;
      break;

    case 'points_earned':
      sql = `
        SELECT COALESCE(SUM(points), 0)::int AS value
        FROM ${SCHEMA}.ledger
        WHERE user_id = $1
          AND type IN ('EARN', 'BONUS')
      `;
      break;

    case 'surveys_completed':
      sql = `
        SELECT COUNT(*)::int AS value
        FROM ${SCHEMA}.survey_responses
        WHERE user_id = $1
      `;
      break;

    case 'redemptions':
      sql = `
        SELECT COUNT(*)::int AS value
        FROM ${SCHEMA}.redemptions
        WHERE user_id = $1
      `;
      break;

    default:
      return 0;
  }

  const result = await db.query(sql, [userId]);
  return result.rows[0].value;
}

async function checkAndAward(db, userId) {
  const achievementsResult = await db.query(
    `SELECT *
     FROM ${SCHEMA}.achievements
     ORDER BY id`
  );

  const earnedResult = await db.query(
    `SELECT achievement_id
     FROM ${SCHEMA}.user_achievements
     WHERE user_id = $1`,
    [userId]
  );

  const earned = new Set(
    earnedResult.rows.map((row) => row.achievement_id)
  );

  const newly = [];

  for (const achievement of achievementsResult.rows) {
    if (earned.has(achievement.id)) {
      continue;
    }

    const value = await metricValue(
      db,
      userId,
      achievement.metric
    );

    if (value < achievement.threshold) {
      continue;
    }

    const awardResult = await db.query(
      `INSERT INTO ${SCHEMA}.user_achievements
         (user_id, achievement_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, achievement_id) DO NOTHING
       RETURNING achievement_id`,
      [userId, achievement.id]
    );

    // Otro proceso pudo haber otorgado el logro primero.
    if (!awardResult.rowCount) {
      continue;
    }

    if (achievement.bonus_points > 0) {
      await addEntry(db, {
        userId,
        type: 'BONUS',
        points: achievement.bonus_points,
        referenceType: 'achievement',
        referenceId: achievement.id,
        note: `Logro desbloqueado: ${achievement.name}`,
        createdBy: null,
      });
    }

    await db.query(
      `INSERT INTO ${SCHEMA}.notifications
         (user_id, type, title, body)
       VALUES ($1, $2, $3, $4)`,
      [
        userId,
        'achievement',
        '¡Logro desbloqueado!',
        `${achievement.name}: +${achievement.bonus_points} pts`,
      ]
    );

    newly.push(achievement);
    earned.add(achievement.id);
  }

  return newly;
}

module.exports = {
  checkAndAward,
  metricValue,
};
