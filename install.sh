#!/bin/bash

set -e

# 检查 Node.js 和 npm
echo "检测 Node.js 和 npm..."
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
  echo "未检测到 Node.js，开始安装..."
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
  source ~/.bashrc || true
  source ~/.bash_profile || true
fi

# 再次确认是否安装成功
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
  echo "Node.js 安装失败，退出脚本。"
  exit 1
fi

echo "Node.js 版本: $(node -v)"
echo "npm 版本: $(npm -v)"

# 交互获取域名
read -p "请输入你的域名（例如 dataonline.x86.dpdns.org）: " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "域名不能为空"
  exit 1
fi

# 交互获取监听端口
read -p "请输入监听端口（默认 4642）: " PORT
PORT=${PORT:-4642}

# 交互获取 UUID
read -p "请输入 UUID（默认: cdc72a29-c14b-4741-bd95-e2e3a8f31a56）: " UUID
UUID=${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}

# 获取 SSH 用户名
USERNAME=$(whoami)
APP_DIR=~/domains/${DOMAIN}/public_html

# 创建路径
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# 下载四个文件
echo "正在下载 app.js, .htaccess, ws.php, package.json..."
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/app.js
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/.htaccess
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/ws.php
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/package.json

# 替换端口与 UUID
echo "正在配置 app.js..."

sed -i "s/process.env.PORT || [0-9]\+/process.env.PORT || $PORT/" app.js
sed -i "s|process.env.UUID || '.*'|process.env.UUID || '$UUID'|" app.js
sed -i "s|process.env.DOMAIN || '.*'|process.env.DOMAIN || '$DOMAIN'|" app.js

# 安装 PM2
echo "正在安装 PM2..."
npm install -g pm2

# 启动应用
echo "启动 PM2 应用..."
pm2 start app.js --name my-app
pm2 save

# 设置 pm2 自动重启
echo "配置 Crontab..."
CRON_CMD="@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon"
(crontab -l 2>/dev/null | grep -v -F "$CRON_CMD" || true; echo "$CRON_CMD") | crontab -

echo "✅ 安装完成！"
echo "PM2 应用已启动，监听端口：$PORT"
