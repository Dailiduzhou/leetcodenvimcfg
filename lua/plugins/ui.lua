return {
  -- 主题，和主配置保持一致
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        integrations = {
          treesitter = true,
          native_lsp = { enabled = true },
          which_key = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- 图标（telescope / 补全菜单用）
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- which-key：所有快捷键按 desc 分组弹出
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "classic",
      delay = 200,
    },
    config = function(_, opts)
      require("which-key").setup(opts)
      -- 分组名字（<leader>l 是题目窗口里的力扣按键，<leader>c 是 LSP 相关）
      require("which-key").add({
        { "<leader>l", group = "leetcode" },
        { "<leader>c", group = "code" },
        { "<leader>q", group = "quit" },
      })
    end,
  },

  -- 状态栏（显示模式、文件名、diagnostics、行列）
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        section_separators = "",
        component_separators = "|",
        globalstatus = false,
      },
    },
  },
}
