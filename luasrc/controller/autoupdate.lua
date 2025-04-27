module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    
    -- 添加升级操作入口
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade"), nil).leaf = true
end

function action_upgrade()
    -- 执行升级前检查
    local check_result = luci.sys.call("/usr/bin/AutoUpdate > /tmp/update_check.log 2>&1")
    
    if check_result ~= 0 then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success=false, message="Check update failed"})
        return
    end
    
    -- 执行升级命令
    local upgrade_result = luci.sys.call("AutoUpdate -u > /tmp/autoupdate.log 2>&1 &")
    
    if upgrade_result == 0 then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success=true, message="Upgrade started"})
    else
        luci.http.prepare_content("application/json")
        luci.http.write_json({success=false, message="Upgrade failed"})
    end
end
