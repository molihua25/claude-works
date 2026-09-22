# 流水线编排

每一段都 `-o json` 落盘，段间用文件传递。**任何一段挂掉都能从上一段的结果重启**，不要写成一根管道串到底。

> **可用性标记**：下文命令里 ✅ = 本机已装（`C:\Users\wwwwz\bin`），
> ⚠️ = 未装、需另行安装，标注了替代方案。**给用户报命令前先确认对应工具在不在**，
> 不要报一个跑不起来的命令然后让用户自己发现。

---

## ⚠️ 三条实测踩出来的硬规则（不遵守命令会"卡死"或"静默无结果"）

### 1. ProjectDiscovery 全家桶必须加 `-duc`

`subfinder` / `httpx` / `nuclei` / `katana` / `dnsx` / `naabu` / `alterx` / `notify` /
`interactsh-client` 启动时都会**联网做版本检查**。本机国际出口受限，它们会**直接吊死**——
不发任何请求、不打任何日志，看着像在跑，其实永远跑不完。

```
实测：httpx 不加 -duc  → 180 秒零输出、零请求（靶标根本没收到包）
      httpx 加   -duc  → 3.3 ms 正常返回
```

**下文所有 PD 工具的命令都已经带上 `-duc`，不要图省事删掉。**

### 2. nuclei 会静默跳过一批模板

nuclei 默认按 `.nuclei-ignore` 排除"匹配器太弱"的模板，**只在 `-v` 下打一行
`Excluded N template[s] with known weak matchers`**。实测
`http/miscellaneous/directory-listing.yaml` 就被静默排除了，扫完报"No results found"，
很容易误判成"目标没问题"。

需要跑这些模板时，先 `-v` 看排除提示，或用 `-it` 显式包含。

### 3. katana 的 `-silent` 和 `-o` 别一起用

实测同时使用会导致**输出文件为空**（不是没爬，是写不进去）。要落盘就不要加 `-silent`。

建议工作目录结构：

```
work/<项目名>/
├── 00-scope.txt          # 授权范围（人工写，唯一真源）
├── 01-subs.txt           # 子域名
├── 02-alive.jsonl        # 存活
├── 03-finger.jsonl       # 指纹
├── 04-nuclei.jsonl       # 漏洞命中
├── 05-verified.md        # 人工验证记录  ← 唯一能进报告的东西
└── 06-report.md
```

---

## 0. 范围准备

**先把授权范围写成文件。** 后面每条命令的输入都从它派生，避免手滑扫到范围外。

```bash
mkdir -p work/<项目名> && cd work/<项目名>
# 把授权域名逐个写进 00-scope.txt，一行一个
```

补天/漏洞盒子的厂商范围可参考目录里的 `butian_public_SRC` / `VulBoxCharitySRC`，
**但这两个仓库都已停更，务必回平台页面核对**——直接用会漏掉近几年新入驻的厂商。

---

## 1. 资产发现

```bash
# 被动枚举（快，无侵入）
subfinder -dL 00-scope.txt -all -duc -silent -o 01-subs-raw.txt     # ✅

# 解析 + 泛解析过滤 —— 必做
# 一个域名一次 -wd，多个域名就重复传多个 -wd
dnsx -l 01-subs-raw.txt -wd example.com -a -resp -duc -silent -o 01-subs.txt   # ✅
sort -u 01-subs.txt -o 01-subs.txt
```

**为什么不用 puredns**：网上教程普遍推荐 `puredns resolve`，但 puredns 只是个调度器，
真正解析的是 **massdns —— 一个 C 程序**，`go install` 装不了、Windows 也没有官方预编译。
`dnsx -wd` 做的是同一件事（泛解析过滤），而且本机已装。

**⚠️ 未装**：`OneForAll`（国内资产覆盖更广，但需 git clone + 一堆 Python 依赖，
本机 Python 3.8 已 EOL，装之前先评估）——没有它不影响主流程，subfinder 够起步。

**坑**：不做泛解析过滤，`*.example.com` 这类通配域名会让结果从几百条膨胀到几万条。

> 若项目**只授权主站不含子域**，跳过本段，直接把 `00-scope.txt` 的主域名交给第 2 段。

---

## 2. 存活探测（去噪主力）

```bash
httpx -l 01-subs.txt \
  -title -tech-detect -status-code -web-server \
  -favicon -jarm -cname \
  -threads 50 -rate-limit 150 -duc \
  -json -o 02-alive.jsonl                                            # ✅
```

**为什么这步关键**：子域枚举出来通常 70–90% 是不通或空壳。先收敛再扫，既快又降低触发 WAF 的概率。

**必设速率限制**：`-rate-limit` 是防止把目标打崩的第一道闸。授权测试打成事故就全完了。

---

## 3. 指纹识别

```bash
# 主力：httpx 上一段已经带了 -tech-detect，直接从 02-alive.jsonl 里筛
cat 02-alive.jsonl | jq -r 'select(.tech != null) | "\(.url) \(.tech|join(","))"'   # ✅
```

**⚠️ 未装（两个都停更了，装之前想清楚值不值）**：
- `TideFinger_Go` —— 指纹库 2.3W 条，但代码停在 2025-02（19 个月），新组件识别率下降
- `EHole` —— 主打国产 OA/ERP 指纹，同样偏老

这层**不建议硬上工具**：目标是筛出高价值资产，`httpx -tech-detect` 加人工扫一眼标题往往就够。
真正高效的做法是直接看 `/actuator`、`/swagger-ui`、`/druid`、登录后台这些**具体路径**——
下面第 5 段用 nuclei 的 `exposures/` 模板覆盖的正是这些。

**看什么**：不是看识别出多少个，而是筛出**高价值目标**——老版本中间件、国产 OA、暴露的管理后台、`/actuator`、`/swagger-ui` 这类。这些是下一步的重点。

---

## 4. 爬虫与 URL 收集

```bash
# 历史 URL（能翻出早已遗忘的接口）
gau --threads 5 < 00-scope.txt > 04-urls-history.txt            # ✅
waybackurls < 00-scope.txt >> 04-urls-history.txt               # ✅

# 主动爬取（能翻出 JS 里的接口）
# 注意：不要加 -silent，会和 -o 冲突导致输出为空（见上文硬规则 3）
katana -list 02-alive.txt -jc -kf all -d 3 -duc -jsonl -o 04-urls-crawl.jsonl   # ✅

# 合并去重
cat 04-urls-history.txt | anew >> 04-urls.txt                   # ✅
```

**JS 里常藏着未公开的 API**——这是挖越权/未授权访问最容易出成果的地方。

---

## 5. 漏洞扫描

```bash
# 起反连平台（盲注/SSRF/Log4j 全靠它）
interactsh-client -duc -v -o 05-interactsh.txt &                # ✅ 但见下方警告

# nuclei 主扫
nuclei -l 02-alive.txt \
  -t http/ -t cves/ -t exposures/ -t misconfiguration/ \
  -severity medium,high,critical \
  -rate-limit 100 -bulk-size 25 -concurrency 20 \
  -duc -stats -jsonl -o 05-nuclei.jsonl                         # ✅
```

**⚠️ `interactsh-client` 本机大概率连不上**：它要连官方 `interactsh` 服务器
（境外），本机国际出口受限。**上机前先确认它能取到域名**，取不到就别指望 OOB 类漏洞
（盲注/SSRF/Log4j）。替代方案见 `field-notes.md`。

**⚠️ 零命中时先别下结论**：nuclei 会静默排除一批"弱匹配器"模板（见上文硬规则 2），
加 `-v` 确认是不是模板压根没加载。

```bash

# afrog 补刀 —— 国产组件/中文漏洞覆盖比 nuclei 好，两个都跑
afrog -T 02-alive.txt -o 05-afrog.txt                           # ✅
```

**severity 过滤很重要**：`info` 级别的结果量极大且几乎全是噪音（比如"检测到 X-Powered-By"）。除非专门查信息泄露，否则不要带 `info`。

**OOB 回调**：nuclei/afrog 命中带外漏洞时，去 `05-interactsh.txt` 核对——**只有真的收到回调才算确认**。

---

## 6. 被动扫描（可选，边点边挖）

挖逻辑漏洞和越权时，自动化扫描帮不上忙，但被动扫描器能兜底：

```bash
# 起 w13scan，浏览器挂上它的代理，然后正常浏览目标站点
w13scan -s 127.0.0.1:7777 --html
```

**⚠️ 未装**：`w13scan` 代码停在 2023-02（三年半），装它要权衡。
纯被动扫描的替代方案是 **Burp Suite 社区版**（图形界面，人工挂着代理浏览即可），
或者干脆跳过本段——挖越权/逻辑漏洞本来就要手工抓包，被动扫描器只是顺手兜底。

适合无脑浏览一遍后台，让它顺手把反射型 XSS、敏感信息泄露捡出来。

---

## 7. 人工验证（不可跳过）

**扫描器的输出是线索，不是结论。**

逐条验证，记进 `05-verified.md`：

| 检查项 | 说明 |
|---|---|
| 真阳性？ | 很多 POC 是"疑似命中"，尤其版本号推断类 |
| 在授权范围内？ | **范围外的发现一律不算**，哪怕是真的漏洞 |
| 能独立复现？ | 写清楚完整复现步骤，换个人能重现 |
| 影响是什么？ | 不能只说"存在漏洞"，要说"能拿到什么" |
| 是否重复？ | 提交前先搜平台历史 |

**分级**：
- **已验证** —— 亲手复现，有完整请求/响应
- **疑似待验** —— 有迹象但没坐实
- 两栏**绝不能混**，报告里也不许混

---

## 8. 通知与报告

```bash
# 结果推到手机（配置见 notify 文档）
echo 05-nuclei.jsonl | notify -provider-config provider.yaml
```

报告格式见 `platforms.md`。

---

## 编排原则（写自己的 orchestrator 时）

1. **每段输出 JSONL**，不要用纯文本——文本没法程序化去重和过滤
2. **每段独立可重跑**，输入是文件的路径，不是上一步的管道
3. **速率限制写死在配置里**，不要指望每次记得加参数
4. **去重放在每段之间**，一个 URL 扫三遍纯属浪费配额
5. **断点续跑**：记录已处理的输入行，重启时跳过

> 真正的自动化收益在**去重和误报过滤**，不在扫描速度。扫描器再快，出来 5000 条待验证的结果等于没干活。
