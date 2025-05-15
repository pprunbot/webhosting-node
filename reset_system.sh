#!/bin/bash

# 初始化检查
check_prerequisites() {
    # 检查root权限
    if [[ $EUID -eq 0 ]]; then
        echo -e "\033[1;31m错误：本脚本不应以root权限执行\033[0m"
        exit 1
    fi

    # 检查终端支持
    if [[ -t 1 ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        NC='\033[0m'
        SEPARATOR="$(printf '%*s' $(tput cols) | tr ' ' '═')"
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
        SEPARATOR="================================================"
    fi
}

# 带时间戳的输出函数
log() {
    echo -e "[$(date +'%T')] $1"
}

# 增强版确认对话框
confirm_action() {
    local attempts=0
    while [[ $attempts -lt 2 ]]; do
        echo -en "${YELLOW}⚠️  请输入 'RESET' 确认操作 (剩余尝试次数 $((2 - attempts))): ${NC}"
        read -r CONFIRM_INPUT
        if [[ "$CONFIRM_INPUT" == "RESET" ]]; then
            return 0
        fi
        ((attempts++))
    done
    echo -e "${RED}错误：验证失败，终止操作${NC}"
    exit 1
}

# 安全备份函数
safe_backup() {
    local src=$1
    local dest=$2
    
    if [[ ! -d "$src" ]]; then
        log "${YELLOW}警告：源目录 $src 不存在${NC}"
        return 1
    fi

    mkdir -p "$dest" || {
        log "${RED}错误：无法创建备份目录 $dest${NC}"
        return 1
    }

    rsync -a --delete "$src/" "$dest/" && {
        log "${GREEN}备份成功：$src → $dest${NC}"
        return 0
    } || {
        log "${RED}错误：备份过程失败${NC}"
        return 1
    }
}

# 主执行流程
main() {
    check_prerequisites

    # 警告横幅
    echo -e "${RED}$SEPARATOR"
    echo "                ⚠️  危 险 操 作 警 告 ⚠️"
    echo "$SEPARATOR"
    echo -e "${YELLOW}此操作将："
    echo -e "• 永久删除所有用户数据"
    echo -e "• 重置系统配置到初始状态"
    echo -e "• 不可逆操作，请谨慎选择！${NC}"
    echo -e "${RED}$SEPARATOR${NC}"

    confirm_action

    # 初始化环境
    USERNAME=$(whoami)
    DOMAIN_ROOT="/home/$USERNAME/domains"
    
    # 自动检测域名目录
    DOMAIN_DIR=$(find "$DOMAIN_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)
    if [[ -z "$DOMAIN_DIR" ]]; then
        log "${YELLOW}警告：未找到域名目录，使用默认路径${NC}"
        DOMAIN_DIR="$DOMAIN_ROOT/example.com"
    fi
    DOMAINS=$(basename "$DOMAIN_DIR")

    # 备份流程
    log "${CYAN}正在执行安全备份...${NC}"
    BACKUP_DIR="$HOME/system_backup_$(date +%Y%m%d_%H%M%S)"
    safe_backup "$DOMAIN_DIR/public_html" "$BACKUP_DIR" || exit 1

    # 安全清理流程
    log "${YELLOW}开始系统清理...${NC}"
    {
        echo -e "${CYAN}安全删除用户文件...${NC}"
        find ~/ -mindepth 1 -maxdepth 1 -not -name 'domains' -exec rm -rf {} +
        
        echo -e "${CYAN}重置配置文件...${NC}"
        cp -f /etc/skel/.bashrc /etc/skel/.profile ~/
        
        echo -e "${CYAN}重建目录结构...${NC}"
        mkdir -p ~/{.local/bin,tmp,domains}
        chmod 700 ~/tmp
    } 2>&1 | while read -r line; do log "$line"; done

    # 恢复环境
    log "${CYAN}恢复基础配置...${NC}"
    {
        echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
        echo 'export TMPDIR="$HOME/tmp"' >> ~/.bashrc
        source ~/.bashrc
    }

    # 完成提示
    echo -e "${GREEN}$SEPARATOR"
    echo "                系 统 重 置 完 成"
    echo "$SEPARATOR"
    echo -e "${CYAN}操作报告："
    echo -e "• 备份位置: $BACKUP_DIR"
    echo -e "• 清理文件: ~/ (保留 domains 目录)"
    echo -e "• 配置恢复: /etc/skel 基础配置"
    echo -e "${GREEN}$SEPARATOR${NC}"
}

# 异常处理
trap 'echo -e "${RED}错误：用户中断操作${NC}"; exit 130' INT
main "$@"
