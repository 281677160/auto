module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    
    -- 添加升级操作入口
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade"), nil).leaf = true
end

function action_upgrade()
    os.execute("rm -f /tmp/compare_version 2>/dev/null")
    os.execute("tee /tmp/autoupdate.log 2>/dev/null")
    -- 定义通用文件检查函数:ml-citation{ref="6,8" data="citationList"}
    local function check_version_file()
        local ver_file = io.open("/tmp/compare_version", "r")
        if ver_file then
            local content = ver_file:read("*l") or ""
            ver_file:close()
            return content:gsub("%s+", "") == "no_update"
        end
        return false
    end

    -- 执行基础检查命令
    local check_result = luci.sys.call("AutoUpdate >> /tmp/autoupdate.log 2>&1")
    if check_result ~= 0 then
        -- 新增版本文件判断:ml-citation{ref="2,6" data="citationList"}
        if check_version_file() then
            luci.http.write_json({ success = false, message = "云端没有最新固件,无需更新" })
        else
            luci.http.write_json({ success = false, message = "Check update failed" })
        end
        return
    end

    -- 执行升级命令
    local upgrade_result = luci.sys.call("AutoUpdate -u >> /tmp/autoupdate.log 2>&1")
    if upgrade_result ~= 0 then
        -- 新增升级失败时的文件判断:ml-citation{ref="4,6" data="citationList"}
        if check_version_file() then
            luci.http.write_json({ success = false, message = "云端没有最新固件,无需更新" })
        else
            luci.http.write_json({ success = false, message = "Check update failed" })
        end
        return
    end

    -- 原有成功响应保持不变
    luci.http.write_json({ success = true, message = "Upgrade started" })
end
