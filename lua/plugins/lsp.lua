local SOLUTIONS = require("lc").solutions

--- rust-analyzer 在"散落单文件"模式下没有项目描述，补全/诊断基本不可用
--- （见 leetcode.nvim issue #86）。这里生成一份 rust-project.json，
--- 把解答目录里每个 .rs 都登记成一个 crate root。
--- 内容有变化才写，避免 rust-analyzer 反复 reload。
local function ensure_rust_project()
  local files = vim.fn.globpath(SOLUTIONS, "*.rs", false, true)
  if #files == 0 then
    return
  end
  -- lc-stubs.rs 是注入用的类型桩，不是题目解答，不要当成 crate
  files = vim.tbl_filter(function(f)
    return vim.fn.fnamemodify(f, ":t") ~= "lc-stubs.rs"
  end, files)
  table.sort(files)
  if #files == 0 then
    return
  end

  local crates = {}
  for _, f in ipairs(files) do
    crates[#crates + 1] = { root_module = f, edition = "2021", deps = {} }
  end

  local sysroot = vim.fn.system({ "rustc", "--print", "sysroot" }):gsub("%s+$", "")
  local library = sysroot .. "/lib/rustlib/src/rust/library"

  local project = { crates = crates }
  if vim.fn.isdirectory(library) == 1 then
    project.sysroot_src = library -- 需要 rust-src 组件；没装就不写这一项
  end

  local path = SOLUTIONS .. "/rust-project.json"
  local content = vim.json.encode(project)
  local ok, old = pcall(vim.fn.readfile, path)
  if not ok or table.concat(old, "") ~= content then
    vim.fn.writefile({ content }, path)
  end
end

--- 用 clangd / rust-analyzer 格式化（只有这两个客户端参与）
---@param bufnr? integer
---@param async? boolean
local function format(bufnr, async)
  -- 注意：nvim 0.11+ 的 lspconfig 里 rust-analyzer 的 server 名是 rust_analyzer（下划线）
  local enabled = { clangd = true, rust_analyzer = true }
  local attached = false
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if enabled[c.name] then
      attached = true
    end
  end
  if not attached then
    return
  end

  vim.lsp.buf.format({
    bufnr = bufnr,
    async = async ~= false,
    timeout_ms = 3000,
    filter = function(client)
      return enabled[client.name] == true
    end,
  })
end

--- 本地 rustc 编译检查。
--- rust-analyzer 不是编译器：像 `Option::cloned(...)` 歧义、`.cloned()` 不存在、
--- 函数没导入这类错误它不一定报，结果就是本地安静、一提交判题器一堆错。
--- 所以这里直接调 rustc 编译一遍，诊断格式和判题器基本一致。
local rustc_ns = vim.api.nvim_create_namespace("leetcode_rustc")

---@param bufnr integer
local function rustc_check(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if not vim.startswith(file, SOLUTIONS .. "/") or vim.fn.filereadable(file) == 0 then
    return
  end

  local outdir = vim.fn.stdpath("cache") .. "/rustc-check"
  vim.fn.mkdir(outdir, "p")

  vim.system({
    "rustc",
    "--edition=2021",
    "--crate-type=lib", -- 单文件解答没有 main，按 lib 编译
    "--emit=metadata",
    "--error-format=json",
    "--out-dir",
    outdir,
    file,
  }, { text = true }, function(out)
    local diagnostics = {}
    -- 注意：rustc 的诊断输出在 **stderr**（不是 stdout）
    for line in vim.gsplit((out.stderr or "") .. (out.stdout or ""), "\n", { trimempty = true }) do
      local ok, msg = pcall(vim.json.decode, line)
      if ok and type(msg) == "table" and msg["$message_type"] == "diagnostic" and msg.level == "error" then
        local span = nil
        for _, s in ipairs(msg.spans or {}) do
          if s.is_primary and s.file_name == file then
            span = s
            break
          end
        end
        if span then
          local start_line, start_col = span.line_start or 1, span.column_start or 1
          diagnostics[#diagnostics + 1] = {
            lnum = start_line - 1,
            col = start_col - 1,
            end_lnum = (span.line_end or start_line) - 1,
            end_col = (span.column_end or start_col) - 1,
            severity = vim.diagnostic.severity.ERROR,
            message = msg.message .. ((msg.code and msg.code.code) and (" [" .. msg.code.code .. "]") or ""),
            source = "rustc",
          }
        end
      end
    end

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.diagnostic.set(rustc_ns, bufnr, diagnostics)
      end
    end)
  end)
end

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- ── C / C++：clangd ────────────────────────────────────────────────────
      -- 力扣的解答是磁盘上平铺的单文件，没有 compile_commands.json，
      -- 编译参数由解答目录里的 .clangd 提供（lua/plugins/leetcode.lua 生成/维护）
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

      -- ── Rust：rust-analyzer ───────────────────────────────────────────────
      -- 名字是 rust_analyzer（下划线），不是 rust-analyzer，写错会报 "cmd got nil"
      ensure_rust_project()
      vim.lsp.config("rust_analyzer", {
        -- 解答目录本身就是"工作区根"，rust-project.json 就在里面
        root_dir = SOLUTIONS,
        capabilities = require("blink.cmp").get_lsp_capabilities(),
        settings = {
          ["rust-analyzer"] = {
            -- 这里**不开** rust-analyzer 自带的 flycheck：rust-project.json 是非 Cargo 工程，
            -- flycheck 跑不起来（会报 "no input filename given"）。
            -- 编译级检查用下面的 rustc_check（保存时直接调 rustc，和判题器同一套诊断）。
            checkOnSave = false,
            -- 明确指向生成的工程描述（每个 .rs 各自是一个 crate root）
            linkedProjects = { SOLUTIONS .. "/rust-project.json" },
            diagnostics = { enable = true, experimental = { enable = false } },
          },
        },
      })
      vim.lsp.enable("rust_analyzer")

      -- 新题目会新建 .rs，把新 crate 登记进去（内容变了 rust-analyzer 会自己 reload）
      vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPre" }, {
        pattern = "*.rs",
        callback = function()
          if vim.startswith(vim.api.nvim_buf_get_name(0), SOLUTIONS .. "/") then
            ensure_rust_project()
          end
        end,
      })

      -- 保存 .rs 时就跑一次 rustc 检查（和判题器同一套诊断）
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*.rs",
        callback = function(args)
          rustc_check(args.buf)
        end,
      })

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
            format(ev.buf)
          end, "格式化（clangd / rust-analyzer）")
          map("n", "]d", function()
            vim.diagnostic.jump({ count = 1 })
          end, "下一个诊断")
          map("n", "[d", function()
            vim.diagnostic.jump({ count = -1 })
          end, "上一个诊断")

          if vim.bo[ev.buf].filetype == "rust" then
            -- 打开就先查一次，然后保存时自动查
            map("n", "<leader>lC", function()
              rustc_check(ev.buf)
            end, "本地 rustc 编译检查")
            rustc_check(ev.buf)
          end

          -- 保存时自动格式化：
          --   C/C++ → clangd 内置 clang-format，风格读 .clang-format（LLVM）
          --   Rust  → rust-analyzer 调 rustfmt，风格读 .rustfmt.toml
          -- 不想要自动格式化就删掉这个 autocmd。
          if vim.tbl_contains({ "c", "cpp", "rust" }, vim.bo[ev.buf].filetype) then
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = ev.buf,
              group = vim.api.nvim_create_augroup("leetcode_format_on_save", { clear = false }),
              desc = "保存时自动格式化",
              callback = function(args)
                format(args.buf, false)
              end,
            })
          end
        end,
      })
    end,
  },

  -- C++ / Rust 补全、签名提示
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      -- 按键：blink 的 `default` preset 里**没有 Enter 接受**（只给了 <C-y>），
      -- 所以之前菜单能弹出来、Tab/Enter 却都没反应。这里用你主配置（LazyVim）同款的
      -- `enter` preset（Enter 接受），并额外让 Tab/Shift-Tab 能移动选中项，
      -- 菜单没开时 fallback 回普通 Tab（缩进）/snippet 跳位。
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<C-y>"] = { "select_and_accept", "fallback" },
      },
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
