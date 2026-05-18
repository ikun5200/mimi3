# ============================================================================
# mimo2api Dockerfile
# 基于 Python 3.11 slim，多阶段构建以减小体积
# ============================================================================

# ---------- 第一阶段：构建依赖 ----------
FROM python:3.11-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# 安装编译依赖（部分包可能需要 gcc）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 先拷贝 requirements.txt 利用层缓存
COPY requirements.txt .

# 安装到独立目录方便复制
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---------- 第二阶段：运行镜像 ----------
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Asia/Shanghai \
    MIMO_METRICS_DB_PATH=/app/data/gateway_metrics.db \
    MIMO_PROCESS_LOCK_PATH=/app/data/mimo2api.lock

WORKDIR /app

# 装运行期工具：tini 做 init，curl 做健康检查，tzdata 改时区
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    curl \
    tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# 从 builder 复制依赖
COPY --from=builder /install /usr/local

# 拷贝项目代码
COPY . .

# 创建持久化数据目录
RUN mkdir -p /app/users /app/logs /app/data

# 暴露服务端口
EXPOSE 8000

# 健康检查（每 30 秒查一次模型列表接口）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -fsS http://localhost:8000/v1/models > /dev/null || exit 1

# tini 作为 PID 1 保证子进程信号正确传递
ENTRYPOINT ["/usr/bin/tini", "--"]

# 启动网关
CMD ["python", "main.py"]
