# leetcode-nvim

力扣（LeetCode 中国站）专用 Neovim 配置，独立于主配置 `~/.config/nvim`（LazyVim），互不影响。

## 安装

**Linux / macOS / WSL**：配置目录就是本仓库，放在 `stdpath("config")` 对应位置：

```sh
git clone <this-repo> ~/.config/leetcode          # NVIM_APPNAME=leetcode 的配置目录
install -Dm755 ~/.config/leetcode/bin/leetcode ~/.local/bin/leetcode
leetcode                                          # 首次启动会自动装插件
```

不想装脚本就写个别名（等价）：

```sh
alias leetcode='NVIM_APPNAME=leetcode nvim leetcode.nvim'
```

**Windows**：配置目录是 `%LOCALAPPDATA%\leetcode`。把仓库放到那里（或做个目录联接），
然后用仓库里的 `leetcode.ps1` 做启动器：

```powershell
# 目录联接（普通用户就能建，仓库就是活配置；不必管理员）
mklink /J "%LOCALAPPDATA%\leetcode" "<仓库路径>"

# 在 $PROFILE 里 dot-source 一次，之后 leetcode 直接启动
. "$env:LOCALAPPDATA\leetcode\leetcode.ps1"
```

两边都是 `NVIM_APPNAME=leetcode`，所以数据目录分别在 `~/.local/share/leetcode`
与 `%LOCALAPPDATA%\leetcode-data`，和主配置（LazyVim）互不影响。

## 使用

```sh
leetcode   # = NVIM_APPNAME=leetcode nvim leetcode.nvim
```

首次使用在面板里选「使用Cookie登录」，粘贴浏览器 F12 → Network → 任意 leetcode.cn 请求
→ Request Headers 里的 `Cookie` 值。（cookie 存在 `stdpath("cache")`，
Linux 是 `~/.cache/leetcode/`，Windows 是 `%LOCALAPPDATA%\Temp\leetcode\`，
换机器时可以拷过去省一次登录。）

## 目录

| 路径 | 说明 |
| --- | --- |
| `~/.config/leetcode` | 本仓库（配置，就是这里） |
| `~/.local/share/leetcode` | 插件、treesitter parser |
| `~/.local/share/leetcode/solutions` | 解答文件（`1.two-sum.cpp` / `1.two-sum.rs`）+ 自动生成的 `.clangd` / `.clang-format` / `.rustfmt.toml` / `lc-stubs.h` / `lc-stubs.rs` / `rust-project.json` |
| `~/.cache/leetcode` | cookie、题库缓存 |

## 快捷键

`<space>l` 是力扣分组。这些映射是**全局**的（面板、题面、控制台任何 buffer 里
which-key 都能看到）：

`l` 主菜单 · `ll` 题库 · `lr` 运行 · `ls` 提交 · `ld` 题面开关 · `lc` 用例/结果面板 ·
`li` 题目信息 · `lu` 切语言（C / C++ / Rust …）· `lt` 已打开题目 · `ly` 每日一题 ·
`lR` 随机一题 · `lo` 浏览器打开 · `lb` 取回上次提交 · `lS` 重置模板 ·
`lj` 重新注入类型桩 · `lq` 退出

LSP：`gd` 定义 · `gr` 引用 · `K` 悬停 · `<space>cr` 重命名 · `<space>ca` 代码操作 ·
`<space>cf` 手动格式化 · `]d`/`[d` 跳诊断 · `<space>cd` 诊断详情浮窗

诊断列表（Trouble，和 LazyVim 一样）：`<space>xx` 全部诊断 · `<space>xX` 当前文件 ·
`<space>xL` 位置列表 · `<space>xQ` Quickfix · `<space>cs` 符号 · `]q`/`[q` 上下一条

Rust 本地检查（clippy 优先）：`<space>lC` 立刻检查 · `<space>lF` 应用当前行的建议

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

## Rust（rust-analyzer）

写 Rust 时用 `<leader>lu` 切语言（会另存为 `xxx.rs`）。想让 Rust 成为默认语言，
把 `lua/plugins/leetcode.lua` 里的 `lang = "cpp"` 改成 `"rust"` 即可。

两个必须的额外工作（否则补全/诊断基本不可用）：

**1. `rust-project.json`（自动生成）**

rust-analyzer 在“散落的单文件”模式下没有项目描述，补全和诊断会很残废
（见 leetcode.nvim issue #86）。本配置会把解答目录里每个 `.rs` 登记成一个 crate root，
写成 `solutions/rust-project.json`（新题目首次打开时自动补上），
这样补全、跳转、诊断就都正常了。

**2. 类型桩注入（和 C++ 同一套思路）**

力扣的 Rust 模板同样把 `TreeNode` / `ListNode` 定义写成注释，而且判题器额外提供
`struct Solution;`，本地 rust-analyzer 看不到这些。`solutions/lc-stubs.rs`
会被自动注入到题目文件顶部的 `// @leet imports` 区（默认折叠、`za` 展开，**不会提交给判题器**）。

> 在配置这份桩之前已经创建的 `.rs` 文件：在窗口里敲 `<leader>lj`（`:Leet inject`）补一次，
> 或者把文件删掉重新开题。

**格式化**：保存时由 rust-analyzer 调 rustfmt，风格读 `solutions/.rustfmt.toml`；
手动格式化是 `<space>cf`。

**本地检查 / clippy（本地就能看到判题器会报什么 + 怎么改）**

rust-analyzer 不是编译器：像 `Option::cloned(...)` 歧义（E0034）、`.cloned()` 不存在（E0599）、
函数忘了写 `Self::`（E0425）这类错它不一定报得出来，于是就出现“本地安静、一提交判题器一堆错”。
而 rust-analyzer 自带的 flycheck（LazyVim / rustaceanvim 里保存时跑 clippy 的那条路）在
“散落单文件 + rust-project.json”下用不了（会报 `no input filename given`）。

所以本配置在**打开 / 保存 `.rs`** 时自己调编译器，用的就是 `cargo clippy` 背后那个东西：

- 有 **clippy-driver** → 用它（`--edition=2021 --crate-type=lib --emit=metadata --error-format=json`），
  于是**报错 + clippy 建议一起出来**（source 显示 `clippy`，带 `clippy::xxx` 编号）
- 没有 clippy → 退回 `rustc`（至少保证报错和判题器一致）

怎么看 / 怎么改：

- `<space>xx` 打开诊断列表（Trouble），每条下面就是 clippy 的 `help: ...`（怎么改）和 `clippy::lint` 编号
- `<space>cd` 看详情浮窗（消息 + `help:` 都在里面）
- 光标停在有建议的那一行按 `<space>lF` 直接应用
  （例如 `nums.len() == 0` → `nums.is_empty()`；有多个建议时会让你选）
- 手动立刻重跑一遍：`<leader>lC`

> 只有 clippy 的 machine-applicable 建议才能一键应用；其余按 `help:` 里的说明手改即可。

> 另外注意：rustc 在类型检查出错后会**停止检查该函数的剩余部分**，所以修完一批错可能又冒出
> 新的（比如 E0382 moved value）——属正常，继续修就行。

**提醒**：力扣中国站并不是每道题都提供 Rust（例如 133 克隆图、138 随机链表的复制就没有）。
`<leader>lu` 的语言列表里能选到的才是当前题目支持的。

## clangd（C / C++）

解答目录里的 `.clangd` 由 `lua/plugins/leetcode.lua` 自动生成，删掉会自动重建：

- `Compiler: g++`：clangd 借 g++ 驱动拿到系统头文件路径，`#include <bits/stdc++.h>` 才不会报错
- `-std=c++20`：判题器若不支持 C++20，改成 `-std=c++17`
- 屏蔽了力扣场景下的噪音警告（模板没写 main、形参用不到、函数体还空着的 return-type 等）

补全/签名提示用 blink.cmp，inlay hints 之类走 clangd 默认能力。

### 类型桩：解决 `Unknown type name 'TreeNode'`

力扣的 C++ 模板把结构体定义放在**块注释**里：

```cpp
/**
 * Definition for a binary tree node.
 * struct TreeNode { ... };
 */
class Solution {
public:
    int maxDepth(TreeNode* root) {   // ← clangd 看不到注释，这里就报 Unknown type name 'TreeNode'
```

链表题是 `ListNode`、克隆图/随机链表是 `Node`、嵌套列表是 `NestedInteger`，套路一样。

本配置用 `solutions/lc-stubs.h`（自动生成）通过 `.clangd` 里的 `-include` 强制喂给 clangd：
只影响本地静态分析，**不进你的解答文件、也不影响判题**（判题器自己带着这些定义）。
已覆盖 `TreeNode` / `ListNode` / `Node` / `NestedInteger` / `Employee`；
碰到别的题目类型，直接往 `lc-stubs.h` 里照着加一个即可。

> 真正的错误不会被屏蔽：类型名写错（比如 `vecotr`）照旧会报错提示。

## 依赖

`nvim`(>=0.10)、`clangd`、`g++`、`tree-sitter-cli`（nvim-treesitter main 分支装 parser 用）、
`git`、`curl`。

- Arch：`sudo pacman -S clang gcc tree-sitter-cli git curl`
- Debian/Ubuntu：`sudo apt install clangd g++ tree-sitter-cli git curl`
- Windows：`scoop install llvm gcc tree-sitter git curl`（或 MSYS2 的 mingw64 工具链）

Rust 需要 rustup 的两个组件：

```
rustup component add rust-analyzer clippy
```

- 缺 `rust-analyzer`：Rust 补全、跳转、诊断全失效（注意 rustup 的 shim 文件依然存在，
  `executable()` 会返回 1，但实际运行会报 `Unknown binary 'rust-analyzer.exe' in official toolchain`）
- 缺 `clippy`：本地检查自动退回 `rustc`，只是没有 clippy 建议
