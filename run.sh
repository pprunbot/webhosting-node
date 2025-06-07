#!/bin/sh

# 支持FreeBSD、共享主机、老旧系统，项目地址：https://github.com/pprunbot/webhosting-node
# 手动下载上传文件（解压自动赋权，最小支持100m硬盘容量主机只需上传二进制文件要手动赋权），node.js上传路径$HOME/.local/bin，官方下载地址：https://nodejs.org/dist/v16.20.2/node-v16.20.2-linux-x64.tar.gz
# 在.bashrc最后一行添加：export PATH="$HOME/.local/bin:$PATH"
# 上传依赖包node_modules.zip解压和四个文件修改配置app.js,package.json,ws.php,.htaccess
# 修改你的用户名和域名USERNAME,YOUDOMAIN，赋权添加cron
LOG_FILE="/home/USERNAME/run.log"
NODE_PATH="/home/USERNAME/.local/bin/node"
APP_PATH="/home/USERNAME/domains/YOUDOMAIN/public_html/app.js"
PID_FILE="/tmp/appjs.pid"

# 如果进程已经在运行，则退出，防止重复启动
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "[INFO] Already running (PID=$(cat "$PID_FILE")). Exiting." >> "$LOG_FILE"
  exit 0
fi

echo "[INFO] Starting new app.js loop at $(date)" >> "$LOG_FILE"

# 写入当前脚本的 PID
echo $$ > "$PID_FILE"

# 启动保活循环
while true; do
  echo "[INFO] Starting app.js at $(date)" >> "$LOG_FILE"
  "$NODE_PATH" "$APP_PATH" >> "$LOG_FILE" 2>&1
  echo "[WARN] app.js exited at $(date). Restarting in 1800 seconds..." >> "$LOG_FILE"
  sleep 1800
done
