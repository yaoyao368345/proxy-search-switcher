# 停用、卸载与故障恢复

异常立即停止后续测试，记录固定状态码、开关、引擎及必要脱敏错误，不记录Token/Authorization/API响应或完整配置。

临时停止：父进程控制台用fx-autoconfig getScriptData确认模块已运行，再导入其chromeURI并调用stop()。它停止调度/请求并关闭DLL，不撤销既有引擎写入；同会话不能再次启动，保持enabled=true并手动重启才能恢复。若stop抛出或效果异常，手动退出Zen。

持久停用：用户手动退出全部Zen进程，只将顶层唯一enabled改回false，保留其他字段；手动启动确认disabled，再观察状态变动至少5秒没有项目写入。此实机流程仍待验收，不为了发布执行。

卸载：先备份不含密钥的所有权/模块记录，手动退出；预览后执行：

```powershell
pwsh -NoProfile -File installer/Uninstall.ps1 -Browser zen -InstallDir '<Zen目录>' -ProfileDir '<Profile根目录>' -WhatIf
# 仅获得卸载授权后去除-WhatIf
```

只移除哈希匹配的本项目模块和记录；保留fx-autoconfig、其他脚本、本地配置和当前默认引擎。未知哈希拒绝；卸载不会把默认引擎恢复为Bing，用户自行选择。当前真实卸载未测，模拟卸载/恢复通过。

失败安装用Recover.ps1；更新回滚用Restore-Update.ps1 -BackupDir '<本机更新备份>' -WhatIf，批准后移除WhatIf，仅恢复两个项目文件。损坏备份、未知哈希或运行中的浏览器会停止。回滚到有旧错误的版本后应停用，不继续运行。

独立fx-autoconfig回滚用原始前置快照Restore-Preparation，需要另行授权与确认共享依赖。不删公共加载器，不扩大恢复到其他Profile，不重写Token配置。

持久停用/卸载安全验收计划：先用户授权→核验模块记录/加载器及安全路径→手动退出→单字段false→启动确认disabled、无切换→关闭→Uninstall WhatIf→明确执行授权→卸载核验仅两文件删除、其他脚本/加载器保留→启动无项目加载且当前引擎保留。无密钥备份，恢复需用户保留配置并用增量Install重新安装。当前计划不执行。

## 新版源码统一入口

Setup.ps1 -Action RestoreUpdate/Uninstall/RestoreLoader提供同样安全校验和WhatIf。新Apply-Update记录deployment-transaction/receipt.json；部分更新failed-stop保留原文件和事务备份，不强行重放。先审阅后RestoreUpdate -WhatIf，可恢复两个项目文件分别为已知新/旧哈希的中间状态。此功能只在后续源码，已发布beta.1包不含。
