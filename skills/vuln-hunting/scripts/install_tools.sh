#!/usr/bin/env bash
# vuln-hunting 工具链安装
#
# 设计原则：
#   1. 幂等 —— 已装的跳过，可反复重跑
#   2. 优先预编译二进制 —— 源码构建有 CGO/build-tags/编译器版本等一堆坑
#   3. 出错不中断后续 —— 单个工具失败不该拖垮整批
#
# 用法：
#   bash install_tools.sh           # 全装
#   bash install_tools.sh 1         # 只跑阶段 1（Go）
#   bash install_tools.sh 1 2       # 跑阶段 1 和 2

set -u

BIN="/c/Users/wwwwz/bin"
TOOLS="/c/Users/wwwwz/tools"
TMP="${TEMP:-/tmp}/vulnhunting-install"
GH="/c/Program Files/GitHub CLI/gh.exe"
[ -x "$GH" ] || GH="gh"

# Go 有两个可能落点：本脚本用免安装 zip 装的是用户级（不需要管理员），
# winget/MSI 装的是机器级。两个都认，谁在就用谁。
GOMIRRORS="https://golang.google.cn/dl https://mirrors.aliyun.com/golang https://mirrors.ustc.edu.cn/golang"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'

ok()   { printf "  ${GRN}OK${RST}   %s\n" "$1"; }
skip() { printf "  ${DIM}skip${RST} %s（已存在）\n" "$1"; }
fail() { printf "  ${RED}FAIL${RST} %s\n" "$1"; FAILED+=("$1"); }
warn() { printf "  ${YEL}warn${RST} %s\n" "$1"; }
head_() { printf "\n${GRN}=== %s ===${RST}\n" "$1"; }

FAILED=()

have() { command -v "$1" >/dev/null 2>&1; }

# winget 装的工具有固定落点，但系统 PATH 要新开终端才生效。
# 自检时直接探这些路径，免得刚装完就报"缺失"。
side_path() {
  case "$1" in
    nmap) [ -x "/c/Program Files (x86)/Nmap/nmap.exe" ] && echo "/c/Program Files (x86)/Nmap/nmap.exe" ;;
  esac
}

# 找出可用的 go，找不到就返回空串
go_exe() {
  for c in "$TOOLS/go/bin/go.exe" "/c/Program Files/Go/bin/go.exe"; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  have go && command -v go
}

# 往**用户级** PATH 追加一个目录（幂等）。
#
# 绝不用 setx：它有两个已知坑 ——
#   1. 值超过 1024 字符会被静默截断，用户的 PATH 恰好很长就会丢条目；
#   2. 从 Git Bash 调用时不展开 %PATH%，会把字面量 "%PATH%;C:\..." 写进注册表。
# PowerShell 的 [Environment]::SetEnvironmentVariable(...,'User') 直接读写注册表
# 原值，只做追加，其余字节原样保留。
add_user_path() {
  local dir="$1" ps="$TMP/add_user_path.ps1"
  mkdir -p "$TMP"
  cat > "$ps" <<'PSEOF'
param([string]$Dir)
$p = [Environment]::GetEnvironmentVariable('Path','User')
if ($null -eq $p) { $p = '' }
if (($p -split ';') -contains $Dir) { Write-Output 'exists'; exit 0 }
if ($p -ne '' -and -not $p.EndsWith(';')) { $p = $p + ';' }
[Environment]::SetEnvironmentVariable('Path', ($p + $Dir), 'User')
Write-Output 'added'
PSEOF
  local r
  r=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ps" 2>/dev/null || echo "$ps")" \
        -Dir "$dir" 2>/dev/null | tr -d '\r' | tail -1)
  case "$r" in
    added)  ok "PATH += $dir（新开终端生效）" ;;
    exists) : ;;
    *)      warn "PATH 未改动（PowerShell 调用失败）—— 如需手动加：$dir" ;;
  esac
}

# ---------------------------------------------------------------- 解压

extract() {
  # $1=压缩包 $2=目标目录
  if have unzip; then
    unzip -o -q "$1" -d "$2" 2>/dev/null && return 0
  fi
  if [ -x /c/Windows/System32/tar.exe ]; then
    /c/Windows/System32/tar.exe -xf "$1" -C "$2" 2>/dev/null && return 0
  fi
  if have tar && tar -xf "$1" -C "$2" 2>/dev/null; then return 0; fi
  return 1
}

# 从 GitHub Release 拉预编译包并解压到 BIN
# $1=repo  $2=asset 匹配模式  $3=要检查的可执行文件名
fetch_release() {
  local repo="$1" pattern="$2" check="$3"
  # 幂等：已经装过就跳过，避免重跑脚本时重复下载几百 MB
  if [ -f "$BIN/$check.exe" ] || [ -f "$BIN/$check" ]; then
    skip "$repo -> $check"
    return 0
  fi
  mkdir -p "$BIN"
  local d="$TMP/$(echo "$repo" | tr '/' '_')"
  rm -rf "$d"; mkdir -p "$d"
  if ! "$GH" release download --repo "$repo" --pattern "$pattern" --dir "$d" --clobber >/dev/null 2>&1; then
    fail "$repo （下载失败，检查网络或 release 资产名）"
    return 1
  fi
  local got
  # .sha256 / .sig 之类不是要装的东西
  got=$(find "$d" -type f ! -name '*.sha256' ! -name '*.sig' ! -name '*.txt' | head -1)
  if [ -z "$got" ]; then fail "$repo （没下到文件）"; return 1; fi

  # 有的项目直接分发裸可执行文件而不是压缩包（例如 chainreactors/gogo 的
  # gogo_windows_amd64.exe），对它调解压必然失败，直接拷过去即可。
  #
  # 注意必须**改名成 $check.exe**：上游的文件名带平台后缀（gogo_windows_amd64.exe），
  # 原样拷过去会落成那个名字，测试却按 gogo.exe 找，结果"报 OK 但实际缺失"。
  if [ "${got##*.}" = "exe" ]; then
    if cp -f "$got" "$BIN/$check.exe"; then ok "$repo -> $check"; else fail "$repo （拷贝失败）"; fi
    return 0
  fi

  if ! extract "$got" "$d"; then fail "$repo （解压失败）"; return 1; fi

  # 只挑出我们要的那一个可执行文件。
  #
  # 绝不要"把包里所有可执行文件都拷进 BIN" —— 曾经这么干过，后果：
  # dirsearch 的 portable 包内嵌了一整套 Python 3.14 运行时（约 150 个文件，
  # 含 python.exe / pip.exe / python314.dll），全量拷贝直接把 bin 淹了。
  # 更糟的是 BIN 在 PATH 第一位，那个 python.exe 会盖掉用户真正的 Python；
  # 而包里的 httpx.exe 是 Python httpx *库* 的控制台入口（108KB），
  # 正好覆盖掉 ProjectDiscovery 的 httpx 工具（30MB）——同名不同物。
  local src
  src=$(find "$d" -type f \( -name "$check.exe" -o -name "$check" \) ! -name '*.zip' | head -1)
  local guessed=0
  if [ -z "$src" ]; then
    # 退路：找不到精确名字时，取体积像样的那一个（>1MB），仍避免扫进运行时文件
    src=$(find "$d" -type f -name '*.exe' -size +1M | head -1)
    [ -n "$src" ] && guessed=1
  fi
  if [ -n "$src" ]; then
    if cp -f "$src" "$BIN/$check.exe"; then
      if [ "$guessed" = 1 ]; then
        warn "$repo -> $check（按体积猜的，原名 $(basename "$src")，请手动 --version 确认）"
      else
        ok "$repo -> $check"
      fi
    else
      fail "$repo （拷贝失败）"
    fi
  else
    fail "$repo （没找到可执行文件 $check）"
  fi
}

# dirsearch 是**目录式**发行包：里面自带一整套 Python 3.14 运行时
# （python/ 约 150 个文件）和 app/ 源码，入口是 dirsearch.cmd。
#
# 所以它绝对不能按 fetch_release 那样往 bin 里拷：
#   1. 包里根本没有 dirsearch.exe，按名字找不到；
#   2. 退路"取个大 exe"会把 python.exe 拷进 bin —— bin 在 PATH 第一位，
#      那个 python.exe 会盖掉用户真正的 Python（上次就这么炸的）。
# 正确做法：整包解到 tools/ 下，只在 bin 放一个 .cmd 转发器。
install_dirsearch() {
  local dest="$TOOLS/dirsearch" shim="$BIN/dirsearch.cmd"

  # 幂等：目标目录和转发器都在才算装好
  if [ -f "$dest/dirsearch.cmd" ] && [ -f "$shim" ]; then skip "maurosoria/dirsearch"; return 0; fi

  mkdir -p "$BIN" "$TOOLS"
  local d="$TMP/maurosoria_dirsearch"; rm -rf "$d"; mkdir -p "$d"

  if ! "$GH" release download --repo maurosoria/dirsearch \
        --pattern "*windows-x64-async-portable.zip" --dir "$d" --clobber >/dev/null 2>&1; then
    fail "maurosoria/dirsearch （下载失败）"; return 1
  fi
  local got; got=$(find "$d" -type f -name '*.zip' | head -1)
  [ -n "$got" ] || { fail "maurosoria/dirsearch （没下到 zip）"; return 1; }

  rm -rf "$dest"; mkdir -p "$dest"
  if ! extract "$got" "$dest"; then fail "maurosoria/dirsearch （解压失败）"; return 1; fi

  # 包里多套了一层带版本号的目录（dirsearch-v0.5.0-.../），拍平掉，
  # 免得以后升版本还要改调用路径。dotglob 是为了别丢 .gitignore 这类隐藏文件。
  local inner
  inner=$(find "$dest" -maxdepth 1 -mindepth 1 -type d | head -1)
  if [ -n "$inner" ]; then
    shopt -s dotglob
    mv "$inner"/* "$dest"/ 2>/dev/null
    shopt -u dotglob
    rmdir "$inner" 2>/dev/null
  fi

  [ -f "$dest/dirsearch.cmd" ] || { fail "maurosoria/dirsearch （包里没有 dirsearch.cmd，结构可能变了）"; return 1; }

  # 转发器用绝对路径，不依赖 %~dp0 的相对推算
  printf '@echo off\r\n"%s\\dirsearch.cmd" %%*\r\n' 'C:\Users\wwwwz\tools\dirsearch' > "$shim"
  ok "dirsearch -> $dest  （PATH 入口：dirsearch）"
}

# ---------------------------------------------------------------- 阶段 1：Go

phase1() {
  head_ "阶段 1/5：Go 工具链"

  local G; G=$(go_exe)
  if [ -n "$G" ]; then
    skip "Go ($("$G" version 2>/dev/null))"
  else
    # 为什么不用 winget install GoLang.Go：
    #   实测报 InternetOpenUrl() failed 0x80072efd —— winget 拉 go.dev 直连失败。
    #   而且 MSI 是机器级安装，必须过 UAC。
    # 改用**免安装 zip**：从国内镜像下、解到用户目录，零权限、不弹窗、可随时删。
    G=$(install_go_zip) || { fail "Go 安装失败（三个镜像都没下成）"; return; }
    ok "Go -> $G"
  fi

  mkdir -p "$BIN"
  ok "确保 $BIN 存在"

  # GOBIN 必须在 go 可用之后设置
  if "$G" env -w GOBIN='C:\Users\wwwwz\bin' 2>/dev/null; then
    ok "GOBIN = $("$G" env GOBIN)"
  else
    warn "GOBIN 设置失败"
  fi
  "$G" env -w GOPATH='C:\Users\wwwwz\go' 2>/dev/null

  # go install 拉模块走 proxy.golang.org，国内基本不通，必须换代理
  if "$G" env -w GOPROXY='https://goproxy.cn,direct' 2>/dev/null; then
    ok "GOPROXY = $("$G" env GOPROXY)"
  fi
  "$G" env -w GOSUMDB=off 2>/dev/null

  # 注意：C:\Users\wwwwz\bin 本来就在用户 PATH 第一位，无需改 PATH。
  # 不要用 setx 改 PATH —— 它会截断 1024 字符以上、且从 Git Bash 调用时
  # 不会展开 %PATH%，会把字面量写进注册表。
}

# 下载 Go 免安装 zip 并解到 $TOOLS/go。
#
# 契约：**stdout 只输出 go.exe 路径这一行**，其余全部走 stderr。
# 调用方是 G=$(install_go_zip)，任何多余的 stdout 输出都会被一起捕获，
# 让 $G 变成多行垃圾串，后面 "$G" env -w ... 就会当成命令名执行失败。
# （这个坑真踩过：GOBIN/GOPROXY 静默没设上，还只报 "warn GOBIN 设置失败"。）
install_go_zip() {
  local ver
  ver=$(curl -s -m 20 "https://golang.google.cn/VERSION?m=text" | head -1)
  # 取不到版本号时兜底一个已知可用的
  [ -n "$ver" ] || ver="go1.27.1"
  printf "  ${DIM}Go 版本：%s${RST}\n" "$ver" >&2

  local zip="$TMP/$ver.windows-amd64.zip"
  mkdir -p "$TMP"
  local got=0
  for base in $GOMIRRORS; do
    printf "  ${DIM}下载 %s ...${RST}\n" "$base" >&2
    if curl -fL -m 600 --retry 2 -o "$zip" "$base/$ver.windows-amd64.zip" 2>/dev/null; then
      # 下成 HTML 错误页也算"成功"，按体积卡一道（真实包约 70MB+）
      local sz; sz=$(stat -c %s "$zip" 2>/dev/null || echo 0)
      if [ "$sz" -gt 50000000 ]; then got=1; break; fi
      printf "  ${DIM}  文件只有 %s 字节，不像真包，换下一个${RST}\n" "$sz" >&2
    fi
  done
  [ "$got" = 1 ] || return 1

  rm -rf "$TOOLS/go"
  mkdir -p "$TOOLS"
  if ! extract "$zip" "$TOOLS"; then return 1; fi   # 包内顶层就是 go/
  rm -f "$zip"

  local g="$TOOLS/go/bin/go.exe"
  [ -x "$g" ] || return 1
  # Go 自带工具链，顺手把用户级 bin 加进 PATH（用 PowerShell 读写注册表原值，
  # 不用 setx —— 后者会截断且不展开 %PATH%）
  add_user_path 'C:\Users\wwwwz\tools\go\bin' >&2
  echo "$g"
}

# ---------------------------------------------------------------- 阶段 2：预编译

phase2() {
  head_ "阶段 2/5：预编译二进制（ProjectDiscovery 全家桶）"

  # 这些都有官方 Windows 预编译包。
  # 不用 go install 源码构建的原因：
  #   katana 需要 CGO + C 编译器；gogo 需要 -tags goregexp；dalfox 已是 Rust 项目。
  #   其余 PD 工具源码构建会拉一大堆依赖，且 nuclei 在 Go 1.27/Windows 上
  #   的构建没有可靠验证过。预编译包是官方推荐路径，也更省时间。
  fetch_release projectdiscovery/subfinder      "*windows_amd64.zip" subfinder
  fetch_release projectdiscovery/httpx          "*windows_amd64.zip" httpx
  fetch_release projectdiscovery/nuclei         "*windows_amd64.zip" nuclei
  fetch_release projectdiscovery/naabu          "*windows_amd64.zip" naabu
  fetch_release projectdiscovery/katana         "*windows_amd64.zip" katana
  fetch_release projectdiscovery/dnsx           "*windows_amd64.zip" dnsx
  fetch_release projectdiscovery/alterx         "*windows_amd64.zip" alterx
  fetch_release projectdiscovery/notify         "*windows_amd64.zip" notify
  fetch_release projectdiscovery/interactsh     "*windows_amd64.zip" interactsh-client
}

# ---------------------------------------------------------------- 阶段 3：其他二进制

phase3() {
  head_ "阶段 3/5：其他预编译工具"

  # 资产名模式都按各仓库实际的 release 资产逐个核对过，不要放宽 ——
  # 放宽会一次匹配多个资产：feroxbuster 会连 debug 版一起下，
  # dalfox 会连 .sha256 校验文件一起下。
  fetch_release ffuf/ffuf        "*windows_amd64.zip"  ffuf
  fetch_release lc/gau           "*windows_amd64.zip"  gau
  fetch_release zan8in/afrog     "*windows_amd64.zip"  afrog
  fetch_release chainreactors/gogo "*windows_amd64.exe" gogo

  # dalfox 已用 Rust 重写，没有 go.mod，只能预编译
  fetch_release hahwul/dalfox    "*windows-x86_64.zip" dalfox

  # Rust 写的
  fetch_release epi052/feroxbuster "*x86_64-windows-feroxbuster*" feroxbuster

  # dirsearch 要求 Python 3.11+（本机 3.8 不够），走目录式预编译包，见上面函数注释。
  install_dirsearch
}

# ---------------------------------------------------------------- 阶段 4：go install 补充

phase4() {
  head_ "阶段 4/5：go install 补充（无预编译包的工具）"

  local G; G=$(go_exe)
  if [ -z "$G" ] || ! "$G" version >/dev/null 2>&1; then
    fail "go 不可用——阶段 1 未成功"
    return
  fi

  # 这些上游要么没发预编译包，要么只有 Linux/macOS 资产，只能 go install。
  # （Go 1.16+ 的 @version 语法会为没有 go.mod 的老仓库合成模块，
  #   所以 assetfinder 这种 GOPATH 时代的仓库也能装）
  #
  # 关于 puredns：**本机装不了，也不打算装**。puredns 本身是 Go 写的，
  # 但它外壳只是个调度器，真正干活的是 massdns —— 那是 C 程序，
  # go install 无效，Windows 也没有官方预编译。泛解析过滤改用
  # `dnsx -wd`（已装），功能等价。
  # 注意 hakrawler 是 hakluke/ 不是 tomnomnom/ —— 作者容易记混，
  # 写错会得到 "Repository not found"（tomnomnom 名下确实没有这个仓库）
  for spec in \
    "github.com/hakluke/hakrawler@latest:hakrawler" \
    "github.com/tomnomnom/assetfinder@latest:assetfinder" \
    "github.com/tomnomnom/waybackurls@latest:waybackurls" \
    "github.com/tomnomnom/anew@latest:anew"
  do
    local mod="${spec%%:*}" name="${spec##*:}"
    if [ -f "$BIN/$name.exe" ]; then skip "$name"; continue; fi
    printf "  ${DIM}go install %s ...${RST}\n" "$mod"
    if "$G" install "$mod" >/dev/null 2>&1; then ok "$name"; else fail "$name (go install $mod)"; fi
  done
}

# ---------------------------------------------------------------- 阶段 5：winget 等其他

phase5() {
  head_ "阶段 5/5：jq / nmap / sqlmap"

  # jq：winget 的 jqlang.jq 在本机实测装不上（先报错，再重跑就 skip 掉了）。
  # 上游 Release 直接发单文件 jq-windows-amd64.exe，用 gh 通道拿更可靠。
  fetch_release jqlang/jq "*windows-amd64.exe" jq

  # 注意：winget 上的 Insecure.Nmap 是 7.80（2019 年），当前版本是 7.99。
  # 这里仍然装，但要知道版本偏老；需要新特性请从 nmap.org 拿官方安装包。
  # 装完落在 C:\Program Files (x86)\Nmap\，winget 会写系统 PATH，但要新开终端才生效 ——
  # 所以这里除了 have nmap，还得直接探路径，否则重跑脚本会重复装一遍。
  if have nmap || [ -x "/c/Program Files (x86)/Nmap/nmap.exe" ]; then
    skip "nmap"
  else
    if winget install --id Insecure.Nmap --exact --accept-package-agreements --accept-source-agreements >/dev/null 2>&1; then
      ok "nmap（版本 7.80，偏老）"
    else
      warn "nmap 安装失败或需要 UAC —— 可从 nmap.org 手动装"
    fi
  fi

  install_sqlmap
}

# sqlmap 没有官方 pip 包，上游推荐 git clone。
#
# 但**本机 git 的 HTTPS 端点会被间歇性封锁**：实测 clone 直接挂死，
# 十几分钟不动，最后只留下一个空 .git 目录。而 gh 的 API 通道是通的
# （同一个 GitHub，走的域名和协议不同）。所以改从 API 拉 tarball。
install_sqlmap() {
  local SM="$TOOLS/sqlmap" TB="$TMP/sqlmap.tar.gz"
  if [ -f "$SM/sqlmap.py" ]; then skip "sqlmap"; return 0; fi

  mkdir -p "$TOOLS" "$TMP"
  rm -rf "$SM"
  # 注意：gh api **没有 --output 参数**（那是 gh release download 的），
  # 它把响应体直接写 stdout，所以要靠重定向落盘。
  if ! "$GH" api repos/sqlmapproject/sqlmap/tarball > "$TB" 2>/dev/null; then
    fail "sqlmap（gh api 拉 tarball 失败）"; return 1
  fi
  local sz; sz=$(stat -c %s "$TB" 2>/dev/null || echo 0)
  if [ "$sz" -lt 1000000 ]; then
    fail "sqlmap（tarball 只有 ${sz} 字节，不像真包）"; rm -f "$TB"; return 1
  fi

  mkdir -p "$SM"
  # GitHub tarball 顶层是 sqlmapproject-sqlmap-<sha>/，--strip-components=1 拍平。
  # Git Bash 自带 GNU tar；万一没有就退回 Windows 的 bsdtar（它同样认这个参数）。
  if ! tar -xzf "$TB" -C "$SM" --strip-components=1 2>/dev/null; then
    if ! /c/Windows/System32/tar.exe -xzf "$(cygpath -w "$TB")" \
           -C "$(cygpath -w "$SM")" --strip-components=1 2>/dev/null; then
      fail "sqlmap（解压失败）"; rm -f "$TB"; return 1
    fi
  fi
  rm -f "$TB"

  if [ ! -f "$SM/sqlmap.py" ]; then fail "sqlmap（解压后没有 sqlmap.py，结构可能变了）"; return 1; fi

  # 放个 PATH 转发器。注意这里写死用 `python` —— bin 里已经没有 python.exe
  # 了（那个是上次 dirsearch 污染事件留下的，已清理），所以能解析到用户真正的 Python。
  printf '@echo off\r\npython "%s\\sqlmap.py" %%*\r\n' 'C:\Users\wwwwz\tools\sqlmap' > "$BIN/sqlmap.cmd"
  ok "sqlmap -> $SM  （PATH 入口：sqlmap）"
}

# ---------------------------------------------------------------- 收尾

templates() {
  head_ "nuclei 模板库"
  local N="$BIN/nuclei.exe"; [ -f "$N" ] || N="$BIN/nuclei"
  if [ -f "$N" ]; then
    echo "  下载模板（约 20-30MB 传输、44MB 解压、14000+ 文件）…"
    if "$N" -update-templates >/dev/null 2>&1; then ok "nuclei-templates"; else fail "nuclei-templates"; fi
  else
    warn "nuclei 未安装，跳过模板更新"
  fi
}

verify() {
  head_ "安装自检"
  local missing=()

  # Go 单独查——它是其余一切的前提，值得先看一眼
  local G; G=$(go_exe)
  if [ -n "$G" ]; then
    printf "  ${GRN}OK${RST}   %-20s %s\n" "go" "$("$G" version 2>&1 | head -1)"
  else
    printf "  ${RED}MISS${RST} %s\n" "go"; missing+=("go")
  fi

  for t in subfinder httpx nuclei naabu katana dnsx alterx notify interactsh-client \
           ffuf gau afrog gogo dalfox feroxbuster dirsearch hakrawler assetfinder \
           waybackurls anew jq nmap; do
    local f="$BIN/$t.exe" c="$BIN/$t.cmd"
    if [ -f "$f" ]; then
      # 不是每个工具都认 --version（hakrawler 就会吐 "flag provided but not defined"），
      # 这种输出当成"装了但探不到版本"，别让它看起来像报错
      local v
      v=$("$f" --version 2>&1 | head -1 | cut -c1-60)
      case "$v" in
        ""|*"not defined"*|*[Uu]sage*) v="（已安装；该工具不支持 --version）" ;;
      esac
      printf "  ${GRN}OK${RST}   %-20s %s\n" "$t" "$v"
    elif [ -f "$c" ]; then
      # .cmd 是转发器（dirsearch）——不探版本，真跑一次要起整个 Python 运行时，太慢
      printf "  ${GRN}OK${RST}   %-20s %s\n" "$t" "$c"
    elif have "$t"; then
      printf "  ${GRN}OK${RST}   %-20s %s\n" "$t" "$(command -v "$t")"
    elif [ -n "$(side_path "$t")" ]; then
      printf "  ${GRN}OK${RST}   %-20s %s（需新终端才在 PATH 里）\n" "$t" "$(side_path "$t")"
    else
      printf "  ${RED}MISS${RST} %s\n" "$t"; missing+=("$t")
    fi
  done

  printf "\n"
  if [ ${#missing[@]} -eq 0 ]; then
    printf "${GRN}全部就绪。${RST}\n"
  else
    printf "${YEL}缺失 %d 个：${RST}%s\n" "${#missing[@]}" "${missing[*]}"
  fi
  if [ ${#FAILED[@]} -gt 0 ]; then
    printf "${RED}失败项：${RST}\n"
    for f in "${FAILED[@]}"; do printf "  - %s\n" "$f"; done
  fi
}

# ---------------------------------------------------------------- main

mkdir -p "$BIN" "$TMP"

if [ $# -eq 0 ]; then
  phase1; phase2; phase3; phase4; phase5; templates; verify
else
  for p in "$@"; do
    case "$p" in
      1) phase1 ;;
      2) phase2 ;;
      3) phase3 ;;
      4) phase4 ;;
      5) phase5 ;;
      t) templates ;;
      v) verify ;;
      *) echo "未知阶段: $p" ;;
    esac
  done
fi
