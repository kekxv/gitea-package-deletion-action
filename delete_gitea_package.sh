#!/bin/bash

# --- 脚本说明 ---
# 功能: 删除 Gitea 实例中的一个指定包版本。
# 要求:
#   1. Gitea Personal Access Token 必须通过环境变量 GITEA_TOKEN 设置。
#      (例如: export GITEA_TOKEN="your_token_here")
#   2. Gitea 服务器地址和其他包信息通过命令行参数提供。

set -e  # 如果任何命令失败，立即退出脚本
set -o pipefail # 管道中的命令失败也会导致脚本退出

# --- 1. 配置检查 ---

# 检查 GITEA_TOKEN 环境变量是否设置
if [ -z "${GITEA_TOKEN}" ]; then
  echo "❌ 错误: 环境变量 GITEA_TOKEN 未设置。"
  echo "请先设置你的 Gitea Access Token:"
  echo "  export GITEA_TOKEN=\"your_personal_access_token\""
  exit 1
fi

# 检查命令行参数数量是否正确
if [ "$#" -ne 5 ]; then
    echo "❌ 错误: 参数数量不正确。"
    echo ""
    echo "使用方法: $0 <gitea_url> <owner> <package_type> <package_name> <version>"
    echo ""
    echo "参数说明:"
    echo "  gitea_url     - 你的 Gitea 实例地址 (例如: https://gitea.example.com)"
    echo "  owner         - 包的所有者 (用户名或组织名)"
    echo "  package_type  - 包的类型 (例如: maven, npm, generic)"
    echo "  package_name  - 包的名称"
    echo "  version       - 要删除的包的版本"
    echo ""
    echo "示例:"
    echo "  $0 https://mygitea.com my-org maven com.mycompany.app my-app 1.0.0-SNAPSHOT"
    exit 1
fi

# --- 2. 从参数中获取变量 ---

# 从命令行参数赋值
GITEA_URL="$1"
OWNER="$2"
PKG_TYPE="$3"
PKG_NAME="$4"
PKG_VERSION="$5"

# 清理可能存在于 URL 末尾的斜杠
GITEA_URL="${GITEA_URL%/}"

# --- 3. 执行删除操作 ---

# 构造 API URL
API_ENDPOINT="${GITEA_URL}/api/v1/packages/${OWNER}/${PKG_TYPE}/${PKG_NAME}/${PKG_VERSION}"

echo "🚀 准备删除 Gitea 包..."
echo "   - Gitea URL: ${GITEA_URL}"
echo "   - Owner:     ${OWNER}"
echo "   - Type:      ${PKG_TYPE}"
echo "   - Name:      ${PKG_NAME}"
echo "   - Version:   ${PKG_VERSION}"
echo "--------------------------------------------------------"
echo "API Endpoint: ${API_ENDPOINT}"
echo "--------------------------------------------------------"

# 使用 curl 发送 DELETE 请求
echo "⏳ 正在发送删除请求..."
# 保存响应到临时文件
response_file=$(mktemp)

# 执行 curl 命令，同时捕获 HTTP 状态码和响应内容
response_code=$(curl -s -w "%{http_code}" \
  -X DELETE \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -o "${response_file}" \
  "${API_ENDPOINT}" 2>&1)

curl_exit_code=$?

# --- 4. 结果处理 ---
# 检查状态码，404也算作成功（包不存在）
if [ "${response_code}" = "404" ]; then
    echo "✅ 包已不存在，HTTP 状态码: ${response_code}"
    echo "🎉 包 '${PKG_NAME}:${PKG_VERSION}' 视为成功删除。"
    rm "${response_file}"
    exit 0
elif [ $curl_exit_code -ne 0 ]; then
    echo "❌ 删除请求失败 (HTTP 状态码: ${response_code})"
    echo "详细错误信息:"
    cat "${response_file}"
    rm "${response_file}"
    exit 1
fi

# 由于使用了 set -e 和 --fail，如果 curl 遇到 4xx/5xx 错误，脚本会提前退出。
# 因此，能执行到这里的基本都是成功的情况 (2xx)。
# 我们仍然可以根据状态码给出更具体的信息。
echo "✅ 请求成功完成，HTTP 状态码: ${response_code}"
if [ "${response_code}" -eq 204 ]; then
  echo "🎉 包 '${PKG_NAME}:${PKG_VERSION}' 已被成功删除。"
else
  # 这种情况很少见，但为了代码健壮性还是加上
  echo "🤔 操作完成，但收到一个非预期的成功状态码: ${response_code}"
fi
