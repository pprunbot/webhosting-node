#!/bin/bash

# 确保脚本以交互模式运行
if [[ ! $- =~ i ]]; then
    echo "脚本需要交互式终端。请直接运行脚本，或者使用 bash 执行该脚本。"
    exit 1
fi

# 获取当前 SSH 用户名
USER=$(whoami)

# 提示用户输入 UUID 和端口号
echo "请输入 UUID (例如：123e4567-e89b-12d3-a456-426614174000)："
read UUID
if [ -z "$UUID" ]; then
    echo "UUID 不能为空，退出安装"
    exit 1
fi

echo "请输入端口号 (例如：8080)："
read PORT
if [ -z "$PORT" ]; then
    echo "端口号不能为空，退出安装"
    exit 1
fi

# 获取域名
DOMAIN=$(ls -d /home/*/domains/*/ | xargs -n1 basename | head -n 1)
if [ -z "$DOMAIN" ]; then
    echo "无法检测到域名，退出安装"
    exit 1
fi
echo "检测到的域名：$DOMAIN"

# 安装 Node.js 和 PM2
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo "Node.js 或 npm 未安装，开始安装..."
    mkdir -p ~/.local/node
    curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
fi

# 检查 Node.js 和 npm 是否安装成功
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo "Node.js 或 npm 安装失败，退出安装"
    exit 1
fi

# 安装 PM2
npm install -g pm2

# 克隆项目并修改配置
echo "克隆所需的文件..."
if [ -d "/home/$USER/domains/$DOMAIN/public_html" ]; then
    echo "目标目录已存在，跳过克隆步骤"
else
    git clone https://github.com/pprunbot/webhosting-node.git /home/$USER/domains/$DOMAIN/public_html
fi

# 修改配置文件
echo "修改 app.js 配置..."
sed -i "s|const DOMAIN = process.env.DOMAIN || '.*'|const DOMAIN = process.env.DOMAIN || '$DOMAIN';|" /home/$USER/domains/$DOMAIN/public_html/app.js
sed -i "s|const PORT = process.env.PORT || 3000|const PORT = process.env.PORT || $PORT;|" /home/$USER/domains/$DOMAIN/public_html/app.js
sed -i "s|const UUID = process.env.UUID || '.*'|const UUID = process.env.UUID || '$UUID';|" /home/$USER/domains/$DOMAIN/public_html/app.js

# 启动应用程序
echo "启动应用程序..."
cd /home/$USER/domains/$DOMAIN/public_html
pm2 start app.js --name my-app
pm2 save

# 设置 crontab 自动恢复 PM2
echo "设置 crontab 以便系统重启时自动恢复 PM2..."
if [ ! -d /tmp ]; then
    mkdir /tmp
fi
crontab -l | { cat; echo "@reboot sleep 30 && /home/$USER/.local/node/bin/pm2 resurrect --no-daemon"; } | crontab -

echo "安装完成，应用程序已通过 PM2 启动，并将在重启时自动恢复。"
