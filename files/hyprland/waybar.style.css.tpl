/* Waybar 外观样式：字体、背景、工作区按钮和右侧状态模块间距。 */
* { font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC"; font-size: 13px; border: none; min-height: 0; }
window#waybar { background: rgba(26, 27, 38, 0.88); color: #c0caf5; }
/* 工作区按钮：active 表示当前工作区。 */
#workspaces button { padding: 0 10px; color: #a9b1d6; background: transparent; }
#workspaces button.active { color: #7aa2f7; background: rgba(122, 162, 247, 0.18); }
/* 这些模块共享水平内边距，避免状态栏过于拥挤。 */
#clock, #network, #pulseaudio, #cpu, #memory, #tray, #window { padding: 0 10px; }
