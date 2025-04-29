module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    
    -- 添加升级操作入口
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade"), nil).leaf = true
end

function action_upgrade()
    luci.http.prepare_content("application/json")
    
    -- 阶段1：执行预检查
    local check_code = luci.sys.call("AutoUpdate > /tmp/update_check.log 2>&1")
    if check_code ~= 0 then
        return luci.http.write_json({
            success = false,
            message = "Check update failed",
            log = io.popen("cat /tmp/update_check.log"):read("*a")
        })
    end

    -- 阶段2：处理升级确认流程
    local confirm = luci.http.formvalue("confirm")
    local cmd = luci.http.formvalue("cmd")
    
    -- 如果已经确认要执行命令
    if confirm == "1" and cmd then
        local exec_code = luci.sys.call(cmd .. " > /tmp/autoupdate_confirm.log 2>&1")
        return luci.http.write_json({
            success = (exec_code == 0),
            message = exec_code == 0 and "Upgrade completed" or "Confirm execution failed",
            log = io.popen("cat /tmp/autoupdate_confirm.log"):read("*a")
        })
    end

    -- 阶段3：执行升级操作
    local upgrade_code = luci.sys.call("AutoUpdate -u > /tmp/autoupdate.log 2>&1")
    
    -- 成功直接返回
    if upgrade_code == 0 then
        return luci.http.write_json({
            success = true,
            message = "Upgrade started",
            log = io.popen("cat /tmp/autoupdate.log"):read("*a")
        })
    end

    -- 失败时解析日志寻找需要确认的命令
    local log_content = io.popen("cat /tmp/autoupdate.log"):read("*a")
    local cmd_match = log_content:match("UPGRADE_COMMAND: (.+%.sh)")  -- 假设日志中包含 UPGRADE_COMMAND: /path/command.sh

    -- 如果找到需要确认的命令
    if cmd_match then
        return luci.http.write_json({
            need_confirm = true,
            command = cmd_match,
            message = "Require confirmation to execute upgrade command",
            log = log_content
        })
    end

    -- 常规错误返回
    return luci.http.write_json({
        success = false,
        message = "Upgrade failed",
        log = log_content
    })
end
