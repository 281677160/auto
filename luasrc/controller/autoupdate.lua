module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate"), _("AutoUpdate"), 60)
    entry({"admin", "system", "autoupdate", "do_check"}, call("action_check")).leaf = true
    entry({"admin", "system", "autoupdate", "do_upgrade"}, call("action_upgrade")).leaf = true
    entry({"admin", "system", "autoupdate", "check_status"}, call("action_check_status")).leaf = true  -- 新增状态检查接口
end

-- 检查更新
function action_check()
    os.execute("rm -f /tmp/compare_version")
    local check_result = luci.sys.call("AutoUpdate >> /tmp/autoupdate.log 2>&1")
    
    local response = {}
    if check_result == 1 then  -- 仅当AutoUpdate显式返回1时视为错误
        response = { success = false, message = "检查更新失败" }
    else
        local has_update = io.open("/tmp/compare_version", "r") ~= nil
        response = {
            success = true,
            has_update = has_update,
            message = has_update and "发现新版本，是否立即升级？" or "当前已是最新版本"
        }
    end
    luci.http.write_json(response)
end

-- 启动升级
function action_upgrade()
    -- 创建锁文件防止重复启动
    os.execute("touch /tmp/autoupdate.lock 2>/dev/null")
    
    -- 使用子shell确保PID文件立即写入
    os.execute("(AutoUpdate -u >> /tmp/autoupdate.log 2>&1 ; rm -f /tmp/autoupdate.lock) & echo $! > /tmp/autoupgrade.pid")
    
    -- 验证PID文件有效性
    local pid_file = io.open("/tmp/autoupgrade.pid", "r")
    if pid_file then
        local pid = pid_file:read("*a")
        pid_file:close()
        
        luci.http.write_json({
            success = true,
            message = "后台升级进程已启动(PID:"..pid..")",
            pid = tonumber(pid)
        })
    else  -- PID文件生成失败时仍返回成功
        luci.http.write_json({
            success = true,
            message = "升级进程已启动但无法获取PID"
        })
    end
end

-- 检查升级状态 (新增接口)
function action_check_status()
    local pid_file = io.open("/tmp/autoupgrade.pid", "r")
    local response = {}
    
    if pid_file then  -- 存在PID文件
        local pid = pid_file:read("*a")
        pid_file:close()
        
        -- 检查进程是否存活
        if os.execute("kill -0 "..pid.." 2>/dev/null") == 0 then
            response = { running = true, message = "升级进行中" }
        else  -- 进程已结束
            os.execute("rm -f /tmp/autoupgrade.pid")
            -- 检查最终结果（根据AutoUpdate日志）
            local exit_code = os.execute("grep -q 'Upgrade succeeded' /tmp/autoupdate.log && echo 0 || echo 1")
            response = {
                running = false,
                success = exit_code == 0,
                message = exit_code == 0 and "升级成功" or "升级失败，查看日志"
            }
        end
    else  -- 无PID文件
        response = { running = false, message = "无进行中的升级" }
    end
    
    luci.http.write_json(response)
end
