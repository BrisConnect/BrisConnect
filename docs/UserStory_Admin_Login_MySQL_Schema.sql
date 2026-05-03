-- User Story: Admin secure login and protected admin access
-- MySQL 8+ schema focused on authentication + authorization controls.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE auth_users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  username VARCHAR(80) NULL,
  password_hash VARCHAR(255) NOT NULL,
  password_algo ENUM('bcrypt','argon2id') NOT NULL DEFAULT 'bcrypt',
  status ENUM('active','locked','disabled') NOT NULL DEFAULT 'active',
  failed_login_count INT UNSIGNED NOT NULL DEFAULT 0,
  locked_until DATETIME(3) NULL,
  last_login_at DATETIME(3) NULL,
  last_password_changed_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_auth_users_email (email),
  UNIQUE KEY uq_auth_users_username (username),
  KEY idx_auth_users_status (status)
) ENGINE=InnoDB;

CREATE TABLE roles (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_code VARCHAR(50) NOT NULL,
  display_name VARCHAR(80) NOT NULL,
  is_system_role TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_roles_role_code (role_code)
) ENGINE=InnoDB;

CREATE TABLE permissions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  permission_code VARCHAR(120) NOT NULL,
  description VARCHAR(255) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_permissions_code (permission_code)
) ENGINE=InnoDB;

CREATE TABLE user_roles (
  user_id BIGINT UNSIGNED NOT NULL,
  role_id SMALLINT UNSIGNED NOT NULL,
  assigned_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  assigned_by BIGINT UNSIGNED NULL,
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_user_roles_user
    FOREIGN KEY (user_id) REFERENCES auth_users(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_user_roles_role
    FOREIGN KEY (role_id) REFERENCES roles(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_user_roles_assigned_by
    FOREIGN KEY (assigned_by) REFERENCES auth_users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE role_permissions (
  role_id SMALLINT UNSIGNED NOT NULL,
  permission_id INT UNSIGNED NOT NULL,
  granted_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (role_id, permission_id),
  CONSTRAINT fk_role_permissions_role
    FOREIGN KEY (role_id) REFERENCES roles(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_role_permissions_permission
    FOREIGN KEY (permission_id) REFERENCES permissions(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE auth_sessions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  session_token_hash CHAR(64) NOT NULL,
  refresh_token_hash CHAR(64) NULL,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(512) NULL,
  is_revoked TINYINT(1) NOT NULL DEFAULT 0,
  issued_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at DATETIME(3) NOT NULL,
  revoked_at DATETIME(3) NULL,
  revoked_reason VARCHAR(120) NULL,
  last_seen_at DATETIME(3) NULL,
  CONSTRAINT fk_auth_sessions_user
    FOREIGN KEY (user_id) REFERENCES auth_users(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  UNIQUE KEY uq_auth_sessions_token_hash (session_token_hash),
  UNIQUE KEY uq_auth_sessions_refresh_hash (refresh_token_hash),
  KEY idx_auth_sessions_user_active (user_id, is_revoked, expires_at)
) ENGINE=InnoDB;

CREATE TABLE login_attempts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email_attempted VARCHAR(255) NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  was_successful TINYINT(1) NOT NULL,
  failure_reason ENUM('invalid_credentials','locked','disabled','unknown_user') NULL,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(512) NULL,
  attempted_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_login_attempts_user
    FOREIGN KEY (user_id) REFERENCES auth_users(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  KEY idx_login_attempts_email_time (email_attempted, attempted_at),
  KEY idx_login_attempts_success_time (was_successful, attempted_at)
) ENGINE=InnoDB;

CREATE TABLE route_policies (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  route_pattern VARCHAR(255) NOT NULL,
  permission_id INT UNSIGNED NOT NULL,
  http_method ENUM('GET','POST','PUT','PATCH','DELETE','*') NOT NULL DEFAULT '*',
  is_enabled TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_route_policies_permission
    FOREIGN KEY (permission_id) REFERENCES permissions(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE KEY uq_route_policy (route_pattern, permission_id, http_method),
  KEY idx_route_policies_enabled (is_enabled)
) ENGINE=InnoDB;

CREATE TABLE auth_audit_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  event_type ENUM(
    'login_success',
    'login_failure',
    'session_revoked',
    'role_denied',
    'role_granted',
    'password_changed'
  ) NOT NULL,
  route VARCHAR(255) NULL,
  ip_address VARCHAR(45) NULL,
  details_json JSON NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_auth_audit_user
    FOREIGN KEY (user_id) REFERENCES auth_users(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  KEY idx_auth_audit_user_time (user_id, created_at),
  KEY idx_auth_audit_event_time (event_type, created_at)
) ENGINE=InnoDB;

-- Baseline RBAC seed for admin-only access.
INSERT INTO roles (role_code, display_name, is_system_role)
VALUES ('admin', 'Administrator', 1), ('local_user', 'Local User', 1), ('visitor', 'Visitor', 1)
ON DUPLICATE KEY UPDATE display_name = VALUES(display_name);

INSERT INTO permissions (permission_code, description)
VALUES
('admin.dashboard.view', 'View admin dashboard'),
('admin.routes.access', 'Access admin-only routes')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.permission_code IN ('admin.dashboard.view', 'admin.routes.access')
WHERE r.role_code = 'admin'
ON DUPLICATE KEY UPDATE granted_at = CURRENT_TIMESTAMP(3);

-- Example route protection mapping.
INSERT INTO route_policies (route_pattern, permission_id, http_method, is_enabled)
SELECT '/admin/%', p.id, '*', 1
FROM permissions p
WHERE p.permission_code = 'admin.routes.access'
ON DUPLICATE KEY UPDATE is_enabled = VALUES(is_enabled);
