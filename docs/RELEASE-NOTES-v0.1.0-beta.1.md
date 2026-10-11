# Proxy Search Switcher v0.1.0-beta.1

公开测试版（GitHub Pre-release），不是正式稳定版。覆盖范围与限制见下文。

Windows x64，通过fx-autoconfig0.10.16全局模块，系统代理或Mihomo TUN任一明确开启选择Google，两者明确关闭选择Bing；无法确定时保持当前。选择第三方引擎时保持；Google/Bing属于自动管理范围。无扩展或外部常驻服务。

## 已验证与尚未验证

- Zen1.23.2b：用户反馈四组合、最终Bing、设置与实际地址栏同步，以及S1多窗口/S2重启/S3GUI退出/S4核心退出恢复/S5stop后重启恢复全部通过。
- WinINet/Toolhelp v2：用户只读实机结构/快照/资源清理通过；计时器数量或内部写入次数未实测，不作宣称。
- Node与PowerShell：三态、401/超时、异常清理、隔离文件安装/持久停用模型/卸载和恢复为自动化/模拟覆盖。
- Firefox：只有适配及模拟，未真实安装或功能验证。
- 全新真实浏览器环境首次安装、持久停用与卸载尚未实测；Hyper-V独立验收作为正式v0.1.0的后续任务，不用模拟替代。

## 依赖与权限提示

需要Windows x64、PowerShell7.2+、Google/Bing引擎存在、固定fx-autoconfig0.10.16。上游需要general.config.sandbox_enabled=false，降低AutoConfig脚本隔离，并使受信任本地脚本获得浏览器特权；不关闭网页内容沙箱，但权限风险真实存在。未知加载器/AutoConfig冲突时停止，不覆盖。项目增量安装器不修改公共加载器或沙箱策略。

本项目MIT，fx-autoconfig独立MPL-2.0依赖，不随包分发。来源和许可见NOTICE/THIRD-PARTY-NOTICES.md。

## 安装与退出测试

安装包模板enabled=false/Token空；用户本地填写配置，停用加载验证通过后自行决定启用，配置更改需手动重启。启用首轮允许真实默认引擎写入。不要将密钥放入反馈、Git或日志。stop仅当前会话停用，恢复需要手动重启；持久停用仅改enabled=false后重启。

卸载需要用户先退出目标浏览器，Uninstall -WhatIf预览后执行，只移除已拥有且哈希匹配的项目模块/记录，保留加载器、本地配置和最后默认引擎。不会自动恢复用户原引擎；用户自行选择。升级/恢复及前置安装说明见docs/INSTALL.md、docs/RECOVERY.md。

## 已知限制

内部Gecko接口版本风险；快照滞后与用户更改竞态；只按进程名识别；系统代理开而核心停止仍Google不证明网络健康；没有JSON热加载；异常资源清理和未知态详细故障主要模拟；Firefox及全新真实安装链路未验收。普通窗口默认引擎受管理，隐私窗口独立默认不覆盖。

## 计划附件

- proxy-search-switcher-0.1.0-beta.1.zip：安装包，含项目源码/安装器/通用构建/文档，不含开发测试、Token、现有Profile、第三方加载器。
- proxy-search-switcher-0.1.0-beta.1-source.zip：脱敏HEAD完整源码快照，含模拟测试与虚构测试值，无Git历史/本机配置；SourceProvenance注明本地源提交。
- SHA256SUMS.txt：以上两个ZIP的重新计算SHA-256，仅完整性校验，不是签名。
- RELEASE-NOTES.md、SOURCE-PROVENANCE.json：发布文字及提交/功能一致性来源说明。

反馈只提供浏览器版本、开关状态、默认引擎/搜索域名、模块状态及脱敏错误，不能提供Token、Authorization、完整配置或API响应。正式v0.1.0另行验收与授权。
