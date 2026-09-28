-- 公共路径（leetcode 插件配置和 lsp 配置都要用）
local M = {}

-- 解答文件目录：力扣的题解平铺在这里，.clangd / .clang-format / lc-stubs.* /
-- rust-project.json / .rustfmt.toml 这些生成物也都放这一层
M.solutions = vim.fn.stdpath("data") .. "/solutions"

return M
