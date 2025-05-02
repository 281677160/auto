module("luci.controller.autoupdate", package.seeall)

-- 引入 ubus 模块
local ubus = require "ubus"

-- 全局变量记录升级状态
local upgrade_status = {
    status = "idle",
    message = ""
}

-- 新增全局变量，用于标记是否确认升级
local is_upgrade_confirmed = false

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade"), nil).leaf = true
    entry({"admin", "system", "autoupdate", "check_status"}, call("action_check_status"), nil).leaf = true
    -- 新增确认升级的接口
    entry({"admin", "system", "autoupdate", "confirm_upgrade"}, call("action_confirm_upgrade"), nil).leaf = true
end

function action_upgrade()
    -- 清理日志
    os.execute("rm -f /tmp/autoupdate.log /tmp/compare_version")
    
    -- 执行基础检查命令
    -- 阶段1：执行 AutoUpdate
    local check_result = luci.sys.call("/usr/bin/AutoUpdate > /tmp/autoupdate.log 2>&1")
    if os.execute("test -f /tmp/compare_version") == 0 then
        luci.http.write_json({ success = false, message = "云端没有最新固件,无需更新", needUpgrade = false })
        return
    elseif check_result ~= 0 then
        luci.http.write_json({ success = false, message = "Check update failed" })
        return
    end

    -- 标记为未确认升级
    is_upgrade_confirmed = false
    luci.http.write_json({ success = true, message = "Upgrade can be started", needUpgrade = true })

end

function action_confirm_upgrade()
    -- 标记为确认升级
    is_upgrade_confirmed = true
    -- 执行升级命令
    local pid = luci.sys.exec("AutoUpdate -k > /tmp/autoupdate.log 2>&1 & echo $!")
    upgrade_status.status = "running"
    upgrade_status.message = ""
    if pid ~= 1 then
        -- 新增版本文件判断:ml-citation{ref="2,6" data="citationList"}
        if check_version_file() then
            luci.http.write_json({ success = false, message = "Check update failed" })
        end
        return
    end

    -- 启动一个异步任务来监控升级状态
    luci.sys.call(string.format([[
        (
            wait %s
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                ubus call luci-autoupdate set_status '{"status": "completed", "message": ""}'
            else
                ubus call luci-autoupdate set_status '{"status": "error", "message": "Upgrade failed with exit code $EXIT_CODE"}'
            fi
        ) &
    ]], pid))

    luci.http.write_json({ success = true, message = "Upgrade started", needUpgrade = true })
end

function action_check_status()
    luci.http.write_json(upgrade_status)
end

-- 注册 ubus 方法来更新状态
local conn = ubus.connect()
if conn then
    local success, err = pcall(function()
        conn:register("luci-autoupdate", {
            set_status = {
                function(req, msg)
                    upgrade_status.status = msg.status
                    upgrade_status.message = msg.message
                end,
                { status = ubus.STRING, message = ubus.STRING }
            }
        })
    end)
    if not success then
        if luci and luci.log then
            luci.log("Failed to register ubus method: " .. tostring(err))
        end
    end
    conn:close()
else
    if luci and luci.log then
        local err = debug.traceback()
        luci.log("Failed to connect to ubus: " .. err)
    end
end
