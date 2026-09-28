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
| `~/.local/share/leetcode/solutions` | 解答文件（如 `1.two-sum.cpp`）+ `.clangd` / `.clang-format`（自动生成） |
| `~/.cache/leetcode` | cookie、题库缓存 |

## 快捷键

`<space>l` 是力扣分组。这些映射是**全局**的（面板、题面、控制台任何 buffer 里
which-key 都能看到）：

`l` 主菜单 · `ll` 题库 · `lr` 运行 · `ls` 提交 · `ld` 题面开关 · `lc` 用例/结果面板 ·
`li` 题目信息 · `lu` 切语言 · `lt` 已打开题目 · `ly` 每日一题 · `lR` 随机一题 ·
`lo` 浏览器打开 · `lb` 取回上次提交 · `lS` 重置模板 · `lq` 退出

LSP：`gd` 定义 · `gr` 引用 · `K` 悬停 · `<space>cr` 重命名 · `<space>ca` 代码操作 ·
`<space>cf` 手动格式化 · `]d`/`[d` 跳诊断

其它：`<C-s>` 保存 · `<Esc>` 清搜索高亮 · `<space>qq` 退出

## 格式化（保存自动，LLVM 风格）

保存时由 clangd 内置的 clang-format 自动格式化，风格读解答目录里的 `.clang-format`
（`BasedOnStyle: LLVM`，自动生成，删掉会重建）。手动格式化是 `<space>cf`。

想调风格就改 `~/.local/share/leetcode/solutions/.clang-format`，比如：

```yaml
BasedOnStyle: LLVM
IndentWidth: 4    # 力扣模板默认 4 空格缩进
ColumnLimit: 120  # LLVM 默认 80 列换行，嫌窄就放宽
```

不想要“保存自动格式化”：删掉 `lua/plugins/lsp.lua` 里那个 `BufWritePre` autocmd 即可。

## clangd

解答目录里的 `.clangd` 由 `lua/plugins/leetcode.lua` 自动生成，删掉会自动重建：

- `Compiler: g++`：clangd 借 g++ 驱动拿到系统头文件路径，`#include <bits/stdc++.h>` 才不会报错
- `-std=c++20`：判题器若不支持 C++20，改成 `-std=c++17`
- 屏蔽了力扣场景下的噪音警告（模板没写 main、形参用不到、函数体还空着的 return-type 等）

补全/签名提示用 blink.cmp，inlay hints 之类走 clangd 默认能力。

## 依赖

`clangd`、`g++`、`tree-sitter-cli`（nvim-treesitter main 分支装 parser 用）、`git`、`curl`。
