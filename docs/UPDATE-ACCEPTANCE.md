# Zen 模块更新与自动切换集成验收准备

## 已确认的真实证据

用户在 Zen 父进程用新版独立只读 WinINet 诊断获得两次 result=pass，结构布局正确：

| 实际状态 | flags | manualProxy | matchesExpectedClashEndpoint | 应判定的手动 Clash 代理 |
|---|---:|---|---|---|
| 系统代理开 | 3 | true | true | enabled |
| 系统代理关，旧地址仍保留 | 1 | false | true | disabled |

原始服务器地址并不代表当前是否使用代理。src/core/state.cjs 已在匹配地址之前检查 flags&2，未设置手动代理位就返回 manual-proxy-off。生产逻辑对本次实测已经正确，无需为此改写核心算法。有效手动 Clash 代理要求 manualProxy && 匹配可信端点；PAC/WPAD、未知来源代理保留 unknown。

与 TUN 的合并继续使用三态 OR：任一明确 enabled -> Google；两者明确 disabled -> Bing；其他 -> 保持当前引擎。关闭系统代理但仍保留 127.0.0.1:7897、同时 TUN 未知时不能误切 Bing。

新增 retained-endpoint.test.cjs 覆盖关闭标志与保留地址、可信/第三方/协议地址、三态 OR，以及真实生产封装的模拟 WinINet -> 状态分类 -> Mihomo -> 搜索控制器集成。四种开关组合、401 保持状态及不重复写入均通过。这是模拟集成证据，不是实际搜索写入验收。

## 此次需要部署的范围：仅两个本项目文件

目标 profile：<目标Profile根目录>。

| 文件 | 本次待部署变更 |
|---|---|
| chrome/JS/proxy-search-switcher.sys.mjs | 用新版模块替换已确认所有权的旧模块，包含独立 WinINet reader、List=32、字段偏移校验、addressOfField、逐项查询与安全清理 |
| proxy-search-switcher.install.json | 仅更新模块 SHA-256，供卸载和下一次更新核验；保持原安装路径、profile、ConfigPath 等字段 |

新 native.cjs 组合 WinINet reader 和 Toolhelp；构建器已包含新依赖。本次地址缓存行为不改动三态核心或搜索调度器。主入口仍在 enabled=false 时提前返回，不初始化检测器。

**不更新** fx-autoconfig 文件、AutoConfig 沙箱设置、本地密钥配置、其他用户脚本、其他 Zen profile、Firefox、Clash 或系统代理。不会自动关闭/重启浏览器。新版诊断查询已 pass，但已安装模块仍是旧版本：本次只准备，不部署。

## 备份、哈希及停止条件

Prepare-Update.ps1 已在外部目录创建：

- originals：旧模块与原安装记录，各自 SHA-256 已验证。
- payload：新版模块与新版安装记录，各自 SHA-256 已记录。
- update-plan.json：两个允许目标、旧/新哈希、前置加载器审计和配置元数据，Applied=false。

本地配置只检查文件元数据，未读取内容、未复制或计算该文件的哈希。保持现有 enabled=false；部署前应由用户在控制台确认 disabled，后续启用必须另外授权。

旧模块 SHA-256：A137357EA13FCEE6E7E4F4A5A2CBD7641C46001D62C765C58DB9E5E63B40E929。

新版载荷 SHA-256 以 update-plan.json 为准。Verify-Update.ps1 已确认两个当前目标仍符合原始基线、两份原备份和新版载荷正确、fx-autoconfig 与配置元数据未变。任何未知文件、哈希冲突、加载器变更、配置元数据变化、路径含链接时停止，不强制覆盖。

## 获得部署授权后的执行顺序（当前不执行）

1. 用户确认仍停用并自行关闭 Zen；常规更新要求关闭，避免模块缓存和磁盘文件不同步。
2. 立即运行 Verify-Update.ps1，重复检查两个原文件和全部备份/载荷哈希。
3. 仅将 payload 的新版模块及新版安装记录应用到两个允许目标。每次替换前重新检查目标仍是已确认旧哈希；使用临时文件及可恢复的替换流程，任何异常停止并保留操作记录。
4. 写入后逐一核验新哈希，复核原备份仍完整及配置元数据/加载器未变化。两文件更新不是一个全局原子操作，因此必须留有可恢复的原始文件。
5. 暂停等待用户手动重启。先确认 fx-autoconfig 标记已加载、status=disabled；不自动清启动缓存、不触发搜索写入。

## 回滚准备

installer/Restore-Update.ps1 已实现并在临时目录测试：浏览器关闭后先验证所有目标和原备份；目标只能是计划中的原哈希或新哈希，任何其他编辑阻止全部恢复。先预览 -WhatIf，再恢复旧模块与旧安装记录，恢复后验证原哈希；支持重复执行。不恢复或覆盖配置密钥，也不卸载公共 fx-autoconfig。

```powershell
pwsh -NoProfile -File <项目目录>\installer\Verify-Update.ps1 -BackupDir '<更新准备目录>'
pwsh -NoProfile -File <项目目录>\installer\Restore-Update.ps1 -BackupDir '<更新准备目录>' -WhatIf
# 真正回滚时，用户退出 Zen、核对预览后再去掉 -WhatIf。
```

模块丢失、备份损坏或发现未知编辑时，脚本会停止，保留证据与原备份，不能通过 -Force 强行覆盖未知内容。

## 自动切换实机验收：仍未授权启用

更新后仍保持 enabled=false。API 带认证 GET /configs 的最终结果尚未回传，不能将 Promise pending 计为成功；Toolhelp 的浏览器内核心快照也仍待验证。先完成这两项独立只读检测，再另行授权 enabled=true 和实际搜索写入。

实机验收表：

| 手动代理 | TUN | 预期 |
|---|---|---|
| off，旧端点保留 | off | Bing |
| on，可信端点 | off | Google |
| off，旧端点保留 | on | Google |
| on，可信端点 | on | Google |
| off | unknown（API 401/超时等） | 保持当前 |
| on，可信端点 | unknown | Google |
| off，核心已退出且控制器拒绝连接 | 有完整退出证据的 disabled | Bing |

Clash GUI 退出但服务核心仍存在不算 TUN 关闭。用户手动调节开关/退出程序；开启自动切换后检查设置界面同步、写入次数、恢复后的切换、两个窗口单一检测器及用户手动重启恢复。出现异常立即停止测试，保存脱敏日志并按对应更新快照回滚。

## 当前验证结论

52 个 Node 测试通过；完整 PowerShell 模拟安装、准备/恢复、第一阶段应用及新增更新准备/恢复测试通过。生产配置和已安装模块没有改动。下一步是审阅两个文件的更新清单，明确授权部署；部署授权不等于自动启用授权。
