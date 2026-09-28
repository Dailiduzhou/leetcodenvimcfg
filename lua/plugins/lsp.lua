local lc = require("lc")
local SOLUTIONS = lc.solutions
--- 这个 buffer 是不是解答目录里的文件（兼容正/反斜杠）
local function is_solution(bufnr_or_path)
  local path = type(bufnr_or_path) == "number" and vim.api.nvim_buf_get_name(bufnr_or_path) or bufnr_or_path
  return lc.is_solution(path)
end

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

--- 本地编译 / clippy 检查。
---
--- rust-analyzer 不是编译器：像 `Option::cloned(...)` 歧义、`.cloned()` 不存在、
--- 函数没导入这类错误它不一定报，结果就是本地安静、一提交判题器一堆错。
--- 而 rust-analyzer 自带的 flycheck（LazyVim / rustaceanvim 里保存时跑 clippy 的那条路）
--- 在“散落单文件 + rust-project.json”下用不了（会报 "no input filename given"），
--- 所以这里自己调编译器，用的就是 `cargo clippy` 背后那个东西：
---   优先 clippy-driver —— 报错和 clippy 建议一起出来（= LazyVim 里保存时的效果）
---   没有 clippy 就退回 rustc —— 至少保证报错和判题器一致
--- 结果通过 vim.diagnostic 发布，所以 <leader>xx / <leader>xX（Trouble）能直接看到。
local rust_ns = vim.api.nvim_create_namespace("leetcode_rust_check")

--- clippy-driver 在就用它，否则 rustc
local function rust_tool()
  return vim.fn.executable("clippy-driver") == 1 and "clippy-driver" or "rustc"
end

--- 把一条 rustc/clippy JSON 诊断转成 nvim 诊断：
---   * 消息里带上 help/note —— clippy 的“怎么改”就在 help 里
---   * 收集 machine-applicable 建议（span + suggested_replacement），
---     之后可以用 <leader>lF 一键应用
---@param json_lines string[]
---@param file string
---@param tool string
---@return vim.Diagnostic[]
local function parse_rust_diagnostics(json_lines, file, tool)
  local diagnostics = {}

  for _, line in ipairs(json_lines) do
    local ok, msg = pcall(vim.json.decode, line)
    if ok and type(msg) == "table" and msg["$message_type"] == "diagnostic" then
      -- 末尾那条 "N warnings emitted" 汇总没有 span，跳过
      local span
      for _, s in ipairs(msg.spans or {}) do
        if s.is_primary and s.file_name == file then
          span = s
          break
        end
      end
      if not span then
        for _, s in ipairs(msg.spans or {}) do
          if s.file_name == file then
            span = s
            break
          end
        end
      end

      if span then
        local code = msg.code
        if type(code) == "table" then
          code = code.code
        end

        local parts = { msg.message }
        local fixes = {}
        for _, child in ipairs(msg.children or {}) do
          local child_msg = type(child.message) == "string" and child.message or ""
          -- 过滤掉 clippy 附带的文档链接，只保留“怎么改”
          local is_doc_link = child_msg:find("for further information visit", 1, true) ~= nil
          if child_msg ~= "" and not is_doc_link then
            parts[#parts + 1] = ("%s: %s"):format(child.level or "note", child_msg)
          end
          -- 同一个 child 的 spans 属于同一个建议，必须一起应用
          local edits = {}
          for _, s in ipairs(child.spans or {}) do
            if s.file_name == file and s.suggested_replacement ~= nil then
              edits[#edits + 1] = {
                srow = (s.line_start or 1) - 1,
                scol = (s.column_start or 1) - 1,
                erow = (s.line_end or s.line_start or 1) - 1,
                ecol = (s.column_end or s.column_start or 1) - 1,
                text = s.suggested_replacement,
              }
            end
          end
          if #edits > 0 then
            fixes[#fixes + 1] = {
              title = tostring(child.message or "应用建议"):gsub("%s*\n.*$", ""),
              edits = edits,
            }
          end
        end

        diagnostics[#diagnostics + 1] = {
          lnum = (span.line_start or 1) - 1,
          col = (span.column_start or 1) - 1,
          end_lnum = (span.line_end or span.line_start or 1) - 1,
          end_col = (span.column_end or span.column_start or 1) - 1,
          severity = msg.level == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
          message = table.concat(parts, "\n"),
          code = code,
          source = tool == "clippy-driver" and "clippy" or "rustc",
          user_data = { fixes = fixes },
        }
      end
    end
  end

  return diagnostics
end

---@param bufnr integer
local function rust_check(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if not is_solution(file) or vim.fn.filereadable(file) == 0 then
    return
  end

  local tool = rust_tool()
  local outdir = vim.fn.stdpath("cache") .. "/rust-check"
  vim.fn.mkdir(outdir, "p")

  vim.system({
    tool,
    "--edition=2021",
    "--crate-type=lib", -- 单文件解答没有 main，按 lib 编译
    "--emit=metadata",
    "--error-format=json",
    "--out-dir",
    outdir,
    file,
  }, { text = true }, function(out)
    -- 注意：诊断输出在 **stderr**（不是 stdout）
    local diagnostics = parse_rust_diagnostics(
      vim.split((out.stderr or "") .. (out.stdout or ""), "\n", { trimempty = true }),
      file,
      tool
    )

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.diagnostic.set(rust_ns, bufnr, diagnostics)
      end
    end)
  end)
end

--- 应用光标所在行诊断的 clippy/rustc 建议。
--- <leader>ca 只会问 LSP（rust-analyzer 自己的诊断），自己跑出来的 clippy 建议要自己 apply。
---@param bufnr integer
local function rust_apply_fix(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  local candidates = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = row, namespace = rust_ns })) do
    for _, fix in ipairs((d.user_data or {}).fixes or {}) do
      candidates[#candidates + 1] = { fix = fix, diag = d }
    end
  end

  if #candidates == 0 then
    vim.notify("当前行没有可自动应用的 clippy/rustc 建议", vim.log.levels.INFO, { title = "leetcode" })
    return
  end

  local function apply(fix)
    -- 从后往前改，避免前面的编辑影响后面的位置
    table.sort(fix.edits, function(a, b)
      return a.srow > b.srow or (a.srow == b.srow and a.scol > b.scol)
    end)
    for _, e in ipairs(fix.edits) do
      vim.api.nvim_buf_set_text(bufnr, e.srow, e.scol, e.erow, e.ecol, vim.split(e.text, "\n", { plain = true }))
    end
    vim.diagnostic.reset(rust_ns, bufnr)
    rust_check(bufnr)
  end

  if #candidates == 1 then
    apply(candidates[1].fix)
    return
  end

  vim.ui.select(candidates, {
    prompt = "选择要应用的修复",
    format_item = function(item)
      return ("L%d  %s  (%s)"):format(item.diag.lnum + 1, item.fix.title, item.diag.code or "")
    end,
  }, function(choice)
    if choice then
      apply(choice.fix)
    end
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
          -- clangd 18+ 只会在 --query-driver 白名单里的驱动器上查询系统头文件路径。
          -- 解答目录的 .clangd 里写的是 `Compiler: g++`，没有这一项时 clangd 不会去问 g++，
          -- 于是 #include <bits/stdc++.h> 直接 "file not found"，std:: 补全全空。
          "--query-driver=**",
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
            -- 编译级检查用下面的 rust_check（保存时直接调 clippy/rustc，和判题器同一套诊断）。
            checkOnSave = false,
            -- 明确指向生成的工程描述（每个 .rs 各自是一个 crate root）
            linkedProjects = { SOLUTIONS .. "/rust-project.json" },
            diagnostics = { enable = true, experimental = { enable = false } },
          },
        },
      })
      vim.lsp.enable("rust_analyzer")

      -- 依赖自检：缺 rust-analyzer / clippy 是“Rust 没反应”最常见的原因，提示一次。
      -- 注意两点：
      --   * rustup 的 shim 文件存在时 executable() 也返回 1，但真跑会报
      --     Unknown binary 'rust-analyzer.exe' in official toolchain，所以要真跑一次；
      --   * vim.system 找不到可执行文件时会直接抛 ENOENT（不是返回非 0），必须 pcall。
      vim.schedule(function()
        if vim.fn.executable("clippy-driver") == 0 then
          vim.notify(
            "没找到 clippy-driver，本地检查会退回 rustc。\n想要 clippy 建议：rustup component add clippy",
            vim.log.levels.WARN,
            { title = "leetcode" }
          )
        end

        local hint = "Rust 补全/诊断会失效。\n修复：rustup component add rust-analyzer"
        if vim.fn.executable("rust-analyzer") == 0 then
          vim.notify("没找到 rust-analyzer，" .. hint, vim.log.levels.WARN, { title = "leetcode" })
          return
        end

        local ok, proc = pcall(vim.system, { "rust-analyzer", "--version" }, { text = true })
        if not ok then
          vim.notify("rust-analyzer 不可用，" .. hint, vim.log.levels.WARN, { title = "leetcode" })
          return
        end
        local res = proc:wait()
        if res.code ~= 0 then
          vim.notify("rust-analyzer 启动失败，" .. hint, vim.log.levels.WARN, { title = "leetcode" })
        end
      end)

      -- 新题目会新建 .rs，把新 crate 登记进去（内容变了 rust-analyzer 会自己 reload）
      vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPre" }, {
        pattern = "*.rs",
        callback = function()
          if is_solution(0) then
            ensure_rust_project()
          end
        end,
      })

      -- 保存 .rs 时就跑一次 clippy/编译检查（和判题器同一套 error + clippy 建议）
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*.rs",
        callback = function(args)
          rust_check(args.buf)
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
            -- 打开就先查一次，然后保存时自动查（clippy 优先于 rustc）
            map("n", "<leader>lC", function()
              rust_check(ev.buf)
            end, "本地 clippy/编译检查")
            map("n", "<leader>lF", function()
              rust_apply_fix(ev.buf)
            end, "应用 clippy 建议（当前行）")
            rust_check(ev.buf)
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
