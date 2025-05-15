#!/bin/bash

echo "⚠️ 警告：该脚本将会清空你的用户主目录（包括隐藏文件），并重置部分配置！"
echo "请确保你已经备份重要数据。"
read -p "确认继续执行脚本？输入 yes 或 y 确认，其他任意键退出: " CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [[ "$CONFIRM_LOWER" != "yes" && "$CONFIRM_LOWER" != "y" ]]; then
    echo "已取消执行。"
    exit 1
fi

USERNAME=$(whoami)
DOMAIN_DIR=$(find /home/"$USERNAME"/domains/ -mindepth 1 -maxdepth 1 -type d | head -n 1)
DOMAINS=$(basename "$DOMAIN_DIR")

ORIGINAL_HTML="/home/$USERNAME/domains/$DOMAINS/public_html"
BACKUP_DIR="$HOME/.public_html_backup"

if [ -d "$ORIGINAL_HTML" ]; then
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    cp -a "$ORIGINAL_HTML" "$BACKUP_DIR/"
    BACKUPED=true
else
    echo "警告：未找到 $ORIGINAL_HTML，跳过备份"
    BACKUPED=false
fi

cd ~ || exit
rm -rf .[^.]* * 2>/dev/null

if [ -f /etc/skel/.bashrc ]; then
    cp /etc/skel/.bashrc ~/
else
    echo "警告：/etc/skel/.bashrc 不存在，跳过恢复"
fi

if [ -f /etc/skel/.profile ]; then
    cp /etc/skel/.profile ~/
elif [ -f /etc/skel/.bash_profile ]; then
    cp /etc/skel/.bash_profile ~/
else
    echo "警告：/etc/skel/.profile 和 .bash_profile 都不存在，跳过恢复"
fi

mkdir -p ~/.local/bin
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc

mkdir -p "$HOME/tmp"
chmod 700 "$HOME/tmp"
echo 'export TMPDIR="$HOME/tmp"' >> ~/.bashrc

source ~/.bashrc

mkdir -p "/home/$USERNAME/domains/$DOMAINS/"
if [ "$BACKUPED" = true ]; then
    cp -a "$BACKUP_DIR/public_html" "/home/$USERNAME/domains/$DOMAINS/"
    echo "public_html 已从备份还原至 /home/$USERNAME/domains/$DOMAINS/"
else
    mkdir -p "/home/$USERNAME/domains/$DOMAINS/public_html"
    echo "已创建空 public_html 目录：/home/$USERNAME/domains/$DOMAINS/public_html"
fi

echo "系统重装脚本执行完成。"
