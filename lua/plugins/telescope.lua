return {
  -- leetcode.nvim 的题库/题目选择器用它
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("telescope").setup({})
    end,
  },
}
