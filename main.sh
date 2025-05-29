#!/bin/bash

# ---
# 用于Linux系统的磁盘空间清理脚本
# 作者: Enderson Menezes
# 日期: 2024-02-16
# 灵感来源: https://github.com/jlumbroso/free-disk-space
# ---

# 变量
# PRINCIPAL_DIR: 字符串
# TESTING: 布尔值 (true 或 false)
# ANDROID_FILES: 布尔值 (true 或 false)
# DOTNET_FILES: 布尔值 (true 或 false)
# HASKELL_FILES: 布尔值 (true 或 false)
# TOOL_CACHE: 布尔值 (true 或 false)
# SWAP_STORAGE: 布尔值 (true 或 false)
# PACKAGES: 字符串 (以空格分隔)
# REMOVE_ONE_COMMAND: 布尔值 (true 或 false)
# REMOVE_FOLDERS: 字符串 (以空格分隔)

# 环境变量
# AGENT_TOOLSDIRECTORY: 字符串

# 验证变量
if [[ -z "${PRINCIPAL_DIR}" ]]; then
    echo "未设置PRINCIPAL_DIR变量"
    exit 0
fi
if [[ -z "${TESTING}" ]]; then
    TESTING="false"
fi
if [[ -z "${REMOVE_DOCKER}" ]]; then
    REMOVE_DOCKER="false"
fi
if [[ ${TESTING} == "true" ]]; then
    echo "测试模式"
    alias rm='echo rm'
fi
if [[ -z "${ANDROID_FILES}" ]]; then
    echo "未设置ANDROID_FILES变量"
    exit 0
fi
if [[ -z "${DOTNET_FILES}" ]]; then
    echo "未设置DOTNET_FILES变量"
    exit 0
fi
if [[ -z "${HASKELL_FILES}" ]]; then
    echo "未设置HASKELL_FILES变量"
    exit 0
fi
if [[ -z "${TOOL_CACHE}" ]]; then
    echo "未设置TOOL_CACHE变量"
    exit 0
fi
if [[ -z "${SWAP_STORAGE}" ]]; then
    echo "未设置SWAP_STORAGE变量"
    exit 0
fi
if [[ -z "${PACKAGES}" ]]; then
    echo "未设置PACKAGES变量"
    exit 0
fi
if [[ ${PACKAGES} != "false" ]]; then
    if [[ ${PACKAGES} != *" "* ]]; then
        echo "PACKAGES变量不是字符串列表"
        exit 0
    fi
fi
if [[ -z "${REMOVE_ONE_COMMAND}" ]]; then
    echo "未设置REMOVE_ONE_COMMAND变量"
    exit 0
fi
if [[ -z "${REMOVE_FOLDERS}" ]]; then
    echo "未设置REMOVE_FOLDERS变量"
    exit 0
fi
if [[ -z "${AGENT_TOOLSDIRECTORY}" ]]; then
    echo "未设置AGENT_TOOLSDIRECTORY变量"
    exit 0
fi

# 全局变量
TOTAL_FREE_SPACE=0

# 验证所需软件包

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
    echo "-"
    echo "📚 正在删除Android文件夹"
    update_and_echo_free_space "before"
    sudo rm -rf /usr/local/lib/android || true
    update_and_echo_free_space "after"
    echo "-"
}

function remove_dot_net_library_folder(){
    echo "📚 正在删除.NET文件夹"
    update_and_echo_free_space "before"
    sudo rm -rf /usr/share/dotnet || true
    update_and_echo_free_space "after"
    echo "-"
}

function remove_haskell_library_folder(){
    echo "📚 正在删除Haskell文件夹"
    update_and_echo_free_space "before"
    sudo rm -rf /opt/ghc || true
    sudo rm -rf /usr/local/.ghcup || true
    update_and_echo_free_space "after"
    echo "-"
}

function remove_package(){
    PACKAGE_NAME=$1
    echo "📚 正在删除 ${PACKAGE_NAME}"
    update_and_echo_free_space "before"
    sudo apt-get remove -y "${PACKAGE_NAME}" --fix-missing > /dev/null
    sudo apt-get autoremove -y > /dev/null
    sudo apt-get clean > /dev/null
    update_and_echo_free_space "after"
    echo "-"
}

function remove_multi_packages_one_command(){
    PACKAGES_TO_REMOVE=$1
    MOUNT_COMMAND="sudo apt-get remove -y"
    for PACKAGE in ${PACKAGES_TO_REMOVE}; do
        MOUNT_COMMAND+=" ${PACKAGE}"
    done
    echo "🗃️ 正在批量删除软件包: ${PACKAGES_TO_REMOVE}"
    update_and_echo_free_space "before"
    ${MOUNT_COMMAND} --fix-missing > /dev/null
    sudo apt-get autoremove -y > /dev/null
    sudo apt-get clean > /dev/null
    update_and_echo_free_space "after"
    echo "-"
}

function remove_tool_cache(){
    echo "📇 正在删除工具缓存"
    update_and_echo_free_space "before"
    sudo rm -rf "${AGENT_TOOLSDIRECTORY}" || true
    update_and_echo_free_space "after"
    echo "-"
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
    echo "-"
}

function remove_folder(){
    FOLDER=$1
    echo "📁 正在删除文件夹: ${FOLDER}"
    update_and_echo_free_space "before"
    sudo rm -rf "${FOLDER}" || true
    update_and_echo_free_space "after"
}

function remove_docker_image(){
    echo "📁 正在删除Docker镜像"
    update_and_echo_free_space "before"
    sudo docker image prune --all --force > /dev/null 2>&1
    update_and_echo_free_space "after"
    echo "-"
}

# 删除库文件
if [[ ${ANDROID_FILES} == "true" ]]; then
    remove_android_library_folder
fi
if [[ ${DOTNET_FILES} == "true" ]]; then
    remove_dot_net_library_folder
fi
if [[ ${HASKELL_FILES} == "true" ]]; then
    remove_haskell_library_folder
fi
if [[ ${PACKAGES} != "false" ]]; then
    if [[ ${REMOVE_ONE_COMMAND} == "true" ]]; then
        remove_multi_packages_one_command "${PACKAGES}"
    else
        for PACKAGE in ${PACKAGES}; do
            remove_package "${PACKAGE}"
        done
    fi
fi
if [[ ${TOOL_CACHE} == "true" ]]; then
    remove_tool_cache
fi
if [[ ${SWAP_STORAGE} == "true" ]]; then
    remove_swap_storage
fi
if [[ ${REMOVE_FOLDERS} != "false" ]]; then
    for FOLDER in ${REMOVE_FOLDERS}; do
        remove_folder "${FOLDER}"
    done
fi
if [[ ${REMOVE_DOCKER} == "true" ]]; then
    remove_docker_image
fi
echo "✅️ 总共释放空间: ${TOTAL_FREE_SPACE} MB"
