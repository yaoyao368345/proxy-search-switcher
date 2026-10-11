# 初始化流程与最小只读诊断

## 源码结论

本轮检查了仓库 src/runtime/start.cjs、src/core/switcher.cjs、scripts/build.cjs，及真实已安装的 proxy-search-switcher.sys.mjs 和 fx-autoconfig boot.sys.mjs。没有读取用户密钥配置，没有修改实际安装文件。

1. **disabled 是主动禁用，不是失败。** initialize() 完成读取、JSON 解析及 validateConfig 后，只有 config.enabled=false 才设置 disabled 并 return。读取失败、无效 JSON、无效配置或后续能力异常使用 blocked:capability-or-config，不会使用 disabled。
2. **模块导入会执行顶层启动入口。** 构建产物包含立即执行函数；fx-autoconfig 用 importESModule 导入 .sys.mjs，函数同步注册启动/退出观察者。上游无需也不会另行调用一个导出的 start()。export getStatus/stop 是诊断和停止接口，不是由加载器调用的启动入口。
3. **disabled 分支在检测器创建之前。** 返回发生在 SearchService 导入、ctypes/DLL 初始化、ServiceRequest 创建、Timer 导入、createSwitcher/start 之前。此状态下没有检测调度器、轮询请求或搜索写入；仅保留退出清理观察者。
4. **API/WinINet 可以独立测试。** 一次性诊断单独创建请求对象或 WinINet 句柄，在结束时清理，不创建 createSwitcher，不调用 SearchService.setDefault，也不设置计时器。
5. **导入成功不等于后台能力初始化成功。** loadedByLoader=true 只表明上游模块导入未同步抛错；之后的异步/事件初始化仍可等待或失败。但先前返回 status=disabled 足以证明 first-window 的 initialize() 已经调用，且配置验证成功。本例属于“初始化已作出停用决策，后台能力按计划未初始化”，不是“启动入口没有调用”。

状态解释：

| status | 含义 |
|---|---|
| waiting | 顶层入口执行，但窗口就绪初始化尚未完成；如果启动后长时间不变，需要调查事件是否错过 |
| disabled | 启动时配置验证成功、enabled=false，提前返回 |
| blocked:sandbox | 顶层缺少 ChromeUtils/Components，安全停止 |
| blocked:capability-or-config | initialize() 捕获配置或能力初始化异常 |
| stopped:search-incompatible | 调度器启动时搜索服务能力或引擎检查失败 |
| stopped | stop()/退出清理已执行 |
| default:* / hold:* | 调度器已运行，分别表示目标决策或保留状态 |

**status 反映启动时的配置判断，不会因后来编辑 JSON 自动更新。** 用户填写 token 不会改变当前 disabled；一次性 API 诊断会在浏览器内重新读取本地配置。模型/构建脚本不读取或回传 token。

## 已有真实证据与未验证项目

- 用户控制台已返回 loaderVersion=0.10.16、loadedByLoader=true、status=disabled。
- 用户报告 SearchService 只读结果：current=Bing、google=true、bing=true、Promise fulfilled。说明现代搜索服务可读且两个引擎存在，不能据此证明本项目后台检测已初始化。
- 此前 file URI 的 loadSubScript 被拒绝，该脚本未执行；不再使用此方式，不设置 allowUnsafeURL 或新增协议映射。
- Mihomo 带认证请求、WinINet 经 js-ctypes 查询仍待以下实机诊断；Firefox 不进行真实验证。

## 执行规则

保持 enabled=false，无需重启。依次执行 examples/diagnostics 下三段代码正文；直接粘贴到当前 Zen 浏览器控制台，不通过 file URI 加载，不用 eval 读取磁盘脚本。

1. **01-loader.js：** 预期版本 0.10.16、loadedByLoader=true、status=disabled、configValidatedAtStartup=true、startupOutcome=configuration-disabled-before-detectors。该代码只在上游已标记模块运行时读取模块状态，避免手动导入造成假阳性。
2. **02-api.js：** 浏览器内重新读取当前 profile 的本地配置，只允许 enabled=false、非空字符串 token、固定 127.0.0.1:9097。一次 GET /configs，1200ms 超时、直接访问、拒绝跳转、限制响应大小。预期 stage=api、result=pass、httpStatus=200、tunEnabled 为真实 boolean、automaticSwitching=false。401/超时等返回 stop；不要继续下一段。结果只包含白名单字段，不含密钥、授权头或响应正文。
3. **03-wininet.js：** Windows x64 布局检查后，只读当前用户 LAN 的 FLAGS_UI、PROXY_SERVER、AUTOCONFIG_URL，结束释放字符串及两个 DLL。预期 result=pass，flags=3 时 manualProxy=true、pacEnabled=false、autoDetect=false；若使用简单手动 127.0.0.1:7897，则 matchesExpectedClashEndpoint=true。flags=1 表示手动/PAC/WPAD 都关闭，flags=5/9 等对应 PAC/WPAD。flags/server 结果是查询证据，不代表已验证所有代理组合或端点进程归属。

任何 result=stop 立即停止测试并回传该段脱敏结果。不要在当前阶段启用配置或切换搜索引擎。Windows 查询不读取本地 token，也不打印 PAC URL 或代理服务器原始文本。

## 测试与修改范围

新增启动流程回归测试、控制台诊断例子及模拟测试，生产初始化、三态核心、搜索切换实现均未改动。测试覆盖主动禁用与读取/校验失败的区分、缺失启动事件、提前退出；覆盖单次 API/401/超时/拒绝跳转、配置 guard、密钥及响应正文不泄露、加载器未运行时不主动导入，以及 WinINet 未验证指针布局拒绝。模拟测试不能代替原生 Windows ABI 和真实网络验收。
