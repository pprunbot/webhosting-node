#!/bin/bash

set -e

echo "=========== WebHosting 一键安装脚本 ==========="

# 自动检测用户名
USERNAME=$(whoami)
echo "当前系统用户: $USERNAME"

# 交互输入参数
read -p "请输入项目域名（如 dataonline.x86.dpdns.org）: " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "❌ 域名不能为空，退出安装。"
  exit 1
fi

read -p "请输入监听端口（默认 4642）: " PORT
PORT=${PORT:-4642}

read -p "请输入 UUID（回车使用默认值）: " UUID
UUID=${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}

echo "使用配置:"
echo "  ✅ 用户名: $USERNAME"
echo "  ✅ 域名: $DOMAIN"
echo "  ✅ 端口: $PORT"
echo "  ✅ UUID: $UUID"

echo
read -p "确认以上信息并继续安装？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "❌ 用户取消安装。"
  exit 1
fi

echo "=========== 检查 Node.js 和 npm ==========="
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "未检测到 Node.js 或 npm，开始安装..."
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
  source ~/.bashrc || true
  source ~/.bash_profile || true
fi

# 再次检查
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "❌ Node.js/npm 安装失败，退出。"
  exit 1
fi

echo "✅ Node.js 版本: $(node -v)"
echo "✅ npm 版本: $(npm -v)"

echo "=========== 下载项目文件 ==========="
TARGET_DIR=~/domains/${DOMAIN}/public_html
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 下载四个核心文件
curl -fsSLO https://raw.githubusercontent.com/pprunbot/webhosting-node/main/app.js
curl -fsSLO https://raw.githubusercontent.com/pprunbot/webhosting-node/main/.htaccess
curl -fsSLO https://raw.githubusercontent.com/pprunbot/webhosting-node/main/ws.php
curl -fsSLO https://raw.githubusercontent.com/pprunbot/webhosting-node/main/package.json

echo "✅ 文件下载完成"

echo "=========== 替换 app.js 中的端口、UUID 和域名 ==========="
# 替换端口
sed -i "s/const port = process.env.PORT || [0-9]\+;/const port = process.env.PORT || $PORT;/" app.js

# 替换 UUID（注意保留引号）
sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js

# 替换域名
sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js

echo "=========== 安装依赖 & 启动服务 ==========="
npm install -g pm2
npm install

pm2 start app.js --name my-app
pm2 save

echo "=========== 设置开机启动 ==========="
CRON_CMD="@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon"
( crontab -l 2>/dev/null | grep -v 'pm2 resurrect' ; echo "$CRON_CMD" ) | crontab -

echo "🎉 安装完成！服务已启动，pm2 名称为 my-app"
