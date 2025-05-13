#!/usr/bin/env bash
set -e

# —— 0. 参数/环境变量读取 —— 
# 优先：ENV DOMAIN > 第1个脚本参数 > 交互式输入
if [ -n "$1" ]; then
  DOMAIN="$1"
elif [ -n "$DOMAIN" ]; then
  DOMAIN="$DOMAIN"
else
  # 只有在 STDIN 是 TTY 时才交互
  if [ -t 0 ]; then
    read -p "请输入项目域名（例如 dataonline.x86.dpdns.org）: " DOMAIN
  fi
fi

if [ -z "$DOMAIN" ]; then
  echo "错误：未提供域名！"
  echo "用法示例："
  echo "  1) 交互式："
  echo "       curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/install.sh | bash"
  echo "  2) 管道 + 环境变量："
  echo "       DOMAIN=host.1212.cloudns.be bash <(curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/install.sh)"
  echo "  3) 管道 + 参数："
  echo "       curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/install.sh | bash -s my.domain.com"
  exit 1
fi

# —— 1. 检测并安装 Node.js v20.12.2 ——
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "检测不到 node/npm，安装 Node.js v20.12.2 到 ~/.local/node ..."
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o /tmp/node.tar.gz
  tar -xzf /tmp/node.tar.gz --strip-components=1 -C ~/.local/node
  rm /tmp/node.tar.gz

  # 写入 PATH（去重）并立即生效
  grep -q 'export PATH=\$HOME/.local/node/bin' ~/.bashrc 2>/dev/null || \
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
  grep -q 'export PATH=\$HOME/.local/node/bin' ~/.bash_profile 2>/dev/null || \
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
  export PATH="$HOME/.local/node/bin:$PATH"

  # 再次检测
  if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
    echo "Node.js 安装失败，退出。"
    exit 1
  fi
fi
echo "检测通过：node $(node -v)，npm $(npm -v)"

# —— 2. 创建目标目录 —— 
TARGET_DIR="$HOME/domains/$DOMAIN/public_html"
echo "创建目录 $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"

# —— 3. 下载四个文件 —— 
echo "下载代码文件到 $TARGET_DIR ..."
BASE_RAW="https://raw.githubusercontent.com/pprunbot/webhosting-node/main"
for file in app.js .htaccess package.json ws.php; do
  curl -fsSL "$BASE_RAW/$file" -o "$TARGET_DIR/$file"
done

# —— 4. 安装 pm2 —— 
echo "安装 pm2 ..."
npm install -g pm2

# —— 5. 读取端口 & UUID —— 
# 管道时也支持 ENV PORT / ENV UUID
PORT=${PORT:-}
UUID=${UUID:-}
if [ -z "$PORT" ] && [ -t 0 ]; then
  read -p "请输入监听端口 [默认 4642]: " PORT
fi
PORT=${PORT:-4642}

if [ -z "$UUID" ] && [ -t 0 ]; then
  read -p "请输入 UUID [默认 cdc72a29-c14b-4741-bd95-e2e3a8f31a56]: " UUID
fi
UUID=${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}

# —— 6. 全局替换默认端口/UUID —— 
echo "替换默认端口 4642 → $PORT，替换默认 UUID → $UUID ..."
sed -i "s/4642/$PORT/g" \
    "$TARGET_DIR/app.js" \
    "$TARGET_DIR/.htaccess" \
    "$TARGET_DIR/ws.php"
sed -i "s/cdc72a29-c14b-4741-bd95-e2e3a8f31a56/$UUID/g" \
    "$TARGET_DIR/app.js"

# —— 7. 启动 & 保存 pm2 —— 
cd "$TARGET_DIR"
pm2 start app.js --name my-app
pm2 save

# —— 8. 配置开机自启 —— 
SSH_USER=$(whoami)
CRON_CMD="@reboot sleep 30 && $HOME/.local/node/bin/pm2 resurrect --no-daemon"
if ! crontab -l 2>/dev/null | grep -Fq "$CRON_CMD"; then
  ( crontab -l 2>/dev/null; echo "$CRON_CMD" ) | crontab -
fi

echo ""
echo "✅ 安装完成！"
echo "访问：http://$DOMAIN/ 验证服务是否正常"
