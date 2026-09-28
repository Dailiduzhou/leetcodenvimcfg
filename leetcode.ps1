function global:Start-LeetCode {
    # 新配置：配置目录 = 本仓库（%LOCALAPPDATA%\leetcode 是指向这里的 junction）
    #           数据目录 = %LOCALAPPDATA%\leetcode-data（插件、解答在 solutions）
    $hadAppName = Test-Path Env:NVIM_APPNAME
    $previousAppName = [Environment]::GetEnvironmentVariable('NVIM_APPNAME', 'Process')
    try {
        $env:NVIM_APPNAME = 'leetcode'

        # nvim-treesitter 装/更新 parser 需要 tree-sitter CLI，本机没有独立安装，
        # 用主配置 mason 里已有的那份。追加到 PATH 末尾，避免抢在 scoop 的 clangd 前面
        # （否则 leetcode 用的 clangd 会在 22.1.6 / mason 23.1.0 之间悄悄变化）。
        $masonBin = "$env:LOCALAPPDATA\nvim-data\mason\bin"
        if ((Test-Path $masonBin) -and ($env:PATH -notlike "*$masonBin*")) {
            $env:PATH = "$env:PATH;$masonBin"
        }

        & nvim @args leetcode.nvim
    }
    finally {
        if ($hadAppName) {
            $env:NVIM_APPNAME = $previousAppName
        }
        else {
            Remove-Item Env:NVIM_APPNAME -ErrorAction SilentlyContinue
        }
    }
}

Set-Alias -Name leetcode -Value Start-LeetCode -Scope Global
