# TODOs

## After Multi-Platform Adaptation

- 修复 Windows / PowerShell 下的中文乱码问题（#16），至少先明确 PowerShell 5.1 / 7 的支持边界，并补安装与使用提示。
- 规划素材提取能力的内收顺序，先评估网页、PDF、本地文件、YouTube，再评估 X 等高波动来源。
- 评估是否需要为 OpenClaw 增加 workspace-skill fallback，而不只支持 shared skill 路径。
- 评估是否需要把安装器拆分成更正式的 `doctor` / `migrate` / `uninstall` 子命令。
- 评估第四个平台接入时的适配层模板，确保不回流到“复制一套主逻辑”。

## Phase B - 核心主线与外挂分离（已完成）

- 已冻结统一素材入口和单一来源总表
- 已明确外挂失败状态和统一回退路径
- 已锁住旧知识库兼容与迁移规则
- 已对齐安装、状态、说明和回归测试

## 引入 JS 单测框架（跨项目决策，不夹带在功能 PR 里）

- **What**：给项目加一个 JavaScript 单测 runner（候选：`bun test` / `vitest` / `node:test`），为 `templates/graph-styles/wash/graph-wash.js` 里的纯函数写细粒度单测——覆盖 `truncateLabel`、`safeLocalStorage`、`cardDims` 等。
- **Why**：现有 `tests/graph-html-*.regression-*.sh` 是 shell + golden HTML + DOM 字符串断言，能抓"页面结构变了"，抓不住"纯函数给边界输入返回错结果"。`truncateLabel` 这种带宽度估算、字素簇遍历、省略号逻辑的函数，golden fixture 间接覆盖率低。
- **Pros**：对纯函数边界（空串 / 单字符 / 超长 / 复杂 emoji / 全角标点）能真正断言。重构提速。新增 graph 逻辑时低成本补测。
- **Cons**：新依赖（对应 runner）、CI 多一步、其他协作者重新 setup、要决定用哪个 runner。所以这是独立决策，不该藏在 UX 修复 PR 里。
- **Context**：决策发生在 2026-04-21 graph UX 修复 v3 plan 的 `/plan-eng-review` 环节。当时为了不扩张 PR 范围，决定把纯函数覆盖交给"多长度 golden fixture 间接测试"，并把这件事单独记下来。v3 plan 已在 "NOT in scope" 显式延后，不重复决策。
- **Depends on / blocked by**：无硬性依赖。动手前先决定 runner（bun test 最轻，但要求所有协作者装 bun；node:test 零依赖但 API 偏底层；vitest 生态最成熟但拉 npm 依赖最重）。

## Phase 1b - 交互式图谱进阶功能（Phase 1 落地后再评）

- **What**（Phase 1 eng review 原列 3 项）：为已落地的交互式图谱新增 AI 隐含关系推断、图谱健康摘要（孤立节点 / 最大连通分量 / 脆弱桥接）、以及边置信度分级着色。
- **What（2026-04-17 design review 追加 5 项）**：
  1. 搜索升级：fuzzy 匹配 + 中英跨语言 alias（Phase 1 只做 prefix + case-insensitive）
  2. 深色模式：`prefers-color-scheme` 自动切；节点 palette 和边 opacity 要再调一次
  3. 设计系统抽离：把 Pass 4 CSS 变量块从 graph-template 抽到 `templates/design-tokens.css`，根目录写正式 `DESIGN.md`
  4. 真正的响应式：替换掉 Phase 1 的 MOBILE opt-out 覆盖层，做 `< 768px` 下单栏堆叠 + 触摸手势 pan/zoom
  5. 图谱演化指标（5-year 视图）：对比上次 graph 的节点度变化、新社区、新孤立节点；写入 `wiki/graph-history/{date}.json`
- **Why**：Phase 1 MVP 先验证有人会用本地 HTML 图谱，避免一步吃下所有 token 成本与维护负担。上面 8 项都是"截图再升级一档"的加戏。
- **Pros**：让图谱更接近 llm-wiki-agent 的能力覆盖；健康摘要给可量化质量信号；搜索和响应式覆盖更多使用场景；演化指标让用户看到"我的知识形状"变化。
- **Cons**：AI 推断每次 graph 要读全部实体页，100+ 节点时 token 消耗明显；深色模式要双份 CSS；演化指标要引入历史数据目录和对比逻辑。
- **Context**：Phase 1（2026-04-17 设计文档 approved，含 Eng Review Addenda + Design Review Addenda）只复用 ingest 已有的 confidence 数据，不重新调 AI。
- **Depends on / blocked by**：Phase 1（交互式图谱 MVP）落地并有至少一位真实用户反馈。
