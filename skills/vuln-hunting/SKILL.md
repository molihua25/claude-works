---
name: vuln-hunting
description: 授权范围内的漏洞挖掘作战手册与工具库，面向 SRC / 众测 / 补天 / 漏洞盒子。当用户提到「挖漏洞」「SRC」「众测」「补天」「漏洞盒子」「资产收集」「信息收集」「子域名」「指纹识别」「nuclei」「POC 批量」「渗透测试」「漏洞报告」时使用。先过授权门禁，再按需刷新 GitHub 工具目录，然后按七层流水线给出命令并执行。
---

# 漏洞挖掘（SRC / 众测）

## 一句话定位

把"挖漏洞"变成一条可复用的流水线：**先确认授权范围 → 刷新工具目录 → 按层执行 → 人工验证 → 写报告**。
重点不是跑得多快，而是**范围不出错、误报不淹没结论**。

---

## ⛔ 第 0 步：授权门禁（硬性，不可跳过）

**在跑任何扫描命令之前，必须拿到以下四项。任一项不清楚就停在这里问，不要"先扫着看看"。**

| 必须确认 | 为什么 |
|---|---|
| 1. 平台与项目名（补天 / 漏洞盒子 / 企业 SRC / 其他） | 决定报告格式与提交口径 |
| 2. **资产范围**（具体域名 / IP 段 / 产品名清单） | 范围外扫描 = 未授权测试 |
| 3. **是否含子域名** | 公益 SRC 常**只授权主站、不含子域**——这是最常见的越界方式 |
| 4. 有无禁测项（DoS、社工、真实数据导出、生产库操作…） | 有些项目明确禁止 |

**为什么这么严**：补天/漏洞盒子的公益 SRC 大多数只授权主站。扫了子域、扫了同 IP 的旁站，轻则判重复/忽略，重则**封号**。这不是形式主义，是保护用户账号。

**门禁通过后**，在后续输出里**始终写明本次授权范围**，每一条发现都标注它落在范围的哪一部分。

---

## 第 1 步：刷新检查

工具库是有保质期的——这个圈子停更比功能重要。

```bash
python ~/.claude/skills/vuln-hunting/scripts/refresh.py
```

- 默认 **24 小时内刷新过就跳过**（0.2 秒返回），不会拖慢每次调用
- 超过 24 小时才会联网：批量校验已有仓库 + 检索新工具，约 35 秒
- 强制刷新加 `--force`；`--check` 只校验存量；`--discover` 只找新工具；`--dry-run` 只报告不写文件

刷新后**先看** `references/last-refresh-report.md`：
- **有变化的仓库** —— 停更预警、归档警告
- **新发现候选** —— 不在目录里的新工具，需人工判断是否收录

> **判断活跃度只看 `pushed_at`。** 本目录曾因此踩坑：`gh search` 返回的 `updatedAt` 会因**加星**而变化，不代表代码更新。实测有仓库两者相差 17 个月（`Ta0ing/MCP-SecurityTools` 搜索显示 2026-09、实际代码停在 2025-04），`w13scan` 更是差了三年半。`refresh.py` 已只用 `pushed_at`。

---

## 第 2 步：查工具目录

**`references/catalog.json`** 是唯一的机器可读真源（`catalog.md` 由它生成，别手改）。

条目字段：`full_name` / `layer` / `role` / `stars` / `pushed_at` / `archived` / `install` / `status_note` / `_staleness`。

七层结构（`layers` 字段）：

| 层 | 内容 |
|---|---|
| `asset-discovery` | 资产发现——子域名、DNS、域名识别 |
| `probe-fingerprint` | 存活探测与指纹识别 |
| `vuln-scan` | 漏洞扫描与 POC 验证 |
| `url-content` | URL 收集、目录爆破、爬虫 |
| `oob-exploit` | 反连平台与漏洞利用辅助 |
| `ai-agent` | AI / Agent 驱动的一体化系统 |
| `knowledge-platform` | 知识库、字典、靶场、平台专用 |

**选工具时优先看 `_staleness`**：活跃（< 6 个月）/ 半停更（6–18 个月）/ 停更（> 18 个月）。
停更的工具不是不能用，但**指纹库、POC 库、域名列表**这三类停更后价值下降最快，别当主力。

---

## 第 3 步：执行流水线

详见 **`references/pipeline.md`**。核心链路：

```
授权范围内域名
   ↓  subfinder / OneForAll          资产发现
   ↓  httpx                           探活（这一步去掉绝大多数噪音）
   ↓  TideFinger / EHole              指纹识别
   ↓  nuclei + afrog                  打 POC（挂 interactsh 收反连）
   ↓  notify                          推送到手机
   ↓  人工验证  ← 不可跳过
   ↓  写报告
```

**铁律**：
- 每一段用 `-o json` 落盘，段与段之间用文件传递，**可断点续跑**
- 每段跑完先看统计再进下一段。上一段出来 5000 个 URL 就该先收敛，别直接怼进扫描器
- **扫描器的输出是线索不是结论**，每条都必须人工验证才能进报告

---

## 第 4 步：平台规则与报告

详见 **`references/platforms.md`**。要点：

- 补天/漏洞盒子的报告要写清 **复现步骤、影响、修复建议**，光有截图会被打回
- 提交前**先搜重复**——公益 SRC 里信息泄露、CORS、SPF 这类早就被刷烂了
- **不要批量自动提交**（目录里的 `int-wc/VulBoxAuto` 就是不推荐的反面例子），平台明确打击，容易封号

---

## AI / Agent 方向

详见 **`references/ai-tools.md`**。

一句话判断：**现在的 AI 挖洞系统，瓶颈普遍在 FOFA 配额和 LLM 成本，不在技术。** 新手别一上来就搭多 Agent 系统——
先用 CLI 工具把流水线跑通，知道每一步在干什么，再考虑让 Agent 接管。目录里 `hexstrike-ai`（MCP 底座）、`AutoHunter`（三段式系统）是这层的代表。

---

## 本地工具状态

工具装在 `C:\Users\wwwwz\bin`（已在 PATH 第一位）。安装/修复脚本：

```bash
bash ~/.claude/skills/vuln-hunting/scripts/install_tools.sh
```

脚本幂等，已装的会跳过。**装之前先 `command -v <工具>` 确认，不要重复安装。**

### 已装清单（跑 `install_tools.sh v` 可随时自检）

| 环节 | 工具 |
|---|---|
| Go 工具链 | `go` 1.27.1（在 `tools/go`，`go install` 的产物直接落 `bin`） |
| 资产发现 | `subfinder` `dnsx`（含水槽/泛解析过滤 `-wd`） `alterx` `assetfinder` |
| 存活探测 | `httpx`（`-tech-detect` 顺带做指纹） `gogo` |
| 漏洞扫描 | `nuclei` 3.11.1（**模板库已下，86MB**） `afrog` 3.5.7 `dalfox` 3.2.3 `feroxbuster` `dirsearch` |
| URL / 爬虫 | `katana` `gau` `waybackurls` `hakrawler` |
| 目录爆破 | `ffuf` |
| 利用 / 反连 | `sqlmap` `interactsh-client` |
| 辅助 | `anew`（去重） `jq`（解析 JSONL） `nmap`（7.80，偏老） `notify` `naabu` |

**三个不在 `bin` 里，别找不到就以为没装**：
- `dirsearch` → `tools/dirsearch`（目录式，自带 Python），入口 `bin\dirsearch.cmd`
- `sqlmap` → `tools/sqlmap`，入口 `bin\sqlmap.cmd`
- `nmap` → `C:\Program Files (x86)\Nmap\`，新开终端才在 PATH 里

**没装、且理由充分的**：`puredns`（依赖 C 写的 massdns，Windows 装不了）、
`OneForAll` / `TideFinger_Go` / `EHole` / `w13scan`（均长期停更，见 `pipeline.md` 的替代方案）。

几个**实测踩过**的安装陷阱（脚本里已处理，别再踩一遍）：

| 工具 | 坑 |
|---|---|
| `dalfox` | 已用 **Rust 重写**，没有 go.mod，`go install` 完全无效，只能预编译 |
| `katana` | 源码构建需要 **CGO + C 编译器**（本机没有），用预编译包 |
| `gogo` | Release 发的是**裸 .exe** 不是压缩包；且文件名带 `_windows_amd64` 后缀，必须改名成 `gogo.exe` |
| `dirsearch` | **目录式发行包**，自带整套 Python 3.14 运行时（6000+ 文件），入口是 `dirsearch.cmd`，包里**没有** `dirsearch.exe` |
| `hakrawler` | 作者是 **hakluke** 不是 tomnomnom，路径写错会得到 `Repository not found` |
| `puredns` | 本机**装不了**——它只是调度器，真正解析的 massdns 是 C 程序。泛解析过滤改用 `dnsx -wd` |
| Go 本体 | `winget install GoLang.Go` 实测报 `0x80072efd`（拉 go.dev 失败），改用**国内镜像免安装 zip**，零权限不弹 UAC |

**最重要的一条**：`dirsearch` 这类自带运行时的包**绝对不能把内容拷进 `bin`**。
`bin` 在 PATH 第一位，包里的 `python.exe` 会盖掉用户真正的 Python，
包里的 `httpx.exe`（Python httpx *库*的入口，108KB）会盖掉 ProjectDiscovery 的
`httpx` 工具（30MB）——**同名不同物**。这事真实发生过，现在脚本只按名字拷单个二进制，
dirsearch 则整包解到 `tools/` 下、只在 `bin` 放一个 `.cmd` 转发器。

---

## 常见坑

**数据类**
- 用搜索结果的 `updatedAt` 判断活跃度 → 会用加星时间冒充提交时间。**只用 `pushed_at`**
- 域名列表类仓库（补天/漏洞盒子的厂商标单）停更后**危害最大的就是它**——直接用会漏掉近几年的新厂商，必须回平台页面核对

**扫描类**
- 泛解析域名不做过滤就爆破 → 成千上万条假子域，`puredns` 就是干这个的
- 忘记给扫描器设速率限制 → 打崩目标 = 从"授权测试"变成"事故"
- 不挂 `interactsh` 就打盲注/SSRF → 这类漏洞根本看不出来

**流程类**
- 扫描器报的全量结果直接写进报告 → 会被平台打回并影响信誉分
- 不查重就提交 → 公益 SRC 里重复率极高

---

## 质量规范

- 任何结论都标注**证据来源**（命令、时间、原始响应）
- 不确定的写"疑似/待验证"，**不要**写成确定结论
- 范围边界永远写清楚：本次授权的是哪些资产
- 报告里的每一条，都要能独立复现

## 完成汇报约定

每次工作结束，汇报固定四项：
1. **本次授权范围**（重申一遍）
2. **跑了什么**（命令 + 产出文件位置）
3. **发现了什么**（分"已验证 / 疑似待验"两栏，不要混在一起）
4. **工具库状态**（本次是否刷新、有无停更预警、有无新候选）
