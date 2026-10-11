# 架构与依赖选型

## 第一阶段实机安装记录（2026-10-11）

用户明确授权后，先复核原始准备快照，再应用独立阶段一快照。实际新增 10 个载荷文件和 1 个本项目安装记录；4 个必要目录已创建；所有新增文件写入后及独立复核的 SHA-256 均一致，4 个旁路审计文件保持不变。新增 config-prefs.js 使用已授权的 general.config.sandbox_enabled=false。

为了确保首次重启只验证加载，配置模板设置 enabled=false，token 为空；该差异只记录在新阶段快照，原始快照未改动。没有执行代理检测、搜索切换或读取 Clash 密钥。未关闭/重启 Zen，Firefox 未修改。

当前状态：installed-awaiting-manual-restart。等待用户手动重启后，仅验证 fx-autoconfig 和全局模块加载；确认成功后才启用后续运行验收。安装文件存在及哈希通过不能代替浏览器运行验证。

恢复：自行关闭 Zen 后先运行 Uninstall.ps1，再用 Restore-Preparation.ps1 回滚阶段一快照；已修改文件停止自动恢复，本地密钥模板保留。原始没有 AutoConfig，移除新增 config-prefs.js 后下次启动恢复默认沙箱。


## 独立模块与成熟加载器

采用 `fx-autoconfig` 的全局 `.sys.mjs` 入口：`chrome/JS/proxy-search-switcher.sys.mjs`。上游在父进程启动时用 `ChromeUtils.importESModule` 导入模块，Gecko 按模块 URI 缓存实例；不会像 `.uc.js` 那样每个窗口注入。模块内部还有初始化守卫，首次窗口完成启动后移除观察者，创建一个串行检测器；退出时清理定时器、请求及 DLL 句柄。

构建将本项目模块包装进一个局部 `scope`，避免在第三方全局对象上发布核心符号。没有自研 AutoConfig 加载器、`@backgroundmodule` 或 `.uc.mjs` 窗口入口。窗口事件用于等待 SearchService 可用，不承担脚本加载。

## 参考项目、版本与许可

| 项目 | 实际审查版本 | 许可 | 结论 |
|---|---|---|---|
| [MrOtherGuy/fx-autoconfig](https://github.com/MrOtherGuy/fx-autoconfig) | 0.10.16，`dfdab5684faffc112b76ccb1d8cab7f75da0102c` | MPL-2.0 | 唯一浏览器加载基础设施；保持源码不变，作为外部前置依赖 |
| [BibekBhusal0/zen-custom-js](https://github.com/BibekBhusal0/zen-custom-js) | `c08488c835b9a85b22defae543a59bd37ba007fe` | MIT | 参考 `utils/search-service.js` 的现代模块导入及服务封装，未复制 UI 或整库 |
| [vheidari/Switcher](https://github.com/vheidari/Switcher) | 2.0.1，`4d69a6910085fe8ed0d16a5968af30465f421757` | MPL-2.0 | WebExtension 的 `browser.proxy.settings` 修改的是浏览器代理；不能证明 Windows/Mihomo 状态，故不采用 |

上游 [boot.sys.mjs](https://github.com/MrOtherGuy/fx-autoconfig/blob/dfdab5684faffc112b76ccb1d8cab7f75da0102c/profile/chrome/utils/boot.sys.mjs) 根据后缀判断全局模块，并在加载器初始化时导入；`utils.sys.mjs`、`fs.sys.mjs`、`uc_api.sys.mjs`、`module_loader.mjs` 与 `chrome.manifest` 必须属于同一版本。`dependencies.lock.json` 用 UTF-8 / LF 归一化 SHA-256 核验八个前置文件，兼容 Windows 换行而不放宽代码内容核验。

项目的 MIT 许可仅覆盖本项目原创代码。备份准备载荷附带完整上游 MPL 许可；未修改或重新许可上游文件。安装器不在线下载或执行最新远程脚本。更新加载器须重新审查版本、许可证及依赖锁。

## 状态检测

`src/core/state.cjs` 维护 enabled / disabled / unknown。任一明确 enabled 足以选择 Google；只有两个 disabled 才选择 Bing。PAC、WPAD、未知来源代理、部分协议代理、读取失败均保留 unknown。允许列表指定用户信任的 Clash 端点，不能证明相同端口的进程产品身份；第三方软件占用同一端点属于当前识别边界。

Windows 适配通过浏览器内 js-ctypes 调用 `InternetQueryOptionW(INTERNET_OPTION_PER_CONNECTION_OPTION)`，读取当前用户 LAN 的 FLAGS_UI、PROXY_SERVER 和 AUTOCONFIG_URL。选择 WinINet 而非进程/端口或单个 ProxyEnable 注册表值，是为了同时读出手动代理、PAC 与自动发现的有效选项。它不读取 WinHTTP、独立 VPN/RAS 连接或浏览器自己的代理策略。[Microsoft API](https://learn.microsoft.com/en-us/windows/win32/api/wininet/nf-wininet-internetqueryoptionw)、[选项结构](https://learn.microsoft.com/en-us/windows/win32/api/wininet/ns-wininet-internet_per_conn_optionw)。

本机只读调查确认 HKCU 的 ProxyEnable=1、ProxyServer=127.0.0.1:7897、DefaultConnectionSettings flags=3；不同权限上下文的注册表视图可能不同，不能用受限环境的空值证明真实关闭。本项目不写注册表。

Mihomo GET `/configs` 读取严格的 boolean `tun.enable`。401、超时、JSON 异常、一般网络错误保留 unknown。只有**控制器拒绝连接且完整 Toolhelp 进程快照证明配置列出的核心进程全不存在**时，才将 TUN 视为 disabled；不能仅凭 GUI 退出，因为服务中的核心可能仍在。自定义/重命名核心必须更新 `coreProcessNames`，否则退出证明的假设不成立。

请求仅允许字面地址 `http://127.0.0.1:<port>`，直接访问本机、拒绝跳转、限制响应大小、禁止日志输出响应内容或授权头。密钥保存在 profile 外的指定本地文件或 profile 的 `.local.json`，模块不嵌入密钥。

## 搜索服务与生命周期

Zen / Firefox 各有入口，共用现代 `moz-src:///toolkit/components/search/SearchService.sys.mjs` 能力检查。显式等待 init，确认 Google/Bing 存在，只在当前默认值属于管理范围且目标不同的情况下 setDefault，使用 CHANGE_REASON.USER。不创建引擎、不改 `search.json.mozlz4`，不触碰隐私窗口的独立默认引擎。

轮询串行，默认两次检测开始间隔约 2 秒；耗时超过间隔时在上次完成后续行，绝不堆积并发。未知状态保留现值；用户选择第三个引擎时暂停覆盖。写入前再次读取默认值以缩小竞态，但内部 API 没有原子条件写入，仍需真实交互验收。

## AutoConfig 沙箱变更：第一阶段已授权应用

Zen 当前 release 构建的 AutoConfig 默认沙箱阻止特权 API。上游 [config-prefs.js](https://github.com/MrOtherGuy/fx-autoconfig/blob/dfdab5684faffc112b76ccb1d8cab7f75da0102c/program/defaults/pref/config-prefs.js) 要求 `general.config.sandbox_enabled=false`，才能让 `config.js` 注册 profile 的 chrome.manifest 并导入 boot 模块。这是**降低 AutoConfig 脚本隔离边界**，不是普通搜索设置，也不是关闭网页内容进程沙箱。

影响范围：使用该 Zen 安装目录启动的所有 profile。只有具有 loader 文件的 profile 会继续执行自定义脚本；profile/chrome 内的代码因此拥有浏览器特权，必须保护文件写权限并审查脚本。前置依赖安装不改变系统代理或 Clash 配置；上游可维护 userChromeJS 自身偏好和菜单。

本项目的增量安装器不会设置该偏好，既有已启用的 fx-autoconfig 环境可以共存；当前机器的全新前置安装已在第一阶段单独批准并完成；重启和运行验收仍按后续阶段执行。回滚前置安装时先移除新增的 config-prefs.js，再移除 hash 匹配的 loader 文件；当前机器没有原有 AutoConfig，下一次正常启动会恢复默认沙箱策略。已有前置环境只卸载本项目模块，不卸载公共加载器。[Mozilla 沙箱选择实现](https://github.com/mozilla/gecko-dev/blob/master/extensions/pref/autoconfig/src/nsReadConfig.cpp)。

## 兼容性风险

- Firefox 内部模块 URI / 方法、ServiceRequest、js-ctypes 或 AutoConfig 政策可能变化；能力缺失时停止。现代 Services 是 chrome 全局，不能假定旧 Services.sys.mjs 仍存在。
- 当前 native 结构仅验证 Win64 布局假设，32 位明确拒绝；ARM64 未验收。DLL 通过 System32 绝对路径加载。
- 0.10.16 已完成源码审查及安装核验模拟，尚未在此 Zen 上运行；不能将上游的一般 Firefox 支持等同于 Zen 157 验收。
- 非固定版本、修改过的加载器、非默认 chrome.manifest 映射会被拒绝，需要人工审查后更新依赖锁。
- 本阶段不启动、修改或真实验收 Firefox。原生调用和 API token 认证仍待 Zen 实测。

## WinINet ABI 修订

原生 WinINet 查询拆为 src/platform/windows/wininet.cjs，Option=16、List=32，运行时还检查字段偏移。通过 addressOfField 获取 union 存储；逐项查询只释放成功转交的字符串，失败输出指针保持未触碰。生产和生成的只读诊断使用同一 reader。细节、失败语义和限制见 WININET-ABI.md。
