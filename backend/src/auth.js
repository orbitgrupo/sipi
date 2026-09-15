// Sipi — autenticación: bcrypt + JWT.
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'sipi-dev-secret-change-me';
if (!process.env.JWT_SECRET) {
  console.warn('[sipi] JWT_SECRET no definido: usando secreto de desarrollo. Defínelo en producción.');
}

function hashPassword(password) {
  return bcrypt.hashSync(password, 10);
}

function verifyPassword(password, hash) {
  return bcrypt.compareSync(password, hash);
}

function signToken(user) {
  return jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
}

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'UNAUTHORIZED' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'INVALID_TOKEN' });
  }
}

// Crea el middleware requireAdmin ligado a una instancia de db (relee el rol).
function makeRequireAdmin(db) {
  return function requireAdmin(req, res, next) {
    const row = db.prepare('SELECT id, role, status FROM users WHERE id = ?').get(req.user.id);
    if (!row || row.status !== 'active') return res.status(401).json({ error: 'UNAUTHORIZED' });
    if (row.role !== 'admin') return res.status(403).json({ error: 'FORBIDDEN' });
    req.user.role = row.role;
    next();
  };
}

module.exports = { hashPassword, verifyPassword, signToken, requireAuth, makeRequireAdmin };
