#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate for Openwrt

Input_Option=$1
Version=V8.0

function Remote_detection() {
if [[ -f "/etc/openwrt_update" ]]; then
  source /etc/openwrt_update
else
  echo "缺少openwrt_update文件?" > /tmp/cloud_version
  exit 1
fi

if ! curl -fsSL ${Github_API2} -o ${API_PATH}; then
  curl -fsSL ${Github_API1} -o ${API_PATH}
fi


if [[ -z "$(grep -E "assets" ${API_PATH})" ]]; then
  echo "获取API数据失败,请检测网络,或您的github仓库为私库?" > /tmp/cloud_version
  exit 1
fi
}

function Remote_detection() {
