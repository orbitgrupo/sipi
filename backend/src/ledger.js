// Sipi — ledger inmutable de puntos sobre PostgreSQL.
//
// REGLAS DE ORO:
// 1. El saldo se deriva de SUM(points).
// 2. El cliente nunca determina montos.
// 3. Toda escritura ocurre dentro de una transacción.
// 4. Antes de modificar el ledger se bloquea el perfil del usuario
//    para serializar operaciones concurrentes.

const SCHEMA = 'sipi_dev';

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

async function getBalance(db, userId) {
  const result = await db.query(
    `SELECT COALESCE(SUM(points), 0)::int AS b
       FROM ${SCHEMA}.ledger
      WHERE user_id = $1`,
    [userId]
  );

  return result.rows[0].b;
}

/**
 * Bloquea el perfil durante la transacción actual.
 *
 * Esto evita que dos operaciones concurrentes del mismo usuario
 * calculen el saldo utilizando simultáneamente el mismo estado.
 */
async function lockUser(db, userId) {
  const result = await db.query(
    `SELECT id
       FROM ${SCHEMA}.profiles
      WHERE id = $1
      FOR UPDATE`,
    [userId]
  );

  if (result.rowCount === 0) {
    throw httpError(404, 'USER_NOT_FOUND');
  }
}

/**
 * Agrega una entrada al ledger.
 *
 * IMPORTANTE:
 * debe recibir un client de PostgreSQL que ya esté dentro de
 * BEGIN/COMMIT. No debe llamarse usando directamente el pool.
 */
async function addEntry(
  db,
  {
    userId,
    type,
    points,
    referenceType,
    referenceId,
    note,
    createdBy,
  }
) {
  if (!Number.isInteger(points) || points === 0) {
    throw httpError(400, 'INVALID_POINTS');
  }

  await lockUser(db, userId);

  const currentBalance = await getBalance(db, userId);
  const balanceAfter = currentBalance + points;

  if (balanceAfter < 0) {
    throw httpError(400, 'INSUFFICIENT_POINTS');
  }

  try {
    const result = await db.query(
      `INSERT INTO ${SCHEMA}.ledger
         (
           user_id,
           type,
           points,
           balance_after,
           reference_type,
           reference_id,
           note,
           created_by
         )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, balance_after`,
      [
        userId,
        type,
        points,
        balanceAfter,
        referenceType || null,
        referenceId == null ? null : referenceId,
        note || '',
        createdBy == null ? null : createdBy,
      ]
    );

    return result.rows[0];
  } catch (error) {
    // PostgreSQL 23505 = unique_violation.
    // Protege contra una acreditación duplicada.
    if (error && error.code === '23505') {
      throw httpError(409, 'DUPLICATE_LEDGER_ENTRY');
    }

    throw error;
  }
}

async function getMovements(db, userId, limit = 50) {
  const safeLimit = Math.min(
    Math.max(Number.parseInt(limit, 10) || 50, 1),
    100
  );

  const result = await db.query(
    `SELECT
       id,
       type,
       points,
       balance_after,
       reference_type,
       reference_id,
       note,
       created_at
     FROM ${SCHEMA}.ledger
     WHERE user_id = $1
     ORDER BY id DESC
     LIMIT $2`,
    [userId, safeLimit]
  );

  return result.rows;
}

module.exports = {
  getBalance,
  addEntry,
  getMovements,
  httpError,
};
