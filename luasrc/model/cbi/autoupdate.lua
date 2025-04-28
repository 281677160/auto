require("luci.sys")
require("luci.http")
require("luci.dispatcher")

local m = Map("autoupdate", translate("AutoUpdate"),
translate("AutoUpdate LUCI supports one-click firmware upgrade and scheduled upgrade"))

local s = m:section(TypedSection, "login", "")
s.addremove = false
s.anonymous = true

-- 自动更新开关
local o = s:option(Flag, "enable", translate("Enable AutoUpdate"),
translate("Automatically update firmware during the specified time"))
o.default = 0
o.rmempty = false

-- 更新时间设置
local week = s:option(ListValue, "week", translate("Week Day"))
week:value(7, translate("Everyday"))
for i = 0, 6 do
    week:value(i, translate(os.date("%A", os.time({year=2000, month=1, day=2+i}))))
end
week.default = 0

local hour = s:option(Value, "hour", translate("Hour"))
hour.datatype = "range(0,23)"
hour.rmempty = false

local minute = s:option(Value, "minute", translate("Minute"))
minute.datatype = "range(0,59)"
minute.rmempty = false

-- 改进的获取系统信息函数
local function get_sys_info()
    local info = {}
    
    -- 确保脚本可执行
    os.execute("chmod +x /usr/bin/AutoUpdate")
    
    -- 执行检查更新脚本并捕获返回值
    local check_result = luci.sys.call("/usr/bin/AutoUpdate > /dev/null 2>&1")
    
    if check_result ~= 0 then
        luci.http.write("<script>alert('"..translate("Check update script failed!").."')</script>")
    end
    
    -- 获取系统信息
    info.github_url = luci.sys.exec("awk -F'=' '/GITHUB_LINK=/ {print $2}' /etc/openwrt_update") or ""
    info.local_version = luci.sys.exec("awk -F'=' '/FIRMWARE_VERSION=/ {print $2}' /etc/openwrt_update") or ""
    info.cloud_version = luci.sys.exec("cat /tmp/cloud_version 2>/dev/null") or translate("Unknown")
    info.equipment_name = luci.sys.exec("awk -F'=' '/EQUIPMENT_NAME=/ {print $2}' /tmp/tags_version 2>/dev/null") or ""
    info.model_type = luci.sys.exec("awk -F'=' '/MODEL_TYPE=/ {print $2}' /tmp/tags_version 2>/dev/null") or ""
    info.kernel_type = luci.sys.exec("awk -F'=' '/KERNEL_TYPE=/ {print $2}' /tmp/tags_version 2>/dev/null") or ""
    
    return info
end

local sys_info = get_sys_info()

-- GitHub URL 设置
local github = s:option(Value, "github", translate("GitHub URL"))
github.default = sys_info.github_url
github.rmempty = false

-- 升级按钮（带执行功能）
local button_upgrade_firmware = s:option(Button, "_upgrade", translate("Upgrade to Latest Version"),
translatef("Click the button below to upgrade to the latest version. Please wait patiently until the router reboots.") ..
"<br><br>" .. translate("local firmware version:") .. " " .. sys_info.local_version ..
"<br>" .. translate("cloud firmware version:") .. " " .. sys_info.cloud_version ..
"<br><br>" .. translate("Device model:") .. " " .. sys_info.equipment_name ..
"<br>" .. translate("Kernel version:") .. " " .. sys_info.kernel_type ..
"<br>" .. translate("Firmware type:") .. " " .. sys_info.model_type)

button_upgrade_firmware.inputtitle = translate("Start Upgrade")
button_upgrade_firmware.template = "autoupdate/upgrade_button"

function button_upgrade_firmware.write(self, section)
    -- 执行升级命令
    local upgrade_result = luci.sys.call("AutoUpdate -u > /tmp/autoupdate.log 2>&1 &")
    
    if upgrade_result == 0 then
        luci.http.write("<script>alert('"..translate("Upgrade started successfully! Router will reboot soon.").."')</script>")
    else
        luci.http.write("<script>alert('"..translate("Upgrade failed! Check /tmp/autoupdate.log for details.").."')</script>")
    end
    
    -- 重定向回页面
    luci.http.redirect(luci.dispatcher.build_url("admin/system/autoupdate"))
end

-- 应用设置后重启服务
function m.on_commit(self)
    luci.sys.call("/etc/init.d/autoupdate restart > /dev/null 2>&1")
end

return m
