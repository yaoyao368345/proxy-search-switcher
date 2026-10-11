# 第二阶段：只读运行诊断

用户已通过 Zen 控制台返回确认：loaderVersion=0.10.16、loadedByLoader=true、status=disabled。此证据仅证明加载器和模块启动；尚未证明 API、原生 Windows 调用或自动切换。用户已手动填写本地 token，代理控制器端口为 9097。

用 scripts/build-readonly.cjs 生成诊断文件（第三参数为本次授权的 profile 绝对路径）。该脚本只打包已审查源码，不读取本地配置或密钥。诊断文件由用户在 Zen 控制台主动执行，浏览器内读取该 profile 的配置并完成一次认证 GET /configs，然后检查 WinINet 系统代理和 Toolhelp 核心快照。只输出三态结果和 wouldUse，不调用 SearchService.setDefault，不创建轮询或更改设置。

必须保持 enabled=false。请求失败、配置异常或原生调用失败时立即停止后续步骤，返回脱敏 stage/reason；资源在 finally 清理。所有响应正文、请求头、密钥和异常详情都不会进入诊断结果。真实测试结果回传前，API 和原生调用仍 Pending。

异常后不启用自动切换，先保存控制台的脱敏诊断行；如需回滚，用户退出 Zen 后依次运行 Uninstall.ps1 和 Restore-Preparation.ps1（阶段一快照）。Firefox 不做真实测试。
## 已观察到的诊断文件加载拒绝

用户在当前 Zen 157 控制台通过 loadSubScript(file URI) 加载外部诊断文件时，出现 Trying to load untrusted URI。诊断脚本没有执行，API/WinINet 验收仍 Pending，测试已暂停。该调用方式撤回；不得使用 allowUnsafeURL、eval 加载磁盘代码或改变协议信任注册来强行运行。错误中的中文 URI 编码异常是额外现象，未证实它是信任拒绝的根因。

继续验证时采用用户审查后直接粘贴诊断代码正文到特权控制台的方式，不调用 file URI 加载器。保持 enabled=false，无需重启；代码只有一次读配置、一次本地请求及只读 Windows 查询，输出脱敏 JSON。当前没有执行新的浏览器测试或修改安装文件。

原始错误已保存在用户输出目录的只读诊断加载失败记录.md。回滚仍按 INSTALL.md 执行：用户关闭 Zen，Uninstall 后使用阶段一快照 Restore-Preparation；保留本地密钥配置。