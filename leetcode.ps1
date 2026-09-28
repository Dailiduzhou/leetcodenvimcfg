# 兼容用的入口：给老的 $PROFILE 写法留着 ——
#   . "$env:LOCALAPPDATA\leetcode\leetcode.ps1"
# 之后就有 leetcode / Start-LeetCode 命令。
#
# 真正的实现在 bin/leetcode.ps1（和 Linux/macOS 的 bin/leetcode 对称）。
# 新装建议直接用 bin 里的那个（把 <仓库>\bin 加进 PATH），见 README。
. "$PSScriptRoot/bin/leetcode.ps1"

# 万一这个文件被当成脚本执行（而不是 dot-source），把参数转交过去正常启动。
if ($MyInvocation.InvocationName -ne '.') {
    Start-LeetCode @args
}
