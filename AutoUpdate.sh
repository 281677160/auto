#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate for Openwrt

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

function Remote_information() {
[ ! -d "${Download_Path}" ] && mkdir -p ${Download_Path} || rm -rf "${Download_Path}"/*
if [[ "${TARGET_BOARD}" == "x86" ]]; then
  if [[ -d '/sys/firmware/efi' ]]; then
    BOOT_Type=uefi
  else
    BOOT_Type=legacy
  fi
elif [[ "${Firmware_SFX}" == ".img.gz" ]]; then
  BOOT_Type=legacy
else
  BOOT_Type=sysupgrade
fi

LOCAL_Version=$(echo "${CURRENT_Version}" |sed "s/.*${DEFAULT_Device}//g" |grep -Eo [0-9]+)
CLOUD_Firmware=$(grep -Eo "${CLOUD_CHAZHAO}-[0-9]+-${BOOT_Type}-[a-zA-Z0-9]+${Firmware_SFX}" ${API_PATH} | awk 'END {print}')
CLOUD_Version=$(echo "${CLOUD_Firmware}" |sed "s/.*${DEFAULT_Device}//g" |sed "s/${BOOT_Type}.*//g" |grep -Eo [0-9]+)
LUCI_Firmware="${SOURCE}-${DEFAULT_Device}-${CLOUD_Version}"
if [[ -z "${CLOUD_Firmware}" ]] && [[ -z "${CLOUD_Version}" ]] && [[ -z "${LUCI_Firmware}" ]]; then
  echo "获取云端信息失败,x86注意本地跟云端固件显示的引导模式是否一致,或者就是云端压根就没您同类型的固件存在,或者作者更了固件获取条件导致您本地跟云端信息不一直!" > /tmp/cloud_version
  exit 0
fi

cat > /tmp/Version_Tags <<-EOF
LOCAL_Version=${LOCAL_Version}
CLOUD_Version=${CLOUD_Version}
LUCI_Firmware=${LUCI_Firmware}
MODEL_type=${BOOT_Type}${Firmware_SFX}
KERNEL_type=${Kernel} - ${LUCI_EDITION}
CURRENT_Device=${CURRENT_Device}
EOF

LOCAL_Version=$(grep LOCAL_Version= /tmp/Version_Tags | cut -c15-100)
CLOUD_Version=$(grep CLOUD_Version= /tmp/Version_Tags | cut -c15-100)
LUCI_Firmware=$(grep LUCI_Firmware= /tmp/Version_Tags | cut -c15-100)
if [[ -n "${LOCAL_Version}" ]] && [[ -n "${CLOUD_Version}" ]] && [[ -n "${LUCI_Firmware}" ]]; then
	if [[ "${LOCAL_Version}" -eq "${CLOUD_Version}" ]]; then
		Checked_Type="已是最新"
		echo "${LUCI_Firmware} [${Checked_Type}]" > /tmp/cloud_version
	elif [[ "${LOCAL_Version}" -lt "${CLOUD_Version}" ]]; then
		Checked_Type="有可更新固件"
		echo "${LUCI_Firmware} [${Checked_Type}]" > /tmp/cloud_version
	elif [[ "${LOCAL_Version}" -gt "${CLOUD_Version}" ]]; then
		Checked_Type="云端最高版本固件,低于您现在所使用版本,请到云端查看原因"
		echo "${LUCI_Firmware} [${Checked_Type}]" > /tmp/cloud_version	
	fi
fi
}

function Remote_upgrade() {
TMP_Available=$(df -m | grep "/tmp" | awk '{print $4}' | awk 'NR==1' | awk -F. '{print $1}')
let X=$(grep -n "${CLOUD_Firmware}" ${API_PATH} | tail -1 | cut -d : -f 1)-4
let CLOUD_Firmware_Size=$(sed -n "${X}p" ${API_PATH} | grep -Eo "[0-9]+" | awk '{print ($1)/1048576}' | awk -F. '{print $1}')+1
if [[ "${TMP_Available}" -lt "${CLOUD_Firmware_Size}" ]]; then
  echo "固件tmp空间值[${TMP_Available}M],云端固件体积[${CLOUD_Firmware_Size}M],空间不足" > /tmp/cloud_version
  exit 0
fi

if [[ "${LOCAL_Version}" -lt "${CLOUD_Version}" ]]; then
  echo "[$(date "+%Y年%m月%d日%H时%M分%S秒") 检测到有可更新的固件版本,立即更新固件!]" > /tmp/cloud_version
elif [[ "${LOCAL_Version}" -eq "${CLOUD_Version}" ]]; then
  exit 0
elif [[ "${LOCAL_Version}" -gt "${CLOUD_Version}" ]]; then
  exit 0
fi

cd "${Download_Path}"
if [[  "$(curl -I -s --connect-timeout 8 google.com -w %{http_code} | tail -n1)" == "301" ]]; then
  DOWNLOAD1=${Release_download1}
  DOWNLOAD2=${Release_download2}
else
  DOWNLOAD1=${Release_download2}
  DOWNLOAD2=${Release_download1}
fi

if ! curl -fsSL ${DOWNLOAD2}/${CLOUD_Firmware} -o ${CLOUD_Firmware}; then
  if ! wget -q ${DOWNLOAD1}/${CLOUD_Firmware} -O ${CLOUD_Firmware}; then
    curl -fsSL ${DOWNLOAD1}/${CLOUD_Firmware} -o ${CLOUD_Firmware}
  fi
fi

if [[ $? -ne 0 ]]; then
  echo "[$(date "+%Y年%m月%d日%H时%M分%S秒") 下载云端固件失败,请检查网络再尝试或手动安装固件]" > /tmp/cloud_version
  exit 0
fi

LOCAL_MD5256=$(md5sum ${CLOUD_Firmware} |cut -c1-3)$(sha256sum ${CLOUD_Firmware} |cut -c1-3)
CLOUD__MD5256=$(echo ${CLOUD_Firmware} |grep -Eo "[a-zA-Z0-9]+${Firmware_SFX}" | sed -r "s/(.*)${Firmware_SFX}/\1/")
if [[ ! "${CLOUD__MD5256}" == "${LOCAL_MD5256}" ]]; then
  echo "[$(date "+%Y年%m月%d日%H时%M分%S秒") MD5对比失败,固件可能在下载时损坏,请检查网络后重试!]" > /tmp/cloud_version
  exit 0
fi

echo "[$(date "+%Y年%m月%d日%H时%M分%S秒") 正在执行更新,更新期间请不要断开电源或重启设备 ...]" >> /tmp/AutoUpdate.log
chmod 755 "${CLOUD_Firmware}"
if [[ `opkg list | awk '{print $1}' | grep -c gzip` -ge '1' ]]; then
  opkg remove gzip > /dev/null 2>&1
fi

if [[ -f "/etc/deletefile" ]]; then
  source /etc/deletefile
fi

rm -rf /etc/config/luci
echo "*/5 * * * * sleep 240; sh /etc/networkdetection > /dev/null 2>&1" >> /etc/crontabs/root
rm -rf /mnt/*upback.tar.gz && sysupgrade -b /mnt/upback.tar.gz
if [[ `ls -1 /mnt | grep -c "upback.tar.gz"` -eq '1' ]]; then
  Upgrade_Options='sysupgrade -F -f /mnt/upback.tar.gz'
else
  Upgrade_Options='sysupgrade -F -q'
fi
echo "[$(date "+%Y年%m月%d日%H时%M分%S秒") 升级固件中，请勿断开路由器电源，END]" >> /tmp/AutoUpdate.log
${Upgrade_Options} ${CLOUD_Firmware}
}

case "$1" in
  "-u")
    Remote_detection
    Remote_information
    Remote_upgrade
  ;;
  "-f")
    Remote_detection
    Remote_information
  ;;
  *)
    exit 0
  ;;
esac
