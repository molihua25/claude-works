#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
vuln-hunting 工具库刷新脚本

做两件事：
  1. 存量校验 —— 核实 catalog.json 里每个仓库的 star / pushed_at / 归档状态，与上次快照比对
  2. 增量发现 —— 用预设检索词在 GitHub 上找新仓库，过滤后列为候选

设计约束：
  - 纯标准库（Python 3.8 兼容，本机是 3.8.10）
  - 通过 gh CLI 取数，脚本本身不接触任何 token
  - 判断活跃度只看 pushed_at。gh search 的 updatedAt 会因加星而变，不代表代码更新
    （实测 Ta0ing/MCP-SecurityTools 搜索显示 2026-09-17、实际 pushed_at 2025-04-07）

用法：
  python refresh.py              # 默认：24 小时内已刷新则跳过
  python refresh.py --force      # 强制刷新
  python refresh.py --check      # 只做存量校验，不做发现
  python refresh.py --discover   # 只做增量发现
  python refresh.py --dry-run    # 只报告，不写回文件
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta

# ---------------------------------------------------------------- 路径

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(SCRIPT_DIR)
CATALOG_JSON = os.path.join(SKILL_DIR, "references", "catalog.json")
CATALOG_MD = os.path.join(SKILL_DIR, "references", "catalog.md")
REPORT_TXT = os.path.join(SKILL_DIR, "references", "last-refresh-report.md")

CACHE_DIR = os.path.join(os.environ.get("TEMP", "/tmp"), "vulnhunting")
CACHE_STAMP = os.path.join(CACHE_DIR, ".last-refresh")

CACHE_HOURS = 24
GRAPHQL_BATCH = 40       # 每个 GraphQL 请求查多少个仓库
SEARCH_SLEEP = 2.5       # 检索词之间间隔，search API 认证额度是 30/分钟

# 相关性过滤：GitHub 的模糊检索会把明显无关的仓库也带进来。
# 实测「资产收集」这个检索词召回了 Dujltqzv/Some-Many-Books（23874★ 的电子书仓库，
# 描述里混着一大段乱码偶然命中了关键词）。不加这道过滤，报告会被这类噪音淹没。
RELEVANCE_KEYWORDS = (
    "security", "secure", "pentest", "penetration", "hacker", "hacking",
    "exploit", "vulnerab", "recon", "scan", "fuzz", "bounty", "red team",
    "redteam", "attack", "cve", "poc", "payload", "malware", "threat",
    "security tool", "offensive", "cyber",
    "安全", "漏洞", "渗透", "攻防", "扫描", "资产收集", "信息收集",
    "指纹识别", "挖洞", "众测", "红队", "应急响应",
)


def is_relevant(description):
    """描述里是否出现安全相关关键词。宁可漏也不要噪音——漏掉的人工补录即可。"""
    low = (description or "").lower()
    if not low.strip():
        return False
    return any(k in low for k in RELEVANCE_KEYWORDS)


def looks_like_spam(description):
    """识别"描述实质上不是一段正常文本"的仓库。

    实测案例：Dujltqzv/Some-Many-Books（23874★ 的电子书仓库）描述里混着一大段
    畸形汉字，一两个安全关键词被随机撞中。特征是超长、且含大段连续空白/控制字符。
    这类仓库通常也没有主语言（language 为 null）。
    """
    d = description or ""
    if len(d) > 400:
        return True
    # 连续 4 个以上相同空白字符 = 排版垃圾，正常仓库描述不会这样
    for ch in ("　", " ", "\t", "\xa0"):
        if ch * 4 in d:
            return True
    return False

# ---------------------------------------------------------------- 输出

def say(msg):
    """控制台输出。仓库名都是 ASCII，中文细节写文件，避免 Windows 控制台编码问题。"""
    try:
        sys.stdout.write(msg + "\n")
        sys.stdout.flush()
    except UnicodeEncodeError:
        sys.stdout.write(msg.encode("ascii", "replace").decode("ascii") + "\n")
        sys.stdout.flush()


def find_gh():
    """gh 通常已在 PATH；退回已知的完整路径。"""
    for cand in ("gh", r"C:\Program Files\GitHub CLI\gh.exe"):
        try:
            subprocess.run([cand, "--version"], capture_output=True, timeout=20)
            return cand
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            continue
    return None


def run_gh(gh, args, stdin_data=None, timeout=120):
    """调 gh，返回 (ok, stdout, stderr)。"""
    try:
        p = subprocess.run(
            [gh] + args,
            input=stdin_data,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        return p.returncode == 0, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return False, "", "gh 调用超时（%ss）" % timeout
    except OSError as e:
        return False, "", "gh 调用失败：%s" % e


# ---------------------------------------------------------------- 缓存

def cache_age_hours():
    if not os.path.exists(CACHE_STAMP):
        return None
    try:
        with open(CACHE_STAMP, "r", encoding="utf-8") as f:
            ts = json.load(f).get("refreshed_at", "")
        dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S")
        return (datetime.now() - dt).total_seconds() / 3600.0
    except Exception:
        return None


def write_cache_stamp(ok_count, candidate_count):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(CACHE_STAMP, "w", encoding="utf-8") as f:
        json.dump({
            "refreshed_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
            "verified": ok_count,
            "candidates": candidate_count,
        }, f, ensure_ascii=False, indent=2)


# ---------------------------------------------------------------- 取数

def fetch_meta_graphql(gh, full_names):
    """用 GraphQL 批量取仓库元信息，比逐个 REST 快一个数量级。
    返回 {full_name: {...}}；任一批次失败则该批仓库缺席，由调用方回退 REST。"""
    out = {}
    for i in range(0, len(full_names), GRAPHQL_BATCH):
        batch = full_names[i:i + GRAPHQL_BATCH]
        parts = []
        for idx, fn in enumerate(batch):
            if "/" not in fn:
                continue
            owner, name = fn.split("/", 1)
            parts.append(
                'r%d: repository(owner: %s, name: %s) {'
                ' stargazerCount pushedAt isArchived description }'
                % (idx, json.dumps(owner), json.dumps(name))
            )
        if not parts:
            continue
        query = "query { " + " ".join(parts) + " }"
        body = json.dumps({"query": query})
        ok, stdout, stderr = run_gh(gh, ["api", "graphql", "--input", "-"], stdin_data=body)
        if not ok:
            say("  [warn] GraphQL 批次失败，回退 REST: %s" % stderr.strip()[:120])
            continue
        try:
            payload = json.loads(stdout).get("data") or {}
        except ValueError:
            continue
        for idx, fn in enumerate(batch):
            node = payload.get("r%d" % idx)
            if not node:
                continue
            out[fn] = {
                "stars": node.get("stargazerCount"),
                "pushed_at": (node.get("pushedAt") or "")[:10],
                "archived": bool(node.get("isArchived")),
                "description": (node.get("description") or "").strip(),
            }
    return out


def fetch_meta_rest(gh, full_name):
    """单个仓库的 REST 回退路径。"""
    ok, stdout, stderr = run_gh(gh, [
        "api", "repos/%s" % full_name,
        "--jq", '{stars: .stargazers_count, pushed_at: (.pushed_at[0:10]), archived: .archived, description: (.description // "")}',
    ])
    if not ok:
        return None
    try:
        return json.loads(stdout)
    except ValueError:
        return None


# ---------------------------------------------------------------- 校验

def months_since(date_str):
    """date_str: YYYY-MM-DD → 距今月数（近似）；无法解析返回 None。"""
    try:
        d = datetime.strptime(date_str, "%Y-%m-%d")
    except (ValueError, TypeError):
        return None
    return (datetime.now() - d).days / 30.44


def staleness_label(months):
    if months is None:
        return "未知"
    if months < 6:
        return "活跃"
    if months < 18:
        return "半停更"
    return "停更"


def verify_existing(gh, catalog):
    """刷新所有已知仓库。返回 (changes, failures)。"""
    repos = catalog["repos"]
    names = [r["full_name"] for r in repos]
    say("  正在批量校验 %d 个仓库…" % len(names))

    meta = fetch_meta_graphql(gh, names)

    missing = [n for n in names if n not in meta]
    if missing:
        say("  GraphQL 未覆盖 %d 个，逐个回退 REST…" % len(missing))
        for n in missing:
            m = fetch_meta_rest(gh, n)
            if m:
                meta[n] = m

    changes, failures = [], []
    for r in repos:
        fn = r["full_name"]
        m = meta.get(fn)
        if not m or m.get("stars") is None:
            failures.append(fn)
            continue

        old_stars = r.get("stars", 0)
        old_pushed = r.get("pushed_at", "")
        new_stars = m["stars"]
        new_pushed = m["pushed_at"]

        delta = new_stars - old_stars
        if delta != 0 or new_pushed != old_pushed or m["archived"] != r.get("archived"):
            changes.append({
                "full_name": fn,
                "stars_delta": delta,
                "stars": new_stars,
                "old_pushed": old_pushed,
                "new_pushed": new_pushed,
                "archived": m["archived"],
            })

        r["stars"] = new_stars
        r["pushed_at"] = new_pushed
        r["archived"] = m["archived"]
        if m.get("description"):
            r["_upstream_description"] = m["description"]
        r["_staleness"] = staleness_label(months_since(new_pushed))

    return changes, failures


# ---------------------------------------------------------------- 发现

def discover(gh, catalog):
    """按预设检索词找新仓库。返回候选列表。"""
    cfg = catalog.get("discovery", {})
    queries = cfg.get("queries", [])
    min_stars = cfg.get("min_stars", 50)
    limit = cfg.get("search_limit", 60)
    blocklist = {b.lower() for b in cfg.get("blocklist", [])}
    known = {r["full_name"].lower() for r in catalog["repos"]} | blocklist

    # 只收近 6 个月有推送的
    cutoff = (datetime.now() - timedelta(days=183)).strftime("%Y-%m-%d")

    seen, candidates = set(), []
    for q in queries:
        say("  检索: %s" % q)
        ok, stdout, stderr = run_gh(gh, [
            "search", "repos", q,
            "--sort", "stars",
            "--limit", str(limit),
            "--json", "fullName,stargazersCount,pushedAt,description,language",
        ])
        if not ok:
            say("    [warn] 检索失败: %s" % stderr.strip()[:100])
            time.sleep(SEARCH_SLEEP)
            continue
        try:
            rows = json.loads(stdout)
        except ValueError:
            rows = []
        for row in rows:
            fn = row.get("fullName", "")
            key = fn.lower()
            if not fn or key in known or key in seen:
                continue
            stars = row.get("stargazersCount") or 0
            pushed = (row.get("pushedAt") or "")[:10]
            desc = (row.get("description") or "").strip()
            # 注意：limit 在服务端过滤之前生效，所以这里必须客户端再筛一遍
            if stars < min_stars or pushed < cutoff:
                continue
            if not is_relevant(desc):
                continue
            if looks_like_spam(desc):
                continue
            # 无主语言的仓库基本是纯资料/文本仓库，不是可用的工具
            lang = (row.get("language") or "").strip()
            if not lang:
                continue
            seen.add(key)
            candidates.append({
                "full_name": fn,
                "stars": stars,
                "pushed_at": pushed,
                "description": desc[:200],
                "language": lang,
                "found_by": q,
            })
        time.sleep(SEARCH_SLEEP)

    candidates.sort(key=lambda c: -c["stars"])
    return candidates


# ---------------------------------------------------------------- 渲染

def render_markdown(catalog):
    """由 catalog.json 生成人读版目录。"""
    repos = catalog["repos"]
    layers = catalog.get("layers", {})
    L = []
    L.append("# 挖漏洞工具库目录")
    L.append("")
    L.append("> 本文件由 `scripts/refresh.py` 自动生成，请勿手改——改 `catalog.json`。")
    L.append("> 最后刷新：%s" % catalog.get("generated", "?"))
    L.append("")
    L.append("**判断活跃度只看 `pushed_at`**：gh search 的 `updatedAt` 会因加星而变，")
    L.append("不代表代码更新（实测有仓库两者相差 17 个月）。")
    L.append("")

    for key, label in layers.items():
        rows = [r for r in repos if r["layer"] == key]
        if not rows:
            continue
        rows.sort(key=lambda r: -(r.get("stars") or 0))
        L.append("## %s" % label)
        L.append("")
        L.append("| 仓库 | ★ | 最近提交 | 状态 | 用途 |")
        L.append("|---|---:|---|---|---|")
        for r in rows:
            months = months_since(r.get("pushed_at", ""))
            st = staleness_label(months)
            if r.get("archived"):
                st = "**已归档**"
            role = r.get("role", "")
            if r.get("status_note"):
                role += "（%s）" % r["status_note"]
            L.append("| `%s` | %s | %s | %s | %s |" % (
                r["full_name"],
                r.get("stars", "?"),
                r.get("pushed_at", "?"),
                st,
                role,
            ))
        L.append("")

    L.append("## 安装命令索引")
    L.append("")
    L.append("| 仓库 | 安装 |")
    L.append("|---|---|")
    for r in sorted(repos, key=lambda x: x["full_name"]):
        if r.get("install"):
            L.append("| `%s` | `%s` |" % (r["full_name"], r["install"]))
    L.append("")
    return "\n".join(L)


def render_report(changes, failures, candidates, elapsed):
    R = []
    R.append("# 工具库刷新报告")
    R.append("")
    R.append("刷新时间：%s（耗时 %.1fs）" % (datetime.now().strftime("%Y-%m-%d %H:%M"), elapsed))
    R.append("")

    R.append("## 存量变化（%d 项）" % len(changes))
    R.append("")
    if not changes:
        R.append("无变化。")
    else:
        R.append("| 仓库 | ★变化 | 最近提交 | 归档 |")
        R.append("|---|---:|---|---|")
        for c in changes:
            delta = c["stars_delta"]
            dtxt = ("+%d" % delta) if delta > 0 else str(delta)
            R.append("| `%s` | %s → %s (%s) | %s → %s | %s |" % (
                c["full_name"], c["stars"] - delta, c["stars"], dtxt,
                c["old_pushed"], c["new_pushed"],
                "是" if c["archived"] else "—",
            ))
    R.append("")

    if failures:
        R.append("## 取数失败（%d 个，可能是改名/删除/网络问题）" % len(failures))
        R.append("")
        for f in failures:
            R.append("- `%s`" % f)
        R.append("")

    R.append("## 新发现候选（%d 个）" % len(candidates))
    R.append("")
    if not candidates:
        R.append("本轮没有新仓库。")
    else:
        R.append("这些**不在** catalog.json 里，需要人工判断是否收录：")
        R.append("")
        R.append("| 仓库 | ★ | 最近提交 | 描述 | 命中检索词 |")
        R.append("|---|---:|---|---|---|")
        for c in candidates:
            R.append("| `%s` | %s | %s | %s | %s |" % (
                c["full_name"], c["stars"], c["pushed_at"],
                c["description"].replace("|", "/"), c["found_by"],
            ))
    R.append("")
    return "\n".join(R)


# ---------------------------------------------------------------- 主流程

def main():
    ap = argparse.ArgumentParser(description="vuln-hunting 工具库刷新")
    ap.add_argument("--force", action="store_true", help="忽略 24 小时缓存，强制刷新")
    ap.add_argument("--check", action="store_true", help="只做存量校验")
    ap.add_argument("--discover", action="store_true", help="只做增量发现")
    ap.add_argument("--dry-run", action="store_true", help="只报告，不写回文件")
    args = ap.parse_args()

    t0 = time.time()

    if not os.path.exists(CATALOG_JSON):
        say("[error] 找不到 catalog.json：%s" % CATALOG_JSON)
        return 2

    with open(CATALOG_JSON, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    # 缓存检查
    do_check = not args.discover
    do_discover = not args.check

    if not args.force and do_check and do_discover:
        age = cache_age_hours()
        if age is not None and age < CACHE_HOURS:
            say("[skip] %.1f 小时前刚刷新过（缓存 %dh），跳过。" % (age, CACHE_HOURS))
            say("       要强制刷新请加 --force")
            return 0

    gh = find_gh()
    if not gh:
        say("[error] 找不到 gh CLI。请确认已安装并登录（gh auth status）。")
        return 2
    say("[gh] %s" % gh)

    changes, failures, candidates = [], [], []

    if do_check:
        say("[1/2] 存量校验")
        changes, failures = verify_existing(gh, catalog)
        say("      完成：%d 个仓库，%d 项变化，%d 个取数失败"
            % (len(catalog["repos"]), len(changes), len(failures)))

    if do_discover:
        say("[2/2] 增量发现")
        candidates = discover(gh, catalog)
        say("      完成：%d 个新候选" % len(candidates))

    catalog["generated"] = datetime.now().strftime("%Y-%m-%d")
    elapsed = time.time() - t0

    if args.dry_run:
        say("[dry-run] 不写回文件")
        say("耗时 %.1fs" % elapsed)
        return 0

    with open(CATALOG_JSON, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    with open(CATALOG_MD, "w", encoding="utf-8") as f:
        f.write(render_markdown(catalog))
    with open(REPORT_TXT, "w", encoding="utf-8") as f:
        f.write(render_report(changes, failures, candidates, elapsed))

    if do_check and do_discover:
        write_cache_stamp(len(catalog["repos"]) - len(failures), len(candidates))

    say("[done] 耗时 %.1fs" % elapsed)
    say("  catalog.json : %d 个仓库" % len(catalog["repos"]))
    say("  catalog.md   : 已重新生成")
    say("  刷新报告     : references/last-refresh-report.md")

    # 控制台只打 ASCII 摘要，中文细节在报告文件里
    if changes:
        say("  -- 有变化的仓库 --")
        for c in changes[:15]:
            say("     %-42s *%s (%+d)  %s -> %s"
                % (c["full_name"], c["stars"], c["stars_delta"],
                   c["old_pushed"], c["new_pushed"]))
    if failures:
        say("  -- 取数失败 --")
        for fn in failures[:10]:
            say("     %s" % fn)
    if candidates:
        say("  -- 新候选（top 10）--")
        for c in candidates[:10]:
            say("     %-42s *%s  %s" % (c["full_name"], c["stars"], c["pushed_at"]))

    return 0


if __name__ == "__main__":
    sys.exit(main())
