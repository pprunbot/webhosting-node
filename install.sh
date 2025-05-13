#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}欢迎使用 Node.js 自动部署脚本${NC}"

# === Step 1: 用户交互输入 ===
read -p "请输入绑定的域名（如 a.360.cloudns.be）: " DOMAIN
while [[ -z "$DOMAIN" ]]; do
  echo -e "${RED}域名不能为空，请重新输入。${NC}"
  read -p "请输入绑定的域名（如 a.360.cloudns.be）: " DOMAIN
done

read -p "请输入监听端口（默认 4642，回车跳过）: " PORT
PORT=${PORT:-4642}

read -p "请输入 UUID（默认 cdc72a29-c14b-4741-bd95-e2e3a8f31a56）: " UUID
UUID=${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}

USERNAME=$(whoami)
APP_DIR=~/domains/$DOMAIN/public_html

echo -e "\n${GREEN}配置如下：${NC}"
echo -e " - 域名：${DOMAIN}"
echo -e " - 端口：${PORT}"
echo -e " - UUID：${UUID}"
echo -e " - 部署目录：${APP_DIR}\n"

read -p "请确认以上信息无误（按回车继续，Ctrl+C 取消）: "

# === Step 2: 安装 Node.js（如不存在）===
echo -e "${GREEN}[1/6] 检查 Node.js ...${NC}"

if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo -e "${RED}未检测到 Node.js，正在安装...${NC}"
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
  export PATH=$HOME/.local/node/bin:$PATH
  rm node.tar.gz
fi

echo -e "${GREEN}Node.js 版本：$(node -v), npm 版本：$(npm -v)${NC}"

# === Step 3: 下载部署文件 ===
echo -e "${GREEN}[2/6] 下载部署文件到 $APP_DIR${NC}"
mkdir -p "$APP_DIR"

curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/app.js -o "$APP_DIR/app.js"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/.htaccess -o "$APP_DIR/.htaccess"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/package.json -o "$APP_DIR/package.json"
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/ws.php -o "$APP_DIR/ws.php"

# 替换变量
sed -i "s|dataonline\.x86\.dpdns\.org|$DOMAIN|g" "$APP_DIR/app.js"
sed -i "s|4642|$PORT|g" "$APP_DIR/app.js"
sed -i "s|cdc72a29-c14b-4741-bd95-e2e3a8f31a56|$UUID|g" "$APP_DIR/app.js"

sed -i "s|127\.0\.0\.1:4642|127.0.0.1:$PORT|g" "$APP_DIR/.htaccess"
sed -i "s|127\.0\.0\.1:4642|127.0.0.1:$PORT|g" "$APP_DIR/ws.php"

# === Step 4: 安装 pm2 ===
echo -e "${GREEN}[3/6] 安装 pm2 进程守护工具...${NC}"
npm install -g pm2

# === Step 5: 启动服务 ===
echo -e "${GREEN}[4/6] 启动 Node.js 服务...${NC}"
cd "$APP_DIR"
pm2 start app.js --name node-app
pm2 save

# === Step 6: 加入开机自启 ===
echo -e "${GREEN}[5/6] 添加开机启动项...${NC}"
CRONCMD="@reboot sleep 10 && /home/$USERNAME/.local/node/bin/pm2 resurrect"
(crontab -l 2>/dev/null | grep -v 'pm2 resurrect'; echo "$CRONCMD") | crontab -

echo -e "${GREEN}[✔] 部署成功！${NC}"
echo -e "📌 地址：http://$DOMAIN"
echo -e "📌 本地端口：$PORT"
echo -e "📌 UUID：$UUID"
echo -e "📁 路径：$APP_DIR"
