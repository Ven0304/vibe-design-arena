# Vibe Design Arena

[English](README.md) | [简体中文](README.zh-CN.md)

从同一个 Git 基线并行产出三套真正不同的前端重设计，完成渲染与审查后，由用户选择一个完整赢家。

Vibe Design Arena 是用于高要求前端重设计的 Codex Skill。它通过隔离的 Git worktree 保护每个方向，以脚本化生命周期把决策与证据绑定到正确提交，并把最终选择留给用户：不拼接版本、不 cherry-pick、不自动选赢家。

## 它保证什么

- **三套真实方向。** 三个候选都从最终 `BASE_SHA` 出发，分支分别为 `style-a`、`style-b`、`style-c`；它们必须在信息层级、布局语法、密度节奏、导航或交互姿态上形成可观察的差异，而非仅停留在表层样式变化。
- **先批准，再实现。** 创建 worktree 前，用户必须完整查看并批准三份 `DESIGN_BRIEF.md`。
- **资格与证据绑定。** 每个候选都需要 brief 完整性、声明的验证、自动化 QA、主 Agent 视觉审查和方向一致性审查。
- **由用户选择。** 资格审查只决定能否参选；它不会打分、排名或挑选赢家。
- **安全收尾。** 只合并被选中的分支；只在合并后验证通过后移除 worktree；三条候选分支都会保留。

## 适用场景

当既有产品需要三套彼此竞争的、完整的前端重设计方案，并且用户希望比较后选择其一时，使用这个 Skill。

不要把它用于普通 UI 微调、单组件改动，或“从三个版本各拿一点组合起来”的请求。先选择一个完整版本；如需进一步探索，再启动独立的后续重设计。

## Arena 流程

```mermaid
flowchart LR
  A[干净的产品基线] --> B[三份已批准的 brief]
  B --> C[三个隔离的 Git worktree]
  C --> D[构建、预览并收集证据]
  D --> E[QA 加两项人工审查]
  E --> F[三版全部合格]
  F --> G[用户选择一个完整版本]
  G --> H[合并并验证赢家]
  H --> I[移除 worktree；保留全部分支]
```

控制器会按以下生命周期记录全过程：

```text
preflight -> briefs-approved -> worktrees-ready -> building
          -> previews-ready -> qualifying -> selection-ready
          -> selected -> merged -> cleaned -> complete
```

## 快速开始

本仓库是 Codex Skill，而不是需要安装的软件包。请从其目录加载，先检查目标产品，再按 [SKILL.md](SKILL.md) 中对应阶段的说明执行。

新建 Arena 时，状态文件必须使用产品仓库之外的绝对路径。只有控制器可以写入 `arena-state.json`。

```powershell
$skillRoot = "<vibe-design-arena 的绝对路径>"
$arena = Join-Path $skillRoot 'scripts\arena.ps1'
$state = "<ARENA_RUN_ROOT 的绝对路径>\records\arena-state.json"

powershell -ExecutionPolicy Bypass -File $arena preflight `
  -State $state `
  -Repo "<产品 Git 根目录的绝对路径>" `
  -SkillRoot $skillRoot `
  -Config "<结构化的 Arena 配置文件.json>"
```

每次会改变状态的命令之前，都要先执行 `status`，并将最新的 `stateRevision` 传给 `-ExpectedRevision`。若 preflight 提出 `.gitattributes` 补丁，须先向用户展示确切补丁并取得确认，才能以 `-ApplyAttributes` 重新执行。

完整命令顺序、配置格式、恢复规则和发布行为见 [references/arena-lifecycle.md](references/arena-lifecycle.md)。

## 是资格审查，不是排名

每个候选进入对比界面前，必须同时通过五项独立门槛：

1. `briefIntegrity`
2. `validation`
3. `automatedQa`
4. `mainAgentVisualReview`
5. `directionConsistencyReview`

自动化 QA 故意保持范围有限且完全声明式：它会验证已配置的浏览器场景，覆盖手机、平板、桌面与明确标注的“等效 200% 布局”代理。它不判断设计是否出色；主 Agent 必须查看当前截图，并完成两项人工签署。

资格审查前，请阅读 [评分卡](references/arena-scorecard.md)、[视觉质量标准](references/visual-quality-bar.md)、[交互质量标准](references/interaction-quality-bar.md) 与 [QA 配置说明](references/qa-configuration.md)。

## 设计参考库

参考库的目标是让三版因正确的理由而难以取舍：每版都应是一套连贯的设计主张，而不是同一安全默认方案换了装饰。

- [方向 Brief 标准](references/direction-brief.md)：每份获批 brief 必须满足的完整合同。
- [反套路检查](references/anti-slop.md)：挑战无依据的渐变、卡片墙、伪终端、装饰性数据等默认做法。
- [金融与数据领域包](references/domain-packs/README.md)：面向金融/数据产品的共享判断，以及三套独立分发的方向校准材料。

## 仓库结构

```text
SKILL.md                         工作流合同与职责划分
references/                      设计标准和操作指南
references/domain-packs/         领域专属校准材料
scripts/arena.ps1                有状态的 Arena 控制器
scripts/arena-integrity.ps1      快照与 brief 完整性工具
scripts/arena-qa.mjs             声明式 Playwright 与 axe QA 执行器
scripts/schemas/                 状态、builder 结果和 QA 合同
scripts/tests/                   生命周期与 QA 回归测试
```

## 依赖与验证

- 生命周期控制器需要 Git 与 PowerShell。
- 内置 QA 执行器和单元测试需要 Node.js。
- 只有要获得自动化 QA 的 `PASS` 时，才需要 Playwright（或 `playwright-core`）、`axe-core` 和 Chromium 运行时；它们绝不会被自动安装。

在仓库根目录运行以下回归校验：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tests\phase1-smoke.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\tests\phase2-smoke.ps1
python -X utf8 "<CODEX_HOME>\skills\.system\skill-creator\scripts\quick_validate.py" "<Skill 根目录绝对路径>"
```

## Git 演进

| 提交 | 变化 |
| --- | --- |
| `a996ba9` | 建立三 worktree、用户选择完整赢家的初始 Skill。 |
| `be6ee06` | 加入由参考资料驱动的设计质量门槛。 |
| `8f1d29b` | 加入首版设计质量参考库。 |
| `fc73b74` | 隔离领域 brief，使 builder 只接收其被分配的方向。 |
| `86c4ea3` | 强化冻结参考、brief、合并验证与分支保留规则。 |
| `f3134b1` | 明确运行记录和已批准 brief 的合同。 |
| `0a553bf` | 加入脚本化生命周期状态机、完整性工具、schema 与 smoke 覆盖。 |
| `fbd17af` | 加入声明式浏览器 QA 和五门资格审查流程。 |
| `d9125f6` | 聚焦主工作流，并将操作细节拆入独立参考文档。 |

## 贡献

请保持三版本流程这一不可协商的边界。尤其不要加入组合式选择、自动选择、清理时删除分支，或手动修改 `arena-state.json` 的逻辑。

若修改脚本或 schema，请同步更新相应回归测试，并运行上面的验证命令。若修改设计指导材料，请保留通用参考、仅主 Agent 可见的跨方向材料，以及 builder 输入之间的边界。

## 许可证

本仓库目前未声明许可证。