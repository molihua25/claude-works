# 挖漏洞工具库目录

> 本文件由 `scripts/refresh.py` 自动生成，请勿手改——改 `catalog.json`。
> 最后刷新：2026-09-22

**判断活跃度只看 `pushed_at`**：gh search 的 `updatedAt` 会因加星而变，
不代表代码更新（实测有仓库两者相差 17 个月）。

## 资产发现——子域名、DNS、域名识别

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `projectdiscovery/subfinder` | 14476 | 2026-09-22 | 活跃 | 被动子域名枚举，事实标准 |
| `shmilylty/OneForAll` | 10080 | 2026-05-11 | 活跃 | 国内子域收集老牌工具，功能全但慢 |
| `0x727/ShuiZe_0x727` | 4022 | 2024-06-13 | 停更 | 信息收集自动化（水泽）（半停更，2024-06 后无提交） |
| `Findomain/Findomain` | 3794 | 2026-09-17 | 活跃 | 域名识别，支持截图与端口扫描 |
| `projectdiscovery/dnsx` | 2879 | 2026-09-21 | 活跃 | 批量 DNS 查询，可配合解析校验 |
| `d3mondev/puredns` | 2245 | 2026-02-23 | 半停更 | 精准过滤泛解析，能大幅削减误报 |
| `CTF-MissFeng/bayonet` | 1523 | 2022-11-22 | 停更 | SRC 资产管理系统，子域→端口→漏洞→爬虫一体化（停更（2022-11），思路可参考，代码勿直接上生产） |
| `projectdiscovery/alterx` | 1006 | 2026-09-21 | 活跃 | 子域名字典 DSL 生成，扩容爆破词表 |

## 存活探测与指纹识别

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `projectdiscovery/katana` | 17546 | 2026-09-21 | 活跃 | 下一代爬虫，挖接口与隐藏端点 |
| `projectdiscovery/httpx` | 10416 | 2026-09-16 | 活跃 | 探活 + 技术栈识别 + 截图，去噪主力 |
| `EdgeSecurityTeam/EHole` | 3516 | 2024-04-02 | 停更 | 棱洞，红队重点系统指纹探测（半停更（2024-04），指纹库偏老） |
| `TideSec/TideFinger` | 2089 | 2023-05-23 | 停更 | 指纹识别，整合多个 web 指纹库（停更（2023-05），指纹库偏老，新组件识别率下降） |
| `TideSec/TideFinger_Go` | 334 | 2025-02-07 | 停更 | Go 版指纹识别，整合 2.3W 条指纹（停更（2025-02）。核实时发现真实 pushed_at 比搜索结果展示的晚了 19 个月，原"推荐优先用"的判断已撤销；仍可作为指纹库来源，但需自行校对新组件） |

## 漏洞扫描与 POC 验证

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `projectdiscovery/nuclei` | 31423 | 2026-09-22 | 活跃 | 模板化漏洞扫描，整条流水线的核心 |
| `projectdiscovery/nuclei-templates` | 13011 | 2026-09-22 | 活跃 | 官方模板库，也收录大量社区模板 |
| `zan8in/afrog` | 4419 | 2026-09-18 | 活跃 | 国产 POC 框架，中文/国产组件漏洞覆盖优于 nuclei，建议两者都跑 |
| `knownsec/pocsuite3` | 3876 | 2025-02-28 | 停更 | 知道创宇 POC 框架（半停更（2025-02）） |
| `chainreactors/gogo` | 2137 | 2026-07-28 | 活跃 | 红队自动化扫描引擎，高度可定制，适合当自建流水线的执行引擎 |
| `w-digital-scanner/w13scan` | 1942 | 2023-02-08 | 停更 | 被动式扫描器，挂代理后边点边扫（停更（2023-02）——尽管仓库页面显示近期有活动，实为加星导致的 updated_at，代码三年半未动。被动扫描思路仍值得借鉴） |
| `78778443/QingScan` | 1830 | 2026-08-04 | 活跃 | 扫描器粘合剂，30 款工具自动调度 |
| `W01fh4cker/Serein` | 1248 | 2023-02-26 | **已归档** | 图形化批量 URL 采集 + Nday 批量检测（停更（2023-02）） |
| `zongdeiqianxing/hscan` | 115 | 2021-02-23 | 停更 | 集成 crawlergo/xray/dirsearch/nmap 的 SRC 挖洞工具（停更（2021）） |

## URL 收集、目录爆破、爬虫

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `ffuf/ffuf` | 16701 | 2026-09-09 | 活跃 | 快速 Web 模糊测试 |
| `maurosoria/dirsearch` | 14749 | 2026-09-22 | 活跃 | Web 路径扫描 |
| `epi052/feroxbuster` | 8079 | 2026-09-05 | 活跃 | Rust 写的递归内容发现，快 |
| `hakluke/hakrawler` | 5135 | 2026-08-05 | 活跃 | 轻量快速爬虫，快速发现端点 |
| `lc/gau` | 5096 | 2026-03-20 | 半停更 | 从 Wayback / OTX / CommonCrawl 拉历史 URL |
| `tomnomnom/waybackurls` | 4563 | 2024-05-01 | 停更 | 拉取 Wayback Machine 已知 URL（半停更（2024-05）） |

## 反连平台与漏洞利用辅助

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `sqlmapproject/sqlmap` | 38487 | 2026-09-20 | 活跃 | SQL 注入检测与利用，事实标准 |
| `frohoff/ysoserial` | 9063 | 2025-12-04 | 半停更 | Java 反序列化 payload 生成 |
| `hahwul/dalfox` | 5297 | 2026-09-21 | 活跃 | XSS 扫描与利用，面向自动化（已用 Rust 重写，根目录是 Cargo.toml，go install 完全无效） |
| `projectdiscovery/interactsh` | 4543 | 2026-09-09 | 活跃 | 自建 OOB 反连平台，SSRF/盲注/Log4j 全靠它 |
| `mbechler/marshalsec` | 3715 | 2025-01-09 | 停更 | JNDI 注入辅助，配合 LDAP/RMI 反连 |
| `projectdiscovery/notify` | 1614 | 2026-09-21 | 活跃 | 扫描结果推送到钉钉/飞书/企微 |

## AI / Agent 驱动的一体化系统

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `0x4m4/hexstrike-ai` | 12038 | 2026-08-03 | 活跃 | MCP Server，让 AI Agent 调用 150+ 安全工具，通用自动化底座 |
| `xalgorix/xalgorix` | 1115 | 2026-09-22 | 活跃 | 自主 AI 渗透 agent，实时侦察+漏洞检测+利用编排（Go + TypeScript） |
| `cckuailong/awesome-gpt-security` | 672 | 2026-07-24 | 活跃 | AI + 安全工具/案例策展清单，跟踪 AI 安全方向的重要索引 |
| `MyuriKanao/src-hunter-skill` | 623 | 2026-05-24 | **已归档** | Claude Code skill：19 类 playbook + 305 payload + 2887 份 HackerOne 案例 + 88636 份 WooYun 统计 |
| `Yean-Sec/StrikeAgent_AtkBrain-Flash` | 500 | 2026-09-20 | 活跃 | AI Agent 渗透平台，自监督/自循环/自进化 |
| `Ta0ing/MCP-SecurityTools` | 409 | 2025-04-07 | 半停更 | 网络安全领域 MCP 工具收录汇总（代码停更（2025-04）。注意：搜索页显示 2026-09-17 是加星导致的 updatedAt，非代码更新——本条目正是 pushed_at 口径的典型例证） |
| `StanleyNull/AutoHunter` | 403 | 2026-09-22 | 活跃 | 自动化 SRC 系统：FOFA 测绘 + LLM 多 worker 自主挖掘/审核/情报沉淀，Collector→Worker→Reviewer 三段式 |
| `zhaji2333/CkSKILLS` | 93 | 2026-09-15 | 活跃 | 基于 Claude Code / Codex 的 SRC Agent 技能体系 |
| `nedlir/MCPwner` | 55 | 2026-08-20 | 活跃 | MCP server，自主漏洞发现 |
| `R0x7e/Argus` | 19 | 2026-08-22 | 活跃 | AI 驱动的 SRC 多智能体系统（星少且新，观望） |
| `NoorQureshi/SploitAgent` | 19 | 2026-09-20 | 活跃 | 面向 AI agent 的安全技能库，85+ 技能覆盖 16 个域（星少且新，观望） |
| `Chenggaorui/AutoSRC-AISkill` | 16 | 2026-08-09 | 活跃 | 全自动 SRC 挖洞 AI-Skill 一体化技能包（星少且新，观望） |

## 知识库、字典、靶场、平台专用

| 仓库 | ★ | 最近提交 | 状态 | 用途 |
|---|---:|---|---|---|
| `swisskyrepo/PayloadsAllTheThings` | 81078 | 2026-08-27 | 活跃 | 万能 payload 与绕过手册，Web 安全百科 |
| `insightglacier/Dictionary-Of-Pentesting` | 2073 | 2023-07-21 | 停更 | 渗透/爆破/Fuzzing/BugBounty 字典合集（停更（2023-07），字典仍然可用） |
| `teamssix/twiki` | 1052 | 2024-12-21 | 停更 | T Wiki 云安全知识文库（半停更（2024-12）） |
| `projectdiscovery/chaos-client` | 883 | 2026-09-07 | 活跃 | Chaos 数据集客户端，被动子域数据源 |
| `Team-intN18-SoybeanSeclab/Phantom` | 689 | 2026-09-16 | 活跃 | 浏览器扩展，自动收集页面敏感信息与泄露线索，支持批量 API 测试与结果导出 |
| `LangziFun/BuTian_Spider` | 178 | 2020-01-02 | 停更 | 补天厂商爬虫 + 数据可视化（停更（2020-01），补天页面结构早已改版，爬虫大概率跑不通） |
| `owl234/Awesome-SRC-experience` | 92 | 2026-06-22 | 活跃 | SRC 挖洞经验与自动化武器知识库 |
| `lingxisec/LingXiLabs` | 49 | 2026-03-14 | 半停更 | 凌曦安全团队漏洞靶场集合，免费练习环境 |
| `luck-ying/butian_public_SRC` | 24 | 2022-08-17 | 停更 | 补天公益厂商域名列表 + Python 脚本（停更（2022-08）。域名列表类仓库停更影响最大——直接使用会漏掉近四年新入驻厂商，务必以平台页面为准人工核对） |
| `NAXG/ARL` | 22 | 2026-01-13 | 半停更 | 资产侦察灯塔系统二开版：升级 Python 3.12 + MongoDB 6.x（半停更（2026-01 后无提交）。灯塔官方仓库 TophantTechnology/ARL 已 404（转私有或下架），此为社区二开版） |
| `z1ng/VulBoxSpider` | 14 | 2019-01-18 | 停更 | 漏洞盒子入驻企业列表爬虫（停更（2019-01），同上，几乎肯定跑不通） |
| `Cynthrial/butian_urls` | 8 | 2022-12-08 | 停更 | 补天公益厂商域名列表（停更（2022-12），同 butian_public_SRC 的时效陷阱） |
| `int-wc/VulBoxAuto` | 5 | 2024-09-13 | 停更 | 漏洞盒子批量提交脚本（不推荐：批量自动提交是平台明确打击的行为，容易封号且产出质量低。仅作了解，勿用于实际提交） |
| `Webb-L/VulBoxCharitySRC` | 2 | 2022-09-19 | 停更 | 漏洞盒子公益 SRC 厂商名单导出 CSV（停更（2022）） |

## 安装命令索引

| 仓库 | 安装 |
|---|---|
| `0x4m4/hexstrike-ai` | `git clone + pip install -r requirements.txt` |
| `0x727/ShuiZe_0x727` | `git clone` |
| `78778443/QingScan` | `docker compose / 手动部署` |
| `CTF-MissFeng/bayonet` | `git clone` |
| `Chenggaorui/AutoSRC-AISkill` | `见 README` |
| `Cynthrial/butian_urls` | `git clone` |
| `EdgeSecurityTeam/EHole` | `预编译二进制` |
| `Findomain/Findomain` | `预编译二进制（Rust 项目）` |
| `LangziFun/BuTian_Spider` | `git clone` |
| `MyuriKanao/src-hunter-skill` | `git clone 到 skills 目录` |
| `NAXG/ARL` | `docker compose` |
| `NoorQureshi/SploitAgent` | `见 README` |
| `R0x7e/Argus` | `见 README` |
| `StanleyNull/AutoHunter` | `docker compose（2C4G 起步，磁盘 >= 20G）` |
| `Ta0ing/MCP-SecurityTools` | `纯资料` |
| `Team-intN18-SoybeanSeclab/Phantom` | `浏览器扩展（加载已解压扩展）` |
| `TideSec/TideFinger` | `git clone（Python）` |
| `TideSec/TideFinger_Go` | `预编译二进制 / go build` |
| `W01fh4cker/Serein` | `git clone` |
| `Webb-L/VulBoxCharitySRC` | `python 脚本` |
| `Yean-Sec/StrikeAgent_AtkBrain-Flash` | `见 README` |
| `cckuailong/awesome-gpt-security` | `纯资料` |
| `chainreactors/gogo` | `go install github.com/chainreactors/gogo/v2@latest` |
| `d3mondev/puredns` | `预编译二进制` |
| `epi052/feroxbuster` | `预编译二进制` |
| `ffuf/ffuf` | `go install github.com/ffuf/ffuf/v2@latest` |
| `frohoff/ysoserial` | `预编译 jar` |
| `hahwul/dalfox` | `预编译二进制（v3.2.3）` |
| `hakluke/hakrawler` | `go install github.com/hakluke/hakrawler@latest` |
| `insightglacier/Dictionary-Of-Pentesting` | `纯资料` |
| `int-wc/VulBoxAuto` | `不推荐使用` |
| `knownsec/pocsuite3` | `pip install pocsuite3` |
| `lc/gau` | `go install github.com/lc/gau/v2/cmd/gau@latest` |
| `lingxisec/LingXiLabs` | `纯资料` |
| `luck-ying/butian_public_SRC` | `git clone` |
| `maurosoria/dirsearch` | `git clone + pip install -r requirements.txt` |
| `mbechler/marshalsec` | `maven build` |
| `nedlir/MCPwner` | `见 README` |
| `owl234/Awesome-SRC-experience` | `纯资料` |
| `projectdiscovery/alterx` | `go install github.com/projectdiscovery/alterx/cmd/alterx@latest` |
| `projectdiscovery/chaos-client` | `go install github.com/projectdiscovery/chaos-client/cmd/chaos@latest` |
| `projectdiscovery/dnsx` | `go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest` |
| `projectdiscovery/httpx` | `go install github.com/projectdiscovery/httpx/cmd/httpx@latest` |
| `projectdiscovery/interactsh` | `go install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest` |
| `projectdiscovery/katana` | `go install github.com/projectdiscovery/katana/cmd/katana@latest` |
| `projectdiscovery/notify` | `go install github.com/projectdiscovery/notify/cmd/notify@latest` |
| `projectdiscovery/nuclei` | `go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest` |
| `projectdiscovery/nuclei-templates` | `nuclei -update-templates` |
| `projectdiscovery/subfinder` | `go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest` |
| `shmilylty/OneForAll` | `git clone + pip install -r requirements.txt` |
| `sqlmapproject/sqlmap` | `git clone（Python 3.8 兼容）` |
| `swisskyrepo/PayloadsAllTheThings` | `纯资料` |
| `teamssix/twiki` | `纯资料` |
| `tomnomnom/waybackurls` | `go install github.com/tomnomnom/waybackurls@latest` |
| `w-digital-scanner/w13scan` | `git clone + pip install -r requirements.txt` |
| `xalgorix/xalgorix` | `见 README` |
| `z1ng/VulBoxSpider` | `git clone` |
| `zan8in/afrog` | `go install github.com/zan8in/afrog/v3@latest` |
| `zhaji2333/CkSKILLS` | `git clone 到 skills 目录` |
| `zongdeiqianxing/hscan` | `docker` |
