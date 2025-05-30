#!/bin/bash

# ---
# 用于Linux系统的磁盘空间清理脚本
# 作者: Enderson Menezes
# 日期: 2024-02-16
# 灵感来源: https://github.com/jlumbroso/free-disk-space
# ---

# 全局变量
TOTAL_FREE_SPACE=0

# 设置提示字体颜色
INFO="[\033[94m 信息 \033[0m]"
ERROR="[\033[91m 错误 \033[0m]"
error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# 验证变量函数
function validate_boolean() {
    local var="$1" param_name="$2"
    if [[ ! "$var" =~ ^(true|false)$ ]]; then
        error_msg "参数 $param_name 的值: $var 无效，必须是 'true' 或 'false'"
    fi
}

# 验证变量函数
function validate_packages() {
    local var="$1" param_name="$2"
    if [[ "$var" =~ ^(true|false)$ ]]; then
        declare -g "$param_name"=""
    fi
}

# 验证变量
function init_var() {
    # 参数验证 (true 或 false)
    validate_boolean "$remove_android" "remove_android"
    validate_boolean "$remove_dotnet" "remove_dotnet"
    validate_boolean "$remove_haskell" "remove_haskell"
    validate_boolean "$remove_tool_cache" "remove_tool_cache"
    validate_boolean "$remove_swap" "remove_swap"
    validate_boolean "$remove_docker" "remove_docker"
    validate_boolean "$testing" "testing"

    # 参数验证 (是否设置为true 或 false,是的话改成空值)
    validate_packages "$remove_packages" "remove_packages"
    validate_packages "$remove_folders" "remove_folders"

    # 设置系统路径
    PRINCIPAL_DIR="$principal_dir"

    echo -e ""
    echo -e "${INFO} remove_android: [ ${remove_android} ]"
    echo -e "${INFO} remove_dotnet: [ ${remove_dotnet} ]"
    echo -e "${INFO} remove_haskell: [ ${remove_haskell} ]"
    echo -e "${INFO} remove_tool_cache: [ ${remove_tool_cache} ]"
    echo -e "${INFO} remove_swap: [ ${remove_swap} ]"
    echo -e "${INFO} remove_docker: [ ${remove_docker} ]"
    echo -e "${INFO} testing: [ ${testing} ]"
    echo -e "${INFO} remove_packages: [ ${remove_packages} ]"
    echo -e "${INFO} remove_folders: [ ${remove_folders} ]"
    echo -e ""
}

function verify_free_disk_space(){
    FREE_SPACE_TMP=$(df -B1 "${PRINCIPAL_DIR}")
    echo "${FREE_SPACE_TMP}" | awk 'NR==2 {print $4}'
}

function convert_bytes_to_mb(){
    awk -v bytes="$1" 'BEGIN{printf "%.2f", bytes/1024/1024}'
}

function verify_free_space_in_mb(){
    DATA_TO_CONVERT=$(verify_free_disk_space)
    convert_bytes_to_mb "${DATA_TO_CONVERT}"
}

function update_and_echo_free_space(){
    IS_AFTER_OR_BEFORE=$1
    if [[ "${IS_AFTER_OR_BEFORE}" == "before" ]]; then
        SPACE_BEFORE=$(verify_free_space_in_mb)
        LINUX_TIMESTAMP_BEFORE=$(date +%s)
    else
        SPACE_AFTER=$(verify_free_space_in_mb)
        LINUX_TIMESTAMP_AFTER=$(date +%s)
        FREEUP_SPACE=$(awk -v after="$SPACE_AFTER" -v before="$SPACE_BEFORE" 'BEGIN{printf "%.2f", after-before}')
        echo "释放空间: ${FREEUP_SPACE} MB"
        echo "耗时: $((LINUX_TIMESTAMP_AFTER - LINUX_TIMESTAMP_BEFORE)) 秒"
        TOTAL_FREE_SPACE=$(awk -v total="$TOTAL_FREE_SPACE" -v free="$FREEUP_SPACE" 'BEGIN{printf "%.2f", total+free}')
    fi
}

function remove_android_library_folder(){
    echo "➖"
    echo "📚 正在删除Android文件夹"
    update_and_echo_free_space "before"
    sudo rm -rf /usr/local/lib/android || true
    update_and_echo_free_space "after"
    echo "➖"
}

function remove_dot_net_library_folder(){
    echo "📚 正在删除.NET文件夹"
    update_and_echo_free_space "before"
    sudo rm -rf /usr/share/dotnet || true
    update_and_echo_free_space "after"
    echo "➖"
}

function remove_haskell_library_folder(){
    echo "📚 正在删除Haskell文件夹"
    update_and_echo_free_space "before"
    sudo rm -rf /opt/ghc || true
    sudo rm -rf /opt/hostedtoolcache/CodeQL || true
    sudo rm -rf /usr/local/.ghcup || true
    update_and_echo_free_space "after"
    echo "➖"
}

function remove_package(){
    PACKAGES_TO_REMOVE=$1
    PACKAGES_ARRAY=($PACKAGES_TO_REMOVE)
    for PACKAGE in "${PACKAGES_ARRAY[@]}"; do
       echo "🗃️ 正在删除软件: ${PACKAGE}"
       update_and_echo_free_space "before"
       sudo apt-get remove -y "${PACKAGE}" --fix-missing > /dev/null
       update_and_echo_free_space "after"
       echo "➖"
    done
    update_and_echo_free_space "before"
    echo "🗃️ 正在删除多余的软件压缩包"
    sudo apt-get autoremove -y > /dev/null
    sudo apt-get clean > /dev/null
    update_and_echo_free_space "after"
    echo "➖"
}

function remove_tool_cache(){
    echo "📇 正在删除工具缓存"
    update_and_echo_free_space "before"
    sudo rm -rf "${AGENT_TOOLSDIRECTORY}" || true
    update_and_echo_free_space "after"
    echo "➖"
}

function remove_docker_image(){
    echo "💽 正在删除Docker镜像"
    update_and_echo_free_space "before"
    sudo docker image prune --all --force > /dev/null 2>&1
    update_and_echo_free_space "after"
    echo "➖"
}

function remove_swap_storage(){
    # 眼睛表情查看交换空间
    echo "🔎 查看交换空间"
    free -h
    echo "🧹 正在删除交换空间"
    sudo swapoff -a || true
    sudo rm -f "/mnt/swapfile" || true
    echo "🧹 已删除交换空间"
    free -h
    echo "➖"
}

function remove_folder(){
    FOLDER=$1
    PACKAGES_FOLDER=($FOLDER)
    for FOLDER in "${PACKAGES_FOLDER[@]}"; do
       echo "🗂️ 正在删除文件夹: ${FOLDER}"
       update_and_echo_free_space "before"
       sudo rm -rf "${FOLDER}" || true
       update_and_echo_free_space "after"
       echo "➖"
    done
}

function free_up_space(){
    echo "✅️ 总共释放空间: ${TOTAL_FREE_SPACE} MB"
}

# 验证变量
init_var "${@}"

# 删除库文件
if [[ ${remove_android} == "true" ]]; then
    remove_android_library_folder
fi
if [[ ${remove_dotnet} == "true" ]]; then
    remove_dot_net_library_folder
fi
if [[ ${remove_haskell} == "true" ]]; then
    remove_haskell_library_folder
fi
if [[ ${remove_tool_cache} == "true" ]]; then
    remove_tool_cache
fi
if [[ ${remove_docker} == "true" ]]; then
    remove_docker_image
fi
if [[ ${remove_swap} == "true" ]]; then
    remove_swap_storage
fi
if [[ -n "${remove_packages}" ]]; then
    remove_package "${remove_packages}"
fi
if [[ -n "${remove_folders}" ]]; then
    remove_folder "${remove_folders}"
fi

free_up_space
