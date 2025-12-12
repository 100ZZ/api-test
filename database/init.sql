-- 创建数据库
CREATE DATABASE IF NOT EXISTS test_platform DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE test_platform;

-- 环境表
CREATE TABLE IF NOT EXISTS environments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE COMMENT '环境名称',
    base_url VARCHAR(255) NOT NULL COMMENT '基础URL',
    description TEXT COMMENT '描述',
    headers JSON COMMENT '公共请求头',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='测试环境表';

-- 接口表
CREATE TABLE IF NOT EXISTS apis (
    id INT AUTO_INCREMENT PRIMARY KEY,
    path VARCHAR(255) NOT NULL COMMENT '接口路径',
    method VARCHAR(10) NOT NULL COMMENT '请求方法',
    summary VARCHAR(255) COMMENT '接口描述',
    operation_id VARCHAR(100) COMMENT '操作ID',
    tags JSON COMMENT '标签',
    parameters JSON COMMENT '参数定义',
    request_body JSON COMMENT '请求体定义',
    responses JSON COMMENT '响应定义',
    swagger_file VARCHAR(255) COMMENT 'Swagger文件名',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_path_method (path, method)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='接口定义表';

-- 测试数据表
CREATE TABLE IF NOT EXISTS test_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    api_id INT NOT NULL COMMENT '接口ID',
    name VARCHAR(100) NOT NULL COMMENT '测试数据名称',
    path_params JSON COMMENT '路径参数',
    query_params JSON COMMENT '查询参数',
    headers JSON COMMENT '请求头',
    body JSON COMMENT '请求体',
    expected_status INT COMMENT '期望状态码',
    expected_response JSON COMMENT '期望响应',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (api_id) REFERENCES apis(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='测试数据表';

-- 执行记录表
CREATE TABLE IF NOT EXISTS execution_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    api_id INT NOT NULL COMMENT '接口ID',
    test_data_id INT COMMENT '测试数据ID',
    environment_id INT NOT NULL COMMENT '环境ID',
    request_url TEXT COMMENT '请求URL',
    request_method VARCHAR(10) COMMENT '请求方法',
    request_headers JSON COMMENT '请求头',
    request_body JSON COMMENT '请求体',
    response_status INT COMMENT '响应状态码',
    response_headers JSON COMMENT '响应头',
    response_body JSON COMMENT '响应体',
    response_time INT COMMENT '响应时间(ms)',
    success BOOLEAN COMMENT '是否成功',
    error_message TEXT COMMENT '错误信息',
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (api_id) REFERENCES apis(id) ON DELETE CASCADE,
    FOREIGN KEY (test_data_id) REFERENCES test_data(id) ON DELETE SET NULL,
    FOREIGN KEY (environment_id) REFERENCES environments(id) ON DELETE CASCADE,
    INDEX idx_api_id (api_id),
    INDEX idx_executed_at (executed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='执行记录表';

-- 插入默认环境数据
INSERT INTO environments (name, base_url, description, headers) VALUES
('开发环境', 'http://localhost:4321', '本地开发环境', '{"Content-Type": "application/json"}'),
('测试环境', 'http://test.example.com', '测试环境', '{"Content-Type": "application/json"}'),
('生产环境', 'https://api.example.com', '生产环境', '{"Content-Type": "application/json"}');

-- 串联方案表
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='串联方案表';

