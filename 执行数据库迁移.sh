#!/bin/bash

echo "=========================================="
echo "  执行数据库迁移"
echo "=========================================="
echo ""

# 切换到脚本所在目录
cd "$(dirname "$0")"

# 检查迁移脚本是否存在
if [ ! -f "backend/migrate_add_pre_request.sql" ]; then
    echo "❌ 错误: 找不到迁移脚本 backend/migrate_add_pre_request.sql"
    exit 1
fi

echo "正在执行数据库迁移..."
echo "请输入 MySQL root 密码:"
echo ""

# 执行迁移
mysql -u root -p apitest < backend/migrate_add_pre_request.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ 数据库迁移成功！"
    echo "=========================================="
    echo ""
    echo "验证迁移结果..."
    echo "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='apitest' AND TABLE_NAME='test_data' AND COLUMN_NAME IN ('pre_request_api_id', 'pre_request_test_data_id', 'variable_extractions');" | mysql -u root -p apitest
    echo ""
    echo "如果看到上面 3 个字段名，说明迁移成功！"
    echo ""
    echo "下一步："
    echo "1. 刷新浏览器 http://localhost:44321"
    echo "2. 选择任意接口，点击'添加测试数据'"
    echo "3. 应该看到'前置接口配置'区域"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "⚠️  迁移可能失败"
    echo "=========================================="
    echo ""
    echo "可能的原因："
    echo "1. 字段已存在（可以忽略）"
    echo "2. MySQL 密码错误"
    echo "3. 数据库不存在"
    echo ""
fi
