/* Waybar 外观样式：字体、背景、工作区按钮和右侧状态模块间距。 */
* { font-family: "Noto Sans CJK SC", "JetBrainsMono Nerd Font", sans-serif; font-size: 14px; font-weight: 600; border: none; min-height: 0; }
window#waybar { background: rgba(35, 38, 52, 0.96); color: #f0f3ff; }
/* 工作区按钮：active 表示当前工作区。 */
#workspaces button { padding: 0 10px; color: #c7cce2; background: transparent; }
#workspaces button.active { color: #232634; background: rgba(138, 173, 244, 0.92); }
/* 这些模块共享水平内边距，避免状态栏过于拥挤。 */
#clock, #network, #pulseaudio, #cpu, #memory, #tray, #window { padding: 0 10px; }
