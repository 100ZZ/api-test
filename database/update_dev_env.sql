-- 更新开发环境配置为 192.168.60.219:48080
-- 运行此脚本更新开发环境的 base_url

USE test_platform;

UPDATE environments 
SET base_url = 'http://192.168.60.219:48080',
    description = '远程开发环境'
WHERE name = '开发环境';

-- 验证更新结果
SELECT id, name, base_url, description FROM environments WHERE name = '开发环境';

