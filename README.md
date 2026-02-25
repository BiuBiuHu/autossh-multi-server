# AutoSSH Multi-Server Tunnel Manager

[中文](#中文说明) | [English](#english)

---

## English

### Overview

A lightweight SSH tunnel management script with zero dependencies (except `autossh`). Features interactive setup wizard and simple config file management. Perfect for maintaining persistent port forwarding connections to multiple remote servers.

### Features

- 🚀 **Multi-Server Support**: Manage tunnels to multiple remote servers simultaneously
- 🔄 **Auto Reconnection**: Uses `autossh` to automatically reconnect on connection failure
- 📊 **Status Monitoring**: Check the status of all tunnels with a single command
- ⚙️ **Interactive Setup**: Friendly wizard for first-time configuration
- 📝 **Simple Config**: Easy-to-edit `.env` style configuration file
- 🔒 **Secure**: Uses SSH key-based authentication
- 🛠️ **Flexible Port Forwarding**: Support multiple port mappings per server
- 🪶 **Zero Dependencies**: No Python or other dependencies required

### Requirements

- `bash` 4.0+
- `autossh` (install via `brew install autossh` on macOS or `apt-get install autossh` on Linux)
- SSH access to remote servers with key-based authentication

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/autossh-multi-server.git
cd autossh-multi-server
```

2. Make the script executable:
```bash
chmod +x tunnel-lite.sh
```

3. Run the interactive setup:
```bash
./tunnel-lite.sh setup
```

4. (Optional) Create an alias in your shell config (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
echo "alias tunnel='$(pwd)/tunnel-lite.sh'" >> ~/.zshrc
source ~/.zshrc
```

### Configuration

First time? Run the setup wizard:
```bash
./tunnel-lite.sh setup
```

Example interaction:
```
===================================
  SSH 隧道配置向导
===================================

需要配置几条隧道? [1-9]: 2

配置隧道 #1
-----------------------------------
隧道名称 (如: server1): my-server
SSH 用户名 (默认: root):
SSH 主机地址 (如: 1.2.3.4): 101.47.158.134
SSH 私钥路径 (如: ~/.ssh/id_rsa): ~/.ssh/mykey.pem
监控端口 (如: 20100):
此隧道有几个端口转发? [1-5]: 2

  端口转发 #1:
    本地端口: 20128
    远程端口: 20128

  端口转发 #2:
    本地端口: 18788
    远程端口: 18789
...
```

Or manually edit `.env` file:
```bash
TUNNEL_COUNT=2

TUNNEL_0_NAME=my-server
TUNNEL_0_PEM=/Users/you/.ssh/mykey.pem
TUNNEL_0_HOST=root@101.47.158.134
TUNNEL_0_MONITOR=20129
TUNNEL_0_FORWARD_COUNT=2
TUNNEL_0_FORWARD_0_LOCAL=20128
TUNNEL_0_FORWARD_0_REMOTE=20128
TUNNEL_0_FORWARD_1_LOCAL=18788
TUNNEL_0_FORWARD_1_REMOTE=18789
```

### Usage

```bash
./tunnel-lite.sh setup    # Interactive configuration wizard
./tunnel-lite.sh start    # Start all tunnels
./tunnel-lite.sh stop     # Stop all tunnels
./tunnel-lite.sh status   # Check status of all tunnels
./tunnel-lite.sh restart  # Restart all tunnels
./tunnel-lite.sh edit     # Edit config file
```

If you created an alias:
```bash
tunnel setup
tunnel start
tunnel status
```

### Troubleshooting

**PEM file permissions:**
```bash
chmod 600 /path/to/your-key.pem
```

**Host key verification:**
```bash
ssh -i /path/to/your-key.pem user@host
# Type 'yes' to accept the host key
```

**Check logs:**
```bash
tail -f /tmp/autossh-tunnels/tunnel_*.log
```

**Auto-install missing dependencies:**
The script will detect missing `autossh` and offer to install it automatically on macOS (with Homebrew) and Linux (with apt-get/yum).

### License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 中文说明

### 概述

轻量级 SSH 隧道管理脚本，零依赖（仅需 `autossh`）。支持交互式配置向导和简单的配置文件管理。适合维护到多个远程服务器的持久端口转发连接。

### 特性

- 🚀 **多服务器支持**: 同时管理到多个远程服务器的隧道
- 🔄 **自动重连**: 使用 `autossh` 在连接失败时自动重连
- 📊 **状态监控**: 用一个命令检查所有隧道状态
- ⚙️ **交互式配置**: 友好的首次配置向导
- 📝 **简单配置**: 易于编辑的 `.env` 风格配置文件
- 🔒 **安全**: 使用基于 SSH 密钥的身份验证
- 🛠️ **灵活的端口转发**: 每个服务器支持多个端口映射
- 🪶 **零依赖**: 无需 Python 或其他依赖

### 系统要求

- `bash` 4.0+
- `autossh` (macOS 上通过 `brew install autossh` 安装，Linux 上通过 `apt-get install autossh` 安装)
- 使用密钥身份验证的 SSH 远程服务器访问权限

### 安装

1. 克隆此仓库:
```bash
git clone https://github.com/yourusername/autossh-multi-server.git
cd autossh-multi-server
```

2. 使脚本可执行:
```bash
chmod +x tunnel-lite.sh
```

3. 运行交互式配置:
```bash
./tunnel-lite.sh setup
```

4. (可选) 在 shell 配置文件中创建别名 (`~/.bashrc`, `~/.zshrc` 等):
```bash
echo "alias tunnel='$(pwd)/tunnel-lite.sh'" >> ~/.zshrc
source ~/.zshrc
```

### 配置

首次使用？运行配置向导：
```bash
./tunnel-lite.sh setup
```

或手动编辑 `.env` 文件：
```bash
TUNNEL_COUNT=2

TUNNEL_0_NAME=my-server
TUNNEL_0_PEM=/Users/you/.ssh/mykey.pem
TUNNEL_0_HOST=root@101.47.158.134
TUNNEL_0_MONITOR=20129
TUNNEL_0_FORWARD_COUNT=2
TUNNEL_0_FORWARD_0_LOCAL=20128
TUNNEL_0_FORWARD_0_REMOTE=20128
TUNNEL_0_FORWARD_1_LOCAL=18788
TUNNEL_0_FORWARD_1_REMOTE=18789
```

### 使用方法

```bash
./tunnel-lite.sh setup    # 交互式配置向导
./tunnel-lite.sh start    # 启动所有隧道
./tunnel-lite.sh stop     # 停止所有隧道
./tunnel-lite.sh status   # 检查所有隧道状态
./tunnel-lite.sh restart  # 重启所有隧道
./tunnel-lite.sh edit     # 编辑配置文件
```

如果创建了别名:
```bash
tunnel setup
tunnel start
tunnel status
```

### 故障排除

**PEM 文件权限:**
```bash
chmod 600 /path/to/your-key.pem
```

**主机密钥验证:**
```bash
ssh -i /path/to/your-key.pem user@host
# 输入 'yes' 接受主机密钥
```

**查看日志:**
```bash
tail -f /tmp/autossh-tunnels/tunnel_*.log
```

**自动安装缺失依赖:**
脚本会检测 `autossh` 是否安装，并提供自动安装选项（支持 macOS Homebrew 和 Linux apt-get/yum）。

### 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

### 贡献

欢迎提交 Issue 和 Pull Request！

### 作者

Created with ❤️ for the DevOps community
