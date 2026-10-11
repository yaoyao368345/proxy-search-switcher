# v0.1.0 发布准备清单

- [x] 用户确认核心四组合/最终Bing、设置/地址栏及S1–S5；记录为反馈。
- [x] 来源/许可审查，本包不再分发fx-autoconfig，独立MIT许可保留。
- [x] 安装、配置、停用、卸载、回滚、兼容矩阵和发布草案。
- [x] 最终全套Node/PowerShell及生产/安装哈希核对（完成后记录）。
- [x] ZIP白名单构建、清单、哈希及解压复核（完成后记录）。
- [x] 最终Git工作区干净（提交后再次核对，输出报告记录提交）。
- [ ] 持久disabled/真实卸载、unknown故障细分实机覆盖：保留Pending，不自动执行。
- [ ] 独立发布授权；没有Tag/远程/Release。

开发测试：npm test；pwsh -NoProfile -File tests/installer.ps1；tests/preparation.ps1和tests/apply-preparation.ps1需要-FxSourceDir '<固定上游源码目录>'；tests/update.ps1。均只在work临时fixture执行。

分发准备：npm run build 后，pwsh -NoProfile -File scripts/package-release.ps1 -OutputDir '<新的外部输出目录>'。打包只使用白名单跟踪文件和通用dist，不包含*.local.json/.env/work/backups/.git。包内FILE-HASHES.json与包外SHA256SUMS.txt供复核，不视为签名。用户先核对来源及哈希，再手动选择安装操作。

最终测试结果：71项Node、四组PowerShell模拟全部通过。重建Profile专用模块哈希1F83F818A4296A54AA180A9512780E9111AC4289AC281074627B658999E92D2B，当前安装匹配；安装记录97BAE8CC756A633C9A439F47ED15F309646220A3B342FC1E7AAE98AAA892025C；通用dist F93640FB9F7F4F9F9408903EB1E968554DA749C69C1A4FE9734B4F5C190E2930。通用与专用路径标记不同，非版本偏差。

打包模拟：65文件ZIP解压数量及所有文件哈希通过；停用空Token模板通过检查。正式候选包使用最终提交重新打包，包外清单另存SHA256SUMS.txt。

最终审查补充：安装ZIP排除tests虚构Token；tests/clean-package.ps1从ZIP执行全新前置/项目安装、持久停用模拟重启、卸载/reinstall保护。真实全新浏览器仍不能用模拟替代。

最终审查详情见FINAL-REVIEW.md。隔离文件/启动模型验收已通过；真实独立环境全新安装/持久停用/卸载仍为正式发布前门槛，不因模拟通过自动完成。安装ZIP不含tests，完整开发源码检出保留测试。

最新策略：用户决定提前公开测试v0.1.0-beta.1，当前仍仅本地准备。beta披露现有覆盖缺口，正式v0.1.0的Hyper-V真实隔离门槛不取消。详见RELEASE-NOTES-v0.1.0-beta.1.md和BETA-PUBLISHING.md。
