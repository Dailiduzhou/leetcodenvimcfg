-- 力扣本体：中国站 + C/C++ + 快捷键 + clangd / clang-format 配置
local LEET_ARG = "leetcode.nvim"

-- 解答文件存放目录（.clangd / .clang-format 也放在这一层）
local SOLUTIONS = vim.fn.stdpath("data") .. "/solutions"

-- clangd 配置：力扣的解答是单文件、没有 compile_commands.json，
-- 关键的是 `Compiler: g++`——clangd 会用 g++ 当驱动去问系统头文件路径，
-- 否则 `#include <bits/stdc++.h>`、libstdc++ 的头文件会全部报红。
local CLANGD_CONFIG = [[
# 由 ~/.config/leetcode/lua/plugins/leetcode.lua 生成
# 文件被删掉的话，下次打开力扣会自动重建；你手动改过的内容不会被覆盖
CompileFlags:
  Compiler: g++
  Add:
    # 力扣判题器若不支持 C++20，把下面这行改成 -std=c++17
    - -std=c++20
    # 力扣的代码本来就是"半成品"（没有 main、形参经常用不到、函数体还空着），这类警告是噪音
    - -Wno-unused-parameter
    - -Wno-unused-variable
    - -Wno-sign-compare
    - -Wno-return-type
Completion:
  ArgumentLists: FullPlaceholders
Index:
  # 一堆互不相干的单文件，没必要后台建索引
  Background: Skip
]]

-- clang-format 风格：clangd 内置的格式化器（保存时格式化用的就是它）会读这个文件
local CLANG_FORMAT = [[
# 由 ~/.config/leetcode/lua/plugins/leetcode.lua 生成
# 文件被删掉的话，下次打开力扣会自动重建；你手动改过的内容不会被覆盖
BasedOnStyle: LLVM

# 下面两条按需打开：
# 力扣模板默认是 4 空格缩进
# IndentWidth: 4
# LLVM 默认 80 列换行，嫌太窄可以放宽
# ColumnLimit: 120
]]

--- 文件不存在才写（已存在就不动，方便你自己改）
local function ensure_file(path, content)
  if vim.uv.fs_stat(path) then
    return
  end
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(vim.split(content, "\n"), path)
end

--- 力扣快捷键。
--- 设成全局映射（而不是只挂在题目 buffer 上），
--- 这样在面板、题面、控制台任何 buffer 里 which-key 的 <leader>l 分组都看得到。
local function setup_keymaps()
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
  end

  map("<leader>l", "<cmd>Leet<cr>", "力扣主菜单")
  map("<leader>ll", "<cmd>Leet list<cr>", "题库列表")
  map("<leader>lr", "<cmd>Leet run<cr>", "运行（测试用例）")
  map("<leader>ls", "<cmd>Leet submit<cr>", "提交")
  map("<leader>ld", "<cmd>Leet desc<cr>", "题目描述 显示/隐藏")
  map("<leader>lc", "<cmd>Leet console<cr>", "测试用例 / 结果面板")
  map("<leader>li", "<cmd>Leet info<cr>", "题目信息（通过率、标签等）")
  map("<leader>lu", "<cmd>Leet lang<cr>", "切换语言（C / C++ / …）")
  map("<leader>lt", "<cmd>Leet tabs<cr>", "已打开的题目")
  map("<leader>ly", "<cmd>Leet daily<cr>", "每日一题")
  map("<leader>lR", "<cmd>Leet random<cr>", "随机一题")
  map("<leader>lo", "<cmd>Leet open<cr>", "在浏览器里打开")
  map("<leader>lb", "<cmd>Leet last_submit<cr>", "取回上次提交的代码")
  map("<leader>lS", "<cmd>Leet reset<cr>", "重置为默认代码模板")
  map("<leader>lq", "<cmd>Leet exit<cr>", "退出力扣")
end

return {
  "kawre/leetcode.nvim",

  -- 只有 `nvim leetcode.nvim` 或 `:Leet` 时才加载
  lazy = vim.fn.argv(0, -1) ~= LEET_ARG,
  cmd = "Leet",

  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
  },

  -- 启动就注册好：快捷键 + clangd / clang-format 配置
  -- （放在 init 而不是 config，这样即使插件因为某些原因没加载，clangd 也是好的）
  init = function()
    setup_keymaps()
    ensure_file(SOLUTIONS .. "/.clangd", CLANGD_CONFIG)
    ensure_file(SOLUTIONS .. "/.clang-format", CLANG_FORMAT)
  end,

  opts = {
    arg = LEET_ARG,

    -- 默认 C++；写 C 用 <leader>lu 切（会另存为 1.two-sum.c）
    lang = "cpp",

    -- 力扣中国站
    cn = {
      enabled = true,
      translator = true, -- 插件界面的中文（内置词典，不走网络）
      translate_problems = true, -- 题面用中文（中国站 content 是英文，translatedContent 才是中文）
    },

    storage = {
      home = SOLUTIONS,
      cache = vim.fn.stdpath("cache"),
    },

    picker = { provider = "telescope" },

    editor = {
      reset_previous_code = false, -- 重开做过的题时不要用模板覆盖上次的代码
      fold_imports = false, -- 不要把 #include 折起来
    },
  },
}
