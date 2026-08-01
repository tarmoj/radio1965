-- Radio 1965 Events DB
-- Run against a MySQL/MariaDB server, e.g.:
--   mysql -u root -p < sql/schema.sql

CREATE DATABASE IF NOT EXISTS radio65 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'radio65'@'localhost' IDENTIFIED BY '__DB_PASSWORD__';
GRANT ALL PRIVILEGES ON radio65.* TO 'radio65'@'localhost';
FLUSH PRIVILEGES;

USE radio65;

CREATE TABLE IF NOT EXISTS events (
  id               VARCHAR(64) PRIMARY KEY,
  type             ENUM('text','audio','video','audiostream','videostream','article','webcontent') NOT NULL,
  title            VARCHAR(255) NOT NULL,
  summary          TEXT,
  url              VARCHAR(1024),
  publish_at       DATETIME NOT NULL,
  shelf_at         DATETIME NULL,
  status           ENUM('unpublished','current','shelfed','archived') NOT NULL DEFAULT 'unpublished',
  show             TINYINT(1) NOT NULL DEFAULT 1,
  comments_enabled TINYINT(1) NOT NULL DEFAULT 0,
  payload          JSON NULL,
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tags (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  event_id VARCHAR(64) NOT NULL,
  tag      VARCHAR(100) NOT NULL,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  UNIQUE KEY uq_event_tag (event_id, tag),
  INDEX idx_tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
