-- 诊断 / 符号 / 引用 列表（LazyVim 里就是这套 Trouble）。
-- <space>xx 看全部诊断，<space>xX 看当前文件 —— 和 LazyVim 的按键一致。
-- C++：clangd + clang-tidy 的诊断；Rust：rust-analyzer 的诊断 + 保存时跑的 clippy 诊断。
return {
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      modes = {
        lsp = {
          win = { position = "right" },
        },
      },
      -- diagnostics 模式用 Trouble 自带的默认配置（和 LazyVim 一样）：
      -- 列表里会显示 severity 图标 + 消息 + 来源（clangd / clippy / rust-analyzer）+ lint 名字
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "诊断列表（全部）" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "诊断列表（当前文件）" },
      { "<leader>cs", "<cmd>Trouble symbols toggle<cr>", desc = "符号列表" },
      { "<leader>cS", "<cmd>Trouble lsp toggle<cr>", desc = "LSP 引用 / 定义 / …" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "位置列表" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix 列表" },
      {
        "[q",
        function()
          if require("trouble").is_open() then
            require("trouble").prev({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "上一个诊断 / Quickfix",
      },
      {
        "]q",
        function()
          if require("trouble").is_open() then
            require("trouble").next({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "下一个诊断 / Quickfix",
      },
    },
  },
}
