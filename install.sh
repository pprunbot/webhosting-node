#!/bin/bash

# 退出脚本执行错误
set -e

# 获取当前用户名
USERNAME=$(whoami)
echo "检测到当前用户名: $USERNAME"

# 检测域名目录
DOMAINS_DIR="/home/$USERNAME/domains"
if [ ! -d "$DOMAINS_DIR" ]; then
  echo "错误：未找到域名目录 $DOMAINS_DIR"
  exit 1
fi

# 获取可用域名列表
DOMAINS=($(ls -d $DOMAINS_DIR/*/ | xargs -n1 basename))
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "错误：未找到任何域名配置"
  exit 1
fi

# 显示域名选择菜单
echo "可用的域名："
for i in "${!DOMAINS[@]}"; do
  echo "$((i+1)). ${DOMAINS[$i]}"
done

# 获取用户选择的域名
read -p "请选择域名（输入数字）[默认1]: " DOMAIN_INDEX
DOMAIN_INDEX=${DOMAIN_INDEX:-1}
if [[ ! $DOMAIN_INDEX =~ ^[0-9]+$ ]] || [ $DOMAIN_INDEX -lt 1 ] || [ $DOMAIN_INDEX -gt ${#DOMAINS[@]} ]; then
  echo "无效的选择"
  exit 1
fi

DOMAIN=${DOMAINS[$((DOMAIN_INDEX-1))]}
echo "已选择域名: $DOMAIN"

# 自定义端口输入
read -p "请输入端口号 [默认4000]: " PORT
PORT=${PORT:-4000}

# 验证端口号
if [[ ! $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
  echo "无效的端口号"
  exit 1
fi

# UUID输入
read -p "请输入UUID [默认随机生成]: " UUID
if [ -z "$UUID" ]; then
  UUID=$(cat /proc/sys/kernel/random/uuid)
  echo "已生成随机UUID: $UUID"
fi

# 检测Node.js安装
check_node() {
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "正在安装Node.js..."
    
    # 创建安装目录
    mkdir -p ~/.local/node
    
    # 下载Node.js
    curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
    
    # 解压文件
    tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
    
    # 添加环境变量
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
    
    # 立即生效
    source ~/.bashrc
    source ~/.bash_profile
    
    # 清理临时文件
    rm node.tar.gz
  fi

  # 再次验证安装
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Node.js安装失败，请手动安装后重试"
    exit 1
  fi
}

check_node

# 安装PM2
echo "正在安装PM2..."
npm install -g pm2

# 创建项目目录
PROJECT_DIR="/home/$USERNAME/domains/$DOMAIN/public_html"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 下载项目文件
echo "正在下载项目文件..."
FILES=("app.js" ".htaccess" "package.json" "ws.php")
for file in "${FILES[@]}"; do
  curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/$file -O
done

# 修改配置文件
sed -i "s/const DOMAIN = process.env.DOMAIN || '.*';/const DOMAIN = process.env.DOMAIN || '$DOMAIN';/" app.js
sed -i "s/const UUID = process.env.UUID || '.*';/const UUID = process.env.UUID || '$UUID';/" app.js
sed -i "s/const port = process.env.PORT || .*;/const port = process.env.PORT || $PORT;/" app.js

# 安装依赖
npm install

# 启动PM2服务
pm2 start app.js --name my-appcs
pm2 save

# 添加定时任务
(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /home/$USERNAME/.local/node/bin/pm2 resurrect --no-daemon") | crontab -

echo "安装完成！"
echo "访问地址：https://$DOMAIN"
echo "UUID: $UUID"
echo "端口: $PORT"
