#!/bin/bash

# 前置接口功能部署脚本
# 作者: AI Assistant
# 日期: 2024-12-09

echo "=========================================="
echo "  前置接口功能部署脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$SCRIPT_DIR/backend"

# 步骤 1: 检查 Python 虚拟环境
echo -e "${BLUE}步骤 1: 检查 Python 虚拟环境...${NC}"
if [ ! -d "$BACKEND_DIR/venv" ]; then
    echo -e "${RED}❌ 未找到虚拟环境，请先创建虚拟环境${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 虚拟环境存在${NC}"
echo ""

# 步骤 2: 安装 Python 依赖
echo -e "${BLUE}步骤 2: 安装 Python 依赖...${NC}"
cd "$BACKEND_DIR"
source venv/bin/activate

if pip show jsonpath-ng > /dev/null 2>&1; then
    echo -e "${GREEN}✅ jsonpath-ng 已安装${NC}"
else
    echo "正在安装 jsonpath-ng..."
    pip install jsonpath-ng==1.6.1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ jsonpath-ng 安装成功${NC}"
    else
        echo -e "${RED}❌ jsonpath-ng 安装失败${NC}"
        exit 1
    fi
fi
echo ""

# 步骤 3: 检查 MySQL 连接
echo -e "${BLUE}步骤 3: 检查 MySQL 连接...${NC}"
if ! command -v mysql &> /dev/null; then
    echo -e "${RED}❌ 未找到 mysql 命令，请确保 MySQL 已安装${NC}"
    exit 1
fi
echo -e "${GREEN}✅ MySQL 命令可用${NC}"
echo ""

# 步骤 4: 执行数据库迁移
echo -e "${BLUE}步骤 4: 执行数据库迁移...${NC}"
echo -e "${YELLOW}请输入 MySQL root 密码：${NC}"

if [ -f "$BACKEND_DIR/migrate_add_pre_request.sql" ]; then
    mysql -u root -p apitest < "$BACKEND_DIR/migrate_add_pre_request.sql"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 数据库迁移成功${NC}"
    else
        echo -e "${RED}❌ 数据库迁移失败${NC}"
        echo -e "${YELLOW}提示: 如果字段已存在，可以忽略此错误${NC}"
    fi
else
    echo -e "${RED}❌ 未找到迁移脚本文件${NC}"
    exit 1
fi
echo ""

# 步骤 5: 验证数据库结构
echo -e "${BLUE}步骤 5: 验证数据库结构...${NC}"
echo "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'apitest' AND TABLE_NAME = 'test_data' AND COLUMN_NAME IN ('pre_request_api_id', 'pre_request_test_data_id', 'variable_extractions');" | mysql -u root -p apitest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 数据库结构验证完成${NC}"
else
    echo -e "${RED}❌ 数据库结构验证失败${NC}"
fi
echo ""

# 步骤 6: 提示信息
echo "=========================================="
echo -e "${GREEN}  🎉 部署完成！${NC}"
echo "=========================================="
echo ""
echo "接下来的步骤："
echo "1. 如果服务正在运行，请重启服务（Ctrl+C 停止，然后 sh start.sh）"
echo "2. 前端会自动热更新，无需重启"
echo "3. 打开浏览器访问 http://localhost:44321"
echo "4. 按照使用指南配置前置接口"
echo ""
echo "📚 文档："
echo "  - 部署指南: $SCRIPT_DIR/部署前置接口功能.md"
echo "  - 使用指南: $SCRIPT_DIR/前置接口功能使用指南.md"
echo "  - 快速开始: $SCRIPT_DIR/QUICKSTART-前置接口.md"
echo ""
echo "=========================================="
