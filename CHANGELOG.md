# 更新日志

## [1.1.0] - 2025-11-18

### 🐛 Bug修复
- **修复URL双斜杠问题**: 修复了接口路径拼接时可能出现的双斜杠问题（如 `/v2//pet`）
  - 在 `swagger_parser.py` 中添加了 `_build_full_path()` 方法
  - 智能处理 basePath 和 path 的拼接，确保只有单个斜杠

### ✨ 新增功能
- **智能测试数据生成器**: 
  - 上传 Swagger 文件后自动为每个接口生成默认测试数据
  - 根据参数类型和名称智能推断合适的测试值
  - 支持通过"生成测试数据"按钮手动生成更多测试数据
  
### 🎯 智能数据生成规则
- **参数名称智能推断**:
  - `email` → `test@example.com`
  - `phone/mobile` → `13800138000`
  - `username` → `testuser`
  - `password/pwd` → `Test123456`
  - `url` → `https://example.com`
  - `date` → 当前日期 (`YYYY-MM-DD`)
  - `age` → `25`
  - `price/amount` → `99.99`
  - `id` → `1`
  - `page` → `1`
  - `size/limit` → `10`

- **参数类型智能生成**:
  - `integer/int` → 1-100随机整数
  - `number/float` → 1-100随机浮点数
  - `boolean` → `true`
  - `string` → 智能字符串或 `test_string`
  - `array` → 空数组或包含示例元素的数组
  - `object` → 根据 schema 递归生成

- **高级特性**:
  - 支持枚举值自动选择第一个值
  - 支持默认值使用
  - 支持嵌套对象和数组
  - 自动处理必填字段

### 📝 API变更
- **新增**: `POST /api/test-data/generate/{api_id}` - 为指定接口生成测试数据
- **修改**: `POST /api/swagger/upload` - 添加 `auto_generate_data` 参数（默认为 true）

### 🎨 UI改进
- 在测试数据卡片中添加"生成测试数据"按钮（绿色魔法棒图标）
- 支持为同一接口生成多组测试数据（命名为"生成的测试数据 #1", "#2"等）

### 📦 新增文件
- `backend/data_generator.py` - 测试数据生成器模块

---

## [1.0.0] - 2025-11-18

### 🎉 首次发布
- 完整的前后端分离架构
- Swagger v2 文件解析
- 接口管理（CRUD）
- 环境管理
- 测试数据管理
- 单个和批量接口执行
- 执行记录保存
- 现代化的 Web UI

