-- 为 test_data 表添加前置接口配置字段

-- 添加前置接口 API ID 字段
ALTER TABLE test_data ADD COLUMN pre_request_api_id INTEGER;

-- 添加前置接口测试数据 ID 字段
ALTER TABLE test_data ADD COLUMN pre_request_test_data_id INTEGER;

-- 添加变量提取规则字段
ALTER TABLE test_data ADD COLUMN variable_extractions JSON;

-- 添加外键约束
ALTER TABLE test_data 
ADD CONSTRAINT fk_pre_request_api 
FOREIGN KEY (pre_request_api_id) 
REFERENCES apis(id) 
ON DELETE SET NULL;

ALTER TABLE test_data 
ADD CONSTRAINT fk_pre_request_test_data 
FOREIGN KEY (pre_request_test_data_id) 
REFERENCES test_data(id) 
ON DELETE SET NULL;

-- 添加索引以提高查询性能
CREATE INDEX idx_test_data_pre_request_api_id ON test_data(pre_request_api_id);
CREATE INDEX idx_test_data_pre_request_test_data_id ON test_data(pre_request_test_data_id);
