#!/bin/bash

# --- 脚本说明 ---
# 功能: (全自动) 遍历当前目录下的所有 Maven 模块，获取其 GAV (GroupId, ArtifactId, Version)，
#       并调用一个外部删除脚本来删除 Gitea 上的对应包。
#       会自动跳过 packaging 为 "pom" 的父/聚合模块。

set -e
set -o pipefail

# --- 1. 参数检查和用法说明 ---

if [ "$#" -ne 3 ]; then
    echo "❌ 错误: 参数数量不正确。"
    echo ""
    echo "用法: $0 <gitea_url> <gitea_owner> <path_to_delete_script>"
    echo ""
    echo "参数说明:"
    echo "  gitea_url             - 你的 Gitea 实例地址 (例如: https://gitea.example.com)"
    echo "  gitea_owner           - 包在 Gitea 上的所有者 (用户名或组织名)"
    echo "  path_to_delete_script - 用于执行删除操作的脚本路径 (例如: ./delete_gitea_package.sh)"
    echo ""
    echo "示例:"
    echo "  $0 https://mygitea.com my-org ./delete_gitea_package.sh"
    echo ""
    echo "注意: Gitea Token 必须通过环境变量 GITEA_TOKEN 提供。"
    exit 1
fi

# --- 2. 从参数中获取变量 ---

GITEA_URL="$1"
GITEA_OWNER="$2"
DELETE_SCRIPT_PATH="$3"
# Gitea 包的类型对于 Maven 项目是固定的
PKG_TYPE="maven"


# --- 3. 检查环境 ---

if [ ! -f "pom.xml" ]; then
    echo "❌ 错误: 未找到 pom.xml 文件。请在 Maven 项目的根目录下运行此脚本。"
    exit 1
fi

if [ -z "${GITEA_TOKEN}" ]; then
  echo "❌ 错误: 环境变量 GITEA_TOKEN 未设置。"
  echo "请先设置: export GITEA_TOKEN=\"your_personal_access_token\""
  exit 1
fi

if [ ! -x "${DELETE_SCRIPT_PATH}" ]; then
    echo "❌ 错误: 删除脚本 '${DELETE_SCRIPT_PATH}' 不存在或没有执行权限。"
    exit 1
fi

# --- 4. 查找所有模块并循环处理 ---

echo "🔍 正在查找当前项目下的所有 pom.xml 文件..."

# 为 mvn 命令设置静默日志选项
MVN_OPTS="-B -q -Dorg.slf4j.simpleLogger.defaultLogLevel=error -DforceStdout"
# 如果你更喜欢使用 2>/dev/null, 可以将上面的 MVN_OPTS 设为空字符串 ""
# 然后在下面的 mvn 命令后都加上 2>/dev/null

find . -name "pom.xml" | while read -r pom_file; do
    module_dir=$(dirname "$pom_file")

    echo ""
    echo "========================================================"
    echo "🚀 处理模块: ${module_dir}"
    echo "========================================================"

    # 使用子 shell `()` 来执行 cd 和 mvn，这样不会影响主脚本的当前目录
    (
        cd "$module_dir"

        echo "   - 正在从 pom.xml 提取信息..."

        PACKAGING=$(mvn ${MVN_OPTS} help:evaluate -Dexpression=project.packaging 2>/dev/null)

        if [ "$PACKAGING" == "pom" ]; then
            echo "   - 🟡 跳过: 这是一个父/聚合模块 (packaging is 'pom')。"
            #exit 0 # 正常退出子 shell，继续处理下一个模块
        fi

        GROUP_ID=$(mvn ${MVN_OPTS} help:evaluate -Dexpression=project.groupId 2>/dev/null)
        ARTIFACT_ID=$(mvn ${MVN_OPTS} help:evaluate -Dexpression=project.artifactId 2>/dev/null)
        VERSION=$(mvn ${MVN_OPTS} help:evaluate -Dexpression=project.version 2>/dev/null)

        if [ -z "${GROUP_ID}" ] || [ -z "${ARTIFACT_ID}" ] || [ -z "${VERSION}" ]; then
            echo "   - ❌ 错误: 无法从 '${pom_file}' 中获取完整的 GAV 信息。"
            exit 1 # 异常退出子 shell, 会导致整个脚本停止
        fi

        PKG_NAME="${GROUP_ID}:${ARTIFACT_ID}"

        echo "   - ✅ 信息提取成功:"
        echo "     - Gitea Name: ${PKG_NAME}"
        echo "     - Version:    ${VERSION}"
        echo "--------------------------------------------------------"
        echo "   - ⏳ 正在调用删除脚本..."

        # 调用外部脚本，传递所有需要的参数
        "${DELETE_SCRIPT_PATH}" "${GITEA_URL}" "${GITEA_OWNER}" "${PKG_TYPE}" "${PKG_NAME}" "${VERSION}"

    ) # 子 shell 结束

done

echo ""
echo "========================================================"
echo "🎉 所有模块处理完毕。"
echo "========================================================"
