# 功能级查重记录

日期：2026-10-16。范围：公开、可访问和可索引的 Mooncakes、GitHub 及网页资料。未检出不构成全网不存在的证明。

本轮先比较 Petri 网／流程分析、并发历史检查、贝叶斯推断、经典规划和黑盒主动学习，再对主动学习方向读取近邻接口与文档。共 30 组实时 moon search 查询、9 组 GitHub 仓库／代码查询，摘要与源码 SHA 记录在 research-2026-10-16.json。

关键检索词：automata learning、active learning、Angluin、Lstar、Lsharp、Mealy、conformance testing、grammar inference、model inference、protocol inference、state machine learning、observation table。GitHub 代码检索限定 language:MoonBit；Angluin、observation_table、learn_mealy、LearnLib、aalpy、distinguishing_sequence 未命中。Mealy 的五个代码命中属于 Wordle 词表和 parser 静态数组快照。

注册表的模糊匹配发现了下述近邻；没有因 GitHub 关键词空结果而忽略它们。

| 项目 | 已核对职责 | 与本项目的边界 |
| --- | --- | --- |
| [quickcheck_statemachine](https://github.com/moonbit-community/quickcheck_statemachine/blob/main/README.mbt.md) | 提供参考模型、前置／后置条件、转移，再生成和检查命令序列；也有并发线性一致性测试 | 不提供本项目的黑盒观测表模型推导 |
| [veri/testing/state_machine](https://github.com/mizchi/veri/blob/main/testing/state_machine/pkg.generated.mbti) | check/replay 接收 Model 与 System，比较输出和状态观察 | 需要调用方先提供独立模型 |
| [veri/model_check](https://github.com/mizchi/veri/blob/main/docs/model-workflows.md) | 从给定 initial/actions/step/predicates 定义探索并检查模型 | 探索已定义状态，不推断不可读取的隐藏状态 |
| [MoonGrammata](https://github.com/erzhuzi259/MoonGrammata) | 给定语法的结构变异、反馈语料、差分／变形测试、缩减与重放 | 未提供状态等价类、闭合一致表及 Mealy 主动学习 |
| [zploc/loci](https://mooncakes.io/docs/zploc/loci) | 注册表提供可组合 FST 和具体运行时 FSM | 本轮链接上游 zpc-sh/loci 返回 404；结论限于注册表摘要，未宣称完成源码排查 |
| mokomoking2501/lockwire | 注册表描述确定性模拟、时钟、故障注入及重放 | 摘要没有从交互推导未知状态模型的职责；仅摘要级核验 |

筛选时还发现 okMambaOut/moonpetri、HhWw96/moontxnwitness 等，因方向已有相关实现而未主推。贝叶斯网络和 PDDL 的精确词空结果也未被当作充分的新颖性证据。

其他语言存在 [LearnLib](https://learnlib.de/) 和 [AALpy](https://github.com/DES-Lab/AALpy)。新颖性定位为 MoonBit 生态中的原生模型推导能力，不宣称发明主动自动机学习。本轮未运行近邻仓库的测试；文档与接口证据不等于本轮运行验证。申报前应继续关注新增同类公开包。
