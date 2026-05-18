# CasaOS 一键导入指南

> 本文档专门讲怎么把 mimi3 (mimo2api) 通过 CasaOS 应用商店的一键导入功能装到你的 NAS / 服务器上。
> 仓库地址：https://github.com/ikun5200/mimi3

---

## 目录

1. 整体方案概览
2. 第一步：让 GitHub 自动构建镜像
3. 第二步：把镜像设为公开
4. 第三步：CasaOS 一键导入
5. 第四步：首次启动配置
6. 升级与维护
7. 常见问题
8. 文件清单

---

## 1. 整体方案概览

CasaOS 一键导入需要一个**已经存在的 Docker 镜像**，所以整个流程是：

```
你的源代码（GitHub）
    │
    │ git push
    ▼
GitHub Actions（自动构建）
    │
    │ docker push
    ▼
GHCR 镜像仓库（ghcr.io/ikun5200/mimi3:latest）
    │
    │ docker pull
    ▼
CasaOS（一键导入 casaos-compose.yml）
    │
    │ docker run
    ▼
跑起来的容器
```

为此我准备了两个核心文件：

| 文件 | 路径（在仓库中的位置） | 作用 |
|------|----------------------|------|
| `casaos-compose.yml` | 仓库根目录 | CasaOS 一键导入用的配置 |
| `.github/workflows/docker-build.yml` | `.github/workflows/` | GitHub Actions 自动构建配置 |

它们已经放在你本地项目里了，只需要 push 到 GitHub 仓库即可生效。

---

## 2. 第一步：让 GitHub 自动构建镜像

### 2.1 push 文件到 GitHub

在本地项目目录执行：

```bash
cd "/Users/admin/Desktop/本地部署/mimo2api/mimi3-master"

# 把所有新文件加入 git
git add Dockerfile docker-compose.yml .dockerignore start.sh
git add casaos-compose.yml
git add .github/workflows/docker-build.yml
git add requirements.txt

git commit -m "Add Docker + CasaOS deployment files"
git push origin master
```

如果你还没初始化 git 或者 remote 没设：

```bash
git init
git remote add origin https://github.com/ikun5200/mimi3.git
git branch -M master
git add .
git commit -m "Initial commit"
git push -u origin master
```

### 2.2 开放 Actions 写包权限

push 完别急着等构建跑起来，先把权限设好，否则会卡在最后一步。

1. 浏览器打开仓库 https://github.com/ikun5200/mimi3
2. 顶部点 **Settings**
3. 左边栏 **Actions** -> **General**
4. 拉到底部 **Workflow permissions** 部分
5. 选中 `Read and write permissions`
6. 点 **Save**

### 2.3 等构建完成

回到仓库主页，点顶部的 **Actions** 标签页。你应该能看到一个名为 `Build and Push Docker Image` 的工作流正在运行。

第一次构建可能需要 5-10 分钟（因为要拉基础镜像、装依赖、跨平台编译）。后续构建有缓存会快很多。

成功标志：工作流变成绿色对勾，并且在 step "Image summary" 看到打印的镜像地址。

### 2.4 失败排查

如果工作流红了：

- **denied: installation not allowed** → 2.2 步权限没开
- **dockerfile not found** → 仓库根目录没有 `Dockerfile`，检查 push 内容
- **multi-platform build error** → 网络问题，重跑一次工作流（Actions 页面右上角有 Re-run 按钮）

---

## 3. 第二步：把镜像设为公开

GHCR 默认镜像是 **private** 的，CasaOS 拉的时候没登录就会失败。所以首次构建成功后必须改成 public。

### 3.1 找到镜像设置页

浏览器打开：

```
https://github.com/users/ikun5200/packages/container/mimi3/settings
```

或者：进入仓库 -> 右下角 **Packages** 区域 -> 点击 `mimi3` -> 右侧 **Package settings**

### 3.2 改成 public

拉到页面最底部 **Danger Zone**：

1. 点 **Change visibility**
2. 选 **Public**
3. 输入镜像名 `mimi3` 确认
4. 点击保存

成功后镜像页能匿名访问：https://github.com/ikun5200/mimi3/pkgs/container/mimi3

### 3.3 关联到仓库（推荐）

在镜像设置页 **Manage Actions access** 部分，把 `ikun5200/mimi3` 仓库加进来。这样后续 Actions 才有权限继续推新版本。

---

## 4. 第三步：CasaOS 一键导入

### 4.1 通过 URL 直接导入（推荐）

由于 `casaos-compose.yml` 已经 push 到仓库根目录，可以直接用 raw URL 导入：

```
https://raw.githubusercontent.com/ikun5200/mimi3/master/casaos-compose.yml
```

操作步骤：

1. 浏览器登录 CasaOS 桌面
2. 右上角点 **应用商店** 图标（购物袋图案）
3. 应用商店页面右上角点 **+** 号
4. 选择 **安装自定义应用**
5. 在 **Docker Compose** 输入框点 **导入** 或 **从 URL 加载**
6. 粘贴上面的 raw URL，点确定
7. CasaOS 会自动解析，弹出配置界面

### 4.2 通过粘贴 YAML 导入

如果你的 CasaOS 版本不支持 URL 导入：

1. 同样点 **+** -> **安装自定义应用**
2. 打开本地的 `casaos-compose.yml` 文件
3. 全选复制内容
4. 粘贴到 CasaOS 的 Docker Compose 输入框
5. 点 **安装**

### 4.3 配置启动参数

CasaOS 会自动识别 `x-casaos` 里定义的环境变量，列出可配置项。**必须修改的至少有三个**：

| 变量 | 推荐值 |
|------|--------|
| `MIMO_RELAY_OPENAI_KEY` | 一长串随机字符（用 `openssl rand -hex 32` 生成） |
| `MIMO_WEBUI_PASSWORD` | 你自己的强密码 |
| `MIMO_WEBUI_SECRET` | 另一串随机字符 |

端口默认 8000，如果你的 CasaOS 上 8000 已经被占了（CasaOS 自身可能用 80/8080），把 **WebUI port** 改成别的，比如 18000。

### 4.4 启动并等待就绪

点 **安装** 后 CasaOS 会：

1. 从 GHCR 拉取镜像（首次大约 1-3 分钟）
2. 创建容器和数据卷
3. 启动服务

完成后桌面会出现一个 `mimi3` 的应用图标。点击图标即可打开 WebUI。

---

## 5. 第四步：首次启动配置

### 5.1 访问 WebUI

点 CasaOS 桌面上的 `mimi3` 图标，或直接浏览器访问：

```
http://你的CasaOS-IP:8000/
```

用你在第 4.3 步设置的 `MIMO_WEBUI_USERNAME` 和 `MIMO_WEBUI_PASSWORD` 登录。

### 5.2 导入小米账号凭证

1. 浏览器另开一个标签，登录 https://aistudio.xiaomimimo.com
2. 按 F12 -> Network 标签 -> 刷新页面
3. 点任意请求 -> 找到 Request Headers 里的 Cookie 字段
4. 复制整个 Cookie 字符串
5. 回到 mimi3 WebUI，点"添加用户"，粘贴 Cookie 字符串，提交

成功后控制面板会出现一个节点，状态先是 CREATING，等几十秒变成 AVAILABLE 就代表可用了。

### 5.3 测试 API

在 CasaOS 服务器上 SSH 进去执行：

```bash
curl http://localhost:8000/v1/models \
  -H "Authorization: Bearer 你设置的MIMO_RELAY_OPENAI_KEY"
```

应该返回模型列表 JSON。

### 5.4 接入客户端

任何支持 OpenAI 协议的客户端配置：

- **Base URL**: `http://你的CasaOS-IP:8000/v1`
- **API Key**: 你设置的 `MIMO_RELAY_OPENAI_KEY`
- **Model**: `mimo-v2.5-pro` 或其他

---

## 6. 升级与维护

### 6.1 升级到最新版本

由于 GitHub Actions 在每次 push master 后自动重新构建镜像，要让 CasaOS 拉新版：

**方式 A：CasaOS UI 操作**

1. 在 CasaOS 桌面找到 `mimi3` 图标，长按或右键 -> **设置**
2. 找到 **更新镜像** 或类似按钮，点击

**方式 B：命令行**

SSH 到 CasaOS 服务器：

```bash
docker pull ghcr.io/ikun5200/mimi3:latest
docker restart mimi3
```

### 6.2 修改配置

在 CasaOS 桌面找到 `mimi3` 应用 -> 右键 -> **设置** -> 修改环境变量 -> **保存并重启容器**。

### 6.3 看日志

**CasaOS UI**：应用图标 -> 右键 -> **查看日志**

**命令行**：

```bash
docker logs -f mimi3
```

**容器内日志文件**：保存在 `/DATA/AppData/mimi3/logs/` 下，宿主机直接访问。

### 6.4 备份

CasaOS 把数据都放在 `/DATA/AppData/mimi3/` 下，备份整个目录即可：

```bash
sudo tar -czf mimi3-backup-$(date +%Y%m%d).tar.gz \
  /DATA/AppData/mimi3/users \
  /DATA/AppData/mimi3/data \
  /DATA/AppData/mimi3/model_mapping.json
```

### 6.5 卸载

CasaOS 桌面 -> 右键应用 -> **卸载**。

数据目录 `/DATA/AppData/mimi3/` **不会**自动删除，需要手动清理：

```bash
sudo rm -rf /DATA/AppData/mimi3
```

---

## 7. 常见问题

### 7.1 CasaOS 拉镜像失败：`unauthorized` 或 `denied`

GHCR 镜像还是 private 状态。回到第 3 节把镜像改成 public。

### 7.2 GitHub Actions 构建失败

打开 Actions 页面看具体报错。最常见三种：

- **权限不足**：见第 2.2 节开启 write 权限
- **Dockerfile 不存在**：检查 `Dockerfile` 是否在仓库根目录
- **arm64 构建超时**：跨架构编译比较慢，超时就在 Actions 页面 Re-run 一次

### 7.3 容器启动后立刻退出

CasaOS UI 看日志，常见原因：

- 端口冲突（CasaOS 自己占了 8000）→ 换成 18000 等其他端口
- `.env` 配置错误 → CasaOS 设置里检查变量
- 数据目录权限问题 → SSH 执行 `sudo chown -R 1000:1000 /DATA/AppData/mimi3`

### 7.4 容器跑起来了但 WebUI 打不开

- 检查 CasaOS 防火墙是否放行了端口
- `docker ps | grep mimi3` 看容器是否 healthy
- `curl http://localhost:8000/v1/models` 在 CasaOS 主机上测连通性

### 7.5 No available nodes / 没有可用节点

`/app/users/` 里没凭证，按第 5.2 节通过 WebUI 添加。

### 7.6 我没有公网 GitHub，能不能用 Docker Hub？

可以。把 GitHub Actions workflow 里的 `${{ env.REGISTRY }}` 换成 `docker.io`，并配置 `DOCKERHUB_USERNAME` 和 `DOCKERHUB_TOKEN` 两个 Secrets。然后把 `casaos-compose.yml` 里的镜像地址改成 `your-dockerhub-username/mimi3:latest`。

### 7.7 我想自己本地构建镜像不用 GHCR

在你的 CasaOS 服务器上执行：

```bash
ssh casaos-server
git clone https://github.com/ikun5200/mimi3.git
cd mimi3
docker build -t mimi3:local .
```

然后把 `casaos-compose.yml` 里的 `image:` 改成 `mimi3:local`，再走 CasaOS 一键导入流程。

### 7.8 镜像构建太慢

GitHub Actions 默认开 amd64 + arm64 双架构。如果你的 CasaOS 是 x86 服务器，可以把 workflow 里：

```yaml
platforms: linux/amd64,linux/arm64
```

改成：

```yaml
platforms: linux/amd64
```

构建速度会快一倍。

### 7.9 想用自己的图标

修改 `casaos-compose.yml` 里 `x-casaos.icon` 字段，指向你自己的图标 URL。推荐 PNG 格式、512x512 像素、放在仓库的 `assets/` 目录用 jsDelivr CDN 引用：

```yaml
icon: https://cdn.jsdelivr.net/gh/ikun5200/mimi3@master/assets/icon.png
```

### 7.10 同时跑多个实例

复制 `casaos-compose.yml` 改名 `casaos-compose-2.yml`，把里面所有 `mimi3` 换成 `mimi3-2`，端口换成不同的（比如 8001），重新导入即可。

---

## 8. 文件清单

为支持 CasaOS 一键导入，本次新增/相关的文件：

| 文件 | 路径 | 必须 | 说明 |
|------|------|------|------|
| `casaos-compose.yml` | 仓库根目录 | 是 | CasaOS 导入的 YAML，含 x-casaos 元数据 |
| `.github/workflows/docker-build.yml` | `.github/workflows/` | 推荐 | GitHub Actions 自动构建镜像 |
| `Dockerfile` | 仓库根目录 | 是 | 镜像构建脚本（已有） |
| `.dockerignore` | 仓库根目录 | 推荐 | 构建时排除无关文件（已有） |
| `requirements.txt` | 仓库根目录 | 是 | Python 依赖列表（已有） |

### 完整推送清单

```bash
git add Dockerfile
git add .dockerignore
git add docker-compose.yml
git add casaos-compose.yml
git add start.sh
git add requirements.txt
git add .github/workflows/docker-build.yml
git commit -m "Support CasaOS one-click deployment"
git push
```

push 完后等 Actions 构建完，去镜像设置改 public，再到 CasaOS 一键导入即可。

---

## 一句话总结

**Push 文件到 GitHub → 等 Actions 构建出 ghcr.io/ikun5200/mimi3:latest → 镜像改 public → CasaOS 应用商店导入 casaos-compose.yml 的 raw URL → 配置密码 → 完成。**

有任何步骤卡住，把报错截图或日志发我。
