-- 更新开发环境端口为4321
-- 如果数据库已经初始化，运行此脚本更新开发环境配置

USE test_platform;

UPDATE environments 
SET base_url = 'http://localhost:4321' 
WHERE name = '开发环境';

