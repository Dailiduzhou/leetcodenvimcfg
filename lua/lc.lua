-- 公共路径（leetcode 插件配置和 lsp 配置都要用）
local M = {}

-- 解答文件目录：力扣的题解平铺在这里，.clangd / .clang-format / lc-stubs.* /
-- rust-project.json / .rustfmt.toml 这些生成物也都放这一层
--
-- 注意：Windows 上 vim.fn.stdpath() 返回反斜杠（C:\Users\...\leetcode-data），
-- 而打开文件时用的路径可能是正斜杠也可能是反斜杠。统一用 vim.fs.normalize
-- （Windows 下会转成正斜杠，并且展开 ~），否则
-- vim.startswith(文件名, M.solutions .. "/") 这类前缀判断会漏掉，
-- 症状就是：保存 .rs 时本地 clippy/编译检查根本不跑。
-- 判断“这个 buffer 是不是解答文件”请用 lc.is_solution()。
M.solutions = vim.fs.normalize(vim.fn.stdpath("data") .. "/solutions")

--- 这个路径是不是解答目录下的文件（两边都先 normalize，兼容正/反斜杠）
---@param path string
---@return boolean
function M.is_solution(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  return vim.startswith(vim.fs.normalize(path), M.solutions .. "/")
end

return M
