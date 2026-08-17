#!/usr/bin/env bash
# Langfuse 本机 demo 一键部署脚本。
#
# 用法：./deploy/up.sh [up|down|restart|logs|status]
#   默认动作 up：确保 .env 存在并填好随机密钥 → docker compose up -d → 等待 web 就绪 → 打印访问信息。
#
# 行为：
# - 若 deploy/.env 不存在，从 .env.example 拷一份；
# - 把 .env 里仍是 __replace_me__ 的 NEXTAUTH_SECRET / SALT / ENCRYPTION_KEY 替换成随机值
#   （ENCRYPTION_KEY 需 64 位十六进制，其余用 base64）；
# - 保留用户已填的其余字段（数据库凭证、LANGFUSE_INIT_* 引导键等）。
#
# 依赖：docker + docker compose（v2 plugin 即可）。脚本不依赖 CWD，全部路径相对自身。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

gen_base64() { openssl rand -base64 32; }
gen_hex64()  { openssl rand -hex 32; }  # 64 hex chars

ensure_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
      echo "❌ 找不到 $ENV_EXAMPLE，无法初始化 .env" >&2
      exit 1
    fi
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "✅ 已从 .env.example 创建 .env"
  fi
  chmod 600 "$ENV_FILE"

  local changed=0
  # 仅当值为占位符 __replace_me__ 时才替换，避免覆盖用户已填的密钥。
  # sed 分隔符用 | 而非 /，因 base64 输出含 /；base64 不含 &，故替换串无需转义 &。
  if grep -q '^NEXTAUTH_SECRET=__replace_me__' "$ENV_FILE"; then
    local v; v="$(gen_base64)"
    sed -i "s|^NEXTAUTH_SECRET=__replace_me__|NEXTAUTH_SECRET=$v|" "$ENV_FILE"
    echo "✅ 生成 NEXTAUTH_SECRET"; changed=1
  fi
  if grep -q '^SALT=__replace_me__' "$ENV_FILE"; then
    local v; v="$(gen_base64)"
    sed -i "s|^SALT=__replace_me__|SALT=$v|" "$ENV_FILE"
    echo "✅ 生成 SALT"; changed=1
  fi
  if grep -q '^ENCRYPTION_KEY=__replace_me__' "$ENV_FILE"; then
    local v; v="$(gen_hex64)"
    sed -i "s|^ENCRYPTION_KEY=__replace_me__|ENCRYPTION_KEY=$v|" "$ENV_FILE"
    echo "✅ 生成 ENCRYPTION_KEY（64 hex）"; changed=1
  fi
  if [[ $changed -eq 1 ]]; then
    echo "   密钥已写入 $ENV_FILE（该文件被 .gitignore 忽略，不会提交）"
  fi
}

wait_for_web() {
  local port; port="$(grep -E '^LANGFUSE_PORT=' "$ENV_FILE" | head -1 | cut -d= -f2 || true)"
  port="${port:-3100}"
  local url="http://localhost:${port}/api/public/health"
  echo "⏳ 等待 langfuse-web 就绪（${url}）..."
  local i=0
  for ((i=0; i<60; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "✅ langfuse-web 已就绪"
      return 0
    fi
    sleep 2
  done
  echo "⚠️  60s 内未探测到 web 健康，可运行 './deploy/up.sh logs' 排查" >&2
  return 1
}

print_info() {
  local port; port="$(grep -E '^LANGFUSE_PORT=' "$ENV_FILE" | head -1 | cut -d= -f2 || true)"
  port="${port:-3100}"
  local pk=""
  pk="$(grep -E '^LANGFUSE_INIT_PROJECT_PUBLIC_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2- || true)"
  echo
  echo "═══════════════════════════════════════════════════════════"
  echo " Langfuse 已启动：http://localhost:${port}"
  echo " OTLP 端点：     http://localhost:${port}/api/public/otel/v1/traces"
  if [[ -n "${pk}" ]]; then
    echo " 引导项目公钥：  ${pk}"
    echo " 引导项目私钥：  已写入 .env，不在终端显示"
  else
    echo " 未配置 LANGFUSE_INIT_*，请到 Web UI 注册后取项目公钥/私钥"
  fi
  echo " trace_url 配置：http://localhost:${port}/api/public/otel/v1/traces"
  echo "═══════════════════════════════════════════════════════════"
}

cmd_up() {
  ensure_env
  docker compose up -d
  wait_for_web || true
  print_info
}

cmd_down()    { docker compose down; }
cmd_restart() { docker compose down; cmd_up; }
cmd_logs()    { docker compose logs -f --tail=100; }
cmd_status()  { docker compose ps; }

action="${1:-up}"
case "$action" in
  up)      cmd_up ;;
  down)    cmd_down ;;
  restart) cmd_restart ;;
  logs)    cmd_logs ;;
  status)  cmd_status ;;
  *)
    echo "用法：$0 [up|down|restart|logs|status]" >&2
    exit 2
    ;;
esac
