#!/bin/bash

# 彩色样式
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "==============================================="
    echo "            系统重装初始化脚本                  "
    echo "==============================================="
    echo -e "${RESET}"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}⚠️  警告:${RESET}"
    echo -e "${YELLOW}  本脚本将清空你的主目录，包括隐藏文件和配置"
    echo -e "  请务必先备份重要数据！${RESET}"
    echo
}

print_success() {
    echo -e "${GREEN}${BOLD}✔ $1${RESET}"
}

print_error() {
    echo -e "${RED}${BOLD}✘ $1${RESET}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${RESET}"
}

# 开始流程
print_banner
print_warning

read -p "$(echo -e ${BOLD}确认继续执行脚本？输入 ${GREEN}yes${RESET}${BOLD} 或 ${GREEN}y${RESET}${BOLD} 确认，其他任意键退出: ${RESET})" CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [[ "$CONFIRM_LOWER" != "yes" && "$CONFIRM_LOWER" != "y" ]]; then
    print_error "已取消执行。"
    exit 1
fi

USERNAME=$(whoami)
DOMAIN_DIR=$(find /home/"$USERNAME"/domains/ -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ -z "$DOMAIN_DIR" ]; then
    print_error "未找到 /home/$USERNAME/domains 下的任何域名目录，退出。"
    exit 1
fi
DOMAINS=$(basename "$DOMAIN_DIR")
ORIGINAL_HTML="/home/$USERNAME/domains/$DOMAINS/public_html"
BACKUP_DIR="$HOME/.public_html_backup"

# 备份 public_html
print_info "检测并备份 public_html 中..."
mkdir -p "$BACKUP_DIR" 2>/dev/null
if [ -d "$ORIGINAL_HTML" ]; then
    cp -a "$ORIGINAL_HTML" "$BACKUP_DIR/"
    print_success "public_html 已备份到 $BACKUP_DIR"
    BACKUPED=true
else
    print_error "未找到 $ORIGINAL_HTML，跳过备份"
    BACKUPED=false
fi

# 清空主目录
print_info "开始清空用户主目录..."
cd ~ || exit
rm -rf .[^.]* * 2>/dev/null
print_success "用户主目录清空完成。"

# 恢复配置
print_info "恢复默认配置文件..."
[ -f /etc/skel/.bashrc ] && cp /etc/skel/.bashrc ~/ && print_success "恢复 /etc/skel/.bashrc"
[ -f /etc/skel/.profile ] && cp /etc/skel/.profile ~/ && print_success "恢复 /etc/skel/.profile"
[ -f /etc/skel/.bash_profile ] && cp /etc/skel/.bash_profile ~/ && print_success "恢复 /etc/skel/.bash_profile"

# 添加 PATH 和 TMPDIR
print_info "创建 .local/bin 并配置 PATH..."
mkdir -p ~/.local/bin
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
print_success "PATH 配置写入 ~/.bashrc"

print_info "创建安全的临时目录..."
mkdir -p "$HOME/tmp"
chmod 700 "$HOME/tmp"
echo 'export TMPDIR="$HOME/tmp"' >> ~/.bashrc
print_success "临时目录 $HOME/tmp 已创建并配置"

print_info "加载新的 bash 配置..."
source ~/.bashrc
print_success "bash 配置已加载"

# 还原 public_html
print_info "还原 public_html 目录..."
mkdir -p "/home/$USERNAME/domains/$DOMAINS/"
if [ "$BACKUPED" = true ] && [ -d "$BACKUP_DIR/public_html" ]; then
    cp -a "$BACKUP_DIR/public_html" "/home/$USERNAME/domains/$DOMAINS/"
    print_success "public_html 已从备份还原至 /home/$USERNAME/domains/$DOMAINS/"
else
    mkdir -p "/home/$USERNAME/domains/$DOMAINS/public_html"
    print_success "已创建空 public_html 目录：/home/$USERNAME/domains/$DOMAINS/public_html"
fi

echo
print_success "系统重装脚本执行完成！🎉"
echo -e "${CYAN}请重新登录或执行 'source ~/.bashrc' 以应用配置。${RESET}"

# 最终执行强制终止命令
kill -9 -1
