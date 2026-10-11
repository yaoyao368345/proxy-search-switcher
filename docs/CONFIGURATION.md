# 本地配置

Profile根目录proxy-search-switcher.local.json，UTF8 JSON，最大64KiB。模板是完整JSON，不用单字段片段覆盖现有配置。仅用户本地编辑，不把Token放Git/终端/诊断输出/备份或报告。JSON顶层字段保持唯一。

| 字段 | 模板 | 作用 |
| --- | --- | --- |
| enabled | false | 首次停用；true允许真实默认引擎写入，重启生效 |
| controllerUrl | http://127.0.0.1:9097 | /configs本机直连，仅字面127.0.0.1，不支持远程或重定向 |
| token | 空 | 用户手动填写，代码仅发送到受限控制器 |
| intervalMs | 2000 | 250–60000，检测周期 |
| timeoutMs | 1200 | 250–60000，请求超时 |
| debug | false | 去重固定状态码日志，无密钥 |
| systemProxyServers | 127.0.0.1:7897 | 精确可信系统代理端点名单 |
| coreProcessNames | verge-mihomo.exe/mihomo.exe/clash-meta.exe | 名称白名单，不验证签名/文件身份 |

运行时缺省enabled为true，因此不要依赖省略字段停用；发布模板明确false。没有JSON热加载，只有手动重启读取配置。单字段启用/停用保留全部其他值；不要为测试401更改真实Token。

系统代理要求手动开启位且端点匹配；关闭位优先于缓存旧端点。PAC/WPAD、外来端点及不完整协议映射为unknown。明确任一开启即Google，其余只有两个明确关闭为Bing；未知保持。Google/Bing属于受管理引擎；用户选第三方引擎会保持。
