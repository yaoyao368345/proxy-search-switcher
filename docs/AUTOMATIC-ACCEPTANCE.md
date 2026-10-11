# 自动切换启用与实机验收准备

本阶段仅准备。启用、实际默认引擎写入以及代理/Clash操作均未执行。不得把模拟测试计为手动验收。v0.1.0发布仍待验收与独立发布授权。

## 启用前检查

Git初始工作区干净；生产修复已提交并部署，用户重启输出 loaderVersion=0.10.16/loadedByLoader=true/status=disabled。SearchService只读结果当前Bing，Google/Bing均存在。WinINet、Toolhelp v2只读实机通过。

实际安装模块SHA-256：`1F83F818A4296A54AA180A9512780E9111AC4289AC281074627B658999E92D2B`。
安装记录SHA-256：`97BAE8CC756A633C9A439F47ED15F309646220A3B342FC1E7AAE98AAA892025C`。
两份文件均匹配部署载荷，加载器审计哈希不变。不是仅由仓库推断：已逐字核对安装模块包含生产 state/mihomo/switcher/wininet/toolhelp/native/request/start 核心（startup仅替换实际配置路径）。

配置路径：`<目标Profile根目录>proxy-search-switcher.local.json`。
元数据：Length305，LastWriteTimeUtcTicks639273030494344685，与部署快照一致。没有读取、哈希、复制配置内容。enabled=false的依据是用户重启后的disabled及未改动元数据；当前字段值应在正式写入前由用户再次确认。

| 审查项 | 实际安装实现与限制 |
| --- | --- |
| 三态OR | 任一enabled→Google；两个disabled→Bing；其他→保持 |
| 系统代理 | 手动代理位开启且可信端点匹配才有效；flags1旧端点保留仍disabled；PAC/WPAD/外来端点unknown |
| 冗余写入 | 当前目标相同不调用setDefault |
| 轮询 | inFlight共享一个任务，不排队、不重叠；完成后仅排一个setTimeout |
| 旧结果 | 串行消除轮询之间逆序覆盖；stop后抑制写入；检测期间外部状态变化仍有一个周期的快照滞后 |
| 多窗口 | 单个全局ESM缓存实例，首次窗口观察者在初始化前移除；同一模块scope有实例保护。不要安装第二份别名模块 |
| 退出 | quit-application-granted移除观察者并stop，清计时器、abort请求、关闭原生DLL；正常清理已模拟，异常抛出时尚需风险确认 |
| 401/超时 | unknown，不当作关闭；系统明确enabled仍Google，否则保持 |
| 核心退出 | 仅connection-refused且完整进程快照无白名单核心才判TUN disabled；GUI退出不等于核心退出 |
| 用户选择 | Google/Bing下一轮恢复策略目标；第三方引擎保持；写入前复查当前值，内部API无原子条件写入 |

API带认证请求此前只有Promise pending反馈，缺少最终成功结果记录。正式启用前应让用户执行现有02-api只读诊断并确认pass及布尔TUN结果；不能将pending当成功，不需要向代理提供Token。

## 最小配置变更：由用户手动编辑

选择手动单字段编辑，避免自动解析/重写整个含密钥JSON、生成暂存副本或把密钥放入操作日志。本阶段不执行编辑命令。正式启用需独立授权，写入前手动退出全部Zen进程并核对路径、元数据、安全路径及模块哈希。

用户在本地可信编辑器打开上述精确配置文件，仅查找顶层唯一的 `"enabled": false`，将false改成true。不粘贴完整配置到聊天，不替换文件为单字段JSON，不改Token/controllerUrl/intervalMs/timeoutMs/debug等任何其他字段。不创建含密钥备份、diff、终端输出或报告；避免编辑器自动备份/上传及全文件格式化。

如果enabled缺失、重复、不是布尔值、文件位置不符或存在符号链接/未知修改，停止并人工核对；不要用全局替换。保存后用户只回报已完成和非秘密轮询参数，不传配置正文。再手动启动Zen；不依赖热加载，初始化只在启动时读取配置。首先检查状态非disabled且非blocked/stopped；首次轮询就可能写默认引擎，所以启用授权必须明确包含该写入。

无密钥恢复记录只写：配置绝对路径、原字段enabled=false、模块/安装记录哈希和改动时间；不保存配置内容或其哈希。停用时仍仅把顶层唯一enabled改回false，保留其他字段。

## 四组合实机步骤（待独立测试授权）

用户先记录非秘密 intervalMs=I、timeoutMs=T。每步等待至少两个轮询周期，建议2×max(I,T)+1秒；默认I=2000/T=1200时至少5秒，但实际参数须由用户确认。若请求或SearchService长时间挂起，计时不能代替完成确认，停止调查。

每步由用户操作代理开关，确认控制器TUN状态与Windows手动标志；等待稳定→检查Zen设置的默认引擎→普通窗口地址栏提交无敏感内容的测试词→核对最终Google/Bing域名（允许地区域名），记录时间、开关、预期/实际、脱敏模块状态。不要凭已有搜索页判断；不把网址导航当搜索。隐私窗口独立默认引擎不在本项目管理范围。

| 顺序 | 系统代理 | TUN | 预期 |
| --- | --- | --- | --- |
| 1 | 关，允许旧127.0.0.1:7897仍保留 | 关 | Bing |
| 2 | 开，可信端点 | 关 | Google |
| 3 | 关 | 开 | Google |
| 4 | 开，可信端点 | 开 | Google |

随后回到两者关确认Bing，稳定等待两个周期确认不重复写入。真实写入次数/计时器数目前没有公开计数接口，不能仅凭getStatus证明只有一个timer；多窗口架构证据加模拟测试与实际行为验收分别记录。

## 异常与恢复测试

| 场景 | 操作与证据 | 预期/验证层级 |
| --- | --- | --- |
| Windows缓存旧端点 | 系统代理关闭，TUN关闭，旧地址仍保留 | Bing；已有只读证据，实际切换待测 |
| API401 | 自动化注入返回401的request替身，使用虚构Token，不改真实密钥或控制器 | 系统关→保持；系统开→Google。模拟通过，真实401端到端未测 |
| API超时 | 自动化请求替身触发timeout；不改真实端口、网络、防火墙或Clash | 同上；模拟通过，实机超时注入未测 |
| GUI退出核心存活 | 用户退出GUI并确认核心仍在，API若继续可用则按TUN；拒绝连接则unknown | 系统关且unknown→保持，系统开→Google；不认为核心已停 |
| 核心完全退出 | 用户手动退出并确认无核心，控制器拒绝连接 | 系统关→Bing；系统仍开→Google（可能无网络，策略不等于代理健康） |
| Clash重启 | 用户手动重启、确认API可用及TUN布尔值 | 后续轮询恢复四组合策略 |
| 两个Zen窗口 | 用户打开第二窗口并交替检查设置/地址栏 | 无重复初始化或额外独立轮询，窗口共享默认值；计数无直接公开证明 |
| Zen重启 | 用户手动关闭并重启 | 初始化/检测恢复，组合目标正确 |
| 用户修改引擎 | 分别手动切Google/Bing与第三方引擎，等待两个周期 | Google/Bing恢复管理目标，第三方保持；再选Bing继续验收 |
| 停用/卸载 | 按下面恢复流程，然后代理状态变化两周期 | 无项目写入；默认引擎不自动还原，按用户选择恢复 |

401/超时采用测试替身，不假装是真实API异常验收。不授权真实异常注入；若需要端到端异常验证，应另行设计独立本地虚构密钥环境，不修改实际配置。

## 回滚和快速停用

出现异常立即停止状态变化测试，保存仅固定状态码、时间、开关和引擎名称的日志；不保存原始API响应、完整配置、Authorization或原生路径异常。

1. 紧急时用户父进程控制台对已加载模块调用导出的stop（不改配置）；正常情况下它会清理计时器、请求与DLL。异常清理若失败，立即手动退出Zen。stop不能撤销已提交的SearchService写入。
2. 用户手动完全退出Zen；只把enabled改回false。手动启动，验证status=disabled；之后观察代理变化不会引起项目搜索写入。该步骤需要独立停用授权或由用户自行执行。
3. 当前默认引擎仍保留最后值，用户手动设置原选择（本次启用前Bing）；不是通过回滚配置自动恢复搜索引擎。

临时stop代码（仅发生异常且获测试授权后使用，当前不执行）：

```javascript
(() => {
  const api = ChromeUtils.importESModule("chrome://userchromejs/content/uc_api.sys.mjs");
  const script = api.Scripts.getScriptData("proxy-search-switcher.sys.mjs");
  if (!script?.isRunning) return "not-loaded";
  const mod = ChromeUtils.importESModule(script.chromeURI);
  mod.stop();
  return mod.getStatus();
})()
```

完整恢复先关闭Zen并enabled=false；先预览再独立授权执行：

```powershell
& '<项目目录>\installer\Restore-Update.ps1' -BackupDir '<Toolhelp-v2更新准备目录>' -WhatIf
# 获授权后移除WhatIf，仅恢复模块及安装记录到Toolhelp v2部署前版本；它有已知旧错误，不建议以此作为继续运行版本。
& '<项目目录>\installer\Uninstall.ps1' -Browser zen -InstallDir 'D:\Zen' -ProfileDir '<目标Profile根目录>' -WhatIf
# 获授权后移除WhatIf，仅卸载本项目；保留本地配置、加载器与当前默认引擎。
```

未知哈希、符号链接、备份损坏或浏览器运行时停止。不删除fx-autoconfig、不恢复沙箱，不清理其他用户脚本。保留更新备份和脱敏日志。

## v0.1.0 发布门槛：手动验收 2 / 7

| 项目 | 手动状态 | 记录要求 |
| --- | --- | --- |
| 四种代理组合全部通过 | 用户反馈通过 | 四组合及最终恢复Bing正常，无详细时间或次数 |
| Zen设置与地址栏搜索同步 | 用户反馈通过 | 用户确认设置/地址栏/模块状态均符合预期，无异常或重复切换 |
| 未知状态不错误切换 | Pending | 三态模拟证据；真实异常限制明确标注 |
| 多窗口仅一个检测器 | Pending | 全局架构、模拟单timer及实际两窗口表现 |
| Zen重启后恢复功能 | Pending | enabled下重启状态及首轮结果 |
| 关闭/卸载无残留影响 | Pending | stop/disabled/卸载后无写入，保留项明确 |
| 自动化通过且Git干净 | Pending | 准备阶段自动化可通过；最终验收后再次核验 |

未验证风险：认证API最终只读结果尚缺；首次真实setDefault及地址栏结果；新版enabled生命周期和双窗口实机；检测快照变化与手动修改竞态；内部API无原子条件写；API/搜索调用挂起延迟超过等待时间；DLL/abort异常路径可能中断stop；没有公开检测器/写入计数，无法凭状态独立证明数量；进程名白名单不认证签名；核心消失而系统代理开仍选Google不保证网络可用；卸载不撤销已改变的默认引擎；Firefox仍未实机验证。

下一阶段分两份授权：A仅修改顶层enabled并允许启动后的自动默认引擎写入（保留密钥及所有其余字段，手动重启）；B授权上述实机组合/异常/恢复验收及用户操作范围。遇异常应预先授权stop和enabled=false恢复，避免等待期间继续切换。此报告本身不构成任一授权。

准备阶段自动化结果：71项Node全部通过；installer/preparation/apply-preparation/update四组PowerShell临时目录测试全部通过。生产源码及已安装文件未更改。

## 最新实机反馈

用户已独立授权首次启用与验收，并反馈四组合与最终恢复Bing均通过，包括设置页面、真实地址栏搜索及模块状态，无观察到异常或重复切换。未提供完整细分域名、时间或内部写入计数，不作补写。此前API最终响应缺失属于历史准备记录；此次功能验收不能替代API响应字段的独立证据。稳定性阶段见STABILITY-ACCEPTANCE.md，尚未完成；其余5项门槛Pending。

稳定性最新用户反馈：S1–S5全部通过。核心两项、多窗口行为、重启通过；内部检测器计数仅模拟/架构。未知态异常細分仍仅模拟与部分场景反馈，持久停用/卸载Pending。完整实机不宣称7/7，最终自动化/Git核验在发布清单记录。
