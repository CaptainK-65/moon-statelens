# v0.4：组件版本演进

[在线实验室](https://captaink-65.github.io/moon-statelens/demo/) · [离线实验文件](demo/index.html) · [原始数据](evidence/v0.4.0/ci/study.json) · [展示提纲](judging-brief.md) · [规则、回归套件与多差异诊断](behavior-validation.md)

## 可复现入口

```sh
moon update
moon run examples/evolution
moon run cmd/statelens --target native -- study-v04
moon run tools/build_evolution_demo.mbtx
```

下载仓库后直接在浏览器打开 `docs/demo/index.html`，点击“运行完整学习实验”。
它是实际 MoonBit 编译程序，运行真实 MoonLimit/MoonLarder 公共 API，包含冷启动、
历史模型引导、新旧组件新鲜回放、模型表和 JSON/JUnit 下载。没有远程服务或录制动画。

## 核心职责

`learn_with(..., LStar, seed=old_model)` 将历史模型的访问序列（显式前缀闭包）
和区分后缀作为初始实验结构。表的观察行从空开始，由新版目标逐条重新采集。
输入集合及顺序必须一致。状态可以新增、消失或合并，旧输出不会成为新版证据。
每个目标版本必须创建新的 `Experiment` / `AsyncExperiment`；不能跨版本复用旧会话的观察缓存。
native 配置执行会为本次目标创建新会话。
历史提示消耗正常的表、查询、步骤与输出预算；准备失败或预算不足不会认证模型。
当前支持明确失败结果，未实现自动冷启动回退，也不序列化暂停闭包。
已有 `learn` 和默认 `learn_with` 行为保留。

`learn_with(..., KearnsVazirani, binary_cex=true)` 使用不相等端点的区间不变量
二分定位相邻分歧，不假设中间输出单调。长度 L 的定位需要 O(log L) 个观察，
随后仍检查实际分裂签名。短反例或靠前的分裂可能在线性策略下更便宜。
本仓库还检查 1,025 输入的延迟分裂：线性处理及重建超过 1,000 个驱动查询，
二分处理及重建少于 30 个；这不是任意学习任务的端到端提速声明。

native `run-config` 接受额外字段：

```json
{
  "learner": "lstar",
  "history": { "abstraction": "与当前配置一致", "model": "替换为完整模型 JSON 对象" }
}
```

这是字段说明片段；实际配置仍需要原有 format/version/target/verification 等字段。
KV 配置可使用 `"counterexample": "binary"`，默认 `linear`。
配置解析在目标 IO 前核对历史模型字母表、抽象名称及学习算法。
异步执行器与同步内核共享实际学习驱动。

## 实际生态组件

新增 `RunnerQuan/moonlimit@0.1.1` 的并发配额与令牌桶目标，均只调用公共 API。
配额容量 2 学得三状态模型；容量变为 3 后学得四状态模型，三次 acquire
返回 rejected/allowed 的差异在两个新实例上重现。它是配置变化，不是上游漏洞。
令牌桶容量 2、每 1,000 毫秒补充 1 个额度，按完整周期推进虚拟时间，仅观察准入结果；
不支持任意实数时间、无限参数或并发交错。虚拟时间溢出会停止实验。
浏览器演示还通过 MoonLarder 公共 API 学习十状态有限 LRU 抽象。

## 成本和独立对照

首组固定 20 对 3–12 状态的延迟观察循环模型，仅改变 probe 输出。
冷启动/历史引导使用同样的新目标、Wp 上界、缓存和预算，都完成验证；
总物理重置中位数减少约 61.02%。基线模型已存在，首次获取基线的成本不在双方升级运行内。
每例保存所有统计、验证阶段重置/步骤和轮数，包含零收益样本；不外推到任意变更。
学习阶段成本可由总计减去验证计数，历史结构准备没有目标 IO。
另有 60 组无关结构/状态数量变化的正确性测试；它们不混入这组性能中位数。
v0.3 回归套件压缩的 62.5% 是另一实验，不与此百分比相加。

独立参考：AALpy 2.0.0 的原始 L* 和 PerfectKnowledgeEqOracle 学习 20 个相同显式目标；
使用精确可观察等价比较验证结果，全部通过。AALpy 不进入生产运行依赖。
`reference/aalpy_backend.py` 仅实现独立学习协议；文件和进程编排在 MoonBit 工具中。

```sh
python -m venv _build/aalpy-env
# Windows 使用 _build/aalpy-env/Scripts/python.exe；Unix 使用 bin/python
_build/aalpy-env/Scripts/python.exe -m pip install aalpy==2.0.0 pydot==4.0.1 pyparsing==3.3.3
moon run tools/verify_evolution.mbtx -- _build/aalpy-env/Scripts/python.exe
```

结果保存到 `_build/evolution-check-*/`，包括完整 study、参考学习模型和等价核验摘要。
这些是独立实现的正确性对照，不是跨语言吞吐比较或真实用户采用量。
