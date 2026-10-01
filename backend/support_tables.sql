-- Sipi — tablas de soporte (preguntas, quejas y chat con usuarios).
-- SOLO si el panel muestra "Error: INTERNAL_ERROR" en la página Soporte:
-- pega este script en el SQL Editor de Supabase y ejecútalo una vez.
-- (El backend intenta crear estas tablas solo al arrancar; si el rol de
-- la API no tiene permiso CREATE, este script manual lo resuelve.)

CREATE TABLE IF NOT EXISTS sipi_dev.support_threads (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  subject TEXT NOT NULL DEFAULT '',
  kind TEXT NOT NULL DEFAULT 'pregunta',
  status TEXT NOT NULL DEFAULT 'open',
  unread_admin BOOLEAN NOT NULL DEFAULT TRUE,
  unread_user BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sipi_dev.support_messages (
  id BIGSERIAL PRIMARY KEY,
  thread_id BIGINT NOT NULL REFERENCES sipi_dev.support_threads(id) ON DELETE CASCADE,
  sender TEXT NOT NULL,
  sender_name TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_threads_user ON sipi_dev.support_threads(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_thread ON sipi_dev.support_messages(thread_id);

-- Por si las tablas ya existían sin la columna sender_name:
ALTER TABLE sipi_dev.support_messages ADD COLUMN IF NOT EXISTS sender_name TEXT NOT NULL DEFAULT '';
