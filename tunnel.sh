#!/bin/bash
# AutoSSH Multi-Server Tunnel Manager
# https://github.com/yourusername/autossh-multi-server

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"
TEMP_DIR="/tmp/autossh-tunnels"

# Language detection (defaults to English)
LANG_CODE="${LANG:-en_US.UTF-8}"
if [[ "$LANG_CODE" == zh_* ]] || [[ "$LANG_CODE" == zh-* ]]; then
    LANGUAGE="zh"
else
    LANGUAGE="en"
fi

# Localized messages
declare -A MSG_EN=(
    [usage]="Usage: $0 {start|stop|status|restart}"
    [no_config]="Configuration file not found: $CONFIG_FILE"
    [no_autossh]="autossh is not installed. Please install it first:"
    [install_autossh_mac]="  macOS: brew install autossh"
    [install_autossh_linux]="  Linux: apt-get install autossh  or  yum install autossh"
    [starting]="Starting tunnel"
    [already_running]="already running, PID:"
    [started]="Started"
    [failed]="Failed to start, check log:"
    [stopped]="Stopped"
    [not_running]="not running"
    [status_title]="=== Tunnel Status ==="
    [status_running]="Status: Running (PID:"
    [status_stopped]="Status: Stopped"
    [port_forward]="Port forwarding:"
    [listening]="listening"
    [not_listening]="not listening"
)

declare -A MSG_ZH=(
    [usage]="用法: $0 {start|stop|status|restart}"
    [no_config]="未找到配置文件: $CONFIG_FILE"
    [no_autossh]="未安装 autossh，请先安装:"
    [install_autossh_mac]="  macOS: brew install autossh"
    [install_autossh_linux]="  Linux: apt-get install autossh  或  yum install autossh"
    [starting]="启动隧道"
    [already_running]="已在运行中，PID:"
    [started]="已启动"
    [failed]="启动失败，请检查日志:"
    [stopped]="已停止"
    [not_running]="未运行"
    [status_title]="=== 隧道状态 ==="
    [status_running]="状态: 运行中 (PID:"
    [status_stopped]="状态: 未运行"
    [port_forward]="端口转发:"
    [listening]="监听正常"
    [not_listening]="未监听"
)

# Get localized message
msg() {
    local key="$1"
    if [[ "$LANGUAGE" == "zh" ]]; then
        echo "${MSG_ZH[$key]}"
    else
        echo "${MSG_EN[$key]}"
    fi
}

# Check dependencies
check_dependencies() {
    if ! command -v autossh &> /dev/null; then
        echo "$(msg no_autossh)"
        echo "$(msg install_autossh_mac)"
        echo "$(msg install_autossh_linux)"
        exit 1
    fi
}

# Parse YAML config using Python
parse_config() {
    python3 - <<'EOF'
import yaml
import sys
import os

config_file = os.path.join(os.path.dirname(__file__), 'config.yml') if '__file__' in dir() else 'config.yml'
config_file = sys.argv[1] if len(sys.argv) > 1 else config_file

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)

    for i, tunnel in enumerate(config.get('tunnels', [])):
        print(f"TUNNEL_{i}_NAME={tunnel.get('name', f'Tunnel {i}')}")
        print(f"TUNNEL_{i}_PEM={tunnel['pem_file']}")
        print(f"TUNNEL_{i}_HOST={tunnel['ssh_host']}")
        print(f"TUNNEL_{i}_MONITOR={tunnel['monitor_port']}")

        forwards = tunnel.get('port_forwards', [])
        print(f"TUNNEL_{i}_FORWARD_COUNT={len(forwards)}")

        for j, fwd in enumerate(forwards):
            print(f"TUNNEL_{i}_FORWARD_{j}_LOCAL={fwd['local']}")
            print(f"TUNNEL_{i}_FORWARD_{j}_REMOTE={fwd['remote']}")

    print(f"TUNNEL_COUNT={len(config.get('tunnels', []))}")
except Exception as e:
    print(f"Error parsing config: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

# Initialize
init() {
    mkdir -p "$TEMP_DIR"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$(msg no_config)"
        echo "Please copy config.example.yml to config.yml and edit it."
        exit 1
    fi
}

# Start a single tunnel
start_tunnel() {
    local tunnel_id=$1
    local name=$(eval echo \$TUNNEL_${tunnel_id}_NAME)
    local pem=$(eval echo \$TUNNEL_${tunnel_id}_PEM)
    local host=$(eval echo \$TUNNEL_${tunnel_id}_HOST)
    local monitor=$(eval echo \$TUNNEL_${tunnel_id}_MONITOR)
    local forward_count=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_COUNT)

    local pid_file="${TEMP_DIR}/tunnel_${tunnel_id}.pid"
    local log_file="${TEMP_DIR}/tunnel_${tunnel_id}.log"

    if [[ -f "$pid_file" ]] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "$(msg starting) [$name] $(msg already_running) $(cat $pid_file)"
        return 0
    fi

    echo "$(msg starting) [$name] -> $host"

    # Build port forward arguments
    local forward_args=""
    for ((j=0; j<forward_count; j++)); do
        local local_port=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_${j}_LOCAL)
        local remote_port=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_${j}_REMOTE)
        forward_args="$forward_args -L ${local_port}:localhost:${remote_port}"
    done

    # Start autossh
    nohup autossh -M $monitor \
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
    pgrep -f "autossh.*${monitor}" > "$pid_file" || true

    if [[ -f "$pid_file" ]] && [[ -s "$pid_file" ]]; then
        echo "  ✓ $(msg started), PID: $(cat $pid_file)"
        for ((j=0; j<forward_count; j++)); do
            local local_port=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_${j}_LOCAL)
            local remote_port=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_${j}_REMOTE)
            echo "    localhost:$local_port -> $host:$remote_port"
        done
    else
        echo "  ✗ $(msg failed) $log_file"
    fi
}

# Stop a single tunnel
stop_tunnel() {
    local tunnel_id=$1
    local name=$(eval echo \$TUNNEL_${tunnel_id}_NAME)
    local pid_file="${TEMP_DIR}/tunnel_${tunnel_id}.pid"

    if [[ -f "$pid_file" ]]; then
        kill $(cat "$pid_file") 2>/dev/null || true
        rm -f "$pid_file"
        echo "$(msg stopped) [$name]"
    else
        echo "[$name] $(msg not_running)"
    fi
}

# Status of a single tunnel
status_tunnel() {
    local tunnel_id=$1
    local name=$(eval echo \$TUNNEL_${tunnel_id}_NAME)
    local host=$(eval echo \$TUNNEL_${tunnel_id}_HOST)
    local forward_count=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_COUNT)
    local pid_file="${TEMP_DIR}/tunnel_${tunnel_id}.pid"

    echo ""
    echo "[$name] -> $host:"

    if [[ -f "$pid_file" ]] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "  $(msg status_running) $(cat $pid_file))"
        echo "  $(msg port_forward)"

        for ((j=0; j<forward_count; j++)); do
            local local_port=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_${j}_LOCAL)
            local remote_port=$(eval echo \$TUNNEL_${tunnel_id}_FORWARD_${j}_REMOTE)

            if lsof -i :$local_port 2>/dev/null | grep LISTEN > /dev/null; then
                echo "    ✓ localhost:$local_port -> $remote_port ($(msg listening))"
            else
                echo "    ✗ localhost:$local_port -> $remote_port ($(msg not_listening))"
            fi
        done
    else
        echo "  $(msg status_stopped)"
        [[ -f "$pid_file" ]] && rm -f "$pid_file"
    fi
}

# Main commands
start_all() {
    eval $(parse_config "$CONFIG_FILE")
    local count=${TUNNEL_COUNT:-0}

    for ((i=0; i<count; i++)); do
        start_tunnel $i
    done
}

stop_all() {
    eval $(parse_config "$CONFIG_FILE")
    local count=${TUNNEL_COUNT:-0}

    for ((i=0; i<count; i++)); do
        stop_tunnel $i
    done
}

status_all() {
    eval $(parse_config "$CONFIG_FILE")
    local count=${TUNNEL_COUNT:-0}

    echo "$(msg status_title)"

    for ((i=0; i<count; i++)); do
        status_tunnel $i
    done
}

# Main
check_dependencies
init

case "${1:-}" in
    start)   start_all ;;
    stop)    stop_all ;;
    status)  status_all ;;
    restart) stop_all; sleep 2; start_all ;;
    *)       echo "$(msg usage)"; exit 1 ;;
esac
