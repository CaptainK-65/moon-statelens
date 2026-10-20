# 使用指南

## 接入目标

目标通过 `System::new(reset~, step~, close~)` 接入。一次物理查询先 reset，再按顺序执行输入，每个输入返回一个输出字符串，最后 close。reset 必须恢复相同的可观察起点；必要时重建对象，而不只是清理部分字段。

System 回调保留为同步、可抛错的进程内函数。v0.2 新增 native AsyncSystem／AsyncExperiment、HTTP、JSONL 子进程及 SQLite 专用接入，详见 [异步组件指南](native.md)。两条执行路线共享 QuerySession 的缓存、预算与冲突语义，并驱动同一套可暂停算法。目标不能重入同一会话，也不能在实验外被并发修改。

输入集合必须是 1—256 个不同字符串。参数无限的 API 需要先选定有限代表值；输出中的时间戳、随机 ID 等需要显式抽象。只对选定输入和抽象后的输出建立结论。状态编号没有业务语义，不会自动命名“已登录”等概念。

## 学习与策略

`Experiment::new` 持有目标、字母表、缓存与预算。`learn(experiment, oracle)` 构造 Mealy 假设，向 oracle 寻找反例，然后加入区分信息。调用方不向学习表提供目标转移矩阵。

`learn_with(experiment, oracle, KearnsVazirani)` 选择独立 KV 学习器；默认 `learn` 仍为 L*。异步接入使用 `runner.infer` 和可暂停 VerificationPlan。同步自定义 Oracle 回调保持兼容，不自动获得异步效果。完整设计见 [算法说明](algorithms.md)。

| Oracle | 用途与结论 |
| --- | --- |
| `Oracle::exact(reference)` | 对受控模型／算法验证使用，精确比较假设与显式参考。调用方负责适配器对应关系 |
| `Oracle::exhaustive(depth, max_tests=...)` | 新鲜执行长度不超过 depth 的全部输入词；只报告该有限范围 |
| `Oracle::random_words(seed=..., max_length=..., tests=...)` | 每轮重置固定种子的随机词实验；没有全局等价保证 |
| `Oracle::w_method(bound, max_tests=...)` | 最小可达假设上的 transition cover × 中间词 × characterizing suffixes；完成后给出有条件上界结论 |
| `Oracle::wp_method(bound, max_tests=...)` | 使用状态覆盖、其余转移覆盖与局部区分后缀，完成后给出有条件上界结论 |
| `Oracle::plan(VerificationPlan::Chain(...))` | 按序执行重放／随机／W/Wp 等阶段；未完成阶段停止，最后完成阶段决定证据 |
| `Oracle::new(callback)` | 自定义实验策略；返回的反例必须在实际查询中成立，证据声明由提供者负责 |

W-method 要求真实目标完整、确定、可可靠重置，使用相同有限操作集合，且实现的可观察状态数不超过声明上界。上界不是算法自动证明出来的。低估上界可能使未覆盖的真实状态漏检；发现假设状态已经超过上界时返回未完成。预算中止、区分集计算中止不能被解释为完整执行。

`Oracle::evaluate` 可直接检查一个模型，它会向调用方传播资源异常；`learn` 则将资源异常转为 inconclusive。所有内置非参考实验均绕过缓存，从真实目标获取新观测。

## 缓存、冲突与清理

前缀树保存已完整执行成功的输入／输出轨迹及其前缀。`use_cache=false` 关闭结果复用，仍保留一致性日志。`query(..., bypass_cache=true)` 强制重新执行；`recheck_every` 可周期性复测。

新结果与任何已记录前缀冲突时，会话保存冲突并失效。即使以后请求本来能够命中缓存，也继续报告冲突。修复目标后需创建新 Experiment。

reset 或 step 抛错时尝试 close；close 自身的异常不替换原始目标异常。成功执行后 close 失败，不提交该次缓存。失败／不完整查询不作为成功轨迹写入缓存。回调仍可能分配资源或耗时；这些预算不是对任意目标代码的沙箱或墙钟超时。

## 默认预算

| 范围 | 默认值 |
| --- | --- |
| 物理查询／目标操作 | 100000／2000000 |
| 单词长度／缓存节点 | 4096／1000000 |
| 已接纳物理输出 UTF-16 单元 | 16777216 |
| 假设状态／学习轮数 | 256／64 |
| 观测表单元／其中输出符号 | 1000000／4000000 |
| 访问前缀 | 20000 |
| 模型最小化工作量 | 8000000 次转移检查 |
| 区分集准备工作量 | 1000000 次状态对转移／见证重建步骤 |
| 模型乘积搜索 | 1000000 个访问状态对 |

构造模型最多 4096 个状态。可通过对应函数的命名参数调整预算；非法配置抛错。预算耗尽时 learn 保留上一个完整模型（如有），不返回半张转移表。

Statistics 是 Experiment 的累计快照。queries 为逻辑请求；resets／steps 包含尝试过但失败的调用；completed_queries 只计执行和清理完成的查询；cache_hits 不执行目标代码。output_code_units 计入预算的已接纳输出，超限的输出不计入该数。CompatibilityResult 的 left_statistics／right_statistics 包括确认回放；其嵌套学习结果的统计截止于对应学习阶段。

## 两个版本的比较

`compare(left_experiment, right_experiment, left_oracle, right_oracle)` 先学习双方，再对模型执行最短区分词搜索，然后向两目标重新执行候选词。确认输出不同才返回 confirmed-difference。

实际输出相同时，将该词加入双方的回归实验并重新学习。次数耗尽返回未完成。模型相同只返回 no-difference-between-hypotheses，不能把有限实验提升成任意实现等价的证明。回放中发生预算耗尽或观测冲突也有明确结果。

显式完整模型之间的 `distinguish` 给出全局最短模型区分词。实际目标上的回放证据只承诺已复现，除非模型对应关系已经成立，否则不称为真实程序的全局最短缺陷。

## 真实 LRU 接入

`adapters/moonlarder` 调用 MoonLarder 0.15.0 的 public new/set/get/clear。每次 reset 新建容量 2 的 LRU 对象；输入为 put/get 三个固定键及 clear；value 等于 key，时间固定为零且没有 TTL；不暴露统计计数。

可观察状态是不同的 LRU 键顺序，最多 1 + 3 + 6 = 10 个。完整测试先只用 W-method(10) 学习，再用独立的有限 LRU 规范作事后模型等价检查。参考规范不传给学习器或 W-method。

## 文件与退出码

CLI 输入文件最多 16 MiB，JSON 文本另有 UTF-16 长度限制，重放词最多 4096 个符号。JSON 解析使用标准库默认嵌套深度限制。模型 format/version、必需字段、整数、完整表、输入唯一性和状态索引都经过校验。

导出命令使用 CreateNew，拒绝覆盖已有文件。退出码 0 表示有效命令／报告，不代表学习达到无条件等价；消费方必须检查 status.kind。参数、IO、目标异常等故障退出非零。

模型格式为 moonstatelens.mealy/version=1；学习报告为 moonstatelens.learning/version=1；兼容性报告为 moonstatelens.compatibility/version=1。模型不存在时使用 JSON null，状态使用 kind 字段，见可运行 CLI 输出和 fixtures。
