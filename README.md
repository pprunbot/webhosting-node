# WebSocket服务器部署工具

这是一个用于共享主机环境快速部署 WebSocket 服务和哪吒探针的自动化工具，简化配置流程，适用于 CloudLinux/CPanel 等虚拟主机。

## 📌 目录

- [特点](#特点)
- [快速开始](#快速开始)
- [功能选项](#功能选项)
- [配置项说明](#配置项说明)
- [创建 Node.js 应用](#创建-nodejs-应用)
- [订阅地址说明](#订阅地址说明)
- [自动保活机制](#自动保活机制)
- [许可证](#许可证)

---

## ✨ 特点

- 一键部署 WebSocket + 哪吒客户端
- 自动识别主机域名目录
- 提供交互式配置菜单
- 自动创建并运行 Node.js 应用
- 同步配置 `.htaccess` 和 PHP 后端桥接文件
- 提供订阅链接（VLESS over WebSocket）
- 自动保活及 PM2 管理支持
- 支持修改监听端口和 UUID 后自动重启服务

---

## 🚀 快速开始

支持终端的主机：一键安装脚本，在终端中粘贴执行：

```bash
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/install.sh -o install.sh
bash install.sh
```

重置系统脚本，需要重新添加域名:

```bash
curl -fsSL https://raw.githubusercontent.com/pprunbot/webhosting-node/main/reset_system.sh -o reset_system.sh && chmod +x reset_system.sh && ./reset_system.sh
```

只支持cron的主机：根据run.sh提示添加，修改用户名USERNAME，在cron添加下面指令

```bash
/home/USERNAME/run.sh
```

只支持cron的主机：复制卸载脚本stop.sh并赋权，修改用户名USERNAME，在cron添加下面指令

```bash
/home/USERNAME/stop.sh
```

### 功能选项

脚本提供以下功能选项：


1. **启动WebSocket代理服务**：
   - 自动创建app.js和package.json文件
   - 使用Node.js虚拟环境启动服务
   - 安装依赖并启动服务

2. **启动哪吒探针**：
   - 下载并安装哪吒探针
   - 使用保存的配置信息启动探针

3. **卸载功能**：
   - 一键卸载

4. **退出脚本**：
   - 快速退出脚本


## 配置选项

在"修改配置文件"选项中，您需要提供以下信息：

- **域名**：脚本会自动扫描您的域名目录，您可以从列表中选择或手动输入
- **节点名称**：显示在订阅信息中的节点名称（默认：Webhosting-Node）
- **监听端口**：WebSocket服务器监听的端口（默认：4000）
- **UUID**：可以自动生成或手动输入，用于WebSocket连接验证
- **反代域名**：用于VLESS连接的反代域名（默认：skk.moe）
- **哪吒服务器地址**：哪吒探针服务器地址（可选）
- **哪吒客户端密钥**：哪吒探针的客户端密钥（可选）
- **TLS连接**：是否使用TLS连接哪吒服务器（默认：是）

## 创建Node.js应用

脚本自动检测并创建对应的Node.js应用，无需开启node.js插件。

## 订阅地址

WebSocket服务启动后，脚本会自动显示您的VLESS订阅地址：

```
您的VLESS订阅地址是：https://您的域名/sub
```

例如：`https://example.com/sub`

这个URL会返回一个Base64编码的VLESS链接，可以直接导入到支持VLESS协议的客户端中。

VLESS链接使用您配置的反代域名作为服务器地址，使用您的实际域名作为SNI和Host参数，这样可以提高连接成功率。

## 自动保活功能

脚本提供了自动保活功能，可以通过定时任务自动检查并重启服务。这对于共享主机环境特别有用，因为服务器可能会定期清理长时间运行的进程。

## 许可证

MIT
