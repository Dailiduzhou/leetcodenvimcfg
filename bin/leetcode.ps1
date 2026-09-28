# LeetCode 专用 Neovim 启动器（Windows / PowerShell）
#
# 和 Linux / macOS / WSL 的 bin/leetcode **行为一致**：
#   1. NVIM_APPNAME=leetcode
#   2. 确保 nvim 的配置目录真的指向本仓库（默认 %LOCALAPPDATA%\leetcode；
#      设了 XDG_CONFIG_HOME 就用它，nvim 也认这个变量）：
#        * 不存在 → 自动建一个目录联接（junction，普通用户即可，不需要管理员）
#        * 指向别处 → 只警告、不覆盖（否则会悄悄用别人的配置，看起来就像本仓库没生效）
#   3. nvim <你给的参数...> leetcode.nvim
#      （最后一个参数固定是 leetcode.nvim，插件靠它判断自己处于刷题模式）
#
# 用法（两种等价，推荐 A）：
#   A) 当命令用（和 Linux 一样）：把 <仓库>\bin 加进 PATH，然后
#        leetcode
#        leetcode -c "set nu"        # 额外参数写在前面，和 Linux 端一致
#      PATH 只需加一次，例如写进 $PROFILE：
#        $env:PATH = "$env:LOCALAPPDATA\leetcode\bin;$env:PATH"
#   B) 老用法（profile 里 dot-source，之后 leetcode 也是命令）：
#        . "$env:LOCALAPPDATA\leetcode\leetcode.ps1"
#
# 环境变量：
#   LEETCODE_SKIP_MASON=1   不把主配置（LazyVim）mason 里的 bin 追加进 PATH
#
# 依赖：nvim(>=0.10)、git、clangd、g++、tree-sitter-cli、curl；Rust 另需 rustup 组件。

# 本仓库根目录：bin/leetcode.ps1 → 仓库根。定义期就算好并被下面的闭包捕获，
# 这样即使命令是之后（交互式）才被调用，也不依赖 $PSScriptRoot / 当前目录。
$LeetCodeRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

# 真正的启动逻辑。用 .GetNewClosure() 捕获 $LeetCodeRepo，做成自包含脚本块，
# 既可以直接执行（& $launch @args），也可以注册成全局函数（dot-source 用法）。
$LeetCodeLaunch = {
    if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
        throw 'leetcode: 找不到 nvim。请先安装 Neovim (>=0.10) 并加入 PATH。'
    }

    $hadAppName = Test-Path Env:NVIM_APPNAME
    $prevAppName = [Environment]::GetEnvironmentVariable('NVIM_APPNAME', 'Process')

    try {
        $env:NVIM_APPNAME = 'leetcode'

        # ── 配置目录：保证 nvim 读到的就是本仓库 ──────────────────────────
        # 算法和 nvim 的 stdpath("config") 一致：XDG_CONFIG_HOME 优先，否则 %LOCALAPPDATA%
        $cfgRoot = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { $env:LOCALAPPDATA }
        $cfg = Join-Path $cfgRoot 'leetcode'

        # 把路径末尾的 junction / 符号链接展开成真实路径再比较。
        # 必须这样做：从 %LOCALAPPDATA%\leetcode 这个 junction 里启动时，
        # $LeetCodeRepo 本身就是那条 junction 路径，不展开就会拿“链接”去和
        # “链接指向的真实目录”比，永远不等 → 误报。
        $realPath = {
            param([string]$Path)
            $p = [IO.Path]::GetFullPath($Path)
            $it = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if ($it -and $it.LinkType) {
                $t = @($it.Target)[0]
                if ($t) {
                    if (-not [IO.Path]::IsPathRooted($t)) { $t = Join-Path (Split-Path -Parent $p) $t }
                    $p = [IO.Path]::GetFullPath($t)
                }
            }
            return $p.TrimEnd('\', '/')
        }

        $repo = & $realPath $LeetCodeRepo
        $item = Get-Item -LiteralPath $cfg -Force -ErrorAction SilentlyContinue
        if (-not $item) {
            $parent = Split-Path -Parent $cfg
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            New-Item -ItemType Junction -Path $cfg -Target $repo | Out-Null
            Write-Host "leetcode: 已把 $cfg 链接到 $repo" -ForegroundColor DarkGray
        }
        elseif ((& $realPath $cfg) -ine $repo) {
            Write-Warning @"
leetcode: 配置目录不是本仓库：
  nvim 会用      $cfg
  本仓库在       $repo
  也就是说本仓库的配置不会生效。想用它：删掉/改名上面那个目录（或把它改成指向本仓库的
  junction），或者直接运行 $repo\bin\leetcode.ps1
"@
        }

        # ── 主配置（LazyVim）mason 里的 tree-sitter CLI：本机没单独装就用它 ──
        # 追加到 PATH 末尾，避免抢在系统 clangd 前面（否则 leetcode 用的 clangd 会变）。
        if (-not $env:LEETCODE_SKIP_MASON) {
            $masonBin = Join-Path $env:LOCALAPPDATA 'nvim-data\mason\bin'
            if ((Test-Path -LiteralPath $masonBin) -and ($env:PATH -notlike "*$masonBin*")) {
                $env:PATH = "$env:PATH;$masonBin"
            }
        }

        & nvim @args leetcode.nvim
    }
    finally {
        if ($hadAppName) {
            $env:NVIM_APPNAME = $prevAppName
        }
        else {
            Remove-Item Env:NVIM_APPNAME -ErrorAction SilentlyContinue
        }
    }
}.GetNewClosure()

if ($MyInvocation.InvocationName -eq '.') {
    # 被 dot-source（例如 $PROFILE 里的 . "...\leetcode.ps1"）：只注册命令，不启动。
    New-Item -Path Function:global:Start-LeetCode -Value $LeetCodeLaunch -Force | Out-Null
    Set-Alias -Name leetcode -Value Start-LeetCode -Scope Global -Force
}
else {
    # 被当成命令执行（PATH 里的 leetcode / .\bin\leetcode.ps1）：直接启动。
    & $LeetCodeLaunch @args
}
