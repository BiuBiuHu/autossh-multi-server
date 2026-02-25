#!/usr/bin/env bash
# SSH 隧道管理脚本 (轻量版)
# 无需 Python，支持交互式配置和 .env 文件

set -eo pipefail

# ============================================
# 脚本配置
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.env"
TEMP_DIR="/tmp/autossh-tunnels"

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

OS=$(detect_os)

# ============================================
# 依赖检查
# ============================================

check_bash() {
    if [[ -z "${BASH_VERSION:-}" ]]; then
        echo "错误: 此脚本需要使用 bash 运行"
        exit 1
    fi
    local major="${BASH_VERSION%%.*}"
    if [[ $major -lt 4 ]]; then
        echo "错误: 需要 bash 4.0+，当前版本: $BASH_VERSION"
        exit 1
    fi
}

auto_install() {
    local dep="$1" cmd="$2"
    echo -n "是否自动安装 $dep? [y/N] "
    read -r -n 1 response 2>/dev/null || response="n"
    echo
    [[ "$response" =~ ^[Yy]$ ]] || return 1
    echo "正在安装 $dep..."
    if eval "$cmd" 2>&1; then
        echo "✓ 安装成功!"
        return 0
    else
        echo "✗ 安装失败，请手动安装"
        return 1
    fi
}

check_autossh() {
    command -v autossh &> /dev/null && return 0

    echo "✗ 未安装 autossh"
    if [[ "$OS" == "macos" ]]; then
        echo "  安装方法: brew install autossh"
        command -v brew &> /dev/null && auto_install "autossh" "brew install autossh" || exit 1
    elif command -v apt-get &> /dev/null; then
        echo "  安装方法: sudo apt-get install autossh"
        auto_install "autossh" "sudo apt-get update && sudo apt-get install -y autossh" || exit 1
    elif command -v yum &> /dev/null; then
        echo "  安装方法: sudo yum install autossh"
        auto_install "autossh" "sudo yum install -y autossh" || exit 1
    else
        exit 1
    fi
}

check_lsof() {
    command -v lsof &> /dev/null || echo "警告: 未安装 lsof，status 功能将受限"
}

check_dependencies() {
    echo "正在检查依赖..."
    check_bash
    check_autossh
    check_lsof
    mkdir -p "$TEMP_DIR"
    echo "✓ 依赖检查完成"
    echo
}

# ============================================
# 配置管理
# ============================================

# 解析 .env 文件（直接 source，简单可靠）
parse_env() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi

    # 直接加载 .env 文件中的变量
    set -a  # 自动导出所有变量
    source "$CONFIG_FILE"
    set +a

    # 验证必需变量
    if [[ -z "${TUNNEL_COUNT:-}" ]]; then
        TUNNEL_COUNT=0
    fi

    return 0
}

# 保存配置到 .env
save_config() {
    cat > "$CONFIG_FILE" <<EOF
# SSH 隧道配置文件
# 由 tunnel-lite.sh 生成，也可手动编辑

TUNNEL_COUNT=$TUNNEL_COUNT
EOF

    for ((i=0; i<TUNNEL_COUNT; i++)); do
        local name="TUNNEL_$i"
        local fw_count=$(eval echo \$TUNNEL_${i}_FORWARD_COUNT)

        cat >> "$CONFIG_FILE" <<EOF

TUNNEL_${i}_NAME=$(eval echo \$TUNNEL_${i}_NAME)
TUNNEL_${i}_PEM=$(eval echo \$TUNNEL_${i}_PEM)
TUNNEL_${i}_HOST=$(eval echo \$TUNNEL_${i}_HOST)
TUNNEL_${i}_MONITOR=$(eval echo \$TUNNEL_${i}_MONITOR)
TUNNEL_${i}_FORWARD_COUNT=$fw_count
EOF

        for ((j=0; j<fw_count; j++)); do
            cat >> "$CONFIG_FILE" <<EOF
TUNNEL_${i}_FORWARD_${j}_LOCAL=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_LOCAL)
TUNNEL_${i}_FORWARD_${j}_REMOTE=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_REMOTE)
EOF
        done
    done

    echo "✓ 配置已保存到: $CONFIG_FILE"
}

# 交互式配置向导
interactive_setup() {
    echo "==================================="
    echo "  SSH 隧道配置向导"
    echo "==================================="
    echo

    # 获取隧道数量
    while true; do
        echo -n "需要配置几条隧道? [1-9]: "
        read -r count
        if [[ "$count" =~ ^[1-9]$ ]]; then
            TUNNEL_COUNT=$count
            break
        fi
        echo "请输入 1-9 之间的数字"
    done
    echo

    # 配置每条隧道
    for ((i=0; i<TUNNEL_COUNT; i++)); do
        echo "-----------------------------------"
        echo "配置隧道 #$((i+1))"
        echo "-----------------------------------"

        echo -n "隧道名称 (如: server1): "
        read -r "TUNNEL_${i}_NAME"
        [[ -z "$(eval echo \$TUNNEL_${i}_NAME)" ]] && eval "TUNNEL_${i}_NAME='tunnel$((i+1))'"

        echo -n "SSH 用户名 (默认: root): "
        read -r ssh_user
        ssh_user="${ssh_user:-root}"

        echo -n "SSH 主机地址 (如: 1.2.3.4 或 example.com): "
        read -r ssh_host
        [[ -z "$ssh_host" ]] && { echo "主机地址不能为空"; exit 1; }
        eval "TUNNEL_${i}_HOST='${ssh_user}@${ssh_host}'"

        echo -n "SSH 私钥路径 (如: ~/.ssh/id_rsa): "
        read -r "TUNNEL_${i}_PEM"
        [[ -z "$(eval echo \$TUNNEL_${i}_PEM)" ]] && { echo "私钥路径不能为空"; exit 1; }
        # 扩展 ~
        local pem
        pem=$(eval echo \$TUNNEL_${i}_PEM)
        eval "TUNNEL_${i}_PEM='$pem'"

        echo -n "使用监控端口? (可能被服务器阻止，输入 n 禁用) [Y/n]: "
        read -r use_monitor
        if [[ "$use_monitor" =~ ^[Nn]$ ]]; then
            eval "TUNNEL_${i}_MONITOR=0"
            echo "  (已禁用监控端口，使用 SSH 心跳检测)"
        else
            echo -n "监控端口 (如: $((20100+i))): "
            read -r monitor
            eval "TUNNEL_${i}_MONITOR=\${monitor:-$((20100+i))}"
        fi

        # 端口转发
        while true; do
            echo -n "此隧道有几个端口转发? [1-5]: "
            read -r fw_count
            if [[ "$fw_count" =~ ^[1-5]$ ]]; then
                eval "TUNNEL_${i}_FORWARD_COUNT=$fw_count"
                break
            fi
        done

        for ((j=0; j<$(eval echo \$TUNNEL_${i}_FORWARD_COUNT); j++)); do
            echo
            echo "  端口转发 #$((j+1)):"
            echo -n "    本地端口: "
            read -r local_port
            echo -n "    远程端口: "
            read -r remote_port
            eval "TUNNEL_${i}_FORWARD_${j}_LOCAL=\${local_port}"
            eval "TUNNEL_${i}_FORWARD_${j}_REMOTE=\${remote_port}"
        done
        echo
    done

    save_config
    echo
    echo "配置完成！现在可以运行: $0 start"
}

# ============================================
# 隧道操作
# ============================================

start_tunnel() {
    local i=$1
    local name=$(eval echo \$TUNNEL_${i}_NAME)
    local pem=$(eval echo \$TUNNEL_${i}_PEM)
    local host=$(eval echo \$TUNNEL_${i}_HOST)
    local monitor=$(eval echo \$TUNNEL_${i}_MONITOR)
    local fw_count=$(eval echo \$TUNNEL_${i}_FORWARD_COUNT)

    local pid_file="${TEMP_DIR}/tunnel_${i}.pid"
    local log_file="${TEMP_DIR}/tunnel_${i}.log"

    # 检查是否已运行
    if [[ -f "$pid_file" ]] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "  [$name] 已在运行中，PID: $(cat $pid_file)"
        return 0
    fi

    # 检查私钥文件
    if [[ ! -f "$pem" ]]; then
        echo "  ✗ [$name] 私钥文件不存在: $pem"
        return 1
    fi

    echo "  启动 [$name] -> $host"

    # 构建端口转发参数
    local forward_args=""
    for ((j=0; j<fw_count; j++)); do
        local local_port=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_LOCAL)
        local remote_port=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_REMOTE)
        forward_args="$forward_args -L ${local_port}:localhost:${remote_port}"
    done

    # 启动 autossh
    # 如果监控端口为 0，使用 -M 0 禁用监控端口，改用 SSH 心跳检测
    local monitor_arg="$monitor"
    if [[ "$monitor" == "0" ]]; then
        monitor_arg="0"
    fi

    nohup autossh -M "$monitor_arg" \
        -i "$pem" \
        $forward_args \
        -N \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -o StrictHostKeyChecking=accept-new \
        "$host" \
        > "$log_file" 2>&1 &

    sleep 1
    # 对于 -M 0 模式，匹配进程的方式不同
    if [[ "$monitor" == "0" ]]; then
        pgrep -f "autossh.*-M 0.*${pem}" > "$pid_file" || true
    else
        pgrep -f "autossh.*${monitor}" > "$pid_file" || true
    fi

    if [[ -f "$pid_file" ]] && [[ -s "$pid_file" ]]; then
        echo "    ✓ 已启动，PID: $(cat $pid_file)"
        for ((j=0; j<fw_count; j++)); do
            local lp=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_LOCAL)
            local rp=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_REMOTE)
            echo "      localhost:$lp -> $host:$rp"
        done
    else
        echo "    ✗ 启动失败，查看日志: $log_file"
        return 1
    fi
}

stop_tunnel() {
    local i=$1
    local name=$(eval echo \$TUNNEL_${i}_NAME)
    local pid_file="${TEMP_DIR}/tunnel_${i}.pid"

    if [[ -f "$pid_file" ]]; then
        kill $(cat "$pid_file") 2>/dev/null || true
        rm -f "$pid_file"
        echo "  [$name] 已停止"
    else
        echo "  [$name] 未运行"
    fi
}

status_tunnel() {
    local i=$1
    local name=$(eval echo \$TUNNEL_${i}_NAME)
    local host=$(eval echo \$TUNNEL_${i}_HOST)
    local fw_count=$(eval echo \$TUNNEL_${i}_FORWARD_COUNT)
    local pid_file="${TEMP_DIR}/tunnel_${i}.pid"

    echo
    echo "[$name] -> $host:"

    if [[ -f "$pid_file" ]] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "  状态: 运行中 (PID: $(cat $pid_file))"
        echo "  端口转发:"

        for ((j=0; j<fw_count; j++)); do
            local lp=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_LOCAL)
            local rp=$(eval echo \$TUNNEL_${i}_FORWARD_${j}_REMOTE)

            if command -v lsof &> /dev/null && lsof -i :$lp 2>/dev/null | grep LISTEN > /dev/null; then
                echo "    ✓ localhost:$lp -> $rp (监听中)"
            else
                echo "    ✗ localhost:$lp -> $rp (未监听)"
            fi
        done
    else
        echo "  状态: 未运行"
        [[ -f "$pid_file" ]] && rm -f "$pid_file"
    fi
}

# ============================================
# 主命令
# ============================================

start_all() {
    parse_env || { echo "配置文件不存在，请先运行: $0 setup"; exit 1; }

    echo "启动所有隧道..."
    for ((i=0; i<TUNNEL_COUNT; i++)); do
        start_tunnel $i
    done
}

stop_all() {
    parse_env || { echo "配置文件不存在"; exit 1; }

    echo "停止所有隧道..."
    for ((i=0; i<TUNNEL_COUNT; i++)); do
        stop_tunnel $i
    done
}

status_all() {
    parse_env || { echo "配置文件不存在，请先运行: $0 setup"; exit 1; }

    echo "=== 隧道状态 ==="
    for ((i=0; i<TUNNEL_COUNT; i++)); do
        status_tunnel $i
    done
    echo
}

show_usage() {
    cat <<EOF
用法: $0 <command>

命令:
  setup    交互式配置向导（首次运行使用）
  start    启动所有隧道
  stop     停止所有隧道
  status   查看隧道状态
  restart  重启所有隧道
  edit     编辑配置文件

配置文件: $CONFIG_FILE
EOF
}

edit_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "配置文件不存在，请先运行: $0 setup"
        exit 1
    fi

    local editor="${EDITOR:-vi}"
    echo "使用 $editor 编辑配置文件..."
    "$editor" "$CONFIG_FILE"
}

# ============================================
# 主入口
# ============================================

check_dependencies

case "${1:-}" in
    setup)   interactive_setup ;;
    start)   start_all ;;
    stop)    stop_all ;;
    status)  status_all ;;
    restart) stop_all; sleep 2; start_all ;;
    edit)    edit_config ;;
    *)       show_usage ;;
esac
