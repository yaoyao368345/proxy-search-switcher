# 兼容性与验证边界

## 第一阶段实机安装记录（2026-10-11）

用户明确授权后，先复核原始准备快照，再应用独立阶段一快照。实际新增 10 个载荷文件和 1 个本项目安装记录；4 个必要目录已创建；所有新增文件写入后及独立复核的 SHA-256 均一致，4 个旁路审计文件保持不变。新增 config-prefs.js 使用已授权的 general.config.sandbox_enabled=false。

为了确保首次重启只验证加载，配置模板设置 enabled=false，token 为空；该差异只记录在新阶段快照，原始快照未改动。没有执行代理检测、搜索切换或读取 Clash 密钥。未关闭/重启 Zen，Firefox 未修改。

当前状态：installed-awaiting-manual-restart。等待用户手动重启后，仅验证 fx-autoconfig 和全局模块加载；确认成功后才启用后续运行验收。安装文件存在及哈希通过不能代替浏览器运行验证。

恢复：自行关闭 Zen 后先运行 Uninstall.ps1，再用 Restore-Preparation.ps1 回滚阶段一快照；已修改文件停止自动恢复，本地密钥模板保留。原始没有 AutoConfig，移除新增 config-prefs.js 后下次启动恢复默认沙箱。


调查日期：2026-10-11。

| 对象 | 已验证 | 未验证 / Pending |
|---|---|---|
| Zen 1.23.2b / Gecko 157.0.1 | 本机版本、安装路径、默认安装映射、omni.ja 含现代 SearchService、原 AutoConfig 缺失 | 本项目真实加载、原生 js-ctypes、令牌认证请求、实际引擎切换及重启 |
| fx-autoconfig 0.10.16 固定提交 | 八个前置文件、MPL-2.0、全局模块导入源码；固定哈希及模拟共存安装 | 此 Zen 上实际执行；其他版本及自定义 manifest 映射 |
| Mozilla Firefox | 独立入口、能力拒绝、共用核心、合成安装/卸载 fixture | 所有真实浏览器版本；没有修改或启动 Firefox |
| Windows x64 | 真实用户系统代理/进程/API 401 的只读调查 | WinINet/Toolhelp 经浏览器 js-ctypes 调用；ARM64 |
| Windows x86 | 明确安全拒绝未支持指针布局 | 不支持 |

用户在任务中提供的 Google/Bing 双向 SearchService 成功验证属于先前技术验证；本轮没有将其计入本项目端到端验收。

自动化通过：19 个 Node 测试，覆盖九种三态组合、PAC/WPAD、第三方代理、API 错误、退出证据、竞态、无重复写入、真实模块构建、模拟多窗口单实例和退出清理。PowerShell 覆盖已有加载器共存、哈希冲突、WhatIf、重复安装/卸载、未知文件保护、恢复和 Firefox fixture。

局限：仅当前用户 LAN 代理；PAC/WPAD 维持 unknown；同端点第三方代理无法归属鉴定；本地控制器暂时不可达时保留状态；进程重命名要配置。UI/扩展同时改变 Google/Bing 时项目继续管理这两个引擎；选择其他引擎会保持用户选择。没有原子 SearchService 条件写入，竞态窗口仍需实测。

## 第二阶段用户回传的只读证据

fx-autoconfig 0.10.16 已标记本项目全局模块运行，status=disabled。用户另行验证现代 SearchService：current=Bing、google=true、bing=true。初始化流程分析与独立 API/WinINet 诊断见 INITIALIZATION.md。带 token 的 Mihomo 请求及浏览器内 WinINet 查询仍 Pending；默认搜索写入未测试。
## WinINet 布局诊断及修复

用户实测 js-ctypes：pointerSize=8、optionSize=16、listSize=32。旧 List=40 检查已修正，字段地址访问和资源归属另行修复，详见 WININET-ABI.md。源码与诊断的 49 个 Node 测试通过，含 16 个新增 WinINet 回归；Windows Python ctypes 独立布局复核一致。新版独立 WinINet 实机查询已由用户完成两次 pass，详见下方；已安装旧模块尚未更新，不进行自动切换验收。

## WinINet 读取实测与更新准备

用户回传：代理开 flags=3/manualProxy=true/端点匹配=true；代理关 flags=1/manualProxy=false/旧端点仍匹配=true，两次均 pass。生产分类逻辑已先检查手动代理位，与实测一致。52 个 Node 测试及全部 PowerShell 临时目录测试通过；新版模块准备备份与载荷完成但未部署。Mihomo 认证、Toolhelp 实测及实际搜索写入仍 Pending。详见 UPDATE-ACCEPTANCE.md。

## Toolhelp 原生能力验证
用户已确认更新后 fx-autoconfig 0.10.16、loadedByLoader=true、status=disabled；SearchService 默认 Bing 且 Google/Bing 均存在。Toolhelp 抽取生产核心后，66 项 Node 和全部四组 PowerShell 临时目录测试通过；实机快照与句柄关闭待用户手动诊断。当前安装版本尚未包含本次 Toolhelp 修正，保持配置停用。详见 TOOLHELP-VALIDATION.md。

Toolhelp v1 实机返回 incomplete/windowsError=0，未通过。Gecko FFI 清零线程错误码并保存至 ctypes.winLastError；仓库 Toolhelp/WinINet 已修复读取方式。68 项 Node 和全部 PowerShell 临时目录测试通过；v2 实机待用户执行，未部署。

Toolhelp v2 用户实机验证通过：result=pass/status=snapshot-complete-handle-closed/corePresent=true/pointerSize=8/processSize=568，偏移0/4/8/16/24/28/32/36/40/44，automaticSwitching=false。修正版尚未部署；更新准备完成，目标仅模块和安装记录，69项Node及四组PowerShell模拟测试通过。

## 首次核心功能实机验收（用户反馈）

Zen1.23.2b，Toolhelp v2安装模块：用户确认系统代理/TUN四组合分别Bing/Google/Google/Google，最终两者关闭恢复Bing，设置、地址栏实际搜索及模块状态均正常，无观察到异常或重复切换。未测量内部写入次数，无详细时间记录。多窗口、启用后重启、Clash退出恢复、临时停止/恢复等稳定性仍待验收；发布门槛2/7。

## 最新稳定性实机反馈

用户确认S1多窗口同步、S2Zen重启恢复、S3GUI退出、S4核心退出重启、S5stop停止/手动重启恢复全部通过。未提供内部计数或具体时间，不添加。最新完整矩阵见RELEASE-MATRIX.md，历史Pending段落不代表当前结论。持久disabled/真实卸载与故障细分仍待。
