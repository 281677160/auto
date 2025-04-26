module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, cbi("autoupdate/autoupdate"), _("Auto Update"), 90)
    entry({"admin", "system", "autoupdate", "check"}, call("action_check")).leaf = true
    entry({"admin", "system", "autoupdate", "update"}, call("action_update")).leaf = true
end

function action_check()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    local result = sys.exec("AutoUpdate.sh")
    http.prepare_content("text/plain")
    http.write(result or "")
end

function action_update()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    local result = sys.exec("AutoUpdate -u")
    http.prepare_content("text/plain")
    http.write(result or "")
end
