#!/bin/bash

echo "=========================================="
echo "  接口测试平台启动脚本"
echo "=========================================="

# 检查MySQL是否运行
echo "检查MySQL服务..."
if ! pgrep -x "mysqld" > /dev/null; then
    echo "❌ MySQL服务未运行，请先启动MySQL"
    exit 1
fi
echo "✅ MySQL服务运行中"

# 启动后端
echo ""
echo "启动后端服务..."
cd backend
if [ ! -d "venv" ]; then
    echo "创建Python虚拟环境..."
    python3 -m venv venv
fi

source venv/bin/activate
pip install -r requirements.txt > /dev/null 2>&1

echo "后端服务启动在 http://localhost:5555"
python main.py &
BACKEND_PID=$!

# 等待后端启动
sleep 3

# 启动前端
echo ""
echo "启动前端服务..."
cd ../frontend

if [ ! -d "node_modules" ]; then
    echo "安装前端依赖..."
    npm install
fi

echo "前端服务启动在 http://localhost:44321"
npm run dev &
FRONTEND_PID=$!

echo ""
echo "=========================================="
echo "  🎉 服务启动成功！"
echo "=========================================="
echo "  后端: http://localhost:5555"
echo "  前端: http://localhost:44321"
echo "  API文档: http://localhost:5555/docs"
echo "=========================================="
echo "  按 Ctrl+C 停止所有服务"
echo "=========================================="

# 等待用户中断
trap "kill $BACKEND_PID $FRONTEND_PID; exit" INT
wait

