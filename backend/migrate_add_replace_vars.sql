-- 为 chain_plans 表添加替换变量字段
ALTER TABLE chain_plans 
ADD COLUMN IF NOT EXISTS replace_key VARCHAR(200) AFTER global_variables,
ADD COLUMN IF NOT EXISTS replace_value TEXT AFTER replace_key;

