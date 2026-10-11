# 真实隔离环境验收准备方案

状态：仅研究与方案；未创建测试环境、VM、浏览器目录、Profile或接口，未安装/修改/启动任何浏览器。仓库工作区保持干净，既有D:\Zen、现有Profile、Clash/Token均未修改或复制。方案路径均是拟议，不代表已经创建。

## 方案结论与依据

优先研究独立Zen安装目录+全新Profile。Gecko官方文档支持--profile指定目录与--no-remote避免复用已有实例；独立程序目录也能隔离AutoConfig选择文件。然而它不是用户账户/OS隔离：Windows的用户AppData来自已知文件夹，更新/注册/崩溃数据可能在安装/Profile之外；WinINet与Toolhelp仍读取同一宿主账户状态。只改APPDATA/TEMP环境变量不能保证边界。此为源码和参数资料的推断，未通过实际启动验证Zen具体行为。

因此不选择在当前账户启动第二套Zen。建议Hyper-V Windows x64 VM，来宾内部仍使用独立Zen目录+全新Profile。主机只读发现：Professional，Hyper-V模块存在、vmms Running；尚未检查是否有可用Windows镜像、许可、空闲磁盘/内存或可复用无敏感数据的VM，不能保证立即可创建。不得自动启用Windows功能或重启宿主。

资料：
- [Gecko启动参数](https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html)
- [Gecko Windows用户目录来源](https://github.com/mozilla/gecko-dev/blob/master/toolkit/xre/nsXREDirProvider.cpp)（GetUserDataDirectoryHome Windows分支）
- [Zen官方1.23.2b](https://github.com/zen-browser/desktop/releases/tag/1.23.2b)
- [Hyper-V检查点与恢复](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/checkpoints)

## 具体拟议目录

| 位置 | 路径 | 用途 |
| --- | --- | --- |
| 宿主VM文件 | D:\PSS-Isolation-VM\v0.1.0 | 独立VHDX/配置/检查点；当前目录不存在 |
| VM名称 | PSS-v010-isolation | 创建前检查名称冲突，不复用未知VM |
| 来宾工作根目录 | C:\PSS-Lab | 全新测试环境 |
| 来宾官方浏览器 | C:\PSS-Lab\Zen-1.23.2b | 仅此目录接收AutoConfig新增文件 |
| 来宾全新Profile | C:\PSS-Lab\Profiles\clean | 与宿主完全不同、无导入/Sync |
| 来宾候选包解压 | C:\PSS-Lab\package\proxy-search-switcher-0.1.0 | 所有安装入口来自审计ZIP，不用当前源码替代 |
| 来宾固定加载器源码 | C:\PSS-Lab\sources\fx-autoconfig-0.10.16 | 独立上游源码及MPL LICENSE |
| 来宾接口与虚构状态 | C:\PSS-Lab\mock | 不含宿主Clash数据 |
| 来宾备份 | C:\PSS-Lab\backups\pre-autoconfig | Prepare生成全新外部快照 |
| 来宾日志/哈希 | C:\PSS-Lab\records | 脱敏步骤结果与文件清单 |
| 宿主输入暂存（待建） | outputs\isolation-input-v0.1.0 | 仅审计包/公开上游/OS输入清单，不放现有Profile |
| 宿主结果导出（待建） | outputs\isolation-results-v0.1.0 | 仅审核后的脱敏记录，不共享用户目录 |

outputs指未来验收时明确批准的证据输出目录；本阶段只保存本方案，不创建上述暂存/测试/结果目录。宿主VM根与先前拟议宿主独立目录均不存在，执行前再次检查路径、磁盘、权限和重解析点。

## 固定输入与隔离措施

候选使用release-final-review-v0.1.0/proxy-search-switcher-0.1.0.zip，SHA-256：962101E90BF2E34DAEAF6138FC44053A7567DAE510B918A85D11B627B6C812F1，50文件已审计，源提交7e0cbd1。不得使用旧候选或重新替换代码。

Zen从官方1.23.2b获取windows x64安装器zen.installer.exe；官方GitHub资产列出的SHA-256为5DB120F5A811DA3FCC449D75C0FEA28BDEEA6C362F5DFA694EA30F47583DDAEE。尚未下载或验证签名；获授权后重新核对官方digest、实际哈希与Authenticode，异常停止。该版本官方资产未列Windows便携ZIP，不假定存在。安装器只在来宾执行，指定独立目录，不设默认浏览器、不装宿主维护服务。若安装行为超出可控来宾范围暂停记录；来宾内系统写入列入VM基线，不影响宿主。

fx-autoconfig固定提交dfdab5684faffc112b76ccb1d8cab7f75da0102c；来源和八文件规范化哈希依dependencies.lock.json，保留MPL告知。不复制D:\Zen内现有加载器/模块，不复制现有Profile或真实本地配置。

VM拟议资源：2vCPU、4–6GiB RAM、64GiB动态虚拟磁盘（上限不是即时占用）；执行前核对宿主余量。OS安装介质/许可由用户指定或批准官方来源，当前不自动获取或启用组件。

- VM网络适配器不连接外部、内部、默认或NAT交换机，无宿主路由；测试服务127.0.0.1仅来宾可访问。
- 不共享宿主盘、用户目录、剪贴板、打印机或凭据；使用基础控制台，不用增强会话重定向。
- 输入通过只读介质传入；记录通过单独结果介质导出，挂载只读核对后复制脱敏文件，不能把整个Profile导出。介质/VM创建需授权。
- 不导入浏览器数据、不登录Sync/微软账户、不设置系统默认浏览器；不安装Clash，不继承宿主proxy/env变量，不调用真实9097/7897。
- 来宾系统代理初始明确关闭，WinINet应flags1；若未知代理/PAC/端点、未知进程、非空Profile、重解析点、文件冲突，停止，不强制“修好”。
- 离线后若Google/Bing引擎不能初始化或首次安装要求网络，不临时接入宿主网络，不改生产源码；暂停提出单独受控网络方案。此次目标是生命周期，不要求访问外部搜索页，真实搜索能力已有既有Zen证据。

## 独立本地接口设计（尚未编写/启动）

在来宾监听127.0.0.1:19097，只提供GET /configs，返回{"tun":{"enable":false}}或true。唯一凭据为公开虚构PSS-LAB-NOT-A-SECRET-010；不读取宿主Token。测试服务不转发、不访问外网/Clash，不监听0.0.0.0，不自动换端口；占用/监听身份异常停止。

状态通过来宾本地交互命令切换，不能提供无认证远程管理接口。日志只记请求序号/状态码/命中次数，不记录请求头、Bearer值、IP路径或原始配置。准备时记录服务文件SHA-256；纯本地服务需另行实现并模拟验证后才能运行。

项目配置仅在来宾全新模板中设置：enabled=false、controllerUrl=http://127.0.0.1:19097、token为上述虚构值、intervalMs2000/timeoutMs1200/debug=false，systemProxyServers独立127.0.0.1:19098，coreProcessNames为明确虚构pss-isolation-fixture.exe。19098不运行代理、不修改系统代理。必须确认来宾手动代理位关闭，因此系统输入disabled；核心名单仅测试配置，不计生产Mihomo退出证据。

这份配置为新建测试数据，不读取/改写既有JSON。不把虚构接口测试称为真实Clash API测试；来宾首轮初始化及SearchService写入是真实浏览器执行。

## 分阶段执行与每步证据

本阶段仅方案。获创建/安装授权后也应在每个停止点汇报，不一次越过整个流程。

A. 创建与基线：检查新路径/名称、VM资源、无路由/共享；传入核验输入，建立clean-os检查点。独立安装官方Zen，第一次只用--no-remote --profile "C:\PSS-Lab\Profiles\clean"。此命令只能在来宾执行，不从宿主打开URL。确认Services.dirsvc的ProfD与进程exe路径精确匹配；出现其他Profile立即退出测试。记录初始引擎E0及AutoConfig相关偏好原始状态、加载器文件缺失，手动退出来宾Zen，建pre-autoconfig检查点。

B. Prepare：从候选package\installer运行Prepare.ps1 -Browser zen -InstallDir独立目录 -ProfileDir独立Profile -FxSourceDir固定源码 -BackupDir新快照；Verify-Preparation通过，报告将新增的安装文件/目录及sandbox_enabled=false。先WhatIf审阅再批准Apply，不使用AllowRunningBrowser。只许快照列出的全新文件。

C. 首次加载默认停用：在新模板填写虚构接口参数，enabled仍false，记录无密钥JSON字段设置，不从任何宿主文件读取。启动独立mock并重置计数，再由用户启动来宾Zen；父进程检查loaderVersion0.10.16/loadedByLoader=true/status=disabled、默认E0不变、服务/configs请求计数0。再换mock状态等待5秒，默认仍E0。记录实际输出，不凭静态文件证明加载。

D. 启用：手动退出来宾Zen，唯一enabled改true；重启。先mock TUN=true应Google，再false应Bing（来宾系统代理disabled），等待每步至少5秒，核对真实SearchService默认值及模块状态、mock计数。不访问真实Clash；离线地址栏外网搜索不属于此项，不能计作全新环境实际网页搜索成功。

E. 持久停用：手动退出，只改enabled=false，mock计数重置；重启检查disabled及请求0。用户在来宾将默认引擎恢复E0（若测试曾改变），然后交替mock状态等待5秒，无项目切换。记录E0、disabled、计数；stop无需替代持久停用。

F. 项目卸载：保存卸载前模块及安装记录SHA-256、E0及依赖哈希，手动退出。Uninstall -WhatIf应只列模块/记录，审阅后执行；两文件缺失、配置/加载器/隔离无关脚本均保留且哈希一致。重启后loader仍0.10.16，但getScriptData不存在或isRunning不是true；禁止主动import已删除项目模块。SearchService默认仍E0，mock/configs计数0。不得自动把默认引擎设成Bing来掩盖差异。

G. AutoConfig独立恢复：手动退出，Restore-Preparation -BackupDir快照 -WhatIf，验证审阅后执行；模块已卸载，随后仅按原快照恢复/移除前置文件。原本无AutoConfig，所以config.js/config-prefs.js和六份utils新增文件应消失；项目local测试配置按脚本规则保留，不额外删除。目录只删除原来不存在且为空的已知目录。启动后比较原始沙箱偏好/原始文件清单及E0，确认不再加载fx-autoconfig；不能强行设置偏好来模拟恢复。若残留自定义目录/测试配置应列为“预期保留”，不宣称目录完全清空。

每阶段日志仅记录实际结果、输入/目标/备份SHA-256、当前引擎名、模块状态、mock计数和是否通过。时间/调用次数只在实测时记录，不补写。测试文件为虚构配置，但不导出全文/请求头；仅字段摘要和元数据。输出记录、快照与检查点统一标记来宾路径，防止误用到宿主。

## 暂停和回滚

任何路径/哈希/签名/端口/加载器/隔离条件不符立即停止，保留已完成步骤，不覆盖未知文件。用户手动退出来宾Zen；项目运行异常可在获测试授权后调用来宾已审查stop，必要时来宾唯一enabled=false并重启；不涉及宿主当前实例。

首选逐文件恢复：先Uninstall项目（已知哈希），再Restore-Preparation恢复前置；遇未知变化不要-force删除，不触碰宿主目录。二级恢复：保存脱敏记录后由用户批准回到pre-autoconfig或clean-os VM检查点，只恢复该测试VM。检查点不是完整备份，记录应先独立保存。VM关闭/回滚/删除需明确授权，当前不执行；删除前再次核对VM标识及绝对目录，不能递归删除计算出的未知路径。测试输入包保持原审计版本。

## 证据矩阵与下一阶段授权

| 类别 | 当前证据 | 状态 |
| --- | --- | --- |
| 既有Zen实机 | 用户反馈核心四组合和S1–S5；WinINet/Toolhelp v2只读实机 | 已通过，范围见既有记录 |
| 自动化模拟 | 71Node/四组PowerShell/ZIP隔离文件安装与VM脚本模型 | 已通过，不是真实独立浏览器 |
| 真实隔离浏览器 | VM内全新加载、持久停用、卸载及前置恢复 | 未创建、未执行、Pending |

需要独立批准的具体动作：新测试VM/磁盘/只读输入介质，Windows镜像来源及资源预算，来宾Zen安装和指定目录，测试接口开发/启动，来宾AutoConfig沙箱变更与项目安装，真实SearchService写入、来宾启用/停用/卸载/前置恢复和用户手动启停。此方案不是这些操作的授权。当前仓库无改动，不打Tag/推送/创建Release。先补齐真实隔离结果，再决定正式v0.1.0发布。

最新发布策略：本文件保留为正式v0.1.0后续任务；当前v0.1.0-beta.1允许公开测试，但不能把未创建的VM标为已实测。后续执行时重新确认所用候选包版本及哈希。
