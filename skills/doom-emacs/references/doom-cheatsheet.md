# Doom Emacs 快捷键速查表

## 🎯 核心概念

### Leader 键
- **SPC** (空格键): 主要 Leader 键
- **, (逗号)**: 次要 Leader 键（在某些模式下）
- **M-x**: 执行命令（Meta + x）

### 基本操作
- **C-g**: 取消当前操作
- **C-x C-c**: 保存并退出 Emacs
- **C-x C-s**: 保存当前文件
- **C-x C-f**: 打开文件
- **M-<**: 跳到文件开头
- **M->**: 跳到文件结尾

## 💻 代码开发（SPC c）

### LSP 集成
| 快捷键 | 功能 | 说明 |
|--------|------|------|
| `SPC c d` | 跳转到定义 | 查看函数/变量定义 |
| `SPC c D` | 查找引用 | 查看所有使用该符号的地方 |
| `SPC c a` | 代码动作 | LSP 提供的代码修复/重构建议 |
| `SPC c r` | 重命名符号 | 安全地重命名变量/函数 |
| `SPC c f` | 格式化代码 | 格式化当前文件或选中区域 |
| `SPC c e` | 列出错误 | 显示所有诊断信息 |
| `SPC c l` | LSP 菜单 | 打开 LSP 命令菜单 |
| `SPC c h` | 查看文档 | 悬停查看符号文档 |
| `SPC c i` | 查看实现 | 查看接口的实现 |
| `SPC c t` | 查看类型定义 | 查看类型定义 |

### 代码导航
| 快捷键 | 功能 |
|--------|------|
| `SPC c n` | 下一个错误 |
| `SPC c p` | 上一个错误 |
| `SPC c .` | 跳转到下一个位置 |
| `SPC c ,` | 跳转到上一个位置 |

## 📁 文件和项目（SPC f / SPC p）

### 文件操作
| 快捷键 | 功能 |
|--------|------|
| `SPC f f` | 查找文件（当前目录） |
| `SPC f r` | 最近打开的文件 |
| `SPC f s` | 保存当前文件 |
| `SPC f S` | 保存所有文件 |
| `SPC f y` | 复制文件路径 |
| `SPC f Y` | 复制文件绝对路径 |
| `SPC f e` | 打开配置文件 |
| `SPC f E` | 打开目录配置文件 |
| `SPC f d` | 删除文件 |
| `SPC f R` | 重命名文件 |
| `SPC f C` | 复制文件 |

### 项目操作
| 快捷键 | 功能 |
|--------|------|
| `SPC p p` | 切换项目 |
| `SPC p f` | 在项目中查找文件 |
| `SPC p s` | 在项目中搜索文本 |
| `SPC p t` | 打开项目终端 |
| `SPC p k` | 杀死项目缓冲区 |
| `SPC p h` | 查找项目文件 |
| `SPC p /` | 在项目中搜索 |

## 🔍 搜索和查找（SPC s）

### 文本搜索
| 快捷键 | 功能 |
|--------|------|
| `SPC s s` | 全文搜索（ripgrep） |
| `SPC s d` | 在当前目录搜索 |
| `SPC s p` | 在项目中搜索 |
| `SPC s /` | 搜索当前缓冲区 |
| `SPC s b` | 搜索打开的缓冲区 |
| `SPC s l` | 搜索当前行 |
| `SPC s w` | 搜索单词 |

### 符号和跳转
| 快捷键 | 功能 |
|--------|------|
| `SPC s i` | 跳转到符号（imenu） |
| `SPC s j` | 跳转到行 |
| `SPC s g` | 跳转到定义（全局） |
| `SPC s r` | 跳转到引用 |
| `SPC s S` | 多文件搜索 |

## 🪟 窗口和缓冲区（SPC w / SPC b）

### 窗口管理
| 快捷键 | 功能 |
|--------|------|
| `SPC w h` | 向左移动窗口 |
| `SPC w j` | 向下移动窗口 |
| `SPC w k` | 向上移动窗口 |
| `SPC w l` | 向右移动窗口 |
| `SPC w H` | 向左移动窗口位置 |
| `SPC w J` | 向下移动窗口位置 |
| `SPC w K` | 向上移动窗口位置 |
| `SPC w L` | 向右移动窗口位置 |
| `SPC w =` | 均衡窗口大小 |
| `SPC w d` | 删除窗口 |
| `SPC w o` | 最大化窗口（其他窗口） |
| `SPC w m` | 最大化窗口 |
| `SPC w u` | 恢复窗口布局 |
| `SPC w v` | 垂直分割窗口 |
| `SPC w s` | 水平分割窗口 |
| `SPC w w` | 切换窗口 |
| `SPC w W` | 选择窗口 |

### 缓冲区管理
| 快捷键 | 功能 |
|--------|------|
| `SPC b b` | 切换缓冲区 |
| `SPC b d` | 关闭缓冲区 |
| `SPC b k` | 杀死缓冲区 |
| `SPC b n` | 下一个缓冲区 |
| `SPC b p` | 上一个缓冲区 |
| `SPC b i` | 显示缓冲区信息 |
| `SPC b I` | ibuffer（缓冲区列表） |
| `SPC b r` | 恢复到之前缓冲区 |
| `SPC b R` | 重命名缓冲区 |
| `SPC b s` | 保存缓冲区 |
| `SPC b S` | 保存所有缓冲区 |
| `SPC b Y` | 复制缓冲区内容 |

## 🤖 GPTel AI 集成（本 Skill 增强）

### 基本操作
| 快捷键 | 功能 |
|--------|------|
| `M-x gptel` | 打开/切换 GPTel 聊天窗口 |
| `C-c <` | 发送选中区域给 AI |
| `C-c >` | 插入 AI 回答到缓冲区 |
| `C-c RET` | 发送消息 |
| `C-c C-k` | 结束会话 |
| `C-c C-c` | 取消当前请求 |

### 自定义快捷键（推荐配置）
```elisp
;; 在 ~/.doom.d/config.el 中添加
(map! :leader
      :prefix ("g" . "gptel")
      :desc "Open GPTel" "g" #'gptel
      :desc "Send region" "r" #'gptel-send-region
      :desc "Insert response" "i" #'gptel-insert-response
      :desc "Menu" "m" #'gptel-menu)
```

## 🆘 帮助系统（SPC h）

### 文档和帮助
| 快捷键 | 功能 |
|--------|------|
| `SPC h k` | 查看按键绑定 |
| `SPC h f` | 查看函数文档 |
| `SPC h v` | 查看变量文档 |
| `SPC h m` | 查看当前模式文档 |
| `SPC h d` | 搜索文档 |
| `SPC h i` | 查看 Info 手册 |
| `SPC h n` | 查看新闻 |
| `SPC h o` | 查看选项 |
| `SPC h p` | 查看包信息 |
| `SPC h r` | 查看 Emacs 手册 |
| `SPC h t` | 打开教程 |
| `SPC h w` | 查看哪里绑定了键 |

### 调试和诊断
| 快捷键 | 功能 |
|--------|------|
| `SPC h l` | 查看最近消息 |
| `SPC h L` | 查看日志 |
| `SPC h e` | 查看错误 |
| `SPC h E` | 查看 Emacs 错误 |
| `SPC h D` | 打开调试器 |

## ⚙️ 配置和自定义

### 配置文件位置
- `~/.doom.d/init.el`: 主配置文件
- `~/.doom.d/config.el`: 自定义配置
- `~/.doom.d/packages.el`: 包管理

### 常用配置命令
```elisp
;; 重新加载配置
M-x doom/reload

;; 同步包
M-x doom/sync

;; 升级 Doom
M-x doom/upgrade

;; 检查健康状态
M-x doom/doctor
```

## 🎯 实用工作流

### Redis 代码分析工作流
```elisp
;; 1. 打开 Redis 源码
SPC f f ~/code/redis/src/dict.c

;; 2. 跳转到 dictFind 函数
SPC c d on "dictFind"

;; 3. 查找所有引用
SPC c D on "dictFind"

;; 4. 查看函数调用关系
SPC s i  # 打开符号列表

;; 5. 使用 GPTel 分析复杂逻辑
M-x gptel
选中代码，C-c < 发送

;; 6. 重命名变量
SPC c r on "变量名"

;; 7. 格式化代码
SPC c f

;; 8. 保存所有文件
SPC f S
```

### 日常开发工作流
```elisp
;; 1. 打开项目
SPC p p 选择项目

;; 2. 查找文件
SPC p f 文件名

;; 3. 搜索文本
SPC s p 搜索词

;; 4. 跳转到定义
SPC c d 符号

;; 5. 查看引用
SPC c D 符号

;; 6. 运行测试
SPC c t  # 如果有测试集成

;; 7. 调试代码
SPC d d  # 开始调试
```

### 窗口管理技巧
```elisp
;; 高效的多窗口工作
SPC w v  # 垂直分割
SPC w s  # 水平分割
SPC w h/j/k/l  # 切换窗口
SPC w =  # 均衡大小
SPC w o  # 专注当前窗口

;; 快速切换布局
SPC w u  # 恢复布局
SPC TAB  # 切换布局
```

## 🚀 性能优化快捷键

### 快速导航
| 快捷键 | 功能 |
|--------|------|
| `SPC j j` | 快速跳转 |
| `SPC j l` | 跳转到行 |
| `SPC j i` | 跳转到符号 |
| `SPC j f` | 跳转到文件 |

### 代码片段
| 快捷键 | 功能 |
|--------|------|
| `SPC i s` | 插入代码片段 |
| `SPC i l` | 插入行 |
| `SPC i b` | 插入块 |

## 📚 学习资源

### 内置教程
- `SPC h t`: Emacs 教程
- `SPC h i g (emacs)`: Emacs 手册
- `SPC h i g (doom)`: Doom Emacs 手册

### 在线资源
- [Doom Emacs 文档](https://github.com/doomemacs/doomemacs)
- [Emacs 维基](https://www.emacswiki.org/)
- [Doom Emacs 社区](https://discord.gg/doomemacs)

### 练习建议
1. **第一天**: 掌握 `SPC f f`, `SPC b b`, `SPC w` 系列
2. **第二天**: 学习 `SPC c d`, `SPC c D`, `SPC s s`
3. **第三天**: 熟悉 `SPC p` 项目操作
4. **第四天**: 自定义配置和快捷键
5. **第五天**: 集成外部工具（LSP、GPTel 等）

## 💡 小贴士

1. **肌肉记忆**: 每天练习 10 分钟，一周内形成肌肉记忆
2. **渐进学习**: 不要一次性学习所有快捷键
3. **自定义**: 根据工作流自定义最常用的快捷键
4. **帮助系统**: 善用 `SPC h k` 查看按键绑定
5. **社区支持**: 遇到问题查看文档或询问社区

---

**最后更新**: 2026-04-18  
**适用于**: Doom Emacs + 本 Skill 集成环境  
**保持更新**: 定期运行 `M-x doom/upgrade` 获取最新功能