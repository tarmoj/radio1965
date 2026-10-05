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
CREATE TABLE IF NOT EXISTS users (
  id            VARCHAR(64) PRIMARY KEY,
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
  author_id        VARCHAR(64) NULL,
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
--   ALTER TABLE events ADD COLUMN author_id VARCHAR(64) NULL,
--     ADD FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL;
