module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    entry({"admin", "system", "autoupdate", "do_check"}, call("action_check")).leaf = true
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade")).leaf = true
end

function action_check()
    os.execute("rm -f /tmp/compare_version")
    local check_result = luci.sys.call("AutoUpdate >> /tmp/autoupdate.log 2>&1")

    local response = {}
    if check_result == 0 then
        -- 命令成功执行后，仅检查文件是否存在
        local file_exists = io.open("/tmp/compare_version", "r")
        if file_exists then
            file_exists:close()
            response = {
                success = true,
                has_update = true,
                message = "发现新版本，是否立即升级？"
            }
        else
            response = {
                success = true,
                has_update = false,
                message = "当前已是最新固件，无需升级"
            }
        end
    else
        -- 命令执行失败时直接报错
        response = {
            success = false,
            message = "AutoUpdate命令执行异常"
        }
    end
    luci.http.write_json(response)
end

function action_upgrade()
    os.execute("nohup AutoUpdate -u >> /tmp/autoupdate.log 2>&1 &")
    -- 修复表构造语法错误（冒号改为等号）:ml-citation{ref="2,8" data="citationList"}
    luci.http.write_json({ 
        success = true, 
        message = "升级进程已启动，请查看日志跟踪进度" 
    })
end
