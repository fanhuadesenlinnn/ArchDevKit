# ArchDevKit 精简环境的 Alacritty 终端配置模板。
# 会安装到 ~/.config/alacritty/alacritty.toml。
[env]
TERM = "xterm-256color"

# 窗口外观：padding 是内容边距，decorations=None 交给 Hyprland 管理边框。
[window]
padding = { x = 8, y = 8 }
decorations = "None"
opacity = 1.0

# 默认使用 Monaco，与系统 UI 字体保持一致；中文和 Emoji 由 fontconfig 回退到 Noto。
[font]
size = 12.5

[font.normal]
family = "Monaco"
style = "Regular"

[font.bold]
family = "Monaco"
style = "Regular"

[font.italic]
family = "Monaco"
style = "Regular"

[colors.primary]
background = "#1C1C1C"
foreground = "#F8F8F2"

[colors.cursor]
text = "#1C1C1C"
cursor = "#81A2BE"

[colors.selection]
text = "#F8F8F2"
background = "#44475A"
