-- 力扣本体：中国站 + C/C++ / Rust + 快捷键 + 自动生成的本地分析配置
local LEET_ARG = "leetcode.nvim"
local SOLUTIONS = require("lc").solutions

-- ─────────────────────────────────────────────────────────────────────────────
-- 生成的文件（都在解答目录里，只在不存在时写，删掉会自动重建）
-- ─────────────────────────────────────────────────────────────────────────────

-- clangd 配置：力扣的解答是单文件、没有 compile_commands.json，
-- 关键的是 `Compiler: g++`——clangd 会用 g++ 当驱动去问系统头文件路径，
-- 否则 `#include <bits/stdc++.h>`、libstdc++ 的头文件会全部报红。
local CLANGD_CONFIG = string.format([[
# 由 ~/.config/leetcode/lua/plugins/leetcode.lua 生成
# 文件被删掉的话，下次打开力扣会自动重建；你手动改过的内容不会被覆盖
CompileFlags:
  Compiler: g++
  Add:
    # 力扣判题器若不支持 C++20，把下面这行改成 -std=c++17
    - -std=c++20
    # 力扣的代码本来就是"半成品"（没有 main、形参经常用不到、函数体还空着），这类警告是噪音
    - -Wno-unused-parameter
    - -Wno-unused-variable
    - -Wno-sign-compare
    - -Wno-return-type
    # 强制包含 C++ 类型桩（TreeNode / ListNode / Node 等），
    # 否则力扣把结构体定义放在块注释里，整个文件都会报 Unknown type name
    - -include
    - %s/lc-stubs.h
Completion:
  ArgumentLists: FullPlaceholders
Index:
  # 一堆互不相干的单文件，没必要后台建索引
  Background: Skip
]], SOLUTIONS)

-- clang-format 风格：clangd 内置的格式化器（保存时格式化用的就是它）会读这个文件
local CLANG_FORMAT = [[
# 由 ~/.config/leetcode/lua/plugins/leetcode.lua 生成
# 文件被删掉的话，下次打开力扣会自动重建；你手动改过的内容不会被覆盖
BasedOnStyle: LLVM

# 下面两条按需打开：
# 力扣模板默认是 4 空格缩进
# IndentWidth: 4
# LLVM 默认 80 列换行，嫌太窄可以放宽
# ColumnLimit: 120
]]

-- rustfmt 配置：保存时格式化（走 rust-analyzer）用的就是它
local RUSTFMT_CONFIG = [[
# 由 ~/.config/leetcode/lua/plugins/leetcode.lua 生成
# 文件被删掉的话，下次打开力扣会自动重建；你手动改过的内容不会被覆盖
edition = "2021"
]]

-- C++ 类型桩：只给 clangd 看（.clangd 里 -include 强制包含），
-- 不进解答文件、也不影响判题
local CPP_STUBS = [[
// 力扣本地分析用的类型桩（stub header）
//
// 由 ~/.config/leetcode/lua/plugins/leetcode.lua 生成，删掉会自动重建。
//
// 为什么需要它：
// 力扣的 C++ 模板把 TreeNode / ListNode 这类结构体的定义放在**块注释**里，
//     /**
//      * Definition for a binary tree node.
//      * struct TreeNode { ... };
//      */
// clangd 看不到注释里的代码，所以整个文件都会报 "Unknown type name 'TreeNode'"。
//
// 这个文件通过 .clangd 里的 `-include` 强制喂给 clangd，只用于本地静态分析：
// 不会出现在你的解答文件里，也不影响判题（判题器自己带着这些定义）。
//
// 遇到别的题目类型报 Unknown type name，照着下面加一个即可。

#pragma once

#include <string>
#include <vector>

// 树题：104. 二叉树的最大深度、226. 翻转二叉树 …
struct TreeNode {
    int val;
    TreeNode *left;
    TreeNode *right;
    TreeNode() : val(0), left(nullptr), right(nullptr) {}
    TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
    TreeNode(int x, TreeNode *left, TreeNode *right) : val(x), left(left), right(right) {}
};

// 链表题：2. 两数相加、206. 反转链表 …
struct ListNode {
    int val;
    ListNode *next;
    ListNode() : val(0), next(nullptr) {}
    ListNode(int x) : val(x), next(nullptr) {}
    ListNode(int x, ListNode *next) : val(x), next(next) {}
};

// Node 在力扣里有好几种形状：133. 克隆图用 neighbors、
// 138. 随机链表的复制用 next+random、589. N-ary 树用 children。
// 这里写成"成员全都带上"的宽松版本，避免换个题就报 No member named ...
struct Node {
    int val = 0;
    Node *next = nullptr;
    Node *random = nullptr;
    Node *left = nullptr;
    Node *right = nullptr;
    Node *child = nullptr;
    std::vector<Node *> neighbors;
    std::vector<Node *> children;

    Node() = default;
    Node(int v) : val(v) {}
    Node(int v, std::vector<Node *> kids) : val(v), neighbors(kids), children(kids) {}
};

// 341. 扁平化嵌套列表迭代器、339. 嵌套列表权重和
class NestedInteger {
public:
    bool isInteger() const;
    int getInteger() const;
    void setInteger(int value);
    void add(const NestedInteger &ni);
    const std::vector<NestedInteger> &getList() const;
};

// 690. 员工的重要性
class Employee {
public:
    int id = 0;
    int importance = 0;
    std::vector<int> subordinates;
};
]]

-- Rust 类型桩：力扣的 Rust 模板同样把 struct 定义写成注释，
-- 而且判题器会额外提供 `struct Solution;`，本地 rust-analyzer 都看不到。
-- 这份内容会被 leetcode.nvim 注入到题目文件顶部的 @leet imports 区（不会提交给判题器）。
local RUST_STUBS = [[
// 力扣本地分析用的类型桩（由 leetcode.nvim 注入，不会提交给判题器）
//
// 力扣的 Rust 模板把 struct 定义写成注释（TreeNode / ListNode），
// 判题器另外还会提供 `struct Solution;`，本地 rust-analyzer 看不到这些，
// 于是整个文件都会报 cannot find type ...
//
// 用全限定路径（std::rc::Rc 等）而不是 use，避免和题目模板自带的 use 重复导入。
// 需要别的类型（比如 Node / NestedInteger）就照抄力扣模板里注释掉的定义往下加。

#![allow(dead_code, unused_imports, unused_variables, unused_mut)]

pub struct Solution;

#[derive(Debug, PartialEq, Eq)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<std::rc::Rc<std::cell::RefCell<TreeNode>>>,
    pub right: Option<std::rc::Rc<std::cell::RefCell<TreeNode>>>,
}

impl TreeNode {
    #[inline]
    pub fn new(val: i32) -> Self {
        TreeNode { val, left: None, right: None }
    }
}

#[derive(PartialEq, Eq, Clone, Debug)]
pub struct ListNode {
    pub val: i32,
    pub next: Option<Box<ListNode>>,
}

impl ListNode {
    #[inline]
    pub fn new(val: i32) -> Self {
        ListNode { next: None, val }
    }
}
]]

--- 文件不存在才写（已存在就不动，方便你自己改）
local function ensure_file(path, content)
  if vim.uv.fs_stat(path) then
    return
  end
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(vim.split(content, "\n"), path)
end

--- 力扣快捷键。
--- 设成全局映射（而不是只挂在题目 buffer 上），
--- 这样在面板、题面、控制台任何 buffer 里 which-key 的 <leader>l 分组都看得到。
local function setup_keymaps()
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
  end

  map("<leader>l", "<cmd>Leet<cr>", "力扣主菜单")
  map("<leader>ll", "<cmd>Leet list<cr>", "题库列表")
  map("<leader>lr", "<cmd>Leet run<cr>", "运行（测试用例）")
  map("<leader>ls", "<cmd>Leet submit<cr>", "提交")
  map("<leader>ld", "<cmd>Leet desc<cr>", "题目描述 显示/隐藏")
  map("<leader>lc", "<cmd>Leet console<cr>", "测试用例 / 结果面板")
  map("<leader>li", "<cmd>Leet info<cr>", "题目信息（通过率、标签等）")
  map("<leader>lu", "<cmd>Leet lang<cr>", "切换语言（C / C++ / Rust …）")
  map("<leader>lt", "<cmd>Leet tabs<cr>", "已打开的题目")
  map("<leader>ly", "<cmd>Leet daily<cr>", "每日一题")
  map("<leader>lR", "<cmd>Leet random<cr>", "随机一题")
  map("<leader>lo", "<cmd>Leet open<cr>", "在浏览器里打开")
  map("<leader>lb", "<cmd>Leet last_submit<cr>", "取回上次提交的代码")
  map("<leader>lS", "<cmd>Leet reset<cr>", "重置为默认代码模板")
  map("<leader>lj", "<cmd>Leet inject<cr>", "重新注入类型桩（老文件缺桩时用）")
  map("<leader>lq", "<cmd>Leet exit<cr>", "退出力扣")
end

return {
  "kawre/leetcode.nvim",

  -- 只有 `nvim leetcode.nvim` 或 `:Leet` 时才加载
  lazy = vim.fn.argv(0, -1) ~= LEET_ARG,
  cmd = "Leet",

  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
  },

  -- 启动就注册好：快捷键 + 各种本地分析配置
  -- （放在 init 而不是 config，这样即使插件因为某些原因没加载，clangd/rust-analyzer 也是好的）
  init = function()
    setup_keymaps()
    ensure_file(SOLUTIONS .. "/.clangd", CLANGD_CONFIG)
    ensure_file(SOLUTIONS .. "/.clang-format", CLANG_FORMAT)
    ensure_file(SOLUTIONS .. "/.rustfmt.toml", RUSTFMT_CONFIG)
    ensure_file(SOLUTIONS .. "/lc-stubs.h", CPP_STUBS)
    ensure_file(SOLUTIONS .. "/lc-stubs.rs", RUST_STUBS)
  end,

  opts = {
    arg = LEET_ARG,

    -- 默认 C++；写 C 用 <leader>lu 切，写 Rust 也用它切（会另存为 1.two-sum.rs）
    lang = "cpp",

    -- 力扣中国站
    cn = {
      enabled = true,
      translator = true, -- 插件界面的中文（内置词典，不走网络）
      translate_problems = true, -- 题面用中文（中国站 content 是英文，translatedContent 才是中文）
    },

    storage = {
      home = SOLUTIONS,
      cache = vim.fn.stdpath("cache"),
    },

    picker = { provider = "telescope" },

    editor = {
      reset_previous_code = false, -- 重开做过的题时不要用模板覆盖上次的代码
      -- 折叠 @leet imports 区（C++ 是 include，Rust 是那一堆类型桩），
      -- 让解答文件顶部保持干净；按 za 可以展开看
      fold_imports = true,
    },

    -- Rust：把类型桩注入到题目文件顶部的 imports 区（不会提交）
    injector = {
      rust = {
        imports = function()
          local ok, lines = pcall(vim.fn.readfile, SOLUTIONS .. "/lc-stubs.rs")
          return ok and lines or {}
        end,
      },
    },
  },
}
