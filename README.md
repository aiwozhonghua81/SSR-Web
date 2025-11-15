# SSR Web Manager (Simplified)

一个基于 Flask 的 ShadowsocksR（SSR）简化版 Web 管理项目，支持一键安装部署（Docker），提供常用的可视化管理：
- 安装/更新/卸载 SSR
- 启动/停止/重启 SSR
- 查看账号信息/连接信息
- 修改端口/密码
- 查看日志
- 配置 BBR（在容器内生效）

本项目内置对 `ssr_simplified.sh` 的集成，通过后端在容器内调用脚本函数实现上述功能。

## 快速开始（Docker Compose）

1. 克隆仓库

```
git clone https://github.com/yourname/ssr-web-manager.git
cd ssr-web-manager
```

2. 启动服务

```
docker compose up -d --build
```

3. 打开浏览器访问

```
http://<服务器IP或域名>:8080
```

> 初次进入可先执行“安装 SSR”。

## 在宝塔面板（BT）中部署

有两种方式：

- 方式一：在“Docker 管理器”中导入 `docker-compose.yml`，一键启动。
- 方式二：构建镜像并运行容器：
  1. 上传项目到服务器
  2. 在宝塔终端执行：
     ```
     docker build -t ssr-web-manager:latest .
     docker run -d --name ssr-web-manager \
       -p 8080:8080 \
       --restart unless-stopped \
       ssr-web-manager:latest
     ```

> 注意：容器内的 iptables/BBR 仅影响容器网络命名空间。如果你需要在宿主机层面统一放行端口，请在宿主机或面板安全组中放行 SSR 端口。

## 一键安装脚本（可选）

如果你的服务器还没有安装 Docker 和 Compose，可以使用：

```
curl -fsSL https://raw.githubusercontent.com/yourname/ssr-web-manager/main/scripts/install.sh | bash
```

该脚本将安装 Docker 与 Compose，并拉起本项目容器。

## 项目结构

```
ssr-web-manager/
├─ app/
│  ├─ main.py             # Flask 后端
│  ├─ ssr_bridge.py       # 调用 ssr_simplified.sh 的桥接层
│  ├─ templates/
│  │  └─ index.html       # 简单管理界面
│  └─ static/
│     ├─ main.css
│     └─ main.js
├─ scripts/
│  └─ install.sh          # 一键安装脚本
├─ ssr_simplified.sh      # 集成本地脚本副本（容器内使用）
├─ Dockerfile
├─ docker-compose.yml
└─ requirements.txt
```

## 环境与限制
- 基于 `Debian/Ubuntu` 容器，Flask 提供 Web 管理界面
- SSR 管理逻辑调用 `ssr_simplified.sh` 内的函数（通过 `bash -lc "source ...; Func"`）
- SSR 固定配置为：加密 `rc4-md5`，协议 `origin`，混淆 `plain`
- 若需自定义更多参数，可扩展 `ssr_bridge.py`

## 安全说明
- 请务必妥善保管面板访问地址
- SSR 端口请按需放行
- 日志中可能包含敏感信息，请谨慎分享

## 许可证
MIT
