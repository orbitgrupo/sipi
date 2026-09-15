// Sipi — ledger inmutable de puntos.
//
// REGLAS DE ORO:
// 1. El saldo NUNCA se almacena como un campo editable: se deriva de SUM(points).
// 2. El cliente NUNCA envía montos: el servidor calcula todo.
// 3. Toda escritura al ledger ocurre dentro de una transacción del caso de uso
//    (aprobar tarea, canjear, reversar, bonus) para que sea atómica.

function getBalance(db, userId) {
  const row = db
    .prepare('SELECT COALESCE(SUM(points), 0) AS b FROM ledger WHERE user_id = ?')
    .get(userId);
  return row.b;
}

function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

/**
 * Agrega una entrada al ledger. Debe llamarse dentro de una transacción.
 * Lanza 400 INSUFFICIENT_POINTS si el saldo resultante sería negativo.
 */
function addEntry(db, { userId, type, points, referenceType, referenceId, note, createdBy }) {
  if (!Number.isInteger(points)) throw httpError(400, 'INVALID_POINTS');
  const balanceAfter = getBalance(db, userId) + points;
  if (balanceAfter < 0) throw httpError(400, 'INSUFFICIENT_POINTS');
  try {
    const info = db
      .prepare(
        `INSERT INTO ledger
           (user_id, type, points, balance_after, reference_type, reference_id, note, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        userId,
        type,
        points,
        balanceAfter,
        referenceType || null,
        referenceId == null ? null : referenceId,
        note || '',
        createdBy == null ? null : createdBy
      );
    return { id: info.lastInsertRowid, balance_after: balanceAfter };
  } catch (e) {
    // UNIQUE(reference_type, reference_id, type): idempotencia ante doble acreditación.
    if (e && /UNIQUE constraint failed/i.test(e.message || '')) {
      throw httpError(409, 'DUPLICATE_LEDGER_ENTRY');
    }
    throw e;
  }
}

function getMovements(db, userId, limit = 50) {
  return db
    .prepare(
      `SELECT id, type, points, balance_after, reference_type, reference_id, note, created_at
       FROM ledger WHERE user_id = ? ORDER BY id DESC LIMIT ?`
    )
    .all(userId, limit);
}

module.exports = { getBalance, addEntry, getMovements, httpError };
