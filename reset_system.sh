#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${RED}${BOLD}⚠️ 警告！该脚本将会清空你的用户主目录（包括隐藏文件），并重置部分配置！${RESET}"
echo -e "${YELLOW}请确保你已经备份重要数据。${RESET}"
read -p "$(echo -e ${CYAN}确认继续执行脚本？输入 ${BOLD}yes${RESET}${CYAN} 或 ${BOLD}y${RESET}${CYAN} 确认，其他任意键退出: ${RESET})" CONFIRM

CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [[ "$CONFIRM_LOWER" != "yes" && "$CONFIRM_LOWER" != "y" ]]; then
    echo -e "${RED}已取消执行。${RESET}"
    exit 1
fi

echo -e "${GREEN}开始执行脚本...${RESET}"

USERNAME=$(whoami)
DOMAIN_DIR=$(find /home/"$USERNAME"/domains/ -mindepth 1 -maxdepth 1 -type d | head -n 1)
DOMAINS=$(basename "$DOMAIN_DIR")

ORIGINAL_HTML="/home/$USERNAME/domains/$DOMAINS/public_html"
BACKUP_DIR="$HOME/.public_html_backup"

if [ -d "$ORIGINAL_HTML" ]; then
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    cp -a "$ORIGINAL_HTML" "$BACKUP_DIR/"
    BACKUPED=true
    echo -e "${GREEN}✔️ 找到 public_html 并完成备份：$BACKUP_DIR${RESET}"
else
    echo -e "${YELLOW}⚠️ 未找到 $ORIGINAL_HTML，跳过备份。${RESET}"
    BACKUPED=false
fi

echo -e "${CYAN}正在清空用户主目录（包括隐藏文件）...${RESET}"
cd ~ || { echo -e "${RED}❌ 进入主目录失败，退出！${RESET}"; exit 1; }
rm -rf .[^.]* * 2>/dev/null

echo -e "${CYAN}恢复 /etc/skel 默认配置...${RESET}"
if [ -f /etc/skel/.bashrc ]; then
    cp /etc/skel/.bashrc ~/
    echo -e "${GREEN}✔️ 恢复 .bashrc${RESET}"
else
    echo -e "${YELLOW}⚠️ /etc/skel/.bashrc 不存在，跳过恢复。${RESET}"
fi

if [ -f /etc/skel/.profile ]; then
    cp /etc/skel/.profile ~/
    echo -e "${GREEN}✔️ 恢复 .profile${RESET}"
elif [ -f /etc/skel/.bash_profile ]; then
    cp /etc/skel/.bash_profile ~/
    echo -e "${GREEN}✔️ 恢复 .bash_profile${RESET}"
else
    echo -e "${YELLOW}⚠️ /etc/skel/.profile 和 .bash_profile 都不存在，跳过恢复。${RESET}"
fi

echo -e "${CYAN}创建本地 bin 目录并更新 PATH...${RESET}"
mkdir -p ~/.local/bin
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc

echo -e "${CYAN}初始化临时目录...${RESET}"
mkdir -p "$HOME/tmp"
chmod 700 "$HOME/tmp"
echo 'export TMPDIR="$HOME/tmp"' >> ~/.bashrc

echo -e "${CYAN}加载新的 bash 配置...${RESET}"
source ~/.bashrc

echo -e "${CYAN}还原 public_html 目录...${RESET}"
mkdir -p "/home/$USERNAME/domains/$DOMAINS/"
if [ "$BACKUPED" = true ]; then
    cp -a "$BACKUP_DIR/public_html" "/home/$USERNAME/domains/$DOMAINS/"
    echo -e "${GREEN}✔️ public_html 已从备份还原至 /home/$USERNAME/domains/$DOMAINS/${RESET}"
else
    mkdir -p "/home/$USERNAME/domains/$DOMAINS/public_html"
    echo -e "${YELLOW}⚠️ 创建空的 public_html 目录：/home/$USERNAME/domains/$DOMAINS/public_html${RESET}"
fi

echo -e "${GREEN}${BOLD}🎉 系统重装脚本执行完成！${RESET}"
