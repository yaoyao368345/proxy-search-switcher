# 安装与安全边界

## 前置条件

Windows x64、PowerShell7.2+、现代SearchService，Google/Bing存在且未隐藏；fx-autoconfig固定0.10.16、提交dfdab5684faffc112b76ccb1d8cab7f75da0102c，来源见THIRD-PARTY-NOTICES.md。Zen1.23.2b已实测，Firefox未实机验证。

本包不安装或覆盖fx-autoconfig。上游配置要求general.config.sandbox_enabled=false以执行特权代码；这降低AutoConfig隔离，不关闭网页内容沙箱，影响使用该安装目录的Profiles。安装前自行审查上游并备份其目标文件；已有AutoConfig冲突时停止，不覆盖。准备工具Prepare/Verify/Apply需独立授权，只允许新增安全验证文件。回滚前置安装须按原快照Restore-Preparation，不能删除其他脚本共享的加载器。不要套用其他机器备份。

本项目增量Install不会改安全设置或加载器；fx-autoconfig八个文件按dependencies.lock.json规范化UTF8-LF检查版本来源，未知版本拒绝。

## 增量安装

1. about:profiles核对实际Profile根目录，使用目标浏览器正确目录。
2. 模板examples/config.example.json默认enabled=false，复制到Profile根目录proxy-search-switcher.local.json，在本地填写必要配置及Token，勿提交、上传或复制到报告。
3. 从解压包根目录执行Inspect；它只检查能力，不启用。
4. 手动完全退出目标浏览器，再执行安装。安装器会在内存解析本地配置以校验，不输出Token；不创建含密钥备份。它创建项目模块和所有权记录，不覆盖未知文件。
5. 手动启动，验证加载器和status=disabled。单独决定是否启用；手动退出后仅改顶层enabled=true，再启动，首轮就可能写默认引擎。

```powershell
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir '<Zen安装目录>' -ProfileDir '<Profile根目录>' -Inspect
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir '<Zen安装目录>' -ProfileDir '<Profile根目录>' -WhatIf
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir '<Zen安装目录>' -ProfileDir '<Profile根目录>'
```

Firefox使用Browser firefox，但所有真实测试未执行，不据Zen结果宣称Firefox实测。脚本不会自动结束浏览器。

## 安全更新

Prepare-Update只为已拥有模块/记录生成两文件备份、载荷和固定哈希计划，不读/复制/哈希密钥配置。Verify-Update必须在部署前检查旧目标/备份/载荷/加载器/配置元数据。不要直接复制dist通用文件；它没有目标Profile安装路径，与专用载荷哈希不同。

```powershell
pwsh -NoProfile -File installer/Prepare-Update.ps1 -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>' -BackupDir '<全新外部准备目录>'
pwsh -NoProfile -File installer/Verify-Update.ps1 -BackupDir '<准备目录>'
```

v0.1.0提供准备、验证和恢复脚本，未提供通用自动应用更新命令。批准部署后只使用准备payload、复核目标旧哈希、外部事务备份、写后校验与操作记录；两个文件不是整体原子事务。未知文件变化、重解析点或冲突立即停止。更新后手动重启验证。

停用、卸载和异常恢复见RECOVERY.md。此前机器的授权历史单独保存在INSTALL-HISTORY.md，不作为通用安装步骤，分发包不包含该机器历史。


## 独立获取fx-autoconfig

从 THIRD-PARTY-NOTICES.md 的固定提交下载源码ZIP并解压，核对LICENSE与dependencies.lock.json的八文件；不要用不匹配的latest替换。若浏览器已有AutoConfig或未知加载器，停止，不覆盖。全新环境先用Prepare.ps1 -Browser zen -InstallDir '<独立Zen目录>' -ProfileDir '<独立Profile>' -FxSourceDir '<固定源码>' -BackupDir '<全新外部快照>'，再Verify-Preparation.ps1 -BackupDir '<快照>'；审阅目标文件、沙箱变更及回滚后，手动退出独立浏览器并授权Apply-Preparation.ps1 -BackupDir '<快照>'。第一次用停用空Token模板，仅验证加载。不要复用别人的准备快照。

依赖配置降低AutoConfig沙箱隔离，需用户单独批准，变更范围是该浏览器安装。已存在依赖时优先增量Install，不修改第三方文件。新安装项目与加载器使用不同所有权/恢复机制；卸载项目不会撤销沙箱变更。

升级采用Prepare-Update/Verify-Update的两文件计划；本版没有通用自动Apply-Update命令。用户需在独立批准的维护流程中替换固定payload与配套记录、保留事务/旧哈希并手动重启。若不具备该流程，应采用已验证的关闭浏览器→Uninstall（保留配置）→用新版源码Install路径，不直接覆盖旧模块。升级前核验旧所有权/模块及其他脚本；任何未知编辑拒绝。当前环境本阶段不执行任何升级。
