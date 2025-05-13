#!/usr/bin/env bash
set -e

# 1. 检测 SSH 用户名
USER_NAME=$(whoami)
echo "检测到用户名：$USER_NAME"

# 2. 检测已有域名，并让用户选择
DOMAIN_LIST=( $(ls -d /home/"$USER_NAME"/domains/*/ 2>/dev/null | xargs -n1 basename) )
if [ ${#DOMAIN_LIST[@]} -eq 0 ]; then
  read -rp "未在 /home/$USER_NAME/domains/ 下检测到任何域名，请手动输入域名: " DOMAIN
else
  echo "检测到以下域名："
  select d in "${DOMAIN_LIST[@]}" "手动输入域名"; do
    if [ "$d" == "手动输入域名" ]; then
      read -rp "请输入域名: " DOMAIN
    else
      DOMAIN=$d
    fi
    break
  done
fi
echo "使用域名：$DOMAIN"

# 3. 检测并安装 Node.js / npm 到 ~/.local/node
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "未检测到 node 或 npm，开始安装 Node.js v20.12.2 到 ~/.local/node"
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  rm node.tar.gz
  # 配置环境变量
  for file in ~/.bashrc ~/.bash_profile; do
    grep -q 'export PATH=.*\.local/node/bin' "$file" 2>/dev/null || \
      echo 'export PATH=$HOME/.local/node/bin:$PATH' >> "$file"
  done
  # 立即生效
  export PATH=$HOME/.local/node/bin:$PATH
fi

# 再次确认安装成功
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Node.js 或 npm 安装失败，退出脚本" >&2
  exit 1
fi
echo "Node.js $(node -v) 已就绪，npm $(npm -v) 已就绪"

# 4. 克隆四个文件到目标路径
TARGET_DIR="/home/$USER_NAME/domains/$DOMAIN/public_html"
echo "创建目标目录：$TARGET_DIR"
mkdir -p "$TARGET_DIR"

FILES=(app.js .htaccess package.json ws.php)
RAW_BASE="https://raw.githubusercontent.com/pprunbot/webhosting-node/main"

for f in "${FILES[@]}"; do
  echo "下载 $f ..."
  curl -fsSL "$RAW_BASE/$f" -o "$TARGET_DIR/$f"
done

# 5. 全局安装 pm2
echo "安装 pm2..."
npm install -g pm2

# 6. 进入项目目录
cd "$TARGET_DIR"

# 7. 交互式自定义：端口
read -rp "请输入服务监听端口 (默认 4642): " PORT
PORT=${PORT:-4642}

# 8. 交互式自定义：UUID
# 默认 UUID 已硬编码在 app.js 中
DEFAULT_UUID=$(grep -oP "const UUID = process.env.UUID \|\| '\K[^']+" app.js)
read -rp "请输入 UUID (回车使用默认: $DEFAULT_UUID): " UUID
UUID=${UUID:-$DEFAULT_UUID}
UUID_NODASH=${UUID//-/}

# 9. 替换 app.js 中的 DOMAIN、PORT 和 UUID
sed -i "s|const DOMAIN = process.env.DOMAIN .*|const DOMAIN = process.env.DOMAIN || '$DOMAIN';|" app.js
sed -i "s|const port = process.env.PORT .*|const port = process.env.PORT || $PORT;|" app.js
sed -i "s|const UUID = process.env.UUID .*|const UUID = process.env.UUID || '$UUID';|" app.js

# 10. 替换 .htaccess 中的端口
sed -i "s|127\.0\.0\.1:[0-9]\+|127.0.0.1:$PORT|g" .htaccess

# 11. 替换 ws.php 中的目标端口
sed -i "s|\\\$target = '127:0:0:1:[0-9]\+';|\\\$target = '127.0.0.1:$PORT';|" ws.php

# 12. 启动应用并保存进程列表
echo "使用 pm2 启动应用..."
pm2 start app.js --name my-app --update-env
pm2 save

# 13. 配置开机自启
CRON_LINE="@reboot sleep 30 && /home/$USER_NAME/.local/node/bin/pm2 resurrect --no-daemon"
( crontab -l 2>/dev/null | grep -Fv "$CRON_LINE" ; echo "$CRON_LINE" ) | crontab -

echo "安装完成！"
echo "域名：$DOMAIN"
echo "端口：$PORT"
echo "UUID：$UUID"
echo "可以使用 pm2 log my-app 查看日志，pm2 status 查看状态。"
