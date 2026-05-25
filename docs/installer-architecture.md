# Installer Architecture

ArchDevKit 的安装器按“入口薄、模块深、配置先行”的方向演进。`install.sh` 负责连接用户意图和执行流程；具体能力放在 `lib/` 和 `modules/` 中，避免入口脚本继续膨胀。

## 运行层次

1. `install_vars`

   项目默认值。交互式安装、命令行安装和用户配置文件都以这里为基线。

2. `lib/config.sh`

   加载 `~/.config/archdevkit/config.env`，只接受白名单键；随后统一做布尔值归一化、端口/URL/DNS 等关键配置校验，并收集非阻断提示。

3. `install.sh`

   解析命令、生成安装计划、展示配置和状态、执行模块、记录安装日志。入口脚本不直接维护配置 schema、模块注册、JSON 序列化或 doctor 检查细节。

4. `lib/module_registry.sh`

   模块注册表。集中维护模块别名、展示名、描述、影响范围、状态指纹、轻量校验和执行入口。新增模块时优先更新这里，而不是在入口脚本中到处加 `case`。

5. `modules/*.sh`

   每个安装模块维护自己的安装、验证、依赖判断和配置渲染逻辑。例如 Proxy 模块负责 Mihomo/sing-box，DNS 模块负责 systemd-resolved。

6. `lib/files.sh`

   集中维护文件写入、root 文件写入、临时文件安装和模板渲染。模块只表达目标路径、权限和模板变量，避免重复 `mktemp` / `backup` / `install -m` 细节。

7. `lib/systemd.sh`

   集中维护 systemd 操作，包括系统 unit 探测、daemon-reload、系统服务启用、开机启用和用户服务启用。模块只表达“要启用哪个服务”，不复制 daemon-reload / enable / active 检查流程。

8. `lib/packages.sh`

   集中维护 pacman、archlinuxcn 兜底、AUR helper、makepkg 回退和命令依赖安装。模块只表达要安装的软件包，不直接关心包来源选择和 AUR 引导路径。

9. `lib/doctor.sh`

   集中维护环境诊断。新增检查项时优先放在这里，避免散落到入口流程。

10. `lib/recovery.sh`

   安装失败恢复提示。安装流程会记录当前阶段和当前模块；失败时输出目标、模块、日志、重试命令和状态清理命令。

11. `lib/json.sh`

   统一 JSON 字段和转义逻辑。`plan/status/doctor --json` 都应保持 `schemaVersion`、`command`、`generatedAt` 和 `warnings`。

## 扩展规则

- 新增用户可配置项时，先放入 `install_vars`，再加入 `lib/config.sh` 的白名单和必要校验。
- 新增安装模块时，模块自身放到 `modules/`，并在 `lib/module_registry.sh` 注册目标、描述、影响范围、状态指纹、轻量校验和执行函数。
- 新增机器可读输出时，复用 `lib/json.sh`，不要在调用点手写未转义 JSON。
- 新增诊断项时，优先更新 `lib/doctor.sh`，并让 `scripts/test.sh` 至少覆盖 JSON 可解析。
- 新增文件写入、root 文件写入或模板渲染时，复用 `lib/files.sh`，不要在模块里重复 `mktemp` / `backup` / `install -m` 流程。
- 新增 systemd 服务启停或 unit 探测时，复用 `lib/systemd.sh`，不要在模块内重复 `systemctl` 流程。
- 新增包安装策略、AUR helper 或 archlinuxcn 兜底路径时，复用 `lib/packages.sh`，不要把安装决策放回模块或 `lib/common.sh`。
- 新增安装阶段时，保留 `lib/recovery.sh` 的阶段/模块上下文，让失败输出仍然能指向可恢复动作。
- 默认行为要同时考虑交互式和命令行安装；能在 `install_vars` 表达的默认值，不应只写死在菜单问题里。

## 测试边界

当前 `scripts/test.sh` 覆盖：

- Bash 语法检查
- `plan/status/doctor --json` 解析和核心字段
- file helper 的 dry-run 输出
- systemd helper 的 dry-run 输出
- package helper 的基础列表处理
- 失败恢复提示中的目标、模块、日志和重试命令
- 用户配置文件覆盖
- Mihomo YAML 和 sing-box JSON 模板渲染

后续适合继续补行为测试：模块计划组合、配置校验失败路径、状态跳过和 `--force` 重跑语义。
