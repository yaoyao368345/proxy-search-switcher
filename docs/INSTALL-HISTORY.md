# Windows 安装、准备与恢复

## 第一阶段实机安装记录（2026-10-11）

用户明确授权后，先复核原始准备快照，再应用独立阶段一快照。实际新增 10 个载荷文件和 1 个本项目安装记录；4 个必要目录已创建；所有新增文件写入后及独立复核的 SHA-256 均一致，4 个旁路审计文件保持不变。新增 config-prefs.js 使用已授权的 general.config.sandbox_enabled=false。

为了确保首次重启只验证加载，配置模板设置 enabled=false，token 为空；该差异只记录在新阶段快照，原始快照未改动。没有执行代理检测、搜索切换或读取 Clash 密钥。未关闭/重启 Zen，Firefox 未修改。

当前状态：installed-awaiting-manual-restart。等待用户手动重启后，仅验证 fx-autoconfig 和全局模块加载；确认成功后才启用后续运行验收。安装文件存在及哈希通过不能代替浏览器运行验证。

恢复：自行关闭 Zen 后先运行 Uninstall.ps1，再用 Restore-Preparation.ps1 回滚阶段一快照；已修改文件停止自动恢复，本地密钥模板保留。原始没有 AutoConfig，移除新增 config-prefs.js 后下次启动恢复默认沙箱。


## 初始准备阶段授权边界（历史记录）

2026-10-11 用户允许源码、测试、文档、本地提交，以及只读调查与备份准备。准备阶段当时没有授权写入 Zen 安装/profile 或关闭沙箱；现在第一阶段已获授权并完成，退出/重启仍由用户手动执行。原始准备快照保留，新阶段快照另存。 Firefox 保持仅模拟验证。

当前机器确认：

- 安装：`D:\Zen`，Zen 1.23.2b，Gecko 157.0.1，release。
- 安装映射的默认 profile：`<目标Profile根目录>`。profiles.ini 还列出另一个 Default Profile，不能自动将它当作当前 profile。
- 默认偏好目录只有 `channel-prefs.js`；无 root config.js / cfg AutoConfig；目标 profile/chrome 只有 `zen-themes.css`，没有 fx-autoconfig。
- 这次安装前准备不需要覆盖任何现有文件。现有 channel-prefs.js、zen-themes.css、profiles.ini、installs.ini 做旁路备份及哈希审计。

## fx-autoconfig 0.10.16 的最小步骤（第一阶段已执行）

使用固定提交 `dfdab5684faffc112b76ccb1d8cab7f75da0102c`，保留上游源码及 MPL-2.0 许可。新安装需要真实修改和安全策略的明确批准。本轮用户授权仅新增文件并保留正在运行的 Zen，因此使用已测试的 Apply-Preparation.ps1 -AllowRunningBrowser；常规增量安装器仍要求浏览器退出。

| 目标位置 | 操作 | 用途 |
|---|---|---|
| `D:\Zen\config.js` | 新增上游原文件 | 注册目标 profile 的 manifest，加载 boot |
| `D:\Zen\defaults\pref\config-prefs.js` | 新增上游原文件 | filename=config.js、obscure_value=0、sandbox_enabled=false |
| `<profile>\chrome\utils\boot.sys.mjs` | 新增 | 全局脚本加载器 |
| `<profile>\chrome\utils\utils.sys.mjs` | 新增 | 加载器通用工具 |
| `<profile>\chrome\utils\fs.sys.mjs` | 新增 | 文件路径与读取工具 |
| `<profile>\chrome\utils\uc_api.sys.mjs` | 新增 | 上游接口 |
| `<profile>\chrome\utils\module_loader.mjs` | 新增 | 上游模块支持 |
| `<profile>\chrome\utils\chrome.manifest` | 新增 | 注册 utils、JS、CSS、resources 的本地路径 |
| `<profile>\chrome\JS\proxy-search-switcher.sys.mjs` | 新增 | 本项目单实例检测器 |
| `<profile>\proxy-search-switcher.local.json` | 新增模板 | 本地密钥及检测配置，token 留空 |
| `<profile>\proxy-search-switcher.install.json` | 增量安装时生成 | 本项目文件所有权、哈希与卸载记录 |

创建尚不存在的 `chrome/utils`、`chrome/JS`、`chrome/CSS`、`chrome/resources` 空目录；**不安装上游示例用户脚本、示例 CSS、额外 mod，不覆盖 zen-themes.css。** 不修改 profiles.ini、installs.ini、prefs.js、channel-prefs.js 或 Clash 文件。

## 为什么需要沙箱变更、影响及回滚

AutoConfig 默认使用受限权限，无法调用本项目所需 SearchService、WinINet 与模块加载 API。上游前置配置把 `general.config.sandbox_enabled` 从 release 默认 true 改为 false。它放宽**AutoConfig 脚本**的隔离，允许可信本地脚本以浏览器特权运行；不关闭普通网页内容进程沙箱，但不能视作无安全影响。

安装目录设置影响用这套 Zen 可执行文件启动的所有 profile。用户或其他本地程序可写的 chrome/JS 文件变成敏感特权代码入口；只安装经过审查的固定版本，不加载未知远程脚本。上游在用户启用更新检查时可访问上游更新源，本项目不启用其自动更新检查。

在本机的全新安装方案中，恢复方法是：自行关闭 Zen、先卸载本项目，再用准备快照核验并移除新增的 `config-prefs.js` 和匹配的上游文件。由于原来没有这些配置文件，下次正常启动恢复 AutoConfig 的默认沙箱。**如果原来就有公共 fx-autoconfig，只卸载本项目，不删除公共加载器或改变其策略。** 修改过的文件停止自动恢复，保留并人工审查。

## 备份准备：只写备份目录

PowerShell 7.2+。`Prepare.ps1` 检查安装路径、源码依赖锁、目标路径及链接，创建外部快照；记录每个目标的“原先存在/不存在”、原文件 SHA-256、预备载荷 SHA-256；旁路备份相关未修改文件。没有原文件的目标以“不存在记录”恢复，不伪造空文件备份。

```powershell
pwsh -NoProfile -File installer/Prepare.ps1 -Browser zen -InstallDir D:\Zen `
  -ProfileDir '<实际profile根目录>' -FxSourceDir '<固定版本fx-autoconfig源码目录>' `
  -BackupDir '<新建的外部备份目录>'
```

快照中的 `manifest.json` 是恢复依据，`payload` 是尚未执行的候选文件，`audit` 是未修改文件的旁路备份，`originals` 仅在拟改文件已存在时生成。准备后必须重新核对实际目标是否仍与快照一致；出现新文件、不同 AutoConfig、链接或其他修改时停止，不能强行套用旧快照。配置模板中的 token 仍为空；不会读取 Clash 密钥。

回滚命令（真实使用前自行退出 Zen）：

```powershell
pwsh -NoProfile -File installer/Restore-Preparation.ps1 -BackupDir '<快照目录>' -WhatIf
pwsh -NoProfile -File installer/Restore-Preparation.ps1 -BackupDir '<快照目录>'
```

恢复脚本先验证全部路径和原备份哈希，仅回滚预备载荷匹配的文件；检测到其他编辑时停止。先移除 AutoConfig 偏好入口，最后只移除原先不存在且当前为空的已知目录。保留本地密钥配置，避免删除安装后填写的 token。恢复后验证原始文件哈希或目标不存在；不会强制恢复搜索引擎。备份不要与配置密钥一起提交 Git。

## 已安装 fx-autoconfig 的增量安装

`Install.ps1` 不安装或修补前置加载器。固定版本文件允许 LF / CRLF 差异，其他源码变化、未知版本和额外 AutoConfig 策略拒绝自动合并。使用 `about:profiles` 指定实际 profile，避免改错多配置环境。

```powershell
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir D:\Zen -ProfileDir '<profile>' -Inspect
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir D:\Zen -ProfileDir '<profile>' -WhatIf
# 自行关闭浏览器后，在获准真实安装时执行：
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir D:\Zen -ProfileDir '<profile>'
```

准备本地 JSON：复制 example，填写 token；默认配置下只有 127.0.0.1:7897 被视作可信手动代理。API 使用字面 127.0.0.1:9097，不跟随跳转。可用 `-ConfigPath` 指定其他绝对本地路径。`intervalMs`、`timeoutMs`、`debug`、`enabled` 下次启动生效。

增量安装不会改动上游文件或其他用户脚本。已有本项目文件但无可信记录、或文件发生编辑时拒绝覆盖。重复同参安装不修改文件。更新本项目需先卸载后安装；普通重启后若缓存仍使用旧脚本，可由用户在 about:support 手动清除启动缓存，脚本不自动清理。

## 卸载与失败恢复

```powershell
pwsh -NoProfile -File installer/Uninstall.ps1 -Browser zen -InstallDir D:\Zen -ProfileDir '<profile>'
pwsh -NoProfile -File installer/Recover.ps1 -Browser zen -InstallDir D:\Zen -ProfileDir '<profile>'
```

关闭浏览器后执行。卸载只删除本项目模块及可信记录；保留本地配置、现有默认搜索引擎、公共加载器。Recover 用于安装中断后的新增模块回滚；如果正式记录也存在，先卸载再恢复。记录或模块有不明变化时不强制删除，先比较快照和实际文件。

## 真实验收清单：Pending

先安装与启动日志，再验证 Google/Bing 双向切换、设置界面同步、四种开关组合、API 401/断连保留策略、真实退出核心后的 Bing、多窗口单实例和重启恢复。要切换 Clash 的真实开关或停止程序须另外取得用户授权。Firefox 本阶段不执行任何真实安装或启动。
