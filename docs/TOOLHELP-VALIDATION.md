# Toolhelp 只读验证

当前已安装模块的 PROCESSENTRY32W 大小568正确，但旧实现仅检查总大小且忽略 CloseHandle 返回值。仓库已抽取 toolhelp.cjs 并补充全部字段偏移、关闭失败处理及脱敏错误；尚未部署这些源码调整。

x64 布局：DWORD/LONG4、ULONG_PTR8、WCHAR2；字段偏移0/4/8/16/24/28/32/36/40/44，WCHAR[260]结束于564，总大小按8对齐到568。

使用 TH32CS_SNAPPROCESS=2；dwSize 在 First 前初始化；First/Next 返回失败后读取 ctypes.winLastError，只有18表示完整终止；NULL及全1无效句柄不关闭，有效句柄无论遍历成功失败均关闭一次。CloseHandle失败不给出核心缺席结论，不重试。DLL关闭幂等，声明失败清理已打开DLL。

诊断由 scripts/build-toolhelp-diagnostic.cjs 直接嵌入生产核心生成，不调用生产启动入口、API、WinINet或调度器，不读取配置或密钥。仅输出匹配默认 coreProcessNames（verge-mihomo.exe/mihomo.exe/clash-meta.exe）的布尔值、ABI数字、状态及固定错误码；名称白名单不构成签名/路径身份认证，自定义名称需要后续人工确认。

父进程控制台直接粘贴 examples/diagnostics/04-toolhelp.js 正文，不使用 file URI。成功应为 result=pass/status=snapshot-complete-handle-closed，processSize=568、pointerSize=8、automaticSwitching=false；核心正在运行应 corePresent=true。stop时保留脱敏输出并停止后续验收。实机尚未验证，用户手动返回结果后记录。

参考：[结构体定义](https://learn.microsoft.com/en-us/windows/win32/api/tlhelp32/ns-tlhelp32-processentry32w)、[快照与释放](https://learn.microsoft.com/en-us/windows/win32/api/tlhelp32/nf-tlhelp32-createtoolhelp32snapshot)、[遍历终止](https://learn.microsoft.com/en-us/windows/win32/api/tlhelp32/nf-tlhelp32-process32nextw)。

生产配置保持 enabled=false；本次不修改安装文件。实机通过后仍须准备本次代码的独立更新方案和启用授权，才能进行四种代理组合验收。

## 实机反馈与 v2

v1 返回 process-enumeration-incomplete/windowsError=0，未通过。根因由 [Gecko CTypes.cpp](https://github.com/mozilla/gecko-dev/blob/master/js/src/ctypes/CTypes.cpp) 的 FunctionType::Call 确认：FFI 调用前清零线程 LastError，调用后缓存到 winLastError。v2 不声明/调用 GetLastError，直接读取缓存；快照创建错误即时捕获，遍历终止码在关闭句柄之前保留。WinINet 同步修复错误读取，成功路径及内存所有权不变。实机 v2 Pending。
