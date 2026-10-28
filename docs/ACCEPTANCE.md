# MoonStateLens 最终验收入口（0.3.0）

本索引对应已通过初审的多算法行为学习与真实组件兼容性验证方向。
实际完成状态、冻结提交、CI 和发布证据见 [验证记录](VALIDATION.md)。
历史申报书保留在 [APPLICATION.md](../APPLICATION.md)，不覆盖当时的承诺与记录。

## 从干净源码复现

需要 Git、已验证的 MoonBit/compiler/core 0.10.15+943464bfa
（moon 0.1.20261012）及位于 PATH 的 sqlite3。核心库的 wasm 验证不需要 SQLite。

```sh
git clone https://github.com/CaptainK-65/moon-statelens.git
cd moon-statelens
moon update
moon run tools/verify_acceptance.mbtx
```

统一入口实际执行依赖更新、四后端检查/构建/测试、格式、生成接口核对、
三个示例、旧 CLI、新配置/产物 CLI 和真实 SQLite/HTTP/JSONL 验证。
任一阶段失败即停止，并保留命令退出码及日志。
输出在 _build/acceptance/run-*/；组件和产物证据另存于
_build/v0.2-evidence/ 和 _build/artifact-evidence/。
v0.3 新功能和量化实验保存在 `_build/v0.3-evidence/`，独立候选源码消费者
在四后端执行相同的已提交测试源。完整说明见 [行为验证](behavior-validation.md)。
元数据记录启动时的提交与工作区是否干净；冻结验收应使用干净且执行期间不变的检出。
GitHub Actions 保存日志/报告及可读摘要；归档有保留期限，正式发布另保留精选公开证据。

## 已申报能力对应

| 能力 | 实现与测试 | 复现与边界 |
| --- | --- | --- |
| L* 与 KV 独立学习 | learning_table.mbt、learning_tree.mbt；learning_driver_test.mbt | examples/session；KV 不调用 L* |
| 可暂停驱动、缓存与预算 | learning_driver.mbt、query_session.mbt、runner/；对应测试 | 同步/异步共享查询语义，异步不代表任意并发学习 |
| W/Wp 及策略链 | oracle_conformance.mbt、verification_words.mbt、verification_test.mbt | 生成语料与独立精确比较核验，状态上界为调用方前提 |
| 真实组件适配 | adapters/moonlarder/、adapters/native/ | 十状态有限 LRU 抽象、真实 SQLite、受控 HTTP/JSONL |
| 真实回放确认差异 | compatibility.mbt、integration/run.mbt；comparison_test.mbt | SQLite 正常/受控突变比较，未复现模型分歧不会确认 |
| 模型与统计导出 | serialization.mbt、integration/run.mbt | JSON/DOT/报告/轨迹；多文件输出不是事务 |
| 配置和工程集成 | integration/target_config.mbt、cmd/statelens/；integration/validation_test.mbt、artifacts_test.mbt | validate-config、compare-config、replay-config；离线验证不探测目标 |
| MoonBit 生态消费 | 根包仅使用标准库；外围使用 async/x/path | 四后端公共包消费者与独立 SQLite 门禁范例 |
| 保存模型回归与断言压缩 | regression_suite.mbt、regression_compaction.mbt、regression_execution.mbt | state/transition/W/Wp；可验证前缀证书；独立复测不压缩 |
| 有限规则验证 | behavior_rules.mbt、integration/regression.mbt | 成功事件触发/解除；模型预测必须实际重放确认；可发现共有缺陷 |
| 多上下文诊断 | diagnosis.mbt、integration/diagnosis.mbt | 可达模型乘积图；共同输入历史关联；逐一双方实际确认 |
| HTML/JUnit 审查 | evidence_render.mbt、tools/verify_v03.mbtx | 离线筛选、逐步轨迹、模型图；不完整执行为门禁失败 |
| 定量验证 | benchmarks/regression_study.mbt、scale_study.mbt | 60 个新增目标、64 状态、1,080 个不等价变异；固定语料与实际重置成本 |

## 最短真实组件演示

```sh
moon update
moon build --target native --deny-warn
moon run cmd/statelens --target native -- validate-config configs/sqlite-kv.json
moon run cmd/statelens --target native -- run-config configs/sqlite-kv.json
moon run cmd/statelens --target native -- compare-config configs/sqlite-kv.json configs/sqlite-mutant.json
```

最后一条应退出 **2**，表示双方真实回放确认差异；它不是执行失败。
适配层故意将 ROLLBACK 映射为 COMMIT，不声称 SQLite 自身存在缺陷。
完整重放、HTTP 服务启动和输出配置见 [native 说明](native.md)。
配置 artifact 路径时要创建父目录、使用新文件名，并为比较双方指定不同目的路径。

## 验证正式发布包

0.2.2 历史发布记录已保留。验证 0.3.0 正式包时，从仓库根目录执行：

```sh
moon run tools/verify_v03_consumer.mbtx -- public wasm 0.3.0
moon run tools/verify_v03_consumer.mbtx -- public wasm-gc 0.3.0
moon run tools/verify_v03_consumer.mbtx -- public js 0.3.0
moon run tools/verify_v03_consumer.mbtx -- public native 0.3.0
moon run tools/verify_published.mbtx -- native 0.3.0
moon run tools/verify_consumer.mbtx -- 0.3.0
```

这些命令创建独立模块并下载公共包，不以当前检出替代包内容。
候选源码 CI 在新版本发布前可以显式验证旧公共版本，但该结果不证明新包已发布。
[独立接入范例](../consumers/sqlite-gate/README.md) 可复制到其他仓库；
它保存反例与双方真实回放，并提供可直接改用的 GitHub Actions 工作流。

## 开源和维护记录

- [Apache-2.0 许可证](../LICENSE)、[依赖与生成物来源](../THIRD_PARTY_NOTICES.md)。
- [维护者原理说明](maintainer-notes.md)、[行为约定](CONTRACT.md)、[安全边界](../SECURITY.md)。
- [更新记录](../CHANGELOG.md)、[Issues](https://github.com/CaptainK-65/moon-statelens/issues?q=is%3Aissue)、[PR](https://github.com/CaptainK-65/moon-statelens/pulls?q=is%3Apr)、[Actions](https://github.com/CaptainK-65/moon-statelens/actions)。
- 测试语料不是数万条独立命名测试；包下载量不作为生产用户或采用情况的证明。
