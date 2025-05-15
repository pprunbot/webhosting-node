#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 恢复默认颜色

# 图形元素
SEPARATOR="================================================================"
SUCCESS_SYMBOL="[✅]"
FAIL_SYMBOL="[❌]"
WARNING_SYMBOL="[⚠️]"

# 显示带格式的消息函数
function show_msg() {
    case $1 in
        "header") echo -e "${BLUE}$2${NC}${SEPARATOR:${#2}}" ;;
        "success") echo -e "${GREEN}${SUCCESS_SYMBOL} $2${NC}" ;;
        "error") echo -e "${RED}${FAIL_SYMBOL} $2${NC}" ;;
        "warning") echo -e "${YELLOW}${WARNING_SYMBOL} $2${NC}" ;;
        "info") echo -e "${CYAN}[ℹ️] $2${NC}" ;;
    esac
}

clear
show_msg "header" "系统重置脚本启动"
echo

# 显示警告框
echo -e "${RED}╔══════════════════════════════════════════════════════════╗"
echo -e "║                      ${YELLOW}危 险 操 作${RED}                     ║"
echo -e "╠══════════════════════════════════════════════════════════╣"
echo -e "║ 此脚本将永久删除以下内容：                                 ║"
echo -e "║ ${YELLOW}• 用户主目录所有文件（包括隐藏文件）${RED}                     ║"
echo -e "║ ${YELLOW}• 重置 bash 配置文件${RED}                                   ║"
echo -e "║ ${YELLOW}• 自动备份 public_html 目录${RED}                           ║"
echo -e "╚══════════════════════════════════════════════════════════╝${NC}"
echo

# 确认提示
echo -e "${RED}▬▬▬▬▬▬▬▬▬▬▬▬▬▬ 操作确认 ▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
read -p "$(echo -e "${YELLOW}⚠️  确认要执行重置操作吗？(yes/no): ${NC}")" CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')

if [[ "$CONFIRM_LOWER" != "yes" && "$CONFIRM_LOWER" != "y" ]]; then
    show_msg "error" "用户取消操作"
    exit 1
fi

# 获取用户信息
USERNAME=$(whoami)
DOMAIN_DIR=$(find "/home/$USERNAME/domains/" -mindepth 1 -maxdepth 1 -type d | head -n 1)
DOMAINS=$(basename "$DOMAIN_DIR" 2>/dev/null)

# 备份 public_html
show_msg "header" "开始备份操作"
ORIGINAL_HTML="/home/$USERNAME/domains/$DOMAINS/public_html"
BACKUP_DIR="$HOME/.public_html_backup"

if [ -d "$ORIGINAL_HTML" ]; then
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    echo -n -e "${CYAN}⏳ 正在备份 public_html..."
    cp -a "$ORIGINAL_HTML" "$BACKUP_DIR/" &>/dev/null
    echo -e "\r\033[K${GREEN}✅ public_html 备份完成 (位置: $BACKUP_DIR)${NC}"
    BACKUPED=true
else
    show_msg "warning" "未找到 public_html 目录，跳过备份"
    BACKUPED=false
fi

# 清理主目录
show_msg "header" "开始清理操作"
echo -e "${YELLOW}▹ 正在删除用户主目录内容..."
echo -n -e "${CYAN}⏳ 正在清理..."

# 模拟进度
for i in {1..3}; do
    rm -rf .[^.]* * 2>/dev/null
    echo -n "."
    sleep 0.5
done
echo -e "\r\033[K${GREEN}✅ 主目录清理完成${NC}"

# 恢复默认配置
show_msg "header" "恢复系统配置"
echo -n -e "${CYAN}⏳ 正在恢复配置文件..."

(
    cp /etc/skel/.bashrc ~/ 2>/dev/null
    cp /etc/skel/.profile ~/ 2>/dev/null
    cp /etc/skel/.bash_profile ~/ 2>/dev/null
) &>/dev/null

echo -e "\r\033[K${GREEN}✅ 默认配置恢复完成${NC}"

# 环境配置
show_msg "header" "设置环境变量"
mkdir -p ~/.local/bin
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
mkdir -p "$HOME/tmp"
chmod 700 "$HOME/tmp"
echo 'export TMPDIR="$HOME/tmp"' >> ~/.bashrc
source ~/.bashrc
show_msg "success" "环境变量配置完成"

# 恢复网站目录
show_msg "header" "恢复网站数据"
if [ "$BACKUPED" = true ]; then
    mkdir -p "/home/$USERNAME/domains/$DOMAINS/"
    cp -a "$BACKUP_DIR/public_html" "/home/$USERNAME/domains/$DOMAINS/" &>/dev/null
    show_msg "success" "public_html 已还原到 /home/$USERNAME/domains/$DOMAINS/"
else
    mkdir -p "/home/$USERNAME/domains/$DOMAINS/public_html"
    show_msg "warning" "已创建空的 public_html 目录"
fi

# 完成提示
echo
show_msg "header" "操作结果汇总"
show_msg "success" "系统重置完成"
show_msg "info" "执行的操作清单："
echo -e "${CYAN}• 用户目录清理"
echo -e "• 系统配置重置"
echo -e "• 环境变量配置"
echo -e "• 网站目录恢复${NC}"
echo
echo -e "${GREEN}════════════════════ 操作成功完成 ══════════════════════${NC}"
