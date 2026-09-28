return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- 这个插件不支持懒加载

    -- 力扣题面是 HTML：html parser 用来把题目描述渲染成可读文本（没有的话会退化成原始 HTML）
    -- cpp / c 用来给解答上语法高亮
    build = function()
      require("nvim-treesitter").install({ "html", "cpp", "c" }):wait(600000)
    end,

    config = function()
      -- main 分支不会自动开 treesitter，需要自己挂 FileType
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },
}
