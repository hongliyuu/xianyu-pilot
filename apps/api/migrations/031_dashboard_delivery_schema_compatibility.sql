-- Migration 031: create the legacy xianyu_message compatibility projection.
-- It is still used by message-context code but was omitted from the initial
-- schema, causing dashboard and compatibility queries to fail on fresh installs.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `xianyu_message` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `account_id` BIGINT NULL,
  `conversation_id` BIGINT NULL,
  `session_id` VARCHAR(200) NULL,
  `from_user_id` VARCHAR(200) NULL,
  `to_user_id` VARCHAR(200) NULL,
  `content` TEXT NULL,
  `message_type` VARCHAR(50) NULL DEFAULT 'text',
  `direction` VARCHAR(20) NULL DEFAULT 'received',
  `is_auto_reply` SMALLINT NULL DEFAULT 0,
  `deleted` SMALLINT NULL DEFAULT 0,
  `created_time` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_xianyu_message_account_created` (`account_id`, `deleted`, `created_time`),
  KEY `idx_xianyu_message_auto_reply` (`is_auto_reply`, `deleted`, `created_time`),
  KEY `idx_xianyu_message_conversation` (`account_id`, `conversation_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Legacy message compatibility projection';
