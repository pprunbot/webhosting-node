#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[1/10] 检查 Node.js 和 npm...${NC}"

if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo -e "${RED}未检测到 Node.js，开始安装...${NC}"
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
  source ~/.bashrc 2>/dev/null || true
  source ~/.bash_profile 2>/dev/null || true
fi

if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo -e "${RED}Node.js 安装失败，退出。${NC}"
  exit 1
fi

echo -e "${GREEN}[2/10] Node.js 安装成功，版本：$(node -v)${NC}"

# 用户输入
read -p "请输入绑定域名（如 dataonline.x86.dpdns.org）: " DOMAIN
read -p "请输入监听端口（默认 4642，回车跳过）: " PORT
PORT=${PORT:-4642}
read -p "请输入 UUID（回车使用默认值 cdc72a29-c14b-4741-bd95-e2e3a8f31a56）: " UUID
UUID=${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}
USERNAME=$(whoami)

APP_DIR=~/domains/$DOMAIN/public_html
mkdir -p "$APP_DIR"

echo -e "${GREEN}[3/10] 开始下载文件到 $APP_DIR${NC}"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/app.js -o "$APP_DIR/app.js"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/.htaccess -o "$APP_DIR/.htaccess"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/package.json -o "$APP_DIR/package.json"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/ws.php -o "$APP_DIR/ws.php"

# 修改变量
sed -i "s|dataonline\.x86\.dpdns\.org|$DOMAIN|g" "$APP_DIR/app.js"
sed -i "s|4642|$PORT|g" "$APP_DIR/app.js"
sed -i "s|cdc72a29-c14b-4741-bd95-e2e3a8f31a56|$UUID|g" "$APP_DIR/app.js"
sed -i "s|127\.0\.0\.1:4642|127.0.0.1:$PORT|g" "$APP_DIR/.htaccess"
sed -i "s|127\.0\.0\.1:4642|127.0.0.1:$PORT|g" "$APP_DIR/ws.php"

echo -e "${GREEN}[4/10] 安装 pm2${NC}"
~/.local/node/bin/npm install -g pm2

echo -e "${GREEN}[5/10] 启动服务...${NC}"
cd "$APP_DIR"
~/.local/node/bin/pm2 start app.js --name my-app
~/.local/node/bin/pm2 save

echo -e "${GREEN}[6/10] 添加启动项到 crontab${NC}"
CRONCMD="@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon"
(crontab -l 2>/dev/null | grep -v 'pm2 resurrect'; echo "$CRONCMD") | crontab -

echo -e "${GREEN}[✔] 安装完成！监听端口：$PORT，UUID：$UUID，域名：$DOMAIN${NC}"
