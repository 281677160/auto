module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    
    -- 添加检查更新和升级操作入口
    entry({"admin", "system", "autoupdate", "do_check"}, call("action_check"), nil).leaf = true
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade"), nil).leaf = true
end

function action_check()
    os.execute("rm -f /tmp/compare_version")
    local check_result = luci.sys.call("AutoUpdate > /tmp/autoupdate.log 2>&1")
    
    local response = {}
    if check_result ~= 0 then
        response.success = false
        response.message = "检查更新失败，请查看日志！"
    else
        local file = io.open("/tmp/compare_version", "r")
        if file then
            local content = file:read("*l") or ""
            file:close()
            response.success = true
            response.has_update = (content:gsub("%s+", "") ~= "no_update")
            response.message = response.has_update and "发现新版本，是否立即升级？" or "当前已是最新固件"
        else
            response.success = true
            response.has_update = true
            response.message = "发现新版本，是否立即升级？"
        end
    end
    
    luci.http.write_json(response)
end

function action_upgrade()
    local upgrade_result = luci.sys.call("AutoUpdate -u > /tmp/autoupdate.log 2>&1")
    
    local response = upgrade_result == 0 and
        { success = true, message = "升级已启动，设备即将重启！" } or  -- 注意结尾逗号
        { success = false, message = "升级失败，请检查日志！" }  -- 结尾可选分号
        
    luci.http.write_json(response)
end

