return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- 力扣的解答是磁盘上平铺的单文件，没有 compile_commands.json，
      -- 编译参数由解答目录里的 .clangd 提供（lua/plugins/leetcode.lua 会生成/维护它）
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          -- 新版 clangd（>=18）这个参数必须带值，只写参数名会报 invalid value
          "--function-arg-placeholders=true",
          "--fallback-style=LLVM",
        },
        root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt" },
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })
      vim.lsp.enable("clangd")

      vim.diagnostic.config({
        virtual_text = true,
        severity_sort = true,
        float = { border = "rounded" },
      })

      -- 常用 LSP 快捷键（which-key 里显示在 <leader>c 分组下）
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
          end

          map("n", "gd", vim.lsp.buf.definition, "跳转定义")
          map("n", "gr", vim.lsp.buf.references, "查找引用")
          map("n", "K", vim.lsp.buf.hover, "悬停文档")
          map("n", "<leader>cr", vim.lsp.buf.rename, "重命名")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "代码操作")
          map("n", "<leader>cd", vim.diagnostic.open_float, "诊断详情")
          map({ "n", "v" }, "<leader>cf", function()
            vim.lsp.buf.format({ async = true })
          end, "格式化（clangd）")
          map("n", "]d", function()
            vim.diagnostic.jump({ count = 1 })
          end, "下一个诊断")
          map("n", "[d", function()
            vim.diagnostic.jump({ count = -1 })
          end, "上一个诊断")
        end,
      })
    end,
  },

  -- C++ 补全 / 签名提示
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      sources = { default = { "lsp", "buffer", "path" } },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        menu = { draw = { treesitter = { "lsp" } } },
      },
      signature = { enabled = true },
      -- 用纯 Lua 的模糊匹配，省掉下载/编译 Rust 二进制这一步
      fuzzy = { implementation = "lua" },
    },
  },
}
