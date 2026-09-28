-- 力扣（LeetCode 中国站）专用 Neovim —— 完全独立于 ~/.config/nvim（LazyVim）
--
-- 启动：终端执行 `leetcode`
--   = NVIM_APPNAME=leetcode nvim leetcode.nvim
--
-- 目录：
--   config      ~/.config/leetcode
--   插件/数据   ~/.local/share/leetcode
--   解答文件    ~/.local/share/leetcode/solutions（.clangd 也在这一层）
--   会话/缓存   ~/.local/state/leetcode、~/.cache/leetcode
--
-- 这里只装力扣用得上的一套东西：启动快，也和主配置互不影响。

local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 200
opt.timeoutlen = 300
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.scrolloff = 4
opt.confirm = true
opt.wrap = false
opt.completeopt = "menu,menuone,noselect" -- blink.cmp 要求 noselect

-- 快捷键（题目窗口里的力扣按键见 lua/plugins/leetcode.lua）
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "保存解答" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "清除搜索高亮" })
vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "退出" })

-- lazy.nvim 引导
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "无法克隆 lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\n按任意键退出...", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = { enabled = false }, -- 专用环境，不需要自动查更新
  change_detection = { notify = false },
})
