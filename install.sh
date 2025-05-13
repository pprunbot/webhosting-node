#!/usr/bin/env bash
set -e

# —— 1. 检测 Node.js & npm ——
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Node.js 或 npm 未检测到，开始安装 Node.js v20.12.2 到 ~/.local/node ..."
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o /tmp/node.tar.gz
  tar -xzf /tmp/node.tar.gz --strip-components=1 -C ~/.local/node
  rm /tmp/node.tar.gz

  # 将 ~/.local/node/bin 加入 PATH（只添加一次）
  grep -q 'export PATH=\$HOME/.local/node/bin' ~/.bashrc 2>/dev/null || \
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
  grep -q 'export PATH=\$HOME/.local/node/bin' ~/.bash_profile 2>/dev/null || \
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile && source ~/.bash_profile

  # 再次检测
  if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
    echo "Node.js 安装失败，退出脚本。"
    exit 1
  fi
fi

echo "检测通过：node $(node -v)，npm $(npm -v)"

# —— 2. 交互：获取域名 —— 
read -p "请输入项目域名（例如 dataonline.x86.dpdns.org）: " DOMAIN
TARGET_DIR="$HOME/domains/$DOMAIN/public_html"
mkdir -p "$TARGET_DIR"

# —— 3. 下载四个文件 —— 
BASE_RAW="https://raw.githubusercontent.com/pprunbot/webhosting-node/main"
for file in app.js .htaccess package.json ws.php; do
  echo "下载 $file 到 $TARGET_DIR ..."
  curl -fsSL "$BASE_RAW/$file" -o "$TARGET_DIR/$file"
done

# —— 4. 安装 pm2 —— 
echo "全局安装 pm2 ..."
npm install -g pm2

# —— 5. 交互：自定义端口 & UUID —— 
read -p "请输入监听端口 [默认 4642]: " PORT
PORT=${PORT:-4642}

read -p "请输入 UUID [回车使用默认 cdc72a29-c14b-4741-bd95-e2e3a8f31a56]: " UUID
UUID=${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}

# —— 6. 在文件中替换端口 & UUID —— 
echo "在 app.js 中替换 PORT 和 UUID ..."
# 替换环境变量默认端口
sed -i "s|\(const port = process.env.PORT || '\)[^']*|\1$PORT|g" "$TARGET_DIR/app.js"
# 替换硬编码监听地址中的端口
sed -i "s|127\.0\.0\.1:[0-9]\+|127.0.0.1:$PORT|g" "$TARGET_DIR/app.js"

# 替换 .htaccess 中的端口
sed -i "s|127\.0\.0\.1:[0-9]\+|127.0.0.1:$PORT|g" "$TARGET_DIR/.htaccess"

# 替换 ws.php 中的端口
sed -i "s|tcp://127:[0-9]\+|tcp://127:$PORT|g" "$TARGET_DIR/ws.php"

# 替换 UUID
sed -i "s|\(const UUID = process.env.UUID || '\)[^']*|\1$UUID|g" "$TARGET_DIR/app.js"

# —— 7. 启动应用 —— 
cd "$TARGET_DIR"
pm2 start app.js --name my-app
pm2 save

# —— 8. 添加开机自启 —— 
SSH_USER=$(whoami)
CRON_CMD="@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon"
# 仅在 crontab 中不存在时添加
( crontab -l 2>/dev/null | grep -F "$CRON_CMD" ) || \
  ( crontab -l 2>/dev/null; echo "$CRON_CMD" ) | crontab -

echo "安装完成！"
echo "访问：http://$DOMAIN/ 查看是否正常。"
