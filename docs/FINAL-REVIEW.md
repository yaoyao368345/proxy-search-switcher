# v0.1.0 发布前最终审查

## 分发审查

旧候选ZIP及SHA256SUMS一致。旧包包含测试源码的虚构Token（并非真实凭据）；正式安装候选现排除tests。包仅README/LICENSE/NOTICE/依赖锁/package元数据、src、installer、scripts、空Token停用模板、只读diagnostics、通用dist及通用文档。根目录只有proxy-search-switcher-0.1.0，安装入口installer/Install.ps1，前置准备入口Prepare.ps1。不是把dist直接复制到现有Profile。

新增打包阻止个人Users路径/Codex输出路径、非空JSON Token及私钥标识；禁止local.json/.env/work/backups/.git，源码重解析点拒绝。候选解压清单数量与每文件SHA256复核，包内FILE-HASHES/外部SHA256SUMS提供校验，不是签名。未读取当前真实Token，扫描不能证明对所有未来秘密形式都自动识别；源文件白名单和人工审查仍必要。

## 安装与恢复

首次模板disabled；增量Install要求固定独立fx-autoconfig0.10.16及用户退出目标浏览器。上游固定来源、MPL许可、安装与沙箱风险见INSTALL/THIRD-PARTY-NOTICES。本包不分发上游源码、不自动修改已有AutoConfig。MPL未来分发义务及AutoConfig权限风险均明确。

升级：先准备两文件快照和Verify，再走独立授权维护事务；本版无通用自动Apply-Update命令。普通用户使用手动退出→哈希受保护Uninstall→新版Install（配置保留）路径，不强行覆盖。卸载仅两份项目文件；Recover处理中断安装，Restore-Update处理已知更新备份，Restore-Preparation仅恢复独立前置快照；任何未知哈希/链接冲突停止。

## 隔离干净安装、持久停用及卸载

tests/clean-package.ps1从ZIP解压到全新work路径，使用固定上游源码和不可执行的虚构zen.exe；不访问现有浏览器Profile，不启动浏览器、不发真实API请求。先Prepare/Verify/Apply全新前置及项目，再用实际生成模块的生产启动入口在VM中验证disabled→enabled→disabled模拟重启；disabled时零模拟计时器、原生构造和SearchService初始化，退出移除观察者并清理模拟资源。随后Uninstall WhatIf、执行、重复执行、重装和再次卸载，核验配置/加载器/其他用户脚本保留。

上述链路已通过。它证明文件安装/持久字段读取/卸载机制，但不证明真实fx-autoconfig在全新Zen进程首次加载或真实停用/卸载行为。

## 真实隔离环境计划（未执行）

必须独立授权并由用户控制浏览器：单独Zen1.23.2b安装目录+全新Profile，完全与当前安装目录隔离（沙箱设置是安装目录范围，不能仅换Profile复用当前目录）。推荐单独Windows VM/测试账户，使用官方浏览器来源，不复制当前Profile、API Token或Clash设置。

1. 核对独立exe/安装目录/空Profile、安全路径、无旧AutoConfig及包校验和。安装前建立独立备份。
2. 用户批准只对独立目录新增固定fx加载器及sandbox_enabled=false；停用空Token模板安装，用户启动父进程检查加载/disabled、无请求/切换。
3. 用独立本地测试服务及虚构凭据证明enabled启动；不连接真实Clash。用户手动退出，只改单字段false，再启动证明disabled且跨状态变化不写默认。
4. 手动退出、Uninstall WhatIf核对两文件，授权执行卸载；检查加载器及其他脚本保留，启动无项目加载，搜索引擎保留用户选择。
5. 必要时恢复前置快照，核对独立安装沙箱恢复；当前正常安装不受影响。

未获该项真实环境授权，不创建/启动/改动实际浏览器。本次只完成隔离模拟。

## 公开发布条件

代码/包准备：可分发候选已具备校验清单、停用模板、准确文档与既有Zen用户实机覆盖；Firefox/故障模拟/资源异常/持久停用未验证范围清晰。

正式稳定v0.1.0：按用户“先补齐干净安装和卸载再发布”的门槛，真实独立环境首次加载、持久停用与卸载尚未通过，不能称已满足全部正式发布条件。先完成上面的真实隔离验收，或由用户明确接受仅隔离模拟的覆盖并变更门槛，再独立授权发布。不得将既有Profile实机或VM模型替代全新真实浏览器证据。

风险：第三方特权加载器隔离降低及版本依赖；未提供通用自动升级应用；Firefox无实机；只按进程名识别；快照竞态/内部API变化；CloseHandle/GlobalFree异常主要模拟；无签名校验、ZIP仅哈希；卸载保留配置和最后默认引擎。无Tag/Release/远程操作授权。

最新策略：用户决定提前公开测试v0.1.0-beta.1，当前仍仅本地准备。beta披露现有覆盖缺口，正式v0.1.0的Hyper-V真实隔离门槛不取消。详见RELEASE-NOTES-v0.1.0-beta.1.md和BETA-PUBLISHING.md。
