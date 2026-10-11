# 稳定性实机验收步骤

当前核心功能为用户反馈通过，发布门槛2/7：四组合和设置/地址栏同步已通过，未知异常、多窗口、重启、停用/卸载及最终自动化/Git核对待完成。不推送、不创建Release；v0.1.0仅在稳定性验收后准备，发布另行授权。

本文件提供步骤，不执行任何浏览器、Clash、stop或配置操作。每阶段通过后才进入下一阶段；全部由用户手动操作。原参数intervalMs2000/timeoutMs1200，每步等待至少5秒；长时间挂起时停止调查，不凭计时判断完成。

## 通用状态诊断（只读）

父进程浏览器控制台直接粘贴，不加载file URI：

```javascript
(() => {
  const api = ChromeUtils.importESModule("chrome://userchromejs/content/uc_api.sys.mjs");
  const script = api.Scripts.getScriptData("proxy-search-switcher.sys.mjs");
  return JSON.stringify({
    loadedByLoader: script?.isRunning === true,
    status: script?.isRunning ? ChromeUtils.importESModule(script.chromeURI).getStatus() : null
  });
})()
```

仅记录系统代理/TUN（或未知）、核心在/不在、设置引擎、实际搜索域名、模块状态、观察到的异常；没有测量的次数/时刻留空。不要保存原始API响应、Token、完整配置或进程列表。可用通用测试词；普通窗口搜索，不检查隐私窗口独立默认引擎。

## S1 多窗口

1. 两者关，基线Bing；保持原窗口A，手动打开窗口B。
2. 开系统代理/TUN关→等待5秒；两窗口设置均Google，分别地址栏搜索Google，状态default:Google。
3. 两者关→等待5秒；两窗口均Bing，状态default:Bing。
4. 关闭B并保持A；再开系统代理→Google，关→Bing，检测继续。

判定：两窗口同步，无观察到异常重复切换，关闭一个窗口不停止整个浏览器检测。单timer有ESM全局实例架构及模拟证据；仅以上行为不能测量内部计数，不声称实测一个timer或零额外请求。

## S2 Zen手动重启

1. 系统代理开/TUN关，确认Google。
2. 用户手动完全退出Zen，然后启动；不改enabled=true。
3. 等待5秒，loadedByLoader=true、default:Google；设置与实际搜索Google。
4. 两者关→等待5秒恢复Bing。

若disabled、blocked、stopped、长时间waiting或设置不同，立即暂停。启用后重启通过不能代替所有退出异常分支的资源泄漏测量。

## S3 Clash GUI退出但核心仍在

1. 系统代理关/TUN开，确认Google。
2. 用户退出GUI；核对核心是否仍运行（任务管理器或既有Toolhelp v2只读探针，只回报corePresent布尔，不贴进程列表）。某些退出动作可能同时停止核心，若如此不能记为GUI-only通过，应记录并转S4或标为无法构造。
3. 核心在且API仍可读取TUN=true：预期default:Google。核心在但API拒绝连接/不可用：系统代理关时预期hold并保留原引擎；不能把它判定为TUN关闭。
4. 用户重新启动GUI并确认API与TUN恢复；按当前开关策略恢复检测，然后两者关→Bing。

API可用性/未知分支需证据，不要只凭GUI消失推断；缺证据时记录unknown/Pending。不人为改密钥或网络制造故障。

## S4 核心完全退出及恢复

1. 系统代理关/TUN开，先确认Google。
2. 用户停止Clash核心；确认无白名单核心且API拒绝连接。只退出GUI不足以证明这一条件。
3. 系统代理保持关，等待5秒：预期Bing（完整无核心快照+控制器拒绝连接）。若仅超时、其他API错误或快照失败，则应unknown保持，记录原因，不强行判失败/成功。
4. 用户重启Clash；系统代理关/TUN开→Google，再两者关→Bing。

附加未知态策略：系统代理明确开，即使核心已停，策略仍选择Google；这不保证网络可用。不必构造该无网络场景来完成必测流程。401/超时保留自动化替身证据，不制造真实故障，不计为真实401/超时验收。

## S5 临时stop与恢复

此阶段用户主动执行停用测试；当前准备阶段不调用stop。先两者关确认Bing，再在父进程控制台手动执行：

```javascript
(() => {
  const api = ChromeUtils.importESModule("chrome://userchromejs/content/uc_api.sys.mjs");
  const script = api.Scripts.getScriptData("proxy-search-switcher.sys.mjs");
  if (!script?.isRunning) return "not-loaded";
  const mod = ChromeUtils.importESModule(script.chromeURI);
  mod.stop();
  return mod.getStatus();
})()
```

预期stopped。随后用户开系统代理/TUN关并等待5秒，默认仍Bing，模块仍stopped，无项目自动切换。stop不会撤销已提交的默认引擎写入；其他扩展或用户操作可能改引擎，应分别记录。

当前模块没有公开start/reload入口，started标志使同一实例不可再次start；重新import被缓存也不能恢复。不要重载别名、手动注入初始化或使用热加载。保持enabled=true，由用户手动完全退出并重新启动Zen；当前系统代理开/TUN关应恢复Google，然后两者关恢复Bing。

此项验证当前会话停止与重新启动恢复。它不等同于enabled=false持久停用或真实卸载验收；若不做持久停用/卸载，应将相应发布门槛保留Pending或标注模拟覆盖，不宣称完整实机通过。

## 异常恢复

任意阶段出现不符或错误立即停止后续测试。保存当前脱敏状态；使用上面已审查stop（异常恢复已有用户授权）停止当前会话。不要反复切换开关或自动重启来掩盖问题。

stop失败或停止后仍疑似项目写入：用户手动完全退出Zen，在本地编辑器只将顶层唯一enabled改回false，保留所有其他字段；不备份/复制含密钥配置。用户手动启动，确认disabled，再由用户选择默认Bing或原始默认引擎。不要删除fx-autoconfig、配置或其他脚本。持久停用不热加载，必须手动重启。原始配置内容不入Git/日志。

若需模块恢复或卸载，先disabled、手动退出，采用AUTOMATIC-ACCEPTANCE.md的WhatIf与已备份哈希恢复流程；必须明确授权，不能覆盖未知文件。旧模块回滚有已知错误，应停用运行。

## 反馈格式与最终门槛

每阶段仅回报：S编号、实际开关/核心状态、设置引擎、搜索目标、模块状态、异常观察、结论（通过/失败/无法构造）。未观察到重复切换不等于测量了写入次数。

稳定性反馈收齐后：整理用户反馈及未覆盖分支，运行完整Node和四组PowerShell模拟测试，核对Git干净。更新7项门槛：四组合和搜索同步已通过；未知态须区分模拟/实机；多窗口/重启待用户反馈；关闭/卸载要区分stop、持久停用、卸载；自动化/Git最终核验仍待稳定性完成。

只有随后才整理v0.1.0发布准备：版本/许可/安装回滚说明/已知风险/验证矩阵；不创建远程仓库、Tag或GitHub Release，不推送，发布另行授权。

最新用户反馈：S1–S5全部通过。上述步骤保留为可重复验收流程，未补写内部数量或时间。持久disabled及真实卸载仍未执行。
