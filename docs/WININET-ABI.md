# WinINet x64 ABI 修复与只读验收

## 根因及布局证据

旧代码错误地要求 INTERNET_PER_CONN_OPTION_LISTW 为 40 字节，实际 Win64 为 32 字节；用户在 Zen 父进程已测得 pointer=8、Option=16、List=32。本轮 Windows Python ctypes 使用真正的 DWORD/LPWSTR/FILETIME union 独立复核，得到相同大小、联合体大小和对齐均为 8，并核对以下偏移。

| 结构 | 字段 | x64 偏移 | 大小 |
|---|---|---:|---:|
| Option | dwOption | 0 | 4 |
| Option | Value union | 8 | 8 |
| List | dwSize | 0 | 4 |
| List | pszConnection | 8 | 8 |
| List | dwOptionCount | 16 | 4 |
| List | dwOptionError | 20 | 4 |
| List | pOptions | 24 | 8 |

微软定义：[List](https://learn.microsoft.com/en-us/windows/win32/api/wininet/ns-wininet-internet_per_conn_option_listw)、[Option union 与 GlobalFree](https://learn.microsoft.com/en-us/windows/win32/api/wininet/ns-wininet-internet_per_conn_optionw)、[InternetQueryOptionW 返回规则](https://learn.microsoft.com/en-us/windows/win32/api/wininet/nf-wininet-internetqueryoptionw)。

js-ctypes 没有本项目可用的 UnionType；使用 uint64_t 表示 Win64 的 8 字节、8 字节对齐联合体原始存储，DWORD/LPWSTR/FILETIME 均满足此大小与对齐。运行时检查 DWORD=4、WCHAR=2、pointer=8、uint64=8、Option=16、List=32，并通过地址差核对全部字段偏移；未验证布局安全停止，不强行改变结构 packing。

另一个旧问题是对 options[i].value 调用 .address()。结构的数值字段不是可依赖的 CData 实例，应使用 option.addressOfField("value") 获取真实字段地址。DWORD 从 uint32_t* 解引用；LPWSTR 从 WCHAR** 解引用。地址差用 BigInt，指针不转成 Number，避免 64 位精度丢失。[Mozilla addressOfField 实现](https://github.com/mozilla/gecko-dev/blob/master/js/src/ctypes/CTypes.cpp)。

## 独立模块及内存归属

src/platform/windows/wininet.cjs 负责 ABI、只读 WinINet 调用、GlobalFree 和 DLL 生命周期；native.cjs 仅组合此模块与原有 Toolhelp 进程查询。WinINet reader 独立关闭它的 wininet/kernel32 句柄，组合层独立关闭 Toolhelp 的 kernel32 引用。

不再使用一个三选项查询的部分返回来推测各字符串是否可释放。改为每次查询一个选项：FLAGS_UI=10、SERVER=2、AUTOCONFIG_URL=4；最后再读 FLAGS_UI 检查采样期间模式是否发生变化。每次输入 buffer 显式零初始化、count=1、connection=NULL（当前用户 LAN），dwSize 和传入长度均为 32。

字符串所有权边界：

- BOOL=FALSE 时输出不构成成功所有权交接；不读取、不解引用、不释放该失败调用的 union，即使非零。仅保存脱敏 optionId 和 GetLastError 数字。
- BOOL=TRUE 的单字符串查询才提取 LPWSTR；NULL 当作空字符串，不 readString、不 GlobalFree。
- 成功返回的非 NULL 字符串在复制为 JS string 后立刻于 finally 中 GlobalFree，一次且仅一次；后续查询失败时，前面已确认的分配早已释放。
- 成功后的字符串转换或返回形状校验失败，仍释放该次成功转交的分配；GlobalFree 返回非 NULL 时停止，不重试或 double-free。
- 失败输出的所有权没有可依赖的明确保证；宁可不碰不确定的指针，也不为避免可能的泄漏而释放未知内存。单选项调用消除“前几个选项成功、后一个失败”的多选项归属歧义；仍不宣称可清理违反 API 成功交接契约的输出。
- 单项查询并非跨选项原子快照；前后 FLAGS_UI 变化时返回 wininet-snapshot-changed，让上层维持 unknown。同 flags 的极短时间内端点变化仍是采样限制。

打开第二个 DLL 或声明失败时关闭已打开句柄；close 幂等，即使一个关闭抛错仍尝试关闭所有其他句柄。关闭后拒绝读操作。生产模块不写日志；错误只携带固定代码、选项 ID 和 Win32 数字，不输出字符串、指针、路径或异常正文。诊断只打印 flags 及布尔状态，不打印代理/PAC URL。

## 统一诊断与构建

scripts/build-wininet-diagnostic.cjs 直接嵌入同一生产 reader，生成 examples/diagnostics/03-wininet.js，不再手工维护另一套 ctypes 结构与清理逻辑。主浏览器模块、一次性完整诊断、PowerShell 安装构建均在 native.cjs 前加入 wininet.cjs。

本轮只修改仓库与输出文件；已安装的 Zen 模块仍为旧版本，没有覆盖、没有修改本地 enabled=false 配置、没有读取密钥，也没有修改 Firefox 或 Clash。备份快照中的旧载荷保持不可变，不按新代码重写原备份哈希。

## 验证范围

自动化回归使用按 Win64 对齐计算布局的独立测试内存模型，分配地址高于 Number 精确范围；标量字段返回标量，以捕捉旧 .value.address() 错误。覆盖布局/偏移、单项调用、NULL、失败非零未确认指针、后续失败、转换失败、成功部分形状异常、GlobalFree 失败、模式变化、打开/声明失败、关闭失败和幂等、组合模块以及由同一 reader 生成的控制台诊断。

完整 Node 测试及 PowerShell 临时目录安装/卸载/准备恢复测试通过。模拟测试不是实际 DLL 调用证明；真实 WinINet 查询仍 Pending。用户已完成的布局诊断只能证明尺寸，不能替代下面的实际读取验收。

## 下一步：仅 WinINet 一次性查询

在 Zen **父进程浏览器控制台**审查并直接粘贴新版 03-wininet.js 代码正文，不用 file URI，不安装额外脚本，不重启，不启用自动切换。该代码不访问 API、不读本地配置或 token、不调用 SearchService、不创建轮询。

成功预期：result=pass、pointerSize=8、optionSize=16、listSize=32，偏移与上表相同，automaticSwitching=false。若 flags=3 且简单手动代理为 127.0.0.1:7897，manualProxy=true、pacEnabled=false、autoDetect=false、matchesExpectedClashEndpoint=true。关闭手动代理可返回 flags=1；PAC/WPAD 等会如实报告标志。

若 result=stop，立即停止并回传脱敏 JSON，可能含 stage、reason、optionId、windowsError；不要继续 API 或自动切换测试。直到真实 WinINet pass 前，不进入自动切换验收。
