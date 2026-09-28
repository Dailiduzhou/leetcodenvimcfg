# leetcode-nvim

力扣（LeetCode 中国站）专用 Neovim 配置，独立于主配置 `~/.config/nvim`（LazyVim），互不影响。

## 使用

```fish
leetcode   # = NVIM_APPNAME=leetcode nvim leetcode.nvim
```

首次使用在面板里选「使用Cookie登录」，粘贴浏览器 F12 → Network → 任意 leetcode.cn 请求
→ Request Headers 里的 `Cookie` 值。

## 目录

| 路径 | 说明 |
| --- | --- |
| `~/.config/leetcode` | 本仓库（配置，就是这里） |
| `~/.local/share/leetcode` | 插件、treesitter parser |
| `~/.local/share/leetcode/solutions` | 解答文件（如 `1.two-sum.cpp`）和 `.clangd` |
| `~/.cache/leetcode` | cookie、题库缓存 |

## 快捷键

题目窗口里 `<space>l` 是力扣分组（which-key 会列出来）：

`ll` 题库 · `lr` 运行 · `ls` 提交 · `ld` 题面开关 · `lc` 用例/结果面板 · `li` 题目信息 ·
`lu` 切语言 · `lt` 已打开题目 · `ly` 每日一题 · `lR` 随机一题 · `lo` 浏览器打开 ·
`lb` 取回上次提交 · `lS` 重置模板 · `lm` 回主菜单 · `lq` 退出

LSP：`gd` 定义 · `gr` 引用 · `K` 悬停 · `<space>cr` 重命名 · `<space>ca` 代码操作 ·
`<space>cf` 格式化（clangd 自带）· `]d`/`[d` 跳诊断

其它：`<C-s>` 保存 · `<Esc>` 清搜索高亮 · `<space>qq` 退出

## clangd

解答目录里的 `.clangd` 由 `lua/plugins/leetcode.lua` 自动生成，删掉会自动重建：

- `Compiler: g++`：clangd 借 g++ 驱动拿到系统头文件路径，`#include <bits/stdc++.h>` 才不会报错
- `-std=c++20`：判题器若不支持 C++20，改成 `-std=c++17`
- 屏蔽了力扣场景下的噪音警告（没有 main、形参用不到等）

## 依赖

`clangd`、`g++`、`tree-sitter-cli`（nvim-treesitter main 分支装 parser 用）、`git`、`curl`。
