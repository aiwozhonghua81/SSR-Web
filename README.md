# SSR Web Manager (Simplified)

> **SSR Web Manager（简化版）** —— 一个用网页浏览器就能操作 SSR 代理服务器的 Docker 面板。
> 不想 SSH、不想记命令？打开网页点按钮就行。

---

## ⚠️ 先读这一段（很重要）

这是一个**简化版**面板，为了「开箱即用」牺牲了不少东西，其中有几条是**真实存在的安全问题**，用之前请务必了解：

| # | 问题 | 后果 | 建议 |
| --- | --- | --- | --- |
| 1 | **面板没有任何登录 / 密码 / 鉴权** | 任何能访问 `http://你的IP:8080` 的人，都能点「查看账号信息」看到 **SSR 密码**，能改配置、能卸载服务 | **绝对不要把 8080 端口直接暴露到公网**，见 [十一、安全注意事项](#十一安全注意事项) |
| 2 | **「修改配置」接口存在命令注入** | 接口把用户输入直接拼进 shell 命令执行。在没有鉴权的前提下，等于**任何人都能在容器内以 root 身份执行任意命令** | 同上，**不要公网暴露**。修复思路见 [10.1 已知问题](#101-修改配置按钮有命令注入漏洞) |
| 3 | **默认密码是 `password123`** | SSR 弱密码会被秒破 | 安装完**第一件事**就是改密码 |
| 4 | **SSR 端口默认没有映射到宿主机** | 装完能打开面板，但**外面的客户端连不上 SSR** | 必须在 `docker-compose.yml` 里加端口映射，见 [7.2 端口映射](#72-端口映射很重要) |
| 5 | **容器重建会丢失 SSR 配置** | `docker compose down` 或 `--build` 之后端口、密码全没了 | 见 [7.5 配置持久化](#75-配置持久化很重要) |

> 这份 README 不藏问题。你需要知道边界在哪，才能安全地用它。

---

## 目录导航

| 章节 | 内容 |
| --- | --- |
| [一、这是什么](#一这是什么) | 一句话说明 |
| [二、适合谁用](#二适合谁用) | 什么时候用 / 什么时候别用 |
| [三、效果速览](#三效果速览) | 命令行 vs 网页面板 |
| [四、核心功能](#四核心功能) | 11 个按钮逐个解释 |
| [五、环境要求](#五环境要求) | 服务器、端口、权限 |
| [六、快速上手](#六快速上手) | 从零到能用 |
| [七、详细说明](#七详细说明) | 端口映射、密码、API、目录结构 |
| [八、目录结构](#八目录结构) | 仓库里有什么 |
| [九、常见问题排查](#九常见问题排查) | 现象 → 原因 → 怎么办 |
| [十、已知问题与限制](#十已知问题与限制) | 真实存在的 bug 清单 |
| [十一、安全注意事项](#十一安全注意事项) | 必读 |
| [十二、卸载](#十二卸载) | 怎么撤干净 |
| [十三、许可证与致谢](#十三许可证与致谢) | 上游项目 |

---

<a id="一这是什么"></a>
## 一、这是什么

**一句话**：一个用 **Flask** 写的网页面板，跑在 **Docker** 容器里，用网页按钮来管理一台服务器上的 **ShadowsocksR（SSR，一种老牌的加密代理协议，把你的网络流量加密后中转到服务器上）** 服务端。

先把名词翻译成人话：

- **代理（Proxy）**：让你的电脑流量「绕道」到另一台服务器上再出去，中间加密，途中的人看不到你在访问什么。
- **ShadowsocksR（简称 SSR）**：2014 年前后很流行的一套加密代理方案。特点是**加密方式、协议、混淆可以自由组合**，在很多网络环境下比裸 TCP 更不容易被识别。缺点是年代久远，属于「老将」而不是现在的「主流」。
- **Docker**：一种「装软件的盒子」。把程序和它需要的环境打包在一起，别人一条命令就能跑起来，不用担心依赖装不上。
- **Flask**：Python 写网页后端的小框架。这个面板的后端总共就一个文件 `app/main.py`。
- **面板**：这里指这个网页界面本身（长这样：一个白底页面，三排按钮，点一下右下角出一堆文字）。

**它解决什么**：把「SSH 上去敲一串命令」变成「浏览器里点一个按钮」。

**它不解决什么**：它没有登录、没有多用户、没有流量统计、没有订阅链接管理、没有节点管理、**也没有加密 / 协议 / 混淆的选择**（这三个被写死成固定值）。

---

<a id="二适合谁用"></a>
## 二、适合谁用

**适合：**

- 已经有**自己的服务器**，想在上面跑 SSR
- 嫌 SSH 敲命令麻烦，想用**网页**管理
- 手里有**宝塔面板**，想用它的 Docker 管理器一键起一个
- 想在**一台机器上快速试一下** SSR，不想污染宿主机环境（容器隔离）

**不适合：**

- ❌ 追求**安全性**的正式生产环境 —— 面板无鉴权 + 命令注入，见 [十一、安全注意事项](#十一安全注意事项)
- ❌ 需要**多用户 / 多节点 / 流量统计 / 订阅链接** —— 本项目是单节点轻量工具
- ❌ 需要**自由选择加密方式 / 协议 / 混淆** —— 本项目固定为 `rc4-md5 / origin / plain`
- ❌ 没有服务器、想用它**上网** —— 这是**服务端**面板，你的电脑要装的是**客户端**

---

<a id="三效果速览"></a>
## 三、效果速览

| 操作 | 用命令行（`ssr_simplified.sh`） | 用这个网页面板 |
| --- | --- | --- |
| 安装 SSR | 敲命令、交互式问答 | 点「安装 SSR」 |
| 启动 / 停止 / 重启 | 敲 `service ssr start` | 点对应按钮 |
| 改端口 | 交互式问答 + 改 JSON + 重启 | 点「修改配置」（**目前有 bug，见 10.2**） |
| 改密码 | 交互式问答 + 改 JSON + 重启 | 点「修改配置」（**同上**） |
| 看账号信息（IP/端口/密码） | 敲命令 | 点「查看账号信息」 |
| 看当前有几个客户端连着 | 敲 `netstat` | 点「显示连接信息」 |
| 看日志 | 敲 `tail -f` | 点「查看日志」（**会卡住，见 10.4**） |
| 卸载 SSR | 敲命令 + 回答 y/N | 点「卸载 SSR」（**实际不生效，见 10.3**） |
| 需要记命令吗 | 要 | **不要** |
| 需要 SSH 吗 | 要 | 不用（浏览器就行） |
| 有密码保护吗 | 有（服务器 SSH） | **没有** ⚠️ |

### 打开面板长什么样

```text
SSR Web Manager
固定配置：rc4-md5 / origin / plain

[安装 SSR] [更新 SSR] [卸载 SSR]
[启动] [停止] [重启] [查看日志]
[查看账号信息] [显示连接信息] [修改配置] [配置 BBR]
```

点完按钮，页面下方那个灰色大框（`<pre>` 区域）会显示脚本执行的输出。

---

<a id="四核心功能"></a>
## 四、核心功能

面板一共有 **11 个按钮**，分成三排。每个按钮对应后端 `app/main.py` 里一个 `action`，后端再调用 `ssr_simplified.sh` 里的一个 shell 函数。

| 按钮 | 后端 action | 调用的 shell 函数 | 人话解释 |
| --- | --- | --- | --- |
| **安装 SSR** | `install` | `Install_SSR` | 在容器里下载并安装 SSR 服务端，写好配置，设好 iptables 规则，启动服务。**因为脚本是非交互运行的，端口会用默认值 `8388`，密码会用默认值 `password123`。** |
| **更新 SSR** | `update` | `Update_SSR` | 试图在 SSR 目录里执行 `git pull` 然后重启。**注意：安装时是下载 zip 解压的，不是 git clone，所以这个按钮大概率会报 `fatal: not a git repository`，见 10.5。** |
| **卸载 SSR** | `uninstall` | `Uninstall_SSR` | 卸载 SSR。**但脚本会问「确定要卸载？[y/N]」，而面板没有输入框，所以这个按钮实际会走到「卸载已取消」，见 10.3。** |
| **启动** | `start` | `Start_SSR` | 启动容器里的 SSR 服务（通过 `/etc/init.d/ssr start`）。 |
| **停止** | `stop` | `Stop_SSR` | 停止 SSR 服务。 |
| **重启** | `restart` | `Restart_SSR` | 先停后启。改完配置后用这个。 |
| **查看日志** | `view_log` | `View_Log` | 实时跟踪 SSR 日志文件。**因为用的是 `tail -f`，请求会一直挂着直到 300 秒超时，见 10.4。** |
| **查看账号信息** | `view_user` | `View_User` | 显示 SSR 的**公网 IP、端口、密码、加密、协议、混淆**，以及一个 `ss://` 链接和一个在线二维码地址。**⚠️ 这里显示的就是 SSR 密码。** |
| **显示连接信息** | `view_conn` | `View_user_connection_info` | 显示当前有几个客户端连着，以及它们的 IP 列表。 |
| **修改配置** | `modify` | `Modify_Config` | 改端口 / 密码 / 全部配置。**⚠️ 这个接口有命令注入漏洞，而且当前实现还跑不通，见 10.1 和 10.2。** |
| **配置 BBR** | `config_bbr` | `Configure_BBR` | 安装 / 启动 / 停止 / 查看 BBR（Linux 内核的 TCP 拥塞控制算法，丢包高的线路上能提速）。**面板没有数字输入框，所以这个按钮实际会走到「已取消」，见 10.3。** |

### 后端 API 长什么样

所有操作都走同一个接口：

```http
POST /api/action
Content-Type: application/json

{"action": "install"}
```

带输入的（比如 `modify`）：

```http
POST /api/action
Content-Type: application/json

{"action": "modify", "payload": "8388\nmypassword"}
```

返回：

```json
{"ok": true, "rc": 0, "output": "……脚本的输出文本……"}
```

`action` 不在白名单里会返回 HTTP 400 和 `{"ok": false, "msg": "unknown action"}`。

---

<a id="五环境要求"></a>
## 五、环境要求

| 项目 | 要求 | 说明 |
| --- | --- | --- |
| 服务器系统 | **Linux**（Ubuntu / Debian / CentOS 均可） | 镜像基于 `debian:12-slim`，宿主机基本没要求 |
| Docker | **必须**，且能联网 | 没装的话用 `scripts/install.sh` 帮你装 |
| Docker Compose | **必须**（v2 插件，脚本会装 v2.27.0） | `docker compose` 不是老的 `docker-compose` |
| 内存 | **建议 ≥ 1 GB** | 容器里要跑 SSR + Python + Flask |
| 磁盘 | **建议 ≥ 2 GB** | SSR 源码解压后几百 MB |
| 端口 | **8080**（面板）+ **你选的 SSR 端口**（默认 8388） | 两个都要在云安全组放行 |
| 权限 | 能 `sudo`（安装 Docker 时需要） | 容器内以 **root** 运行 |
| 权限（容器） | Docker 自动加 `NET_ADMIN` | 需要它才能在容器里改 iptables |
| 浏览器 | 任意现代浏览器 | 就一个页面，没有前端框架 |

### 关于 `NET_ADMIN`

`docker-compose.yml` 里给了：

```yaml
cap_add:
  - NET_ADMIN
sysctls:
  - net.ipv4.ip_forward=1
```

`NET_ADMIN` 是容器内改防火墙规则（iptables）的必需权限。没有它，脚本里的 `iptables -I INPUT ...` 会失败。

---

<a id="六快速上手"></a>
## 六、快速上手

### 第 1 步：SSH 登录服务器

```bash
ssh root@你的服务器IP
```

**成功标志**：看到 `root@your-server:~#` 这样的提示符。

### 第 2 步：克隆仓库

```bash
git clone https://github.com/aiwozhonghua81/SSR-Web.git
cd SSR-Web
```

**成功标志**：当前目录里有 `Dockerfile`、`docker-compose.yml`、`app/`、`scripts/` 这些东西。

```bash
ls -la
```

### 第 3 步：启动面板

```bash
docker compose up -d --build
```

**这一步在干什么**：用 `Dockerfile` 构建一个镜像，再按 `docker-compose.yml` 启动一个容器，把容器的 8080 端口映射到服务器的 8080 端口。

**成功标志**：

```bash
docker compose ps
```

看到类似：

```text
NAME                IMAGE               STATUS          PORTS
ssr-web-manager     ssr-web-manager     Up 10 seconds   0.0.0.0:8080->8080/tcp
```

> ⚠️ **首次 `docker compose up` 需要下载基础镜像和 Flask 依赖，可能要几分钟。** 没有网络访问 Docker Hub 会失败。

**服务器上还没装 Docker？** 用仓库自带的脚本装（**必须先 clone 再执行**，原因见 [7.7](#77-scriptsinstallsh-到底做了什么)）：

```bash
git clone https://github.com/aiwozhonghua81/SSR-Web.git
cd SSR-Web
bash scripts/install.sh
```

### 第 4 步：打开浏览器

```text
http://你的服务器IP:8080
```

**成功标志**：浏览器里出现白底页面，顶上是「SSR Web Manager」，下面三排按钮。

> 如果打不开，先检查服务器本机防火墙有没有放行 8080，以及云控制台安全组有没有放行 8080。

### 第 5 步：点「安装 SSR」

**这一步在干什么**：在容器里下载并安装 SSR 服务端、生成配置、开 iptables 规则、启动服务。

**成功标志**：右下角输出框里出现：

```text
[信息] ShadowsocksR 安装完成！
===================================================
 ShadowsocksR 配置信息：

 IP地址 : 1.2.3.4
 端口   : 8388
 密码   : password123
 加密   : rc4-md5
 协议   : origin
 混淆   : plain
```

**⚠️ 看到 `8388` 和 `password123` 就说明你用的是默认值 —— 一定要改（见第 7 步）。**

> ⚠️ 安装脚本会从 `https://github.com/ToyoDAdoubi/shadowsocksr/archive/manyuser.zip` 下载 SSR 源码。**这个上游仓库已停止活跃维护**，如果下载失败会看到「ShadowsocksR 下载失败 !」，见 [九、常见问题排查](#九常见问题排查)。

### 第 6 步：把 SSR 端口映射到宿主机（**必做**）

**这一步在干什么**：Docker 默认只把你在 `ports:` 里写明的端口暴露出来。`docker-compose.yml` 里目前只有 `8080:8080`，**所以 SSR 的 8388 端口外面根本连不到。**

编辑 `docker-compose.yml`：

```yaml
services:
  web:
    build: .
    container_name: ssr-web-manager
    ports:
      - "8080:8080"
      - "8388:8388"     # ← 加这一行：SSR 端口
    restart: unless-stopped
```

然后重建：

```bash
docker compose up -d --build
```

**成功标志**：

```bash
docker compose ps
```

PORTS 列变成：

```text
0.0.0.0:8080->8080/tcp, 0.0.0.0:8388->8388/tcp
```

> 如果你改了 SSR 端口，这里的 `8388` 也要跟着改成一样的数字。

### 第 7 步：改密码（**必做**）

**当前的面板按钮改不了密码**（原因见 [10.1](#101-修改配置按钮有命令注入漏洞)、[10.2](#102-修改配置按钮当前跑不通)）。

**用命令行改**，最省事：

```bash
docker compose exec web bash -lc '
  jq ".password = \"你的新密码\"" /usr/local/shadowsocksr/config.json > /tmp/c.json &&
  mv /tmp/c.json /usr/local/shadowsocksr/config.json &&
  /etc/init.d/ssr restart
'
```

**成功标志**：再点一次「查看账号信息」，密码已经变成新值。

> 更完整的改配置方法见 [7.3 手动修改 SSR 配置](#73-手动修改-ssr-配置)。

### 第 8 步：放行端口 + 导入客户端

1. 云控制台安全组放行 **TCP 8388**（需要 UDP 的话再放行 **UDP 8388**）
2. 点「查看账号信息」，把 IP / 端口 / 密码抄到客户端
3. 客户端的加密 / 协议 / 混淆固定填：`rc4-md5` / `origin` / `plain`

**成功标志**：客户端显示「已连接」。

### 在宝塔面板（BT）中部署

**方式一：在「Docker 管理器」中导入 `docker-compose.yml`，一键启动。**

**方式二：构建镜像并运行容器**（在宝塔终端执行）：

```bash
docker build -t ssr-web-manager:latest .

docker run -d --name ssr-web-manager \
  -p 8080:8080 \
  -p 8388:8388 \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  ssr-web-manager:latest
```

> ⚠️ 容器内的 iptables / BBR 只影响容器自己的网络命名空间。要在宿主机层面放行端口，请去宿主机防火墙或云安全组里操作。
>
> ⚠️ 用 `docker run` 时注意**必须加上 `-p 8388:8388`**，否则面板能开但客户端连不上。

---

<a id="七详细说明"></a>
## 七、详细说明

### 7.1 端口一览

| 端口 | 谁在用 | 默认值 | 在哪改 |
| --- | --- | --- | --- |
| **8080** | **网页面板**（Flask） | 8080 | 改 `docker-compose.yml` 的 `ports:` 和 `environment: PORT=`，两处要一致 |
| **8388** | **SSR 代理服务** | 8388 | 面板「修改配置」（当前不可用）或进容器手动改，见 [7.3](#73-手动修改-ssr-配置) |

面板监听地址是 `0.0.0.0`（代码里写死的），所以只要防火墙放行，外网就能访问。

**改面板端口的正确做法**（以改成 9090 为例）：

```yaml
services:
  web:
    ports:
      - "9090:9090"
    environment:
      - PORT=9090
```

```bash
docker compose up -d --build
```

然后访问 `http://你的IP:9090`。

> ⚠️ **只改 `ports:` 不改 `PORT` 环境变量是不行的** —— 容器里的 Flask 还监听 8080，映射不到 9090，页面会打不开。

<a id="72-端口映射很重要"></a>
### 7.2 端口映射（很重要）

Docker 的端口映射规则是 **「宿主机端口:容器端口」**，容器里跑的什么，容器里就还是什么。

本项目涉及两个服务：

| 服务 | 在容器里监听 | 需要映射到宿主机吗 | 不映射会怎样 |
| --- | --- | --- | --- |
| 面板（Flask） | 8080 | **必须**（`8080:8080` 已有） | 浏览器打不开面板 |
| SSR | 8388 | **必须**（默认**没有**，要自己加） | **面板能用，但客户端连不上 SSR** |

**除了 `ports:`，还别忘了云安全组**。容器里的 iptables 规则只对容器网络命名空间生效，**不影响云厂商的宿主机防火墙**。

**方案 B：host 网络模式**（更省事，端口自动直通）

```yaml
services:
  web:
    build: .
    container_name: ssr-web-manager
    network_mode: host
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    volumes:
      - ./ssr_simplified.sh:/app/ssr_simplified.sh:ro
```

用 host 模式时**不要再写 `ports:`**（写了会报错），面板和 SSR 都直接监听宿主机端口。

⚠️ **但要清楚代价**：host 模式下，容器里 `iptables` 改的是**宿主机**的防火墙规则；而且面板的 8080 会直接暴露在公网上，**无鉴权**（见 [十一](#十一安全注意事项)）。

<a id="73-手动修改-ssr-配置"></a>
### 7.3 手动修改 SSR 配置

**方法一：进容器改（推荐）**

```bash
# 进容器
docker compose exec web bash

# 看当前配置
cat /usr/local/shadowsocksr/config.json

# 用 jq 改密码（jq 已经装在容器里了）
jq '.password = "你的新密码"' /usr/local/shadowsocksr/config.json > /tmp/c.json
mv /tmp/c.json /usr/local/shadowsocksr/config.json

# 改端口
jq '.server_port = 9999' /usr/local/shadowsocksr/config.json > /tmp/c.json
mv /tmp/c.json /usr/local/shadowsocksr/config.json

# 重启生效
/etc/init.d/ssr restart
```

**方法二：直接用脚本函数**

```bash
docker compose exec web bash -lc 'source /app/ssr_simplified.sh; Modify_config_password'
```

⚠️ 注意这个命令会**进入脚本顶层的交互菜单**（脚本最后会 `read` 一个 1-11 的数字）。按提示操作即可。

**改完记得**：

1. 同步改 `docker-compose.yml` 的端口映射
2. 同步改云安全组规则
3. 同步改客户端

### 7.4 默认值一览

| 项目 | 默认值 | 在哪定义 |
| --- | --- | --- |
| 面板端口 | `8080` | `docker-compose.yml` 的 `PORT` / `app/main.py` |
| SSR 端口 | `8388` | `ssr_simplified.sh` → `Set_config_port()` |
| SSR 密码 | `password123` | `ssr_simplified.sh` → `Set_config_password()` |
| 加密方式 | `rc4-md5` | `ssr_simplified.sh` → `Set_config_all()`，**写死不可改** |
| 协议 | `origin` | 同上，**写死不可改** |
| 混淆 | `plain` | 同上，**写死不可改** |
| 服务端监听 | `0.0.0.0` | `Write_configuration()` |
| 连接超时 | `120` 秒 | `Write_configuration()` |
| worker 数 | `1` | `Write_configuration()` |

<a id="75-配置持久化很重要"></a>
### 7.5 配置持久化（很重要）

**当前 `docker-compose.yml` 只挂载了一个文件**：

```yaml
volumes:
  - ./ssr_simplified.sh:/app/ssr_simplified.sh:ro
```

也就是说：

| 操作 | SSR 配置会丢吗 |
| --- | --- |
| `docker compose stop` 然后 `docker compose start` | ❌ 不会丢（容器还在） |
| `docker compose restart` | ❌ 不会丢 |
| `docker compose down` 再 `up` | ✅ **会丢** |
| `docker compose up -d --build`（带 `--build`） | ✅ **会丢** |
| `docker system prune` / 删了重建容器 | ✅ **会丢** |

因为 SSR 的配置在容器内的 `/usr/local/shadowsocksr/config.json`，**没有挂载到宿主机**。

**想保住配置，就加一个 volume 挂载**：

```yaml
volumes:
  - ./ssr_simplified.sh:/app/ssr_simplified.sh:ro
  - ./ssr-data:/usr/local/shadowsocksr
```

这样 `/usr/local/shadowsocksr` 目录就落在宿主机上了，容器随便重建都不怕。

> ⚠️ 注意：容器里的 SSR **不是用 systemd 管的**，用的是 SysV 的 `/etc/init.d/ssr`。这个 init 脚本在容器重建后需要重新执行 `update-rc.d` 之类的初始化，所以严格来说**挂载目录后重启容器，SSR 服务不一定自动起来**，需要在容器里跑一次 `/etc/init.d/ssr start`。这是本项目「简化」带来的固有局限。

### 7.6 BBR 在容器里的效果

BBR 是**内核级**的 TCP 拥塞控制算法。

- 容器和宿主机**共用同一个内核**，所以宿主机开了 BBR，容器里的 SSR 也能受益
- 但容器里的 `sysctl` 写操作**只影响容器自己的网络命名空间**，改不了宿主机的全局设置
- 脚本里 `Configure_BBR` 会去下载 `https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/bbr.sh` —— **这个上游仓库也已归档**，下载可能失败

**结论**：**BBR 建议直接在宿主机上开**，不要指望容器面板。宿主机上开的方式：

```bash
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p
```

<a id="77-scriptsinstallsh-到底做了什么"></a>
### 7.7 `scripts/install.sh` 到底做了什么

```bash
# 1. 没装 docker 就装（官方脚本）
curl -fsSL https://get.docker.com | bash

# 2. 没有 compose 插件就装 v2.27.0
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-$(uname -s)-$(uname -m) -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# 3. 回到仓库根目录，起容器
cd "$SCRIPT_DIR/.."
docker compose up -d --build
```

**⚠️ 正确的用法是先克隆再执行**：

```bash
git clone https://github.com/aiwozhonghua81/SSR-Web.git
cd SSR-Web
bash scripts/install.sh
```

脚本本身的地址是：

```text
https://raw.githubusercontent.com/aiwozhonghua81/SSR-Web/main/scripts/install.sh
```

**为什么不能直接 `curl ... | bash`？**

脚本靠 `${BASH_SOURCE[0]}` 找自己的位置，定位到仓库根目录再执行 `docker compose up`。当脚本是**从管道喂给 bash** 执行时，`BASH_SOURCE[0]` 会变成 `bash`，脚本会跳到「当前目录的上一级」去找 `docker-compose.yml`，**找不到就会失败**。

> 所以本文件末尾没有提供「一条命令装完」的写法 —— 那条命令是错的。

**如果一定要用管道方式**，至少要先保证当前目录的**上一级**存在 `docker-compose.yml`（也就是先 clone 再 `cd SSR-Web`，让脚本从本地文件执行）：

```bash
# 先 clone，再从本地文件执行（脚本能正确定位仓库根目录）
git clone https://github.com/aiwozhonghua81/SSR-Web.git
cd SSR-Web
bash scripts/install.sh
```

### 7.8 容器内的关键路径

| 路径 | 说明 |
| --- | --- |
| `/app/app/` | Flask 应用代码 |
| `/app/ssr_simplified.sh` | SSR 管理脚本（从宿主机挂载进来，只读） |
| `/usr/local/shadowsocksr/` | **SSR 安装目录**（配置 `config.json`、程序、`jq` 都在这） |
| `/usr/local/shadowsocksr/config.json` | SSR 主配置 |
| `/usr/local/shadowsocksr/shadowsocks/ssserver.log` | SSR 日志文件 |
| `/usr/local/shadowsocksr/jq` | JSON 解析器（二进制） |
| `/etc/init.d/ssr` | SSR 的 SysV 启停脚本 |
| `/etc/iptables.up.rules` | iptables 规则持久化文件 |

---

<a id="八目录结构"></a>
## 八、目录结构

```
SSR-Web/
├─ app/
│  ├─ main.py             # Flask 后端（路由 + 调用 shell 脚本）
│  ├─ ssr_bridge.py       # 桥接层占位（目前只有注释）
│  ├─ templates/
│  │  └─ index.html       # 面板页面，11 个按钮
│  └─ static/
│     ├─ main.css
│     └─ main.js
├─ scripts/
│  └─ install.sh          # 装 Docker + Compose + 起容器
├─ ssr_simplified.sh      # SSR 管理脚本（容器内使用，也挂载到宿主）
├─ Dockerfile              # debian:12-slim + Flask
├─ docker-compose.yml     # 端口 8080、NET_ADMIN、sysctl、挂载
├─ requirements.txt       # flask==3.0.3
├─ .gitignore
└─ README.md
```

| 路径 | 说明 |
| --- | --- |
| `app/main.py` | **Flask 后端**，全部逻辑都在这里 |
| `app/ssr_bridge.py` | 预留的「更细颗粒控制」占位文件，目前只有两行注释 |
| `scripts/install.sh` | 一键装 Docker + Compose + 起容器 |
| `ssr_simplified.sh` | **核心**：被集成进来的 SSR 管理脚本（530 行） |
| `Dockerfile` | 镜像定义，基于 `debian:12-slim` |
| `docker-compose.yml` | 编排定义：端口、权限、挂载 |
| `requirements.txt` | Python 依赖，只有一行 `flask==3.0.3` |

**后端调用链**（点一下按钮会发生什么）：

```text
浏览器点击按钮
   ↓
app/static/main.js  →  fetch('POST /api/action', {action: "install"})
   ↓
app/main.py  →  run_ssr_function("Install_SSR")
   ↓
subprocess.run("bash -lc 'source /app/ssr_simplified.sh; Install_SSR'")
   ↓
ssr_simplified.sh 里的 Install_SSR() 真正干活
   ↓
stdout + stderr 原样返回给浏览器，显示在右下角灰框里
```

---

<a id="九常见问题排查"></a>
## 九、常见问题排查

| 现象 | 原因 | 怎么办 |
| --- | --- | --- |
| `docker compose ps` 显示容器一直 `Restarting` | 启动命令崩了 | `docker compose logs --tail=50 web` 看日志 |
| 浏览器打不开面板 | 云安全组 / 服务器防火墙没放行 8080 | 放行 8080 的 TCP；本机检查 `ss -lntp \| grep 8080` |
| 面板能开，但客户端连不上 SSR | **SSR 端口没做端口映射**（最常见） | 在 `docker-compose.yml` 的 `ports:` 里加 `"8388:8388"`，见 [7.2](#72-端口映射很重要) |
| 改完端口映射还是连不上 | 云安全组没同步改 | 云控制台加 TCP / UDP 新端口 |
| 点「安装 SSR」报「ShadowsocksR 下载失败 !」 | 上游 `manyuser.zip` 下载不到（上游仓库已归档 / 网络不通） | 换网络环境重试；或手动把 SSR 目录放进容器 |
| 点「安装 SSR」报「检测到 ShadowsocksR 已安装」 | 容器里已经有 `config.json` | 说明之前装过了。想重装就先删掉容器再 `up` |
| 面板显示的 IP 是内网地址 | 容器里拿不到公网 IP（`ipinfo.io` 等被墙） | 客户端里手动填你的服务器公网 IP |
| 点「查看账号信息」显示 `JQ解析器 不存在` | 安装过程没走完 | 重新点一次「安装 SSR」；或手动装 jq |
| 点「查看日志」页面卡住不动 | 脚本用的是 `tail -f`，永远不会自己结束 | 后端 300 秒后会返回 `Execution timeout`。想看日志用命令行：`docker compose exec web tail -f /usr/local/shadowsocksr/shadowsocks/ssserver.log` |
| 点「修改配置」返回 `rc: 127` / `Modify_Config: command not found` | 后端把 `source` 放在管道里，函数在子 shell 中，父 shell 调不到 | 见 [10.2](#102-修改配置按钮当前跑不通)，临时用命令行改 |
| 点「卸载 SSR」什么都没发生 | 脚本要交互确认，面板没输入框 | 见 [10.3](#103-卸载和-config_bbr-按钮实际不生效)，用命令行卸载 |
| 点「配置 BBR」什么都没发生 | 同上，脚本要选 1-4 | 见 [10.3](#103-卸载和-config_bbr-按钮实际不生效)，在宿主机上开 BBR |
| 容器重建后配置全没了 | 配置没挂载到宿主机 | 见 [7.5](#75-配置持久化很重要)，加 volume 挂载 |
| 容器里的 SSR 重启机器后没起来 | 容器里用的是 SysV init，不是 systemd | 手动 `docker compose exec web /etc/init.d/ssr start` |
| 端口被占用起不来 | 宿主机 8080 或 8388 已被占用 | `ss -lntp \| grep -E '8080\|8388'` 看是谁占的 |
| `docker compose up` 卡在拉镜像 | 服务器连不上 Docker Hub | 配国内镜像加速源 |

---

<a id="十已知问题与限制"></a>
## 十、已知问题与限制

这一节写的是**读代码 + 实际验证**出来的问题，不是猜测。

<a id="101-修改配置按钮有命令注入漏洞"></a>
### 10.1 「修改配置」按钮有命令注入漏洞

`app/main.py` 的 `run_ssr_function()` 把用户输入的 `payload` **直接拼进 shell 命令**：

```python
cmd = f"bash -lc 'printf %s \"\"\"{input_text}\"\"\" | source {SSR_SCRIPT}; {func_name}'"
completed = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
```

`{input_text}` 没有任何转义。只要 payload 里带一个单引号，就能**跳出 `bash -lc '...'` 的引号**，后面的内容会被外层 shell 当命令执行。

**已实测验证**，构造 payload：

```text
x'; echo INJECTION_RAN; id -un; #
```

拼接后变成：

```bash
bash -lc 'printf %s """x'; echo INJECTION_RAN; id -un; #""" | source /app/ssr_simplified.sh; Modify_Config'
```

实测输出：

```text
INJECTION_RAN
root
```

也就是说 —— **任何能访问面板的人，都可以在容器里以 root 身份执行任意命令**（容器内是 root，且带 `NET_ADMIN` 权限）。再加上面板**没有任何鉴权**，这是一个可以直接利用的远程代码执行。

**修复思路**（改 `app/main.py`）：

```python
# 不要把用户输入拼进命令行；改成走 stdin，并禁用 shell
completed = subprocess.run(
    ["bash", "-c", f"source {SSR_SCRIPT}; {func_name}"],
    input=input_text,
    capture_output=True, text=True, timeout=300,
)
```

`input=` 走的是管道，**不经过 shell 解析**，单引号、换行、`;`、`|` 全都变成普通字符。

<a id="102-修改配置按钮当前跑不通"></a>
### 10.2 「修改配置」按钮当前跑不通

即使不注入任何东西，`modify` 这个 action 也是坏的。

原因还是上面那行命令：写成 `printf ... | source script; Modify_Config` 时，**`source` 处于管道的子 shell 里**，它定义的函数在父 shell 中并不存在。

**已实测验证**（`rc = 127`，`bash: Modify_Config: command not found`）：

```bash
bash -lc 'printf %s """123""" | source /tmp/script.sh; Modify_Config'
# → bash: Modify_Config: command not found
# → rc=127
```

对比不带 payload 的写法（其他 10 个 action 用的就是这个），工作正常：

```bash
bash -lc 'source /tmp/script.sh; Install_SSR'
# → 正常执行
```

**修复思路**：用 `input=` 参数喂 stdin，而不是用管道 + `source`（同 10.1 的改法）。

<a id="103-卸载和-config_bbr-按钮实际不生效"></a>
### 10.3 「卸载」和「配置 BBR」按钮实际不生效

`Uninstall_SSR()` 里有一句：

```bash
echo "确定要 卸载 ShadowsocksR？[y/N]"
read -e -p "(默认: n):" unyn
[[ -z ${unyn} ]] && unyn="n"
```

`Configure_BBR()` 里有一句：

```bash
read -e -p "(默认: 取消):" bbr_num
```

面板通过 `subprocess.run(..., capture_output=True)` 调用时**没有提供 stdin**，子进程读到的是 EOF，`read` 拿不到任何输入。

结果：

- **卸载**：`unyn` 为空 → 被赋值为 `n` → 走到「卸载已取消」，**什么都没删**
- **配置 BBR**：`bbr_num` 为空 → 走到「已取消...」

**临时解决办法**：直接进容器操作。

```bash
# 卸载
docker compose exec web bash -lc 'source /app/ssr_simplified.sh; Uninstall_SSR' <<< "y"

# BBR（宿主机上开更靠谱）
docker compose exec web bash -lc 'source /app/ssr_simplified.sh; Configure_BBR' <<< "4"
```

<a id="104-查看日志按钮会卡满-300-秒"></a>
### 10.4 「查看日志」按钮会卡满 300 秒

`View_Log()` 用的是 `tail -f`，这个命令**永远不会自己退出**。后端 `subprocess.run` 会一直等，等到 `timeout=300` 秒才抛 `TimeoutExpired`，接口返回 `{"ok": false, "output": "Execution timeout"}`。

**临时解决办法**：

```bash
docker compose exec web tail -f /usr/local/shadowsocksr/shadowsocks/ssserver.log
```

<a id="105-更新-ssr-按钮大概率失败"></a>
### 10.5 「更新 SSR」按钮大概率失败

`Update_SSR()` 里执行的是：

```bash
cd ${ssr_folder}
git pull
```

但安装时 `Download_SSR()` 是**下载 zip 压缩包再解压**（`wget .../archive/manyuser.zip` + `unzip`），**整个脚本里没有任何 `git clone`**。所以 `/usr/local/shadowsocksr` 里通常**没有 `.git` 目录**，`git pull` 会报：

```text
fatal: not a git repository (or any of the parent directories): .git
```

### 10.6 其他限制

| 限制 | 说明 |
| --- | --- |
| 加密 / 协议 / 混淆不可改 | 写死 `rc4-md5 / origin / plain`。而且 `origin` + `plain` 组合的**特征非常明显**，抗探测能力弱 |
| 没有鉴权 | 见 [十一](#十一安全注意事项) |
| 没有 HTTPS | Flask 跑的是明文 HTTP，密码在网络上是裸奔的 |
| 用 Flask 内置服务器 | 不是 gunicorn / uwsgi，生产环境性能和安全都一般 |
| 单节点 | 没有多用户、没有流量统计、没有订阅链接 |
| 配置不持久 | 见 [7.5](#75-配置持久化很重要) |
| 上游已归档 | SSR 本体（`ToyoDAdoubi/shadowsocksr`）和 BBR 脚本（`ToyoDAdoubi/doubi`）都已停止维护 |

---

<a id="十一安全注意事项"></a>
## 十一、安全注意事项

### 🚨 最要紧的三条

**1. 不要把面板端口直接暴露到公网**

面板**没有任何登录验证**。任何扫到 8080 端口的人都能：

- 点「查看账号信息」**直接看到你的 SSR 密码**
- 点「修改配置」**改掉你的 SSR 端口和密码**（虽然当前这个按钮坏了，但 [10.1](#101-修改配置按钮有命令注入漏洞) 的命令注入是能用的）
- 点「卸载 SSR」（当前不生效，但这是代码作者本来的意图）

**推荐的加固方式（任选其一，从简单到复杂）**：

**方式 A：只监听本机 + SSH 隧道访问**

```yaml
ports:
  - "127.0.0.1:8080:8080"
```

然后在你自己的电脑上：

```bash
ssh -N -L 8080:127.0.0.1:8080 root@你的服务器IP
```

浏览器访问 `http://127.0.0.1:8080`。**这是最省事也最安全的做法。**

**方式 B：加 Nginx 反代 + HTTPS + Basic Auth**

用 Nginx / Caddy 做一层反代，加上域名、HTTPS 证书和密码认证，再把 8080 收回成 `127.0.0.1:8080`。

**方式 C：只放行固定 IP**

云安全组里把 8080 的来源改成你自己的公网 IP，而不是 `0.0.0.0/0`。

### 2. 改掉默认密码

`password123` 这种密码在公开的密码字典里，**几秒就能被爆破**。装完第一件事就是改。

### 3. 修掉命令注入

在改代码之前，**至少不要让面板暴露在公网**。修复方法见 [10.1](#101-修改配置按钮有命令注入漏洞)。

### 其他常规建议

- ✅ 云安全组**只放行实际需要的端口**
- ✅ SSH 用密钥登录，禁掉 root 密码登录
- ✅ 定期 `docker compose logs` 翻翻面板日志
- ✅ 定期 `apt update && apt upgrade`
- ✅ 不要在公开仓库、截图、群里分享 `ss://` 链接和二维码（里面是密码）
- ❌ 不要把 `docker-compose.yml` 里 `ports:` 写成 `0.0.0.0:8080:8080` 又指望它安全

### 合规提醒

请只在你**拥有或获准管理**的服务器和网络环境中使用本项目，并遵守所在地法律法规、云服务商条款和网络管理要求。

---

<a id="十二卸载"></a>
## 十二、卸载

### 卸载面板

```bash
cd SSR-Web

# 停掉并删除容器（会一起删掉网络）
docker compose down

# 顺便把构建出来的镜像也删了
docker compose down --rmi local
```

### 卸载 SSR 服务端（容器内）

面板的「卸载 SSR」按钮当前不生效（见 [10.3](#103-卸载和-config_bbr-按钮实际不生效)），用命令行：

```bash
docker compose exec web bash -lc 'source /app/ssr_simplified.sh; Uninstall_SSR' <<< "y"
```

这会：停进程 → 删 iptables 规则 → 移除 SysV 服务 → 删掉 `/usr/local/shadowsocksr` 目录。

### 彻底删干净

```bash
# 1. 删容器和镜像
docker compose down --rmi local

# 2. 删掉仓库
cd .. && rm -rf SSR-Web

# 3. 如果用了 host 网络模式，检查宿主机残留的 iptables 规则
sudo iptables -L INPUT -n --line-numbers | grep -E '8388|ssr'
```

### 回滚

本项目**不修改宿主机上任何已有的服务配置**（除了 `NET_ADMIN` 容器内的 iptables 和 `sysctls` 里的 `net.ipv4.ip_forward=1`），所以回滚就是 `docker compose down` 再把 `docker-compose.yml` 改回去即可。

---

<a id="十三许可证与致谢"></a>
## 十三、许可证与致谢

### 许可证

**MIT**

### 上游项目

本项目集成了以下开源项目的脚本逻辑：

| 项目 | 地址 | 用途 |
| --- | --- | --- |
| ShadowsocksR (manyuser) | https://github.com/ToyoDAdoubi/shadowsocksr | SSR 服务端本体 |
| ShadowsocksR 服务脚本 | https://github.com/ToyoDAdoubi/doubi | `/etc/init.d/ssr` 启停脚本、BBR 脚本 |
| Flask | https://github.com/pallets/flask | Web 后端框架 |

### ⚠️ 上游状态提醒

`ToyoDAdoubi/shadowsocksr` 和 `ToyoDAdoubi/doubi` 都**已经归档、停止维护**。这意味着：

- SSR 服务端可能拿不到最新版本
- `bbr.sh` 可能下载失败
- `manyuser.zip` 可能下载不到

如果遇到下载失败，这是上游的问题，不是本项目的 bug。

### 本项目自检

```bash
# 看容器状态
docker compose ps

# 看面板日志
docker compose logs --tail=50 web

# 进容器手动操作
docker compose exec web bash
```

---

如果这份说明帮到你了，欢迎点个 ⭐ Star。有问题去 [Issues](https://github.com/aiwozhonghua81/SSR-Web/issues) 提。
