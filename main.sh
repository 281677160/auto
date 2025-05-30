#!/bin/bash

# ---
# 用于Linux系统的磁盘空间清理脚本
# 作者: Enderson Menezes
# 日期: 2024-02-16
# 灵感来源: https://github.com/jlumbroso/free-disk-space
# 修改: 改进交换空间释放量的计算
# ---

# 全局变量
TOTAL_FREE_SPACE=0
TOTAL_SWAP_SPACE=0
CURRENT_SWAP_SIZE=0

# 设置提示字体颜色
STEPS="[\033[93m 执行 \033[0m]"
INFO="[\033[94m 信息 \033[0m]"
NOTE="[\033[92m 结果 \033[0m]"
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

# 获取交换空间大小（以 KB 为单位）
function get_swap_space() {
    local swap_size=$(swapon --show=SIZE --noheadings --raw)
    if [[ -z "$swap_size" ]]; then
        echo 0
    else
        # 将带有单位的大小转换为纯数字（以 KB 为单位）
        if [[ "$swap_size" =~ ^([0-9]+)([kMG])$ ]]; then
            local value=${BASH_REMATCH[1]}
            local unit=${BASH_REMATCH[2]}
            case "$unit" in
                k) echo "$value" ;;
                M) echo $((value * 1024)) ;;
                G) echo $((value * 1024 * 1024)) ;;
                *) echo 0 ;;
            esac
        else
            echo 0
        fi
    fi
}

# 将KB转换为MB
function convert_kb_to_mb() {
    awk -v kb="$1" 'BEGIN{printf "%.2f", kb/1024}'
}

# 将字节转换为MB
function convert_bytes_to_mb() {
    awk -v bytes="$1" 'BEGIN{printf "%.2f", bytes/1024/1024}'
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

function verify_free_space_in_mb(){
    DATA_TO_CONVERT=$(verify_free_disk_space)
    convert_bytes_to_mb "${DATA_TO_CONVERT}"
}

function update_and_echo_free_space(){
    OPERATION=$1
    IS_AFTER_OR_BEFORE=$2
    
    if [[ "${IS_AFTER_OR_BEFORE}" == "before" ]]; then
        if [[ "${OPERATION}" == "disk" ]]; then
            SPACE_BEFORE=$(verify_free_space_in_mb)
            LINUX_TIMESTAMP_BEFORE=$(date +%s)
        elif [[ "${OPERATION}" == "swap" ]]; then
            # 保存当前交换空间大小
            CURRENT_SWAP_SIZE=$(get_swap_space)
            LINUX_TIMESTAMP_BEFORE=$(date +%s)
        fi
    else
        if [[ "${OPERATION}" == "disk" ]]; then
            SPACE_AFTER=$(verify_free_space_in_mb)
            LINUX_TIMESTAMP_AFTER=$(date +%s)
            FREEUP_SPACE=$(awk -v after="$SPACE_AFTER" -v before="$SPACE_BEFORE" 'BEGIN{printf "%.2f", after-before}')
            echo "释放磁盘空间: ${FREEUP_SPACE} MB"
            TOTAL_FREE_SPACE=$(awk -v total="$TOTAL_FREE_SPACE" -v free="$FREEUP_SPACE" 'BEGIN{printf "%.2f", total+free}')
        elif [[ "${OPERATION}" == "swap" ]]; then
            # 交换空间已经关闭，使用之前保存的CURRENT_SWAP_SIZE
            LINUX_TIMESTAMP_AFTER=$(date +%s)
            # 转换KB到MB
            FREEUP_SPACE=$(convert_kb_to_mb "$CURRENT_SWAP_SIZE")
            echo "释放交换空间: ${FREEUP_SPACE} MB"
            TOTAL_SWAP_SPACE=$(awk -v total="$TOTAL_SWAP_SPACE" -v free="$FREEUP_SPACE" 'BEGIN{printf "%.2f", total+free}')
            # 重置CURRENT_SWAP_SIZE
            CURRENT_SWAP_SIZE=0
        fi
        echo "耗时: $((LINUX_TIMESTAMP_AFTER - LINUX_TIMESTAMP_BEFORE)) 秒"
    fi
}

function remove_android_library_folder(){
    echo "➖"
    echo -e "${STEPS} 📚 删除Android文件夹"
    update_and_echo_free_space "disk" "before"
    sudo rm -rf /usr/local/lib/android || true
    update_and_echo_free_space "disk" "after"
    echo "➖"
}

function remove_dot_net_library_folder(){
    echo -e "${STEPS} 📚 删除.NET文件夹"
    update_and_echo_free_space "disk" "before"
    sudo rm -rf /usr/share/dotnet || true
    update_and_echo_free_space "disk" "after"
    echo "➖"
}

function remove_haskell_library_folder(){
    echo -e "${STEPS} 📚 删除Haskell文件夹"
    update_and_echo_free_space "disk" "before"
    sudo rm -rf /opt/ghc || true
    sudo rm -rf /opt/hostedtoolcache/CodeQL || true
    sudo rm -rf /usr/local/.ghcup || true
    update_and_echo_free_space "disk" "after"
    echo "➖"
}

function remove_package(){
    PACKAGES_TO_REMOVE=$1
    PACKAGES_ARRAY=($PACKAGES_TO_REMOVE)
    for PACKAGE in "${PACKAGES_ARRAY[@]}"; do
       echo -e "${STEPS} 🗃️ 移除软件: ${PACKAGE}"
       update_and_echo_free_space "disk" "before"
       sudo apt-get remove -y "${PACKAGE}" --fix-missing > /dev/null
       update_and_echo_free_space "disk" "after"
       echo "➖"
    done
    update_and_echo_free_space "disk" "before"
    echo -e "${STEPS} 👝 删除多余的软件压缩包"
    sudo apt-get autoremove -y > /dev/null
    sudo apt-get clean > /dev/null
    update_and_echo_free_space "disk" "after"
    echo "➖"
}

function remove_tool_cache(){
    echo -e "${STEPS} 📇 删除工具缓存"
    update_and_echo_free_space "disk" "before"
    sudo rm -rf "${AGENT_TOOLSDIRECTORY}" || true
    update_and_echo_free_space "disk" "after"
    echo "➖"
}

function remove_docker_image(){
    echo -e "${STEPS} 💽 删除Docker镜像"
    update_and_echo_free_space "disk" "before"
    docker rmi $(docker images -q)
    sudo rm -rf /var/lib/docker
    sudo rm /etc/docker/daemon.json
    sudo rm /lib/systemd/system/docker.service
    sudo rm /lib/systemd/system/docker.socket
    update_and_echo_free_space "disk" "after"
    echo "➖"
}

function remove_swap_storage(){
    echo -e "${STEPS} 🧹 删除交换空间"
    update_and_echo_free_space "swap" "before"
    CURRENT_SWAP_SIZE=$(get_swap_space)
    sudo swapoff -a || true
    sudo rm -f "/mnt/swapfile" || true
    update_and_echo_free_space "swap" "after"
    echo "➖"
}

function remove_folder(){
    FOLDER=$1
    PACKAGES_FOLDER=($FOLDER)
    for FOLDER in "${PACKAGES_FOLDER[@]}"; do
       echo -e "${STEPS} 📂 删除文件夹: ${FOLDER}"
       update_and_echo_free_space "disk" "before"
       sudo rm -rf "${FOLDER}" || true
       update_and_echo_free_space "disk" "after"
       echo "➖"
    done
}

function free_up_space(){
    echo -e "${NOTE} ☑️ 总共释放空间: $(awk -v disk="$TOTAL_FREE_SPACE" -v swap="$TOTAL_SWAP_SPACE" 'BEGIN{printf "%.2f", disk+swap}') MB"
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
