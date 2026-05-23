-- 自动启动模块：Hyprland 启动时拉起壁纸、状态栏、剪贴板、输入法和常用应用。
local vars = require("modules.variables")

local function exec_once(cmd)
	hl.exec_cmd(cmd)
end

hl.on("hyprland.start", function()
	exec_once("hyprpaper")
	exec_once("waybar")
	exec_once("wl-paste --type text --watch cliphist store")
	exec_once("wl-paste --type image --watch cliphist store")
	exec_once("fcitx5 -d")
	exec_once("systemctl --user start hyprpolkitagent")
	exec_once("dunst")
	exec_once("[workspace 1] " .. vars.browser)
	exec_once("[workspace 2 silent] " .. vars.terminal)
end)
