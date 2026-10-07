-- 自动括号闭合。
--
-- 这份力扣配置是完全独立的（不引 LazyVim），所以 LazyVim 自带的 mini.pairs
-- 在这里并不存在 —— 之前敲 `(` 不会自动出 `()`。这里显式装回来。
--
-- mini.pairs 的行为：几乎总是"做点什么"（补成对、跳过已存在的右括号），
-- 敲 `)` 时如果右边已经是 `)` 就只是移过去；在 `{}` 里按回车会展开成两行。
-- 想去掉某类行为就改 opts，详见 :h MiniPairs.config。
return {
  {
    "echasnovski/mini.pairs",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },
}
