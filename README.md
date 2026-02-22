# AutoSSH Multi-Server Tunnel Manager

[中文](#中文说明) | [English](#english)

---

## English

### Overview

A robust SSH tunnel management script that supports multiple servers with automatic reconnection using `autossh`. Perfect for maintaining persistent port forwarding connections to multiple remote servers.

### Features

- 🚀 **Multi-Server Support**: Manage tunnels to multiple remote servers simultaneously
- 🔄 **Auto Reconnection**: Uses `autossh` to automatically reconnect on connection failure
- 📊 **Status Monitoring**: Check the status of all tunnels with a single command
- ⚙️ **Easy Configuration**: Simple YAML configuration file
- 🔒 **Secure**: Uses SSH key-based authentication
- 🛠️ **Flexible Port Forwarding**: Support multiple port mappings per server

### Requirements

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
chmod +x tunnel.sh
```

3. Copy the example configuration and edit it:
```bash
cp config.example.yml config.yml
vim config.yml
```

4. (Optional) Create an alias in your shell config (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
echo "alias tunnelmgr='$(pwd)/tunnel.sh'" >> ~/.zshrc
source ~/.zshrc
```

### Configuration

Edit `config.yml` to define your tunnels:

```yaml
tunnels:
  - name: "Server 1"
    pem_file: "/path/to/key1.pem"
    ssh_host: "root@192.168.1.100"
    monitor_port: 20129
    port_forwards:
      - local: 20128
        remote: 20128
      - local: 18788
        remote: 18789

  - name: "Server 2"
    pem_file: "/path/to/key2.pem"
    ssh_host: "root@192.168.1.101"
    monitor_port: 20130
    port_forwards:
      - local: 18787
        remote: 18789
```

### Usage

```bash
./tunnel.sh start    # Start all tunnels
./tunnel.sh stop     # Stop all tunnels
./tunnel.sh status   # Check status of all tunnels
./tunnel.sh restart  # Restart all tunnels
```

If you created an alias:
```bash
tunnelmgr start
tunnelmgr status
```

### Troubleshooting

**Permission denied for PEM file:**
```bash
chmod 600 /path/to/your-key.pem
```

**Host key verification failed:**
```bash
ssh -i /path/to/your-key.pem user@host
# Type 'yes' to accept the host key
```

**Check logs:**
```bash
tail -f /tmp/tunnel-*.log
```

### License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 中文说明

### 概述

一个强大的 SSH 隧道管理脚本，支持多服务器并使用 `autossh` 实现自动重连。适合维护到多个远程服务器的持久端口转发连接。

### 特性

- 🚀 **多服务器支持**: 同时管理到多个远程服务器的隧道
- 🔄 **自动重连**: 使用 `autossh` 在连接失败时自动重连
- 📊 **状态监控**: 用一个命令检查所有隧道状态
- ⚙️ **简单配置**: 简单的 YAML 配置文件
- 🔒 **安全**: 使用基于 SSH 密钥的身份验证
- 🛠️ **灵活的端口转发**: 每个服务器支持多个端口映射

### 系统要求

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
chmod +x tunnel.sh
```

3. 复制示例配置并编辑:
```bash
cp config.example.yml config.yml
vim config.yml
```

4. (可选) 在 shell 配置文件中创建别名 (`~/.bashrc`, `~/.zshrc` 等):
```bash
echo "alias tunnelmgr='$(pwd)/tunnel.sh'" >> ~/.zshrc
source ~/.zshrc
```

### 配置

编辑 `config.yml` 来定义你的隧道:

```yaml
tunnels:
  - name: "服务器 1"
    pem_file: "/path/to/key1.pem"
    ssh_host: "root@192.168.1.100"
    monitor_port: 20129
    port_forwards:
      - local: 20128
        remote: 20128
      - local: 18788
        remote: 18789

  - name: "服务器 2"
    pem_file: "/path/to/key2.pem"
    ssh_host: "root@192.168.1.101"
    monitor_port: 20130
    port_forwards:
      - local: 18787
        remote: 18789
```

### 使用方法

```bash
./tunnel.sh start    # 启动所有隧道
./tunnel.sh stop     # 停止所有隧道
./tunnel.sh status   # 检查所有隧道状态
./tunnel.sh restart  # 重启所有隧道
```

如果创建了别名:
```bash
tunnelmgr start
tunnelmgr status
```

### 故障排除

**PEM 文件权限被拒绝:**
```bash
chmod 600 /path/to/your-key.pem
```

**主机密钥验证失败:**
```bash
ssh -i /path/to/your-key.pem user@host
# 输入 'yes' 接受主机密钥
```

**查看日志:**
```bash
tail -f /tmp/tunnel-*.log
```

### 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

### 贡献

欢迎提交 Issue 和 Pull Request！

### 作者

Created with ❤️ for the DevOps community
