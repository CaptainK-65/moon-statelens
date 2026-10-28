# 行为验证与回归门禁（v0.3）

v0.3 在原有双算法学习和实际适配器上增加三种工作流：单组件规则检查、
保存模型回归套件，以及多上下文差异诊断。规则和回归断言可以发现两版共有的缺陷，
不必依赖“新旧版本输出不同”。核心代码仍由 MoonBit 实现，没有引入外部学习或测试引擎。

## 从源码完整复现

使用仓库固定工具链和 PATH 中的 sqlite3：

```sh
moon update
moon run tools/verify_v03.mbtx
```

工具实际运行三个固定实验、JSONL 和 HTTP 会话服务、真实 SQLite、
保存模型与套件、正常及受控变异回归、规则和多差异确认、HTML/JUnit 导出，
并验证重复输出不会覆盖旧文件。结果位于 `_build/v0.3-evidence/run-*/`。
受控变异是适配层故意引入的缺陷，不代表 SQLite 或任何第三方软件存在漏洞。

## 保存一次学习成果，持续运行回归

首先通过 `run-config` 学习目标，配置 `artifacts.model` 保存完整模型。
下面用仓库内的会话参考模型演示套件导出；该步骤不声称从文件学习未知组件：

```sh
moon build --target native --deny-warn
moon run cmd/statelens --target native -- generate-suite fixtures/session.json wp 2 session-suite.json
moon run cmd/statelens --target native -- regress-config configs/session-jsonl.json session-suite.json compact
```

`generate-suite MODEL PROFILE BOUND OUT` 支持 `state`、`transition`、`w`、`wp`。
生成器先最小化模型，记录原始输入和**每一步**期望输出，去除重复词。
默认最多检查 100,000 个候选词、2,000,000 个累计生成输入符号，单词最长 4,096；
字符化工作默认上限 1,000,000。库接口可显式设置预算。
若最小化或字符化准备本身无法完成，会直接报错，不产生伪造的完整套件。
截断时 `generation_complete=false`，CLI 退出 3，仍可检查已保存的部分套件。
`state` 仅表示模型状态覆盖，`transition` 表示模型迁移覆盖。
只有完整生成并执行的 W/Wp 套件，才在确定、完全、可重置、相同字母表及
**实际行为状态数不超过声明上界**等前提下提供条件式一致性证据。
修改文档中的 `generation_complete` 不会改变结论：导入会重新生成断言并核对全部证据。

`regress-config` 不重新学习被测目标。它对保存的期望输出执行实际查询，报告
原始 case 编号、实际输出和首个失配位置（从 0 计数）。
一个回归失配表示实际组件不满足保存的模型断言；要确认旧、新**实际程序**差异，
继续使用 `compare-config`、`diagnose-config` 或双方 `replay-config`。

## 可核查的前缀共享

在确定性 Mealy 语义下，实际执行 `login → request → logout` 得到的完整输出，
同时提供它的 `login` 与 `login → request` 前缀断言。
Trie 仅保留最长物理词，证书 `case_to_word` 为**每一个原始 case**记录负责它的物理词；
期望输出与输入前缀均重新核对。它不是随机删测试，也不会降低原始完整 W/Wp 的义务。

默认每个物理词执行一次，再进行一次独立、绕过缓存的稳定性复测。
复测不会被压缩或缓存命中替代。`raw` 与 `compact` 使用相同复测次数，均运行全部测试；
因此成本比较不会混入失败后提前退出带来的差异。
不稳定、查询预算耗尽或超时不会得到 `passed=true`。
即使部分 case 已执行，尚未完成复测的 case 仍显示 `not-run`。
这种调度依赖相同初始状态和与历史无关的确定性输出，不适用于任意并发、随机或时钟系统。

`moon run cmd/statelens --target native -- demo lru-gate` 还会仅通过真实
`jhshuai/moonlarder` 的公开 API 学习十状态有限 LRU 抽象，把套件序列化并导入，
再在一个新的实际 LRU 适配器上执行保存的断言，展示对 MoonBit 生态组件的直接用途。

配置 artifact 遵循 replay 规则：可声明 `report`、`traces`，不接受 `model`、`dot`。
报告内含基线模型、断言结果、证书和实际统计；输出仍使用独占创建和既有路径检查。

## 有限安全规则

```sh
moon run cmd/statelens --target native -- rules-config configs/session-jsonl.json fixtures/session-rules.json
```

规则以输入/输出**事件对**匹配。例如 `logout / ok` 才激活约束，
`login / ok` 才解除约束，失败的登录不会解除退出后的隔离要求。
支持三类：`forbidden`（始终禁用某事件）、`after`（触发事件后禁用）、
`until`（触发后禁用，直到解除事件）。`after` 与 `until` 重置后默认未激活。
同一步先处理解除，再处理触发，最后检查禁用条件；因此同一步重新触发仍生效。
规则 ID 在一次请求中必须唯一。

搜索在“学习模型 × 两状态监视器”上执行，默认最多 100,000 个状态对。
找到的输入序列必须在实际组件上绕过缓存重新执行，并再次检查规则。
`confirmed-violation` 包含实际输出和违规位置；`not-reproduced` 保留未复现的模型预测；
`no-model-violation` 只是当前模型中没有违规路径，仍依赖学习证据。
预算不足为 `inconclusive`。这不是完整 LTL、并发模型检查或安全漏洞扫描器。

## 多上下文差异诊断

```sh
moon run cmd/statelens --target native -- diagnose-config configs/sqlite-kv.json configs/sqlite-mutant.json
```

先独立学习双方，再遍历可达的模型乘积图，以**共同输入历史**关联双方状态。
不要求同名状态对应，也不假定一对一映射。每个发现的输出不同边都有一个可重放上下文，
逐一在双方实际目标上重新执行。默认最多 64 个发现、100,000 个状态对、1,000,000 条检查边；
长度或累计符号预算同样受限。截断及未复现预测保留在报告中，不算“无差异”。
`confirmed_contexts` 是已确认输入上下文数，**不是独立 bug 数量**。
当前真实 SQLite/受控回滚变异案例产生 4 个确认上下文。
原有 `compare-config` 仍适合只需首个差异并继续反例修正的场景。

## 离线审查和 CI 输出

将实际命令的 JSON 输出保存为文件，或配置 `artifacts.report`，然后：

```sh
moon run cmd/statelens --target native -- render-report report.json report.html
moon run cmd/statelens --target native -- junit regression-report.json regression.xml
```

HTML 无 CDN 或网络依赖，支持筛选、分页、逐步输出检查、模型迁移表和原始 JSON 下载。
所有目标标签通过文本节点显示；内嵌 JSON 使用惰性转义文本，不拼接可执行脚本。
JUnit 为每个原始 case 保留结果；未执行的 case 标为 skipped，生成或执行不完整另加一个
失败的 evidence case，避免 CI 把部分执行当成通过。

退出码：0 表示所请求的证据策略满足；1 为配置、IO 或执行失败；
2 为确认规则违规、保存基线断言失配或真实双方差异；3 为证据不足。
存在已确认发现同时又部分未完成时，可退出 2，但报告仍明确 `complete=false`；
因此自动门禁应检查报告中的完整性和具体证据范围，而非只读取发现数量。

## 量化口径

| 指标 | 固定语料实测 | 口径 |
| --- | --- | --- |
| 学习规模 | 60 个新增目标、双算法 120 次正确运行，最大 64 状态 | 独立核查最小、可达状态数；采用精确参考 oracle，不代表实际组件 W/Wp 成本 |
| 完整 W/Wp 模型覆盖 | 100% 可达状态/迁移 | 30 个 2–6 状态模型、两类套件；不是程序代码覆盖率 |
| 断言保留 | 1,183 个原始 case 全部映射 | 每个 case 的完整期望输出不变，独立复测保留 |
| 受控变异 | 1,080 个不等价变异全部检出 | 输出及迁移目标变异；独立精确比较排除等价；完整压缩/未压缩的原始失败结果一致 |
| 等价基线 | 0 误报 | 正常执行和 30 个状态重编号等价模型；不作无限总体保证 |
| 重置成本 | 中位数减少 62.5% | 同一 30 模型 × W/Wp，完整正常执行、相同独立复测次数；包括退化样本 |
| 前缀族 | 单独报告 | 特意构造的嵌套状态访问路径，不混入上述中位数，也不冒充 W/Wp 完备套件 |

原始结果和逐样本统计见正式发布的 `docs/evidence/v0.3.0/`；
开发中的本地结果以 `tools/verify_v03.mbtx` 输出为准。没有使用下载量或测试 case 数冒充采用人数。

设计参考 [AutomataLib 的测试生成](https://learnlib.de/pages/automatalib) 和
[ALEX 的模型测试套件工作流](https://learnlib.de/alex/book/contents/user-manual/learning/)。
本项目独立实现有限模型分析、断言保留调度及实际 MoonBit 组件确认，
不宣称发明 W/Wp、主动学习或通用回放/缩减算法。
