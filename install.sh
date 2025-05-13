#!/bin/bash

set -e

# 检测是否安装了 node 和 npm
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo "Node.js 和 npm 未安装，正在安装..."

    mkdir -p ~/.local/node
    curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node

    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    source ~/.bashrc || true
    source ~/.bash_profile || true

    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        echo "Node.js 安装失败，请检查系统依赖或手动安装。"
        exit 1
    fi
fi

echo "Node.js 和 npm 已安装："
node -v
npm -v

# 获取用户输入
read -p "请输入你的域名（如 dataonline.x86.dpdns.org）: " DOMAIN
read -p "请输入要监听的端口（默认 4642）: " PORT
PORT=${PORT:-4642}
read -p "请输入自定义 UUID（回车使用默认）: " CUSTOM_UUID
UUID=${CUSTOM_UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}

# 获取当前 SSH 用户名
USERNAME=$(whoami)
echo "检测到用户名为：$USERNAME"

INSTALL_DIR=~/domains/$DOMAIN/public_html
mkdir -p "$INSTALL_DIR"

echo "克隆项目文件到 $INSTALL_DIR"
cd "$INSTALL_DIR"
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/app.js
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/.htaccess
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/package.json
curl -O https://raw.githubusercontent.com/pprunbot/webhosting-node/main/ws.php

# 替换端口和 UUID
echo "配置端口和 UUID..."
sed -i "s/PORT || [0-9]\+/PORT || $PORT/g" app.js
sed -i "s/cdc72a29-c14b-4741-bd95-e2e3a8f31a56/$UUID/g" app.js
sed -i "s/dataonline\.x86\.dpdns\.org/$DOMAIN/g" app.js
sed -i "s/127.0.0.1:4642/127.0.0.1:$PORT/g" .htaccess
sed -i "s/127.0.0.1:4642/127.0.0.1:$PORT/g" ws.php

# 安装 pm2 并启动
echo "安装 PM2 并启动服务..."
npm install -g pm2
cd "$INSTALL_DIR"
pm2 start app.js --name my-app
pm2 save

# 设置开机自启
CRONCMD="@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon"
(crontab -l 2>/dev/null | grep -v -F "$CRONCMD" || true; echo "$CRONCMD") | crontab -

echo "✅ 安装完成！服务已通过 PM2 启动，目录：$INSTALL_DIR"
