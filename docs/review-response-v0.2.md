# v0.2 重新申报说明

本次沿用 MoonStateLens 仓库，按上一轮反馈补充算法、外部适配与工程集成。
以下为实现与复现入口；发布和平台验证结果以 VALIDATION.md 为准。

| 初审反馈 | 已新增的独立职责 | 实现与证据 |
| --- | --- | --- |
| 只有 L* | 独立 Mealy KV 区分树、状态归类和反例分裂 | learning_tree.mbt；learning_driver_test.mbt；docs/algorithms.md |
| 验证策略不足 | Wp、局部状态区分集、可暂停策略链、逐阶段记录 | verification*.mbt；65,536 对模型的独立精确核验 |
| 缺少异步 | 查询状态与执行分离，真正等待 I/O；超时、取消和清理 | query_session.mbt；runner/；runner/async_test.mbt |
| 缺少跨进程 | 有界 JSONL、请求 ID、EOF／退出检查及受管进程回收 | adapters/native/channel.mbt、jsonl.mbt 及故障测试 |
| 实际组件不足 | 真实 SQLite CLI 事务抽象；原有真实 MoonLarder 保留 | adapters/native/sqlite.mbt；sqlite_test.mbt；configs/sqlite-*.json |
| 工程集成不足 | 严格配置、证据策略、版本化报告、退出码与真实重放 | integration/；cmd/statelens/config.mbt；tools/verify_native.mbtx |

## 复现

```sh
moon update
sqlite3 --version
moon build --target native --deny-warn
moon run cmd/statelens --target native -- run-config configs/sqlite-kv.json
moon run cmd/statelens --target native -- run-config configs/sqlite-lstar.json
moon run cmd/statelens --target native -- compare-config configs/sqlite-kv.json configs/sqlite-mutant.json
moon run tools/verify_native.mbtx
```

比较命令按设计退出 2，表明真实输出存在差异。受控缺陷把适配层的
ROLLBACK 错发为 COMMIT，生成并实际重放 begin → put → rollback → read，
分别得到 empty 与 present；不声称发现 SQLite 自身缺陷。

## 由本项目承担、依赖组合无法替代的职责

从交互观测中自动选择实验、划分隐藏状态、构造及精化假设；
两种不同的数据结构和反例更新方法；
从模型生成 W/Wp 验证实验及区分词；
跨同步／异步执行保留一致的预算、缓存和冲突语义；
将模型分歧交给两个真实目标重新执行，并修正未复现的模型近似。

SQLite、MoonLarder、进程／网络 IO 与 JSON 都不执行这些学习和验证职责。
本项目没有将 LearnLib／AALpy 作为算法服务或运行时后端。

## 明确边界

v0.2 是可复位、确定、有限输入抽象的 Mealy 组件学习。
异步适配不等于并发交错、非确定、概率或时钟模型学习。
状态上界由调用方提供；有限随机探索不是等价证明。
KV 当前使用线性反例分解，不宣称实现 TTT 或所有成熟框架能力。
所有基准公开实际计数，不承诺 KV 在每个目标上都比 L* 更省查询。

后续可研究 TTT、更有效的反例分析和模型引导探索，均与已实现能力分开列示。

