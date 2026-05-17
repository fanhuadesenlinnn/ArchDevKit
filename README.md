# ArchDevKit

ArchDevKit 是一个面向 Arch Linux 最小化安装后的工作站初始化工具。

它支持两种使用方式：

- 交互式菜单：适合新机器手动初始化
- 参数化安装：适合重复执行和自动化

当前模块：

- `base`：基础工具、编译工具、常用命令
- `archlinuxcn`：配置 archlinuxcn 软件源
- `git`：Git / GitHub CLI 环境
- `runtime`：mise + Node.js / npm / Python / Go
- `nvim`：Neovim + 个人配置仓库
- `docker`：Docker / Docker Compose / 镜像源
- `fonts`：中文字体、Nerd Font、可选 Monaco
- `shell`：Zsh / Oh My Zsh / Powerlevel10k
- `desktop`：Hyprland 桌面环境
- `dev`：开发环境组合
- `workstation`：完整工作站组合

## 快速开始

```bash
git clone https://github.com/fanhuadesenlinnn/ArchDevKit.git
cd ArchDevKit

bash install.sh
```

无参数时进入交互式菜单。

完整工作站安装：

```bash
bash install.sh workstation
```

非交互安装：

```bash
bash install.sh workstation --yes
```

只安装 Neovim：

```bash
bash install.sh nvim
```

只安装 Hyprland：

```bash
bash install.sh desktop
```

查看当前配置：

```bash
bash install.sh config
```

## 默认网络配置

默认开启中国大陆友好配置：

- npm 源：`https://registry.npmmirror.com`
- pip 源：`https://pypi.tuna.tsinghua.edu.cn/simple`
- GitHub 代理：`https://hubproxy.babadafafafafa.cn/`

关闭 GitHub 代理：

```bash
bash install.sh nvim --no-github-proxy
```

指定 GitHub 代理：

```bash
bash install.sh nvim --github-proxy https://gh-proxy.com/
```

## 常用参数

```bash
-y, --yes                 自动确认
--dry-run                 只显示计划，不执行
--no-china                不配置 npm/pip 国内源
--no-github-proxy         不使用 GitHub 代理
--github-proxy URL        指定 GitHub 代理
--repo URL                指定 Neovim 配置仓库
--branch NAME             指定 Neovim 配置分支
--no-plugin-sync          不同步 Neovim 插件
--node-version VERSION    指定 Node.js 版本
--npm-version VERSION     指定 npm 版本
--python-version VERSION  指定 Python 版本
--go-version VERSION      指定 Go 版本
--no-sddm                 不启用 SDDM
--nvidia                  安装 NVIDIA Wayland 相关包
--monaco                  安装 Monaco 字体
--browser-package NAME    指定桌面浏览器安装包
--browser-app COMMAND     指定桌面浏览器启动命令
--rime-schema NAME        指定 Rime 默认方案
```

## 桌面默认值

Hyprland 桌面默认安装 Google Chrome，不安装 Firefox。默认浏览器包为 `google-chrome`，启动命令为 `google-chrome-stable`；如果当前 pacman 源没有该包，脚本会先尝试按配置启用 `archlinuxcn`，仍不可用时再从 AUR 构建。

中文输入法默认使用 Fcitx5 + Rime，默认方案为 `luna_pinyin_simp`。可通过 `install_vars` 或参数覆盖：

```bash
bash install.sh desktop --browser-package google-chrome --browser-app google-chrome-stable --rime-schema luna_pinyin_simp
```

## 设计原则

- 默认值可用，直接回车即可使用推荐配置
- 参数可覆盖默认值
- 交互式和参数式走同一套模块函数
- 所有安装提示、错误提示和注释使用中文
- 修改配置前自动备份
- GitHub 代理只在本脚本 clone / 插件同步阶段临时生效，不污染全局 Git 配置
