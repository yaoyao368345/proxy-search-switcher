# beta.1 独立公开发布操作清单（尚未执行）

用户采用提前公开测试策略；beta可明确披露未验证范围，正式0.1.0仍保留Hyper-V干净安装、持久停用、卸载/前置恢复任务。当前授权仅准备。

1. 用户明确公开仓库所有者、仓库名proxy-search-switcher、公开可见性，授权创建远程仓库。
2. 明确是否推送脱敏源码快照。当前公开HEAD已脱敏，但本地历史仍保留旧个人路径；不直接推送整个历史/所有refs。建议从最终-source.zip创建独立公开初始提交，保留SOURCE-PROVENANCE源提交记录；原项目本地历史不改写。该本地公开初始化及推送也需独立授权。
3. 推送前再次扫描快照/公开提交，核对README/LICENSE/NOTICE/安装恢复及beta说明，再明确授权远程绑定和push。
4. 用户批准在确认的公开提交创建v0.1.0-beta.1 Tag并推送。若公开提交来自净化快照，记录公开Tag提交与本地源提交两者，不将它们混为同一SHA。
5. 用户批准创建GitHub Release：标题Proxy Search Switcher v0.1.0-beta.1，必须Pre-release=true，不能作为稳定Latest；使用审阅的RELEASE-NOTES正文，上传指定两个ZIP、SHA256SUMS、说明及provenance，上传后核对哈希/资产/Pre-release标志。
6. 保留撤回方案：错误附件或隐私问题停止发布，按用户授权删除/替换对应资产；不默认为能删除代码历史或改写Tag。

以上创建远程、公开推送、Tag及Release分别未经当前阶段授权，不执行。不得自动创建Hyper-V环境、改当前Zen/Token/Clash或升级运行中的模块。

本地历史审查发现4个文档变更提交含旧个人路径；当前HEAD已脱敏，公开前不得直接推送旧历史。最终beta功能逐字对比审计候选通过，仅版本头变化。72项Node、四组PowerShell、betaZIP隔离模型链路通过。Hyper-V完整后续计划：ISOLATED-ACCEPTANCE-PLAN.md。
