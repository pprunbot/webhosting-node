#!/usr/bin/env bash
set -e

# 1. 检测当前 SSH 用户名
USER_NAME=$(whoami)
echo "Detected user: ${USER_NAME}"

# 2. 检测域名目录
DOMAINS=( $(ls -d /home/${USER_NAME}/domains/*/ 2>/dev/null | xargs -n1 basename) )
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "Error: No domains found under /home/${USER_NAME}/domains/"
  exit 1
elif [ ${#DOMAINS[@]} -gt 1 ]; then
  echo "Multiple domains detected. Please choose one:"
  select DOMAIN in "${DOMAINS[@]}"; do
    [ -n "$DOMAIN" ] && break
  done
else
  DOMAIN=${DOMAINS[0]}
fi

echo "Using domain: ${DOMAIN}"

# 3. 环境变量注入默认值
DEFAULT_PORT=4642
DEFAULT_UUID="cdc72a29-c14b-4741-bd95-e2e3a8f31a56"

echo -n "请输入服务监听端口 [${DEFAULT_PORT}]: "
read -r PORT
PORT=${PORT:-$DEFAULT_PORT}

echo -n "请输入 UUID [${DEFAULT_UUID}]: "
read -r UUID
UUID=${UUID:-$DEFAULT_UUID}

# 4. 检测 Node.js 和 npm
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "Node.js and npm already installed: $(node -v), $(npm -v)"
else
  echo "Installing Node.js locally to ~/.local/node..."
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  rm node.tar.gz
  export PATH="$HOME/.local/node/bin:$PATH"
  echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bashrc
  echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bash_profile
  source ~/.bashrc 2>/dev/null || true
  source ~/.bash_profile 2>/dev/null || true
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Node.js installed: $(node -v), $(npm -v)"
  else
    echo "Error: Node.js installation failed."
    exit 1
  fi
fi

# 5. 准备项目目录并下载文件
TARGET_DIR="/home/${USER_NAME}/domains/${DOMAIN}/public_html"
echo "Cloning app files into ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}"
BASE_RAW="https://raw.githubusercontent.com/pprunbot/webhosting-node/main"
for FILE in app.js .htaccess package.json ws.php; do
  curl -fsSL "${BASE_RAW}/${FILE}" -o "${TARGET_DIR}/${FILE}"
done

# 6. 注入环境变量到 app.js 和 .htaccess
echo "Updating configuration in app.js..."
sed -i \
  -e "s|const DOMAIN = process.env.DOMAIN.*|const DOMAIN = process.env.DOMAIN || '${DOMAIN}';|" \
  -e "s|const port = process.env.PORT.*|const port = process.env.PORT || ${PORT};|" \
  -e "s|const UUID = process.env.UUID.*|const UUID = process.env.UUID || '${UUID}';|" \
  "${TARGET_DIR}/app.js"

# .htaccess 中的端口替换
sed -i "s|127.0.0.1:[0-9]\+|127.0.0.1:${PORT}|g" "${TARGET_DIR}/.htaccess"

# 7. 安装 pm2 并启动服务
echo "Installing pm2 globally..."
npm install -g pm2

echo "Starting application with pm2..."
cd "${TARGET_DIR}"
pm install
pm2 start app.js --name my-app
pm2 save

# 8. 配置开机自启
CRONTAB_CMD="@reboot sleep 30 && /home/${USER_NAME}/.local/node/bin/pm2 resurrect --no-daemon"
( crontab -l 2>/dev/null | grep -F "$CRONTAB_CMD" ) || (
  crontab -l 2>/dev/null; echo "$CRONTAB_CMD";
) | crontab -

echo "Installation complete! Application is running under pm2 as 'my-app'."
