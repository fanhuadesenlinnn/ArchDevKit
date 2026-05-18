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
- `proxy`：Mihomo / sing-box 代理核心，可选 MetaCubeXD 面板
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

只安装 Proxy：

```bash
bash install.sh proxy
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
--rime-repo URL           指定 Rime 配置仓库
--rime-branch NAME        指定 Rime 配置分支
--no-rime-config          不安装 Rime 配置仓库
--with-proxy              workstation 中安装 Proxy 模块
--no-proxy                workstation 中不安装 Proxy 模块
--proxy-core NAME         指定代理核心：mihomo / sing-box
--no-metacubexd           不安装 MetaCubeXD 面板
--mihomo-config PATH/URL  指定 Mihomo 配置文件或 URL
--sing-box-config PATH/URL 指定 sing-box 配置文件或 URL
```

## 桌面默认值

Hyprland 桌面默认安装 Google Chrome，不安装 Firefox。默认浏览器包为 `google-chrome`，启动命令为 `google-chrome-stable`；如果当前 pacman 源没有该包，脚本会先尝试按配置启用 `archlinuxcn`，仍不可用时再从 AUR 构建。

中文输入法默认使用 Fcitx5 + Rime，默认方案为 `luna_pinyin_simp`。Rime 配置默认从独立仓库拉取并安装到 `~/.local/share/fcitx5/rime`：

```bash
https://github.com/fanhuadesenlinnn/rime-config.git
```

该仓库只保留可共享配置，不包含 `build/`、`*.userdb/`、`sync/`、`installation*.yaml`、`user*.yaml` 等机器状态、同步数据和个人输入习惯文件。

可通过 `install_vars` 或参数覆盖：

```bash
bash install.sh desktop --browser-package google-chrome --browser-app google-chrome-stable --rime-schema luna_pinyin_simp
bash install.sh desktop --rime-repo https://github.com/fanhuadesenlinnn/rime-config.git
bash install.sh desktop --no-rime-config
```

Hyprland、Waybar、Mako、Wofi、Kitty 的默认配置模板放在 `files/hyprland/`。脚本安装时会根据 `install_vars` 中的 `TERMINAL_APP`、`APP_LAUNCHER`、`FILE_MANAGER`、`BROWSER_APP` 渲染模板。

## Proxy 模块

Proxy 是可选模块，默认配置为：

```bash
ENABLE_PROXY=0 # 1=随 workstation 安装，0=不随 workstation 安装；直接执行 proxy 命令不受此项限制
PROXY_CORE="mihomo" # mihomo / sing-box
PROXY_AUTO_ENABLE_SERVICE=1 # 1=安装后启用并启动服务，0=只安装和生成配置

MIHOMO_SERVICE_NAME="mihomo.service"
MIHOMO_CONFIG_DIR="/etc/mihomo"
MIHOMO_CONFIG_FILE="${MIHOMO_CONFIG_DIR}/config.yaml"
MIHOMO_EXTERNAL_UI_DIR="${MIHOMO_CONFIG_DIR}/ui"

ENABLE_METACUBEXD=1 # 1=安装 MetaCubeXD 面板，0=不安装面板
```

单独安装默认 Mihomo + MetaCubeXD：

```bash
bash install.sh proxy
```

安装完整工作站时顺带安装 Proxy：

```bash
bash install.sh workstation --with-proxy
```

切换为 sing-box：

```bash
bash install.sh proxy --proxy-core sing-box
```

Mihomo 会按系统级服务方式安装：

- 配置目录：`/etc/mihomo`
- 配置文件：`/etc/mihomo/config.yaml`
- UI 目录：`/etc/mihomo/ui`
- 服务管理：`sudo systemctl enable --now mihomo.service`

脚本不会再为 Mihomo 生成 `~/.config/mihomo` 或 `~/.config/systemd/user/archdevkit-mihomo.service` 之类的用户目录配置。sing-box 目前仍使用用户级配置和 ArchDevKit 自建用户服务。

默认 Mihomo 配置模板来自 `files/mihomo/config.yaml.tpl`，基于日常大陆网络、AI 服务、流媒体、GitHub、游戏平台、广告拦截和懒猫微服兼容整理。
模板只保留一个机场订阅示例：`proxy-providers.airport.url`。不在模板里写任何示例节点，所有节点都通过订阅连接拉取到 `proxy-providers` 后供策略组使用。
默认 sing-box 配置模板来自 `files/sing-box/config.json.tpl`。

MetaCubeXD 面板安装后会复制到 `MIHOMO_EXTERNAL_UI_DIR`，默认是 `/etc/mihomo/ui`，生成的 Mihomo 配置中 `external-ui` 也会指向这个目录。

使用自己的配置文件或订阅 URL 覆盖默认模板：

```bash
bash install.sh proxy --mihomo-config /path/to/config.yaml
bash install.sh proxy --sing-box-config /path/to/config.json
```

默认配置不会写入任何真实节点、订阅 token 或密钥，仓库里只保留示例订阅地址。
如果脚本检测到仍在使用示例订阅地址，会跳过自动启动 Mihomo 服务，避免启动一个不可用的代理环境。

安装后常用地址：

- Mihomo mixed-port：`127.0.0.1:7890`
- Mihomo 控制接口：`http://127.0.0.1:9090`
- MetaCubeXD 面板：`http://127.0.0.1:9090/ui/`

## 设计原则

- 默认值可用，直接回车即可使用推荐配置
- 参数可覆盖默认值
- 交互式和参数式走同一套模块函数
- 所有安装提示、错误提示和注释使用中文
- 修改配置前自动备份
- GitHub 代理只在本脚本 clone / 插件同步阶段临时生效，不污染全局 Git 配置
