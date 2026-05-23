-- 常用程序变量。其它 Hyprland Lua 模块会引用这里的终端、文件管理器和启动器。
local variables = {
	terminal = "~/.local/bin/archdevkit-terminal",
	fileManager = "yazi",
	menu = "rofi -show run",
	browser = "google-chrome-stable",
	taskManager = "btop",
	colorpicker = "hyprpicker",
	note = "obsidian",
}

return variables
