module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    
    -- 添加升级操作入口
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade"), nil).leaf = true
end

function action_upgrade()
    luci.http.prepare_content("application/json")
    
    -- 清理旧的日志文件和标志文件
    os.execute("rm -f /tmp/update_check.log /tmp/autoupdate.log /tmp/autoupdate_confirm.log /tmp/Updatei /tmp/Updatef")
    
    -- 阶段1：执行 AutoUpdate
    local check_code = luci.sys.call("AutoUpdate -k > /tmp/update_check.log 2>&1")
    if check_code == 2 then
        -- Check update completed successfully
        return luci.http.write_json({
            success = true,
            message = "Check update completed successfully",
            log = io.popen("cat /tmp/update_check.log"):read("*a")
        })
    elseif check_code == 1 then
        -- Check update failed
        return luci.http.write_json({
            success = false,
            message = "Check update failed",
            log = io.popen("cat /tmp/update_check.log"):read("*a")
        })
    end

    -- 检查是否需要继续运行 AutoUpdate -i
    if os.execute("test -f /tmp/Updatei") == 0 then
        -- 阶段2：执行 AutoUpdate -i
        local status_msg = "正在下载固件中... 🕒"
        local download_code = luci.sys.call("AutoUpdate -i > /tmp/autoupdate.log 2>&1")
        if download_code == 2 then
            -- Download completed
            return luci.http.write_json({
                success = true,
                message = "Download completed",
                log = io.popen("cat /tmp/autoupdate.log"):read("*a"),
                status_msg = status_msg
            })
        elseif download_code == 1 then
            -- Download failed
            return luci.http.write_json({
                success = false,
                message = "Download failed",
                log = io.popen("cat /tmp/autoupdate.log"):read("*a"),
                status_msg = status_msg
            })
        end
    end

    -- 检查是否需要继续运行 AutoUpdate -f
    if os.execute("test -f /tmp/Updatef") == 0 then
        -- 阶段3：执行 AutoUpdate -f
        local status_msg = "正在升级固件中，请勿重启和切断电源... 🕒"
        local upgrade_code = luci.sys.call("AutoUpdate -f > /tmp/autoupdate.log 2>&1")
        if upgrade_code == 0 then
            -- Upgrade completed
            return luci.http.write_json({
                success = true,
                message = "Upgrade completed",
                log = io.popen("cat /tmp/autoupdate.log"):read("*a"),
                status_msg = status_msg
            })
        elseif upgrade_code == 1 then
            -- Upgrade failed
            return luci.http.write_json({
                success = false,
                message = "Upgrade failed",
                log = io.popen("cat /tmp/autoupdate.log"):read("*a"),
                status_msg = status_msg
            })
        end
    end

    -- 如果没有标志文件，返回未知错误
    return luci.http.write_json({
        success = false,
        message = "Unknown error occurred during upgrade process",
        log = io.popen("cat /tmp/autoupdate.log"):read("*a")
    })
end
