-- Radio 1965 Events DB
-- Run against a MySQL/MariaDB server, e.g.:
--  sudo mysql -u root -p < sql/schema.sql


-- NB! Replace __DB_PASSWORD__ with the actual password in the SQL commands below before running this script.

CREATE DATABASE IF NOT EXISTS radio65 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'radio65'@'localhost' IDENTIFIED BY '__DB_PASSWORD__';
GRANT ALL PRIVILEGES ON radio65.* TO 'radio65'@'localhost';
FLUSH PRIVILEGES;

USE radio65;

-- "Become a Contributor" accounts (project-description.md #10.2) - must
-- exist before `events` below, since events.author_id references it.
-- Plain auto-increment integer id (not Event's "evt_<ts>"-style string) -
-- easier to hand-edit/cross-reference directly in the DB.
CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(255) NOT NULL,
  email         VARCHAR(255) NOT NULL UNIQUE,
  role          ENUM('pending','contributor','manager','banned') NOT NULL DEFAULT 'pending',
  password_hash VARCHAR(255) NOT NULL,
  access_token  VARCHAR(64) NOT NULL UNIQUE,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS events (
  id               VARCHAR(64) PRIMARY KEY,
  type             ENUM('text','audio','video','audiostream','videostream','article','webcontent') NOT NULL,
  title            VARCHAR(255) NOT NULL,
  summary          TEXT,
  url              VARCHAR(1024),
  publish_at       DATETIME NOT NULL,
  shelf_at         DATETIME NULL,
  status           ENUM('unpublished','new','shelved','archived') NOT NULL DEFAULT 'unpublished',
  comments_enabled TINYINT(1) NOT NULL DEFAULT 0,
  payload          JSON NULL,
  -- Who posted this event - nullable, not yet populated by
  -- POST /events/publish (project-description.md #10.2/#10.3 - out of
  -- scope until the editor itself knows who's submitting).
  author_id        INT NULL,
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tags (
  event_id VARCHAR(64) NOT NULL,
  tag      VARCHAR(64) NOT NULL,
  PRIMARY KEY (event_id, tag),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  INDEX idx_tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- This file is a fresh-install bootstrap script, not applied incrementally
-- - an *existing* deployed DB (which already has `events` without
-- `author_id`, same situation as EVENT_TYPES growing over time) needs this
-- run by hand instead:
--   CREATE TABLE users (...);               -- the CREATE TABLE above
--   ALTER TABLE events ADD COLUMN author_id INT NULL,
--     ADD FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL;
--
-- If you already created `users` with the old VARCHAR(64) "usr_<ts>" id
-- (before it switched to a plain auto-increment INT) and only have
-- throwaway test rows in it so far (author_id is never populated yet, so
-- there's nothing real depending on the old id values): events.author_id's
-- FK has to be dropped first - MySQL refuses to touch users.id while
-- anything still references it, even if every value is NULL.
--   SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
--     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'events'
--       AND COLUMN_NAME = 'author_id' AND REFERENCED_TABLE_NAME = 'users';
--   ALTER TABLE events DROP FOREIGN KEY <name from the query above>;
--
-- Then either drop and recreate (simplest, loses existing rows):
--   DROP TABLE users;
--   CREATE TABLE users (...);               -- the CREATE TABLE above
-- ...or convert in place to keep existing rows:
--   ALTER TABLE users ADD COLUMN id_new INT AUTO_INCREMENT UNIQUE FIRST;
--   ALTER TABLE users DROP PRIMARY KEY, DROP COLUMN id,
--     CHANGE COLUMN id_new id INT AUTO_INCREMENT PRIMARY KEY;
--
-- Either way, finish by converting author_id to match and re-adding the FK:
--   ALTER TABLE events MODIFY COLUMN author_id INT NULL,
--     ADD FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL;
