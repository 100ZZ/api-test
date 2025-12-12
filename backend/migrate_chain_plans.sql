-- 创建串联方案表
CREATE TABLE IF NOT EXISTS chain_plans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    api_ids JSON NOT NULL,
    api_params JSON,
    api_assertions JSON,
    global_variables JSON,
    environment_id INT,
    stop_on_error BOOLEAN DEFAULT TRUE,
    delay_ms INT DEFAULT 500,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (environment_id) REFERENCES environments(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;