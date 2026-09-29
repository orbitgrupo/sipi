// Sipi — autenticación mediante Supabase Auth.
//
// Supabase valida identidad y sesiones.
// Sipi mantiene autorización de negocio en sipi_dev.profiles.

const { supabaseAdmin } = require('./supabase');

const SCHEMA = 'sipi_dev';

function bearerToken(req) {
  const header = req.headers.authorization || '';

  if (!header.startsWith('Bearer ')) {
    return null;
  }

  return header.slice(7).trim() || null;
}

async function getSupabaseUser(token) {
  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(token);

  if (error || !user) {
    return null;
  }

  return user;
}

async function requireAuth(req, res, next) {
  const token = bearerToken(req);

  if (!token) {
    return res.status(401).json({ error: 'UNAUTHORIZED' });
  }

  try {
    const user = await getSupabaseUser(token);

    if (!user) {
      return res.status(401).json({ error: 'INVALID_TOKEN' });
    }

    req.user = {
      id: user.id,
      email: user.email,
    };

    req.accessToken = token;

    next();
  } catch (error) {
    next(error);
  }
}

async function maybeAuth(req, res, next) {
  const token = bearerToken(req);

  if (!token) {
    req.user = null;
    return next();
  }

  try {
    const user = await getSupabaseUser(token);

    req.user = user
      ? {
          id: user.id,
          email: user.email,
        }
      : null;

    if (user) {
      req.accessToken = token;
    }

    next();
  } catch {
    req.user = null;
    next();
  }
}

function makeRequireAdmin(db) {
  return async function requireAdmin(req, res, next) {
    try {
      if (!req.user?.id) {
        return res.status(401).json({ error: 'UNAUTHORIZED' });
      }

      const result = await db.query(
        `SELECT id, role, status, approved
           FROM ${SCHEMA}.profiles
          WHERE id = $1`,
        [req.user.id]
      );

      const profile = result.rows[0];

      if (
        !profile ||
        profile.status !== 'active' ||
        !profile.approved
      ) {
        return res.status(401).json({ error: 'UNAUTHORIZED' });
      }

      if (profile.role !== 'admin') {
        return res.status(403).json({ error: 'FORBIDDEN' });
      }

      req.user.role = profile.role;
      req.user.approved = profile.approved;

      next();
    } catch (error) {
      next(error);
    }
  };
}

module.exports = {
  requireAuth,
  maybeAuth,
  makeRequireAdmin,
};
