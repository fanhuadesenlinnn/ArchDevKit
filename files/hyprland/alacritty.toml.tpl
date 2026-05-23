# ArchDevKit 精简环境的 Alacritty 终端配置模板。
# 会安装到 ~/.config/alacritty/alacritty.toml。
[env]
TERM = "xterm-256color"

# 窗口外观：padding 是内容边距，decorations=None 交给 Hyprland 管理边框。
[window]
padding = { x = 8, y = 8 }
decorations = "None"
opacity = 1.0

# 字体建议使用 Nerd Font，保证图标和终端提示符能正常显示。
[font]
size = 12.5

[font.normal]
family = "JetBrainsMono Nerd Font Mono"
style = "Regular"

[font.bold]
family = "JetBrainsMono Nerd Font Mono"
style = "Bold"

[font.italic]
family = "JetBrainsMono Nerd Font Mono"
style = "Italic"

[colors.primary]
background = "#1C1C1C"
foreground = "#F8F8F2"

[colors.cursor]
text = "#1C1C1C"
cursor = "#81A2BE"

[colors.selection]
text = "#F8F8F2"
background = "#44475A"
