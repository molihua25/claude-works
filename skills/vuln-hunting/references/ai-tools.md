# AI / Agent 挖漏洞方向

## 一句话判断

**现在的 AI 挖洞系统，瓶颈普遍在 FOFA 配额和 LLM 成本，不在技术。**

这意味着两件事：
1. 别指望装一个开源项目就自动出洞——它跑起来第一件事是问你要 FOFA key 和 LLM API key
2. 如果你的目标范围只有几个域名，**手工流水线比 Agent 系统更快更省**

---

## 这层的三个梯队

### 第一梯队：MCP 底座（让 AI 能调用真实工具）

| 仓库 | ★ | 说明 |
|---|---|---|
| `0x4m4/hexstrike-ai` | 12038 | MCP Server，让 Claude/GPT 等调用 150+ 安全工具。**这是目前最成熟的"AI 操作真实工具"方案** |

为什么重要：LLM 本身不会扫端口。MCP 是 LLM 和真实工具之间的桥。`hexstrike-ai` 把 nmap/nuclei/sqlmap 这些包成 MCP tool，Agent 就能真正执行而不是"建议你执行"。

### 第二梯队：一体化系统（侦察→挖掘→审核全流程）

| 仓库 | ★ | 说明 |
|---|---|---|
| `xalgorix/xalgorix` | 1115 | 自主渗透 agent，实时侦察 + 漏洞检测 + 利用编排（Go + TypeScript），2026 年新项目 |
| `Yean-Sec/StrikeAgent_AtkBrain-Flash` | 500 | 叶安团队的 AI Agent 渗透平台，主打自监督/自循环/自进化 |
| `StanleyNull/AutoHunter` | 403 | **国产 SRC 场景最对口**：FOFA 测绘 + LLM 多 worker，Collector→Worker→Reviewer 三段式，自带归属反查和报告生成 |

`AutoHunter` 的架构值得学：**它不是让一个 Agent 干所有事，而是拆成采集/挖掘/审核三个角色**。审核层专门过滤半成品和误报——这正是纯扫描器最缺的一环。

### 第三梯队：Skill / 知识库（把方法论沉淀下来）

| 仓库 | ★ | 说明 |
|---|---|---|
| `MyuriKanao/src-hunter-skill` | 623 | Claude Code skill：19 类 playbook + 305 结构化 payload + 263 个 WAF 绕过变体 + 2887 份 HackerOne 案例 + 88636 份 WooYun 案例统计 |
| `zhaji2333/CkSKILLS` | 93 | 同类，基于 Claude Code / Codex 的 SRC Agent 技能体系 |
| `NoorQureshi/SploitAgent` | 19 | 85+ 安全技能覆盖 16 个域（新，观望） |
| `cckuailong/awesome-gpt-security` | 672 | **跟踪 AI 安全方向的重要索引**，建议定期看 |

---

## 观察：为什么 AI 挖洞还没取代人

从目录里这些项目的实际形态能看出几个共性瓶颈：

1. **误报过滤还没解决**。`AutoHunter` 专门设了一个 Reviewer 角色，`hexstrike-ai` 也没解决这个——说明 LLM 判漏洞真假目前只能做到"辅助"级别。
2. **成本结构不对**。让 LLM 读一个页面的完整 HTML 就要几千 token，扫一万个资产就是天文数字。所以基本都是"传统工具粗筛 → LLM 精判"。
3. **越权和逻辑漏洞基本无能为力**。这类洞需要对业务的理解，LLM 看单个请求看不出问题。
4. **停更极快**。这层仓库半年不更新很常见——本目录的 `Ta0ing/MCP-SecurityTools` 就是例子（搜索显示活跃、实际停更 17 个月）。

---

## 务实的使用建议

**如果目标只有几个域名**：
别上 Agent 系统。手工跑 `pipeline.md` 那七步，快得多也便宜得多。

**如果要批量扫很多资产**：
1. 先用 `hexstrike-ai` 或直接 CLI 把流水线跑通
2. 结果交给 LLM 做**二次筛选**（判断哪些值得人工看）
3. 人工验证通过的才进报告

**如果想把方法论固化下来**：
看 `src-hunter-skill` 的组织方式——把 payload、playbook、案例统计分开维护。这个思路本目录也借鉴了（`catalog.json` 存工具数据、`pipeline.md` 存编排、`platforms.md` 存规则）。

**永远不要**：
让 Agent 自动提交漏洞报告。发现可以自动化，提交必须人工——这也是 `platforms.md` 里的硬规则。

---

## 本目录的进化方式

`scripts/refresh.py` 的检索词里已经包含 `AI agent pentest`、`LLM 漏洞挖掘`、`MCP security tools`、`autonomous vulnerability discovery` 四个 AI 方向词。

所以**每次刷新都在自动跟踪这个方向的新项目**。看到 `last-refresh-report.md` 里"新发现候选"出现 AI 挖洞项目时，值得点进去看一眼——这层变化最快。
