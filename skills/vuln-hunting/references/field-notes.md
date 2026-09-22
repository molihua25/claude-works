# 实测回馈（Field Notes）

**这个文件干什么用的**：把每次真实测试里"工具跑出来什么、卡在哪、什么条件下能拿到什么"
记下来，**下次不用重新试一遍**。

和 `catalog.json` 的分工：
- `catalog.json` —— 工具的**静态元数据**（★、停更、安装方式）
- 本文件 —— **动态实测结果**，只有真跑过才知道的东西

---

## 怎么写

每条一个 `###` 小节，标题格式：**`工具名 —— 一句话结论`**

正文四项，缺一不可：

| 项 | 说明 |
|---|---|
| **日期** | `YYYY-MM-DD`。超过半年的结论要复查 |
| **环境** | 本机 / 目标侧条件（网络、权限、WAF、目标类型） |
| **现象** | 实际观察到什么——**贴关键命令和原始输出片段**，不要转述 |
| **对策** | 下次该怎么做 |

### 什么值得记

- **静默失败**（跑完像成功、其实没结果）← 最值钱，因为看不出来
- 被 WAF / 风控拦住，以及**绕过方式**
- 某工具**在什么条件下**能拿到什么信息
- 参数组合的坑（某两个 flag 不能一起用）
- 目标侧特征（这类系统有什么共性）

### 什么不值得记

- 一次性的网络抖动
- 安装期的坑 —— 那些归 `SKILL.md`（已有一张表）
- 工具的通用用法 —— 那是官方文档的事

---

## 已验证的行为

### ProjectDiscovery 全家桶 —— 不加 `-duc` 会静默吊死

- **日期**：2026-09-22
- **环境**：本机，国内网络（国际出口受限）
- **现象**：`httpx -l target.txt ... -json -o out.jsonl` 跑了 **180 秒**，
  **零 stdout、零文件输出，目标侧一个请求都没收到**（用本地靶标的访问日志确认的）。
  加 `-duc` 后 **3.3 毫秒**正常返回。
- **对策**：`subfinder` / `httpx` / `nuclei` / `katana` / `dnsx` / `naabu` / `alterx` /
  `notify` / `interactsh-client` **全部加 `-duc`**。这是本机第一硬规则。
- **为什么难发现**：它不报错。看起来像"网络慢"或"目标不通"，实际是卡在启动时的
  版本检查上。

### nuclei —— 会静默跳过一批模板

- **日期**：2026-09-22
- **环境**：本机，nuclei 3.11.1 + nuclei-templates v10.4.9
- **现象**：同时指定 2 个模板，结果只加载了 1 个：
  `Excluded 1 template[s] with known weak matchers / tags excluded from default run using .nuclei-ignore`，
  最后报 `no templates provided for scan`（**抛 FTL 但退出码不显眼**）。
  被排除的是 `http/miscellaneous/directory-listing.yaml`。
- **对策**：跑完命中为空时，**先加 `-v` 看有没有 Excluded 提示**，再判定"目标没问题"。
  需要跑被排除的模板用 `-it` 显式包含。
- **为什么难发现**：不加 `-v` 时这行警告根本不显示，"零命中"和"模板没加载"长得一模一样。

### katana —— `-silent` 和 `-o` 一起用会写出空文件

- **日期**：2026-09-22
- **环境**：本机 + 本地靶标
- **现象**：`katana -u <url> -duc -nc -silent -o out.txt` → `out.txt` **0 行**。
  去掉 `-silent` 后同一目标抓到 **7 个端点**（含 `/.git/config`、`/backup/db_config.bak`），
  靶标访问日志也确认收到了请求。
- **对策**：要落盘就别加 `-silent`；要静默输出就别用 `-o`，二选一。

---

## 目标侧特征

### 高校 / edu.cn 资产（补天公益SRC）

- **日期**：2026-09-22
- **环境**：补天公益SRC 海南大学（Company/61188），未实际扫描
- **现象**：补天厂商页**不列资产范围**——该页"厂商介绍"为"暂无介绍"，
  全文只有漏洞数（42）和已处理数（25），**没有任何 `hainanu.edu.cn` 字样或范围字段**。
  对照补天《新人须知》：**"专属SRC"才有"厂商规定可测范围"，公益SRC 没有这个机制**。
- **对策**：**公益SRC 的范围由"归属"界定，不由页面清单界定**。
  厂商忽略漏洞的理由里明确有一条 **"误归属，漏洞不属于所属厂商"**——
  所以边界判断要靠自己确认资产归属，而不是找一份清单。
- **延伸**：高校资产要多想一层归属——附属医院、独立法人公司、科技园这类
  **可能是独立主体**，扫了容易判"误归属"。

### 西安博达网站群 CMS（Bodasoft）—— 国内高校最常见，指纹好认

- **日期**：2026-09-22
- **环境**：`www.hainanu.edu.cn` 实测
- **指纹**（见到任意一条基本可定钉）：
  - 附件路径 `/__local/<x>/<xx>/<xxx>/<hash>.jpg` —— **最独特**
  - `/system/resource/vue/static/element/index.css`（Vue + Element UI 前端）
  - `_sitegray/_sitegray_d.css`
  - 栏目/文章 URL 形如 `/hdxw/ttxw.htm`、`/info/1043/673041.htm`
- **已知接口**（从前端 JS 里挖出来的，不是猜的）：
  - `/system/resource/code/news/click/dynclicks.jsp?clickid=&owner=&clicktype=`
  - `/system/resource/code/news/click/dynclicksbatch.jsp?clickids=&owner=&clicktype=`
  - `/system/resource/code/news/click/addclicktimes.jsp?wburlid=&owner=&type=`
  - `/system/resource/getToken.jsp?mode=` / `getSession.jsp` / `sensitiveFilter.jsp`
- **后台入口是 `/system/`**，实测返回"您需要登录后才可访问系统"——**有鉴权，别指望裸奔**
- **对策**：**先从首页 HTML 里 grep `/system/` 挖接口**，比盲扫目录高效得多。
  不要浪费时间爆破 `/wcm/`（那是别的 CMS 的路径）。

### 反向代理的三种响应码 —— 用它区分"真不存在"和"被拦"

- **日期**：2026-09-22
- **环境**：`www.hainanu.edu.cn`（前置 `wrdproxy.hainanu.edu.cn`）
- **现象**：同一站点出现**三种完全不同的错误页**，字节数各不相同：

  | 响应 | 大小 | 含义 |
  |---|---|---|
  | 404 | **4689B** 固定 | 路径真的不存在（**可作过滤基线**） |
  | 502 | 5088B | **代理主动拦截**——`.DS_Store` / `.svn/entries` / `*.zip` 全走这个 |
  | 403 | 1693B | **WAF 内容检查拦截**——POST body 内容可疑时触发 |

- **对策**：
  1. **开工先校准 404 基线**（请求一个随机路径，记下 `code:size`）。
     之后**凡是不等于这个 size 的响应都值得看**。本例中靠这条一次就捞出了
     `/system/`（912B）和 `sensitiveFilter.jsp`（10B）。
  2. **502 ≠ 文件不存在**，是代理在挡。别当成"路径存在"的线索追下去。
  3. **403 出现说明 WAF 在看请求体**——完整业务 JSON 被拦、空 `{}` 放行，是典型特征。

### webber 搜索 API —— 匿名令牌就是 `tourist`，但管理接口不吐数据

- **日期**：2026-09-22
- **环境**：`www.hainanu.edu.cn`，博达站群外挂的搜索系统
- **现象**：
  - 网关前缀 `/aop_component`，直接访问 `/webber/...` 会 404（**没有前缀就是 404**）
  - `/aop_component/webber/search/test` 无头 → `401 {"msg":"token不存在"}`
  - **鉴权就是 `Authorization` 头，匿名值字面量 `tourist`**
    （前端 JS 写死 `token = params['token'] || 'tourist'`）
  - 带上后 `test` → `200 {"code":"0000","msg":"成功"}`
  - 接口集：`search/search/{queryPage,suggest,clickUrl,clickButton}` +
    `search/manage/{indexTemplate/list,show/list,showHot/list,configTemplate/owner,statistics/topSearch}`
- **关键结论**：**5 个 `manage/` 接口返回 200 但 `Content-Length: 0`，不吐任何数据**。
  路由活着（会返回"method not supported"而不是 404），但**没有数据泄露**。
  匿名搜索本身是设计如此，**不构成漏洞**。
- **对策**：遇到这套 API，**先拿 `tourist` 打通再谈别的**；但**别把"接口可达"当成"越权"**，
  要实际拿到不该拿的数据才算。这条线索到这里就断了，别反复试。

### sensitiveFilter.jsp —— 回显完全不编码，但被 Content-Type 挡住

- **日期**：2026-09-22
- **环境**：`www.hainanu.edu.cn/system/resource/sensitiveFilter.jsp`
- **现象**：POST `content=probe"<'><b>PROBE123</b>` →
  **原样返回** `probe"< '><b>PROBE123</b>`，**一个字符都没转义**。
  但响应头是 **`Content-Type: image/jpeg`** —— 浏览器不会当 HTML 渲染。
  且该响应**独独缺少 `X-Content-Type-Options: nosniff`**（同站其他接口都有）。
- **结论**：**不是可提交的 XSS**。content-type 把直接利用堵死了，
  前端那个 `filterSensitiveWords()` 函数在主站/文章页**都没有被调用**。
- **对策**：**别看到"未编码回显"就写 XSS 报告**——先看三件事：
  ① `Content-Type` 是不是 HTML；② 有没有 `nosniff`；③ **前端有没有把返回值塞进 DOM**。
  三条缺一，写出去就是无效报告，还掉信誉分。本例只值一条"加固建议"。

### CORS 检测 —— `*`+credentials 是**假的**，反射才是真的

- **日期**：2026-09-22
- **环境**：`oa.hainanu.edu.cn` 与 `ehall.hainanu.edu.cn` 对照实测
- **现象**：两个主机都返回"看起来有问题"的 CORS 头，但**性质完全相反**：

  | 主机 | `Allow-Origin` | `Allow-Credentials` | 能否利用 |
  |---|---|---|---|
  | ehall `/gsapp/` | **反射请求的任意 Origin** | `true` | ✅ **能** |
  | oa `/seeyon/rest/` | `*` | `true` | ❌ **不能** |

- **为什么 `*` + credentials 打不了**：**CORS 规范明文禁止**这个组合，
  浏览器拿到 `*` 就直接拒绝暴露响应，凭据也不发。**它是配置瑕疵，不是漏洞。**
  很多扫描器会把它报成漏洞——**那是误报，别跟着报**。
- **怎么判真伪**：发 `Origin: https://evil-attacker.example.com`，看回显：
  - 回显成 **`evil-attacker.example.com`（原样反射）** → 真问题
  - 回显成 **`*`** → 打不了
  - 再补一个 `Origin: null`（沙箱 iframe / `data:` URL 的 Origin）——
    连 `null` 都反射，说明**根本没有任何白名单逻辑**
- **附**：**302 响应也反射**说明错误配在网关层（本例是 openresty），不是某个应用里，
  影响面通常覆盖整站。**这条是判断影响范围的好线索。**

### 致远 OA（Seeyon）—— 经典 RCE 端点全 404 = 已修补

- **日期**：2026-09-22
- **环境**：`oa.hainanu.edu.cn`（致远 A8，接入 CAS 单点登录）
- **指纹**：根路径 302 → `/seeyon/index.jsp` → 再跳 `/seeyon/casSSOController.do?method=casSsoLogin`；
  页面出现 "A8C验证码"
- **实测（纯 GET 查存在性）**：

  | 端点 | 结果 |
  |---|---|
  | `/seeyon/htmlofficeservlet` | **404** ← 经典任意文件上传 |
  | `/seeyon/wpsAssistServlet` | **404** |
  | `/seeyon/autoinstall.do.css` | **404** |
  | `/seeyon/management/status.jsp` | **404** |
  | `/seeyon/rest/` | 401 `{"code":"1010"}`（通用会话失效，非鉴权绕过） |

- **对策**：**这几个一 404，说明该打的补丁都打了，别再按老 POC 试**。
  剩下的路只有"有凭据进业务"或"找新洞"，**继续盲试只是浪费时间**。
- **纪律**：这些端点的历史漏洞**都是文件上传/RCE，验证 payload 是有破坏性的**。
  本次只做 HTTP 状态码存在性判断，**没发任何上传或注入 payload**——授权不等于可以打破坏性请求。

### 金智教育 EMAP / 统一身份认证 —— ehall 的技术栈

- **日期**：2026-09-22
- **环境**：`ehall.hainanu.edu.cn`（IP `210.37.41.178`，与 www/oa 不同段）
- **指纹**：
  - `/gsapp/` 返回 `Welcome come to EMAP.` ← **EMAP 是金智的应用平台**
  - 响应头 `Server: openresty` + `Set-Cookie: route=<hex>`（后端负载均衡）
  - 其余路径 302 到 `authserver.hainanu.edu.cn/authserver/login?service=...`
  - 两个 404 基线**不同**：`/gsapp/*` 约 2400B，其他路径 599B
- **路径含义**：`gsapp`=研究生应用、`xsfw`=学生服务、`publicapp`=公共应用
- **对策**：EMAP 的业务接口在 `/gsapp/sys/<appId>/...`，**appId 得从 JS 或页面里挖，猜不中**。

### nuclei 的 `New templates added: N` 不是"你缺 N 个模板"

- **日期**：2026-09-22
- **环境**：本机，nuclei v3.11.1，`-duc` 常开
- **现象**：扫描时输出 `New templates added in latest release: 123`，
  第一反应是"模板库落后了 123 个"。**实际不是**——单独跑
  `nuclei -update-templates` 返回 `No new updates found for nuclei templates`（退出码 0），
  **本地模板是最新的**。那行只是"最新发布版总共新增了多少"的版本信息。
- **对策**：
  - **别把这行当成"本地过期"的告警**，更别因此判定扫描覆盖不全。
  - 真想知道模板新不新，跑 `nuclei -update-templates` 看返回，**这条命令不需要也不该加 `-duc`**，
    实测能通（本机国际出口受限的情况下仍可用，说明它走的是可达的源）。
  - `-duc` 依然必须常开——不加会吊死（见上文硬规则 1）。**两者不冲突。**

---

## 验证记录

### 本地验靶环境（`work/validation/`）

- **日期**：2026-09-22
- **用途**：不依赖外网、不碰任何真实目标，验证流水线各段是否真能跑通
- **构成**：`serve.py`（Python 3.8 标准库）在 `127.0.0.1:8080` 起一个故意留洞的服务：
  暴露 `/.git/config`、开启目录列表且**标题做成 Apache 的 `Index of` 风格**
- **一个关键细节**：Python 自带 `http.server` 的目录列表标题是
  `Directory listing for /`，而 nuclei 的 `directory-listing` 模板要的是
  `<title>Index of` —— **直接用 `python -m http.server` 当靶标会"跑完零命中"，
  验证不出任何东西**。必须自己写 handler。

**各段实测结果**：

| 段 | 工具 | 结果 |
|---|---|---|
| 存活探测 | httpx | ✅ 正确识别 title / webserver / tech |
| 漏洞扫描 | nuclei | ✅ 命中 `git-config`，并提取出内嵌凭据 `["deploy:Sup3rS3cret"]` |
| 目录爆破 | ffuf | ✅ 命中 `backup/` `admin/` `.git/config` |
| 爬虫 | katana | ✅ 7 个端点（去掉 `-silent` 后） |
| 去重 | anew | ✅ 幂等性正确 |
| 解析 | jq | ✅ 正常解析 JSONL |

**为什么值得留着**：这是**唯一能确定"工具本身没问题"的基线**。
以后在真实目标上零命中时，先用这个靶标跑一遍——靶标有命中而真实目标没有，
说明是目标侧的事（WAF / 无该漏洞），不是工具坏了。

---

## 待验证（还没实测过的）

- `afrog` —— 只跑过 `--version`，没跑过真实扫描
- `dalfox` / `feroxbuster` / `dirsearch` —— 只验证过"能启动"，没验证扫描效果
- `gogo` —— 只验证过能启动；**它需要 `-tags goregexp` 编译才能正确加载 Windows 指纹**，
  预编译版是否已含该 tag 未确认
- `dnsx -wd` 泛解析过滤 —— 没在真实通配域名上验证过
- `interactsh-client` —— 反连平台未验证（需要能连到官方 interactsh 服务器，
  本机国际出口受限，**很可能连不上**，这是个高风险项）

### 单目标 + SPA + WAF 时，流水线要换打法（2026-09-22 实测得出）

`www.hainanu.edu.cn` 是**单主机、Vue SPA、前置 WAF**，常规七层流水线大部分用不上：

| 段 | 为什么跳过 |
|---|---|
| 子域枚举（subfinder/dnsx） | 范围只有一台主机，做了就是越界 |
| 爬虫（katana/gau/waybackurls） | SPA 的 HTML 里没有链接，**gau 只回 3 条、wayback 0 条** |
| 目录爆破（ffuf/dirsearch） | 单站可以，但**先校准 404 基线**；WAF 会拦 |

**这种目标上真正有效的是手工读 JS**——本次全部有价值的线索
（6 个 CMS 接口、搜索 API 全套、匿名令牌 `tourist`）**都是从 JS 里读出来的**，一条都不是扫出来的。
**教训：拿到 SPA 先抓 JS 读，别急着上扫描器。**
