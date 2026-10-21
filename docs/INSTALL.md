# 统一安装、升级与恢复

本文对应后续源码中的新向导，已发布v0.1.0-beta.1附件没有这些新增入口；不会重传旧版本附件。本次功能仅模拟验证，没有改当前正常运行的Zen。原始私有仓库保持历史归档，后续使用public仓库。

## 最简单的入口

Windows x64，PowerShell7.2+。解压/检出完整项目后，双击根目录setup.cmd，或：

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Interactive
```

向导列出操作，自动尝试识别安装目录；有多套安装时要求手动指定。列出profiles.ini的Profile候选，但**不选择默认项**：用户必须用about:profiles核对并输入编号/根目录。所有准备快照应用/恢复前显示其目标。

没有安装PowerShell7时只提示官方获取地址；不自动安装依赖、不请求管理员权限、不设置执行策略Bypass。脚本被系统策略或下载标记阻止时先核对来源/策略，由用户处理，不通过关闭安全检查绕过。

## 只读检查

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Action Inspect -Browser zen -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>'
```

仅检查加载器、项目记录及配置是否存在，不读本地配置正文。缺少/多个Profile不得猜测；链接、Junction、未知版本加载器、旧文件冲突会拒绝修改。辅助进程未退出或无法确认路径也会停止。

## 已有fx-autoconfig：增量安装

选择菜单2。依赖固定0.10.16及锁定八文件，不覆盖加载器、其他用户脚本或已有配置。

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Action Install -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>' -WhatIf
# 用户手动完全退出目标浏览器后，移除-WhatIf再执行。
```

配置缺失时，新建enabled=false/Token为空的完整模板；已有配置不重写，Install仅在内存验证必需字段，不打印Token。配置需用户本地填写，先验证disabled再决定是否改enabled。不能把单字段片段覆盖完整JSON。已安装但配置丢失时不会擅自重建；先人工恢复。重复安装不重复写入。失败安装只回滚已拥有模块，可能保留新建停用模板和恢复记录，不删除用户配置。

新模板不启用项目，已有enabled值保持原样。不会自动退出或启动浏览器；用户手动重启后，已有enabled=true配置会正常运行原策略。

## 新环境：前置准备和应用分开

选择菜单3，再选择4；不自动从网络拉取第三方代码。用户独立获取[固定fx-autoconfig源码](https://github.com/MrOtherGuy/fx-autoconfig/tree/dfdab5684faffc112b76ccb1d8cab7f75da0102c)并解压。来源/许可见THIRD-PARTY-NOTICES.md和NOTICE。

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Action PrepareLoader -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>' -FxSourceDir '<固定源码>' -BackupDir '<全新外部备份目录>'
pwsh -NoProfile -File installer/Setup.ps1 -Action ApplyLoader -BackupDir '<同一备份目录>' -WhatIf
# 审阅快照、手动退出浏览器，并明确批准沙箱变更后：
pwsh -NoProfile -File installer/Setup.ps1 -Action ApplyLoader -BackupDir '<同一备份目录>' -AllowSandboxChange
```

准备只创建备份/载荷，不改浏览器。仅限所有拟新增文件尚不存在的新环境；遇到已有配置会在读取、哈希、复制前停止，防止把真实密钥带入快照。其他未知AutoConfig也不能在应用时合并或覆盖。

前置应用会设置general.config.sandbox_enabled=false，使可信本地脚本拥有浏览器特权。这降低AutoConfig脚本隔离，影响使用该安装目录的Profiles，不关闭网页内容沙箱。交互入口要求输入ALLOW-AUTOCONFIG，命令行需-AllowSandboxChange；WhatIf无需该同意，但仍检查浏览器退出状态。普通增量安装不会改安全策略。已存在前置配置时使用增量模式，不强行重复前置安装。

这一步仅支持Zen；Firefox仍为增量代码适配/模拟，不实际安装或测试。

## 安全升级：不用先卸载

选择菜单5生成新载荷、旧两文件备份及update-plan.json，输出计划SHA-256。备份必须在浏览器和Profile之外，应用原子替换还要求与Profile同卷。建议用户自己的外部备份目录，不放Git中；新目录不得已存在。

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Action PrepareUpdate -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>' -BackupDir '<全新外部同卷备份目录>'
# 审阅两个目标/新旧哈希，复制输出的计划SHA-256；手动退出浏览器。
pwsh -NoProfile -File installer/Setup.ps1 -Action ApplyUpdate -BackupDir '<上述备份>' -PlanSha256 '<已审阅的64位SHA-256>' -WhatIf
# 检查无误后移除-WhatIf。
```

应用仅替换项目模块和安装记录；不读取/复制/哈希密钥配置。配置长度/修改时间不符则停止，原enabled、Token等字段不变。源代码或载荷改变后需新快照和重新审阅，不能悄悄刷新计划哈希跳过。

先暂存并复核完整基线，再逐个File.Replace，外部保留replaced-original备份和receipt.json。每次替换检查进程、旧哈希及计划，完成后检查两个新哈希、公共加载器及配置元数据。两文件并非一个全局原子事务；中途失败停在failed-stop，不盲目回滚未知改动。备份与已替换部分均保留，使用恢复入口处理；已有事务禁止重放。

调用底层脚本也支持同样操作：Prepare-Update/Verify-Update/Apply-Update -PlanSha256。前两步可在目标浏览器运行时准备；应用/恢复/卸载及对应WhatIf要求它已退出。

## 恢复与卸载

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Action RestoreUpdate -BackupDir '<更新备份>' -WhatIf
pwsh -NoProfile -File installer/Setup.ps1 -Action Uninstall -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>' -WhatIf
pwsh -NoProfile -File installer/Setup.ps1 -Action RestoreLoader -BackupDir '<前置安装快照>' -WhatIf
```

审阅后明确执行时移除WhatIf。升级恢复仅恢复两个项目文件到旧哈希，任何未知文件不覆盖。卸载保留密钥配置、其他脚本、加载器及最后默认引擎。前置恢复会移除/恢复快照对应的加载器和安全选择文件，影响共享该加载器的其他脚本；需另行审查并先卸载项目，不是日常卸载的一部分。不要复用别人的备份。

安装中断仍可用Recover.ps1。永久停用依然由用户手动退出、只改单字段enabled=false、再启动；向导不处理真实Token、不自动停用或启用。详细异常恢复见RECOVERY.md。

## 验证边界

向导、Profile解析、停用模板、准备/应用/恢复、部分失败及冲突均仅在临时fixture中验证；不会把模拟说成全新真实Zen验收。Windowsx64/Zen1.23.2b原核心用户实机结果保持不变。Firefox、Hyper-V完整新环境和新安装UI实机仍未验证。此次开发不修改已发布Tag/Release或当前安装。
