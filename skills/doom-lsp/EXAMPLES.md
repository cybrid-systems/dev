# Doom LSP 使用示例

## 精确位置导航工作流

### 示例 1：找到符号并跳转到定义

```bash
# 1. 找到符号的精确位置
doom-lsp goto-symbol src/main.py "calculate_total"
# 输出: "15:8" (第15行第8列)

# 2. 打开文件到该位置
doom-lsp open-file src/main.py 15 8

# 3. 跳转到该符号的定义
doom-lsp find-def src/main.py "calculate_total"
```

### 示例 2：完整的重构工作流

```bash
# 假设我们要重命名变量 'old_name' 为 'new_name'

# 1. 找到变量位置
doom-lsp goto-symbol src/utils.py "old_name"
# 输出: "42:12"

# 2. 重命名变量
doom-lsp rename src/utils.py 42 12 "new_name"

# 3. 查找所有引用，确认修改
doom-lsp find-ref src/utils.py "new_name"
```

### 示例 3：代码理解工作流

```bash
# 理解一个复杂函数

# 1. 打开函数定义
doom-lsp goto-symbol src/processor.py "process_data"
doom-lsp open-file src/processor.py 78 4

# 2. 查看函数调用的其他函数
doom-lsp find-def src/processor.py "helper_function"
doom-lsp find-def src/processor.py "validate_input"

# 3. 查看类型信息
doom-lsp hover src/processor.py 80 15
```

## 实际场景示例

### 场景 1：修复编译错误

```bash
# 假设编译报错：undefined reference to 'calculate_sum'

# 1. 找到这个函数
doom-lsp goto-symbol src/math.c "calculate_sum"

# 2. 如果找不到，可能在其他文件
doom-lsp find-ref src/  # 在所有文件中查找（需要扩展功能）

# 3. 查看函数定义
doom-lsp find-def include/math.h "calculate_sum"
```

### 场景 2：理解第三方库

```bash
# 理解一个不熟悉的库函数

# 1. 找到库函数调用
doom-lsp goto-symbol src/app.py "database.connect"

# 2. 跳转到库中的定义
doom-lsp find-def src/app.py "database.connect"
# 这会跳转到库的源码

# 3. 查看文档
doom-lsp hover /path/to/library/database.py 120 10
```

### 场景 3：批量代码审查

```bash
# 检查所有 Python 文件的类型注解

for file in *.py; do
  echo "=== Checking $file ==="
  
  # 打开文件，激活 LSP
  doom-lsp open-file "$file"
  
  # 检查诊断信息（简化版）
  doom-lsp diagnostics "$file" | grep -i "type\|annotation"
  
  # 查找特定模式
  doom-lsp goto-symbol "$file" "def.*->"
done
```

## 与 OpenClaw 集成的智能工作流

### 智能代码修复

```bash
# OpenClaw 可以自动：
# 1. 检测代码问题
doom-lsp diagnostics $PROBLEM_FILE

# 2. 分析问题原因
doom-lsp find-def $PROBLEM_FILE $PROBLEM_SYMBOL
doom-lsp find-ref $PROBLEM_FILE $PROBLEM_SYMBOL

# 3. 智能建议修复
# （需要 gptel 集成）
```

### 自动化重构

```bash
# 批量重命名所有 'temp' 变量为 'temporary'

# 1. 找到所有 'temp' 出现的位置
doom-lsp find-ref src/ "temp"

# 2. 对每个位置执行重命名
# （需要脚本包装）
```

### 代码文档生成

```bash
# 基于 LSP 信息生成文档

# 1. 获取函数签名
doom-lsp hover $FILE $LINE $COL

# 2. 获取函数定义
doom-lsp find-def $FILE $FUNCTION

# 3. 获取调用关系
doom-lsp find-ref $FILE $FUNCTION
```

## 高级技巧

### 1. 组合命令

```bash
# 一行命令完成：找到符号 -> 打开文件 -> 跳转到定义
POS=$(doom-lsp goto-symbol src/main.py "my_function")
doom-lsp open-file src/main.py ${POS%:*} ${POS#*:}
doom-lsp find-def src/main.py "my_function"
```

### 2. 错误处理

```bash
# 检查命令是否成功
if doom-lsp health-check | grep -q "ready"; then
  echo "LSP is ready"
else
  echo "LSP not available, starting..."
  emacs --daemon
  sleep 2
fi
```

### 3. 性能优化

```bash
# 批量操作时重用 Emacs 会话
doom-lsp open-file file1.py
doom-lsp find-def file1.py func1
doom-lsp open-file file2.py  # 重用同一个 Emacs 实例
```

## 故障排除示例

### 问题：符号找不到

```bash
# 1. 检查文件是否在项目中
doom-lsp open-file the_file.py

# 2. 检查 LSP 是否激活
doom-lsp health-check

# 3. 尝试不同的搜索策略
doom-lsp goto-symbol the_file.py "FunctionName"  # 精确匹配
doom-lsp goto-symbol the_file.py "functionname"  # 忽略大小写
```

### 问题：跳转失败

```bash
# 1. 检查语言服务器
doom-lsp health-check

# 2. 手动打开文件查看
doom-lsp open-file the_file.py 1 1

# 3. 检查文件编码和语法
file the_file.py
```

这些示例展示了如何充分利用 Doom LSP 的精确位置功能进行高效的代码导航和理解。