# Proxy Search Switcher

Windows x64 的 Zen/Firefox 默认搜索引擎自动切换：系统代理或 Mihomo TUN 任一明确开启选择 Google，两者明确关闭选择 Bing，其余未知组合保持当前引擎。使用 fx-autoconfig 0.10.16 加载一个全局模块，无扩展或外部常驻服务。

**v0.1.0-beta.1 公开测试版准备中（尚未发布）。** Zen 1.23.2b 已由用户完成核心及稳定性实机验收；Firefox 仅适配与模拟测试。尚未创建版本Tag或GitHub Release。全新真实环境安装、持久停用和卸载尚未实测，Hyper-V验收保留为正式v0.1.0后续任务。详见[验证矩阵](docs/RELEASE-MATRIX.md)和[beta说明](docs/RELEASE-NOTES-v0.1.0-beta.1.md)。

## 功能演示

56 秒了解 Google / Bing 自动切换、未知状态保持和第三方搜索引擎保护。

https://github.com/user-attachments/assets/cb1fa629-8302-4ce2-b12b-8006646af0ad

> 视频为功能原理示意，非真实浏览器录屏；Firefox 目前仅完成适配与模拟测试。

## 安装与使用

需要 Windows x64、PowerShell7.2+、已安装且匹配依赖锁的fx-autoconfig0.10.16。fx-autoconfig脚本以浏览器特权运行；上游要求关闭AutoConfig脚本沙箱，降低隔离边界（不关闭网页沙箱）。只安装可信固定版本，先确认[安装文档](docs/INSTALL.md)的权限和安全影响，再自行退出浏览器安装。安装器从源码生成目标Profile专用模块，拒绝覆盖未知文件或修改加载器。

从 `examples/config.example.json` 创建Profile根目录的 `proxy-search-switcher.local.json`，模板默认停用、Token为空。只在本地填写密钥，先完成停用加载检查，再手动仅改enabled并重启。[配置说明](docs/CONFIGURATION.md)。

```powershell
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir 'D:\Zen' -ProfileDir '<Profile根目录>' -Inspect
# 手动退出Zen后：
pwsh -NoProfile -File installer/Install.ps1 -Browser zen -InstallDir 'D:\Zen' -ProfileDir '<Profile根目录>'
```

默认每2秒检测；当前为Google/Bing时受项目策略管理，第三方引擎保留。配置变更仅下次启动生效。

## 停用、卸载和恢复

临时stop后需手动重启恢复；持久停用：手动退出，enabled=false，再启动。卸载只删除哈希匹配的项目模块和记录，保留加载器、配置及当前搜索引擎。[故障恢复](docs/RECOVERY.md)。

## 开发

Node20+，无npm依赖：`npm test`；PowerShell模拟流程见[发布清单](docs/RELEASE-CHECKLIST.md)。生产通用构建：`npm run build`；不要把通用dist文件直接覆盖Profile专用模块。

本项目MIT。fx-autoconfig独立采用MPL-2.0，不随分发包提供；[来源及许可说明](THIRD-PARTY-NOTICES.md)。

安装ZIP不含开发测试目录；开发测试应从完整源码检出执行。安装包包含安装器依赖的src和dependencies.lock.json，无需Node安装即可用PowerShell增量安装。
