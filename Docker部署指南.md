# mimo2api Docker 部署指南（一键安装版）

> 推荐部署方式。比直接装 Python 更省心：环境隔离、一键启停、随时迁移。
> 本文档假设你已经安装好了 Docker。如果没装，看第 1 节。

---

## 目录

1. 准备：安装 Docker
2. 三步快速启动（最简版）
3. 详细启动流程
4. 配置说明
5. 日常管理命令
6. 数据持久化与备份
7. 升级与重建
8. 修改端口 / 暴露到公网
9. 常见问题
10. 文件清单

---

## 1. 准备：安装 Docker

### 1.1 macOS

下载安装 Docker Desktop：https://www.docker.com/products/docker-desktop/

装完打开 Docker.app，等右上角 Docker 图标变成稳定状态。验证：

```bash
docker --version
docker compose version
```

### 1.2 Linux（Ubuntu / Debian / CentOS）

一键脚本：

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker

# 让当前用户免 sudo 用 docker（重新登录后生效）
sudo usermod -aG docker $USER
```

验证：

```bash
docker --version
docker compose version
```

### 1.3 国内服务器加速（强烈推荐）

国内拉镜像太慢，配置加速器：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://docker.nju.edu.cn"
  ]
}
EOF
sudo systemctl restart docker
```

---

## 2. 三步快速启动（最简版）

```bash
# 1. 进入项目目录
cd "/Users/admin/Desktop/本地部署/mimo2api/mimi3-master"

# 2. 运行一键脚本
chmod +x start.sh && ./start.sh

# 3. 打开浏览器访问
# http://127.0.0.1:8000/
```

`start.sh` 会自动完成：检测 Docker、生成 `.env`、创建必要目录、构建镜像、启动容器。

首次构建会下载基础镜像和依赖，预计 2-5 分钟（视网速）。后续启动只需几秒。

---

## 3. 详细启动流程

如果你想理解每一步在干什么，按下面顺序手动操作。

### 3.1 进入项目目录

```bash
cd "/Users/admin/Desktop/本地部署/mimo2api/mimi3-master"
```

### 3.2 准备配置文件

```bash
cp env.example .env
```

用任何编辑器打开 `.env`，至少建议设置：

```
MIMO_RELAY_OPENAI_KEY=sk-换成你自己的长随机串
MIMO_WEBUI_USERNAME=admin
MIMO_WEBUI_PASSWORD=换成自己的密码
MIMO_WEBUI_SECRET=换成至少32位的随机字符
```

生成随机串小技巧：

```bash
openssl rand -hex 32
```

### 3.3 准备必要目录

```bash
mkdir -p users logs data
[ -f model_mapping.json ] || echo '{}' > model_mapping.json
```

### 3.4 构建镜像

```bash
docker compose build
```

### 3.5 启动容器

```bash
docker compose up -d
```

`-d` 表示后台运行。第一次启动需要 10-30 秒等服务就绪。

### 3.6 查看状态

```bash
docker compose ps
```

应该看到 `mimo2api` 状态为 `Up` 或 `healthy`。

### 3.7 实时日志

```bash
docker compose logs -f
```

看到下面这行说明已就绪：

```
Uvicorn running on http://0.0.0.0:8000
```

按 `Ctrl + C` 退出日志查看（不会停服务）。

### 3.8 访问 WebUI

浏览器打开：http://127.0.0.1:8000/

---

## 4. 配置说明

### 4.1 配置文件优先级

环境变量加载顺序（后者覆盖前者）：

1. Dockerfile 中的 `ENV`
2. `.env` 文件（通过 `env_file` 自动注入）
3. `docker-compose.yml` 中的 `environment` 段

### 4.2 关键文件清单

```
mimi3-master/
├── Dockerfile              # 镜像构建配置
├── docker-compose.yml      # 容器编排配置
├── .dockerignore           # 构建时排除的文件
├── start.sh                # 一键启动脚本
├── requirements.txt        # Python 依赖
├── .env                    # 你的运行配置（首次启动后生成）
├── env.example             # 配置模板
├── main.py                 # 程序主入口
├── mimo2api/               # 业务代码包
├── users/                  # 凭证目录（挂载持久化）
├── logs/                   # 日志目录（挂载持久化）
├── data/                   # 状态数据目录（挂载持久化）
└── model_mapping.json      # 模型映射（挂载持久化）
```

### 4.3 挂载关系一览

| 宿主机路径 | 容器内路径 | 用途 |
|-----------|-----------|------|
| `./users` | `/app/users` | 用户凭证 JSON 文件 |
| `./logs` | `/app/logs` | 日志输出 |
| `./data` | `/app/data` | 度量数据库 + 进程锁 |
| `./model_mapping.json` | `/app/model_mapping.json` | 模型名称映射 |
| `./.env` | 通过 `env_file` 注入环境变量 | 运行配置 |

宿主机这些路径下的内容会被持久化，容器删了也不丢。

---

## 5. 日常管理命令

所有命令都需要在 `mimi3-master/` 目录下执行。

### 5.1 查看状态

```bash
docker compose ps
```

### 5.2 实时日志

```bash
# 持续滚动看日志
docker compose logs -f

# 只看最后 100 行
docker compose logs --tail 100

# 看特定时间段
docker compose logs --since 30m
```

### 5.3 停止服务

```bash
docker compose stop
```

仅停止容器，不删除。下次 `start` 直接复用。

### 5.4 启动已停止的服务

```bash
docker compose start
```

### 5.5 重启服务

```bash
docker compose restart
```

改了 `.env` 后必须执行这条让配置生效。

### 5.6 销毁服务

```bash
docker compose down
```

停止并删除容器（数据卷里的内容仍在宿主机的 `users/`、`logs/`、`data/`）。

### 5.7 进容器内部排查

```bash
docker compose exec mimo2api bash
```

进去之后可以用 `ls`、`cat`、`python` 等命令排查问题。`exit` 退出。

### 5.8 直接执行临时命令

```bash
# 看 Python 版本
docker compose exec mimo2api python --version

# 看依赖列表
docker compose exec mimo2api pip list
```

---

## 6. 数据持久化与备份

### 6.1 哪些数据需要备份

| 数据 | 路径 | 重要性 |
|------|------|--------|
| 用户凭证 | `users/*.json` | 高（丢了要重新导入） |
| 运行配置 | `.env` | 高（含密码密钥） |
| 模型映射 | `model_mapping.json` | 中 |
| 度量数据库 | `data/gateway_metrics.db` | 低（历史指标） |
| 日志 | `logs/*.log` | 低（可丢） |

### 6.2 一键备份

```bash
cd "/Users/admin/Desktop/本地部署/mimo2api/mimi3-master"

tar -czf "mimo2api-backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
  .env users model_mapping.json data/gateway_metrics.db 2>/dev/null
```

会生成一个 `mimo2api-backup-20260518-143022.tar.gz` 之类的备份包。

### 6.3 恢复

```bash
# 停服务
docker compose down

# 解压备份到原位置
tar -xzf mimo2api-backup-xxx.tar.gz

# 重启
docker compose up -d
```

### 6.4 迁移到新机器

把整个 `mimi3-master` 目录打包上传到新机器，然后：

```bash
cd mimi3-master
docker compose up -d --build
```

镜像会自动重新构建，数据原样恢复。

---

## 7. 升级与重建

### 7.1 代码更新后重新构建

如果你修改了 `mimo2api/` 下的代码或 `requirements.txt`：

```bash
docker compose up -d --build
```

`--build` 会强制重新构建镜像，启动新版本。

### 7.2 强制完全重建（清缓存）

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### 7.3 清理无用镜像

```bash
docker image prune -f       # 删除未使用的镜像
docker system prune -af     # 清理所有未使用的资源（慎用）
```

---

## 8. 修改端口 / 暴露到公网

### 8.1 修改宿主机端口

编辑 `docker-compose.yml`，把 `ports` 那段改成你想要的：

```yaml
ports:
  - "18000:8000"     # 宿主机 18000 -> 容器 8000
```

然后：

```bash
docker compose up -d
```

注意：容器内部端口（右边的 `8000`）不要改，跟 `.env` 里 `SERVER_PORT` 保持一致即可。

### 8.2 局域网访问

容器默认监听 `0.0.0.0`，宿主机的 IP 可以直接被局域网访问。

查局域网 IP：

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'
```

然后在同网段其他设备访问：`http://局域网IP:8000/`

防火墙开放端口：

```bash
# Ubuntu
sudo ufw allow 8000/tcp

# CentOS
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --reload
```

### 8.3 公网访问

公网 IP 服务器直接用 `http://公网IP:8000/` 即可。

**强烈建议**配合 Nginx 反代 + HTTPS：

```nginx
server {
    listen 443 ssl http2;
    server_name api.your-domain.com;

    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
        proxy_buffering off;       # 流式响应必备
    }
}
```

证书可以用免费的 Let's Encrypt（acme.sh 或 certbot）。

---

## 9. 常见问题

### 9.1 `permission denied while trying to connect to the Docker daemon socket`

Linux 下当前用户没在 docker 组：

```bash
sudo usermod -aG docker $USER
```

执行完**注销重新登录**才生效。或临时加 `sudo`。

### 9.2 `port is already allocated` 端口被占用

宿主机 8000 端口被别的程序占了。改 `docker-compose.yml` 里的端口映射，比如改成 `"18000:8000"`。

### 9.3 容器一直 unhealthy

```bash
docker compose logs --tail 100
```

看最后的报错。最常见原因：

- `.env` 配置错误
- `users/` 里凭证格式有问题
- 端口冲突

### 9.4 容器启动后立刻退出

```bash
docker compose logs
```

看完整启动日志。一般会有 Python traceback，根据报错排查。

### 9.5 `Cannot connect to the Docker daemon`

Docker 服务没启动：

```bash
# Linux
sudo systemctl start docker

# macOS：手动打开 Docker.app
```

### 9.6 拉镜像超时 / 卡死

国内网络问题，参考 1.3 节配置镜像加速。或者用代理：

```bash
# 临时代理
export HTTPS_PROXY=http://127.0.0.1:7890
docker compose pull
```

### 9.7 改了 .env 没生效

容器启动后环境变量是被"冻结"的。改完必须重启：

```bash
docker compose restart
```

### 9.8 想看容器内某个文件

```bash
# 直接 cat
docker compose exec mimo2api cat /app/main.py

# 拷出来
docker compose cp mimo2api:/app/logs/gateway.log ./
```

### 9.9 磁盘空间被 Docker 占满

```bash
# 看 Docker 占用
docker system df

# 清理
docker system prune -af --volumes
```

注意：`--volumes` 会删除未挂载的卷，你的项目数据是 bind mount 挂的（`./users` 这种），不受影响。

### 9.10 fcntl 报错

Docker 容器底层是 Linux，`fcntl` 完全支持，不会有问题。如果真的报错说明镜像没用对，重新 `docker compose build --no-cache` 重建。

---

## 10. 文件清单

本次 Docker 化新增的文件：

| 文件 | 作用 |
|------|------|
| `Dockerfile` | 镜像构建配置 |
| `docker-compose.yml` | 容器编排配置 |
| `.dockerignore` | 排除无关文件，加快构建 |
| `start.sh` | 一键启动脚本 |
| `Docker部署指南.md` | 本文档 |

### 完整命令速查表

```bash
# 一键启动
./start.sh

# 手动构建启动
docker compose up -d --build

# 看日志
docker compose logs -f

# 重启（改完 .env 必做）
docker compose restart

# 停止
docker compose stop

# 销毁容器（数据保留）
docker compose down

# 完全清理（含镜像，慎用）
docker compose down --rmi all

# 进容器
docker compose exec mimo2api bash

# 备份
tar -czf mimo2api-backup-$(date +%Y%m%d).tar.gz \
  .env users model_mapping.json data/gateway_metrics.db
```

---

部署完后访问 `http://127.0.0.1:8000/` 验证。
有问题先看日志（`docker compose logs -f`），90% 的问题日志里都有提示。
