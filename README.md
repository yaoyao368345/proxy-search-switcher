# Proxy Search Switcher

Windows x64 的 Zen/Firefox 默认搜索引擎自动切换：系统代理或 Mihomo TUN 任一明确开启选择 Google，两者明确关闭选择 Bing，其余未知组合保持当前引擎。使用 fx-autoconfig 0.10.16 加载一个全局模块，无扩展或外部常驻服务。

**v0.1.0-beta.1已发布，当前源码正在改进安装方式。** 下述向导仅在后续源码中，尚未更新已发布的beta.1附件。Zen1.23.2b核心及S1–S5由用户实机确认；Firefox和全新真实浏览器安装/持久停用/卸载仍未实测。[验证范围](docs/RELEASE-MATRIX.md)。

## 功能演示

56 秒了解 Google / Bing 自动切换、未知状态保持和第三方搜索引擎保护。

https://github.com/user-attachments/assets/cb1fa629-8302-4ce2-b12b-8006646af0ad

> 视频为功能原理示意，非真实浏览器录屏；Firefox 目前仅完成适配与模拟测试。

## 安装与使用

Windows x64、PowerShell7.2+。在项目根目录双击 **setup.cmd**，选择操作后核对浏览器和Profile；也可以运行：

```powershell
pwsh -NoProfile -File installer/Setup.ps1 -Interactive
```

- **已有fx-autoconfig**：选“增量安装”。缺少配置时创建enabled=false、Token为空的模板；已有配置完整保留。
- **全新环境**：先“准备全新加载器”，审阅快照，再“应用前置安装”。固定使用fx-autoconfig0.10.16，未知文件/AutoConfig冲突会停止，不覆盖。
- **升级**：先“准备升级”，保存计划SHA-256；手动退出浏览器后“应用升级”，核对哈希并保留恢复记录，不需先卸载。

fx-autoconfig以浏览器特权运行，前置安装会降低AutoConfig脚本沙箱隔离（不关闭网页沙箱），应用必须明确确认。不自动关闭/重启浏览器，不读取Token用于显示或备份，不自动启用；用户只在本地填写配置，手动重启才生效。首次Install在内存校验已有配置，不输出其内容。

安装时请用about:profiles核对根目录，不自动选默认Profile。先用检查/WhatIf审阅，再决定写入。完整命令、权限及恢复见[安装说明](docs/INSTALL.md)、[配置说明](docs/CONFIGURATION.md)。

默认每2秒检测，Google/Bing受项目策略管理，第三方引擎保留。运行时密钥留在本地，不提交Git或报告。

## 停用、卸载和恢复

临时stop后需手动重启恢复；持久停用：手动退出，enabled=false，再启动。卸载只删除哈希匹配的项目模块和记录，保留加载器、配置及当前搜索引擎。[故障恢复](docs/RECOVERY.md)。

## 开发

Node20+，无npm依赖：`npm test`；PowerShell模拟流程见[发布清单](docs/RELEASE-CHECKLIST.md)。生产通用构建：`npm run build`；不要把通用dist文件直接覆盖Profile专用模块。

本项目MIT。fx-autoconfig独立采用MPL-2.0，不随分发包提供；[来源及许可说明](THIRD-PARTY-NOTICES.md)。

以后统一在本公开仓库开发，原私有仓库仅作历史归档；本轮不推送或修改既有Release。

安装ZIP不含开发测试目录；开发测试应从完整源码检出执行。安装包包含安装器依赖的src和dependencies.lock.json，无需Node安装即可用PowerShell增量安装。
