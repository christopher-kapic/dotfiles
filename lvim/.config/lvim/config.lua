-- CKLunarVim Configuration
-- This is a fork of LunarVim, updated for Neovim 0.11.5+
--
-- Repository: https://github.com/christopher-kapic/CKLunarVim
-- Note: Links below are for upstream LunarVim (may not be applicable to this fork)
-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- ============================================================================
-- Basic Settings
-- ============================================================================

-- Enable automatic formatting on save
lvim.format_on_save.enabled = true

-- Set colorscheme (options: tokyonight, lunar, habamax, etc.)
lvim.colorscheme = "tokyonight"

-- Enable transparent window background
lvim.transparent_window = true

-- Set log level (options: "trace", "debug", "info", "warn", "error", "fatal")
lvim.log.level = "error"

-- Set leader key (use "space" for spacebar, or any other key)
lvim.leader = "space"

-- ============================================================================
-- Formatters
-- ============================================================================

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  {
    name = "prettier",
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  },
}

-- ============================================================================
-- Builtin Plugin Configurations
-- ============================================================================

-- Alpha Dashboard (startup screen)
lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"

-- Terminal
lvim.builtin.terminal.active = true

-- NvimTree (file explorer)
-- Position the file tree on the right side
lvim.builtin.nvimtree.setup.view.side = "right"
-- Show git status icons in the file tree
lvim.builtin.nvimtree.setup.renderer.icons.show.git = true

-- Treesitter (syntax highlighting)
-- List of language parsers to ensure are installed
lvim.builtin.treesitter.ensure_installed = {
  "bash",
  "c",
  "javascript",
  "json",
  "lua",
  "python",
  "typescript",
  "tsx",
  "css",
  "rust",
  "java",
  "yaml",
}

-- Languages to skip installing (useful if a parser causes issues)
lvim.builtin.treesitter.ignore_install = { "haskell" }

-- Enable syntax highlighting
lvim.builtin.treesitter.highlight.enable = true

-- Mason (LSP/DAP/formatter installer UI)
-- Set border style for Mason UI windows
lvim.builtin.mason.ui.border = "rounded"

-- ============================================================================
-- Custom Key Mappings
-- ============================================================================

-- Toggle MiniMap with 'm' key in normal mode
lvim.keys.normal_mode.m = function()
  require("mini.map").toggle()
end

-- ============================================================================
-- Custom Plugins
-- ============================================================================

lvim.plugins = {
  -- Git Blame plugin - shows git blame information
  {
    "f-person/git-blame.nvim",
    event = "BufRead",
    config = function()
      -- Customize the highlight color for git blame
      vim.cmd "highlight default link gitblame SpecialComment"
      -- Disable by default (enable with :GitBlameToggle)
      vim.g.gitblame_enabled = 0
    end,
  },
  -- MiniMap - code minimap sidebar
  {
    "echasnovski/mini.map",
    branch = "stable",
    config = function()
      local map = require("mini.map")
      map.setup({
        -- Integrate with builtin search and diagnostics
        integrations = {
          map.gen_integration.builtin_search(),
          map.gen_integration.diagnostic({
            error = "DiagnosticFloatingError",
            warn = "DiagnosticFloatingWarn",
            info = "DiagnosticFloatingInfo",
            hint = "DiagnosticFloatingHint",
          }),
        },
        -- Use dot symbols for the minimap
        symbols = {
          encode = map.gen_encode_symbols.dot("4x2"),
        },
        -- Minimap window configuration
        window = {
          side = "right", -- Position on the right side
          width = 8, -- Width in characters (set to 1 for pure scrollbar)
          winblend = 100, -- Transparency level (0-100)
          show_integration_count = false, -- Don't show integration count
        },
      })

      -- Hide statusline and winbar for minimap windows to prevent "content" text from showing
      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        pattern = "*",
        callback = function()
          if vim.bo.filetype == "minimap" then
            local win_id = vim.api.nvim_get_current_win()
            vim.wo[win_id].statusline = ""
            vim.wo[win_id].winbar = ""
          end
        end,
        desc = "Hide statusline and winbar in minimap windows",
      })
    end,
  },
  -- OpenCode - AI coding assistant integration
  -- Integrates OpenCode AI assistant with Neovim for editor-aware research, code reviews, and assistance
  -- Requires: opencode CLI to be installed separately
  -- Run :checkhealth opencode after installation to verify setup
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      vim.g.opencode_opts = {}
      vim.o.autoread = true

      -- Keymaps for opencode interaction
      -- <C-a>: Ask opencode with "@this: " context (current selection/buffer)
      vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask opencode" })
      -- <C-x>: Execute opencode action selector
      vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end, { desc = "Execute opencode action…" })
      -- <C-.>: Toggle opencode terminal window
      vim.keymap.set({ "n", "t" }, "<C-.>", function() require("opencode").toggle() end, { desc = "Toggle opencode" })

      -- Operator mode keymaps for adding context to opencode
      -- go: Add selected range to opencode context
      vim.keymap.set({ "n", "x" }, "go", function() return require("opencode").operator("@this ") end, { expr = true, desc = "Add range to opencode" })
      -- goo: Add current line to opencode context
      vim.keymap.set("n", "goo", function() return require("opencode").operator("@this ") .. "_" end, { expr = true, desc = "Add line to opencode" })
    end,
  },
}

-- ============================================================================
-- Autocommands
-- ============================================================================

-- Autocommands for MiniMap - automatically open/close based on filetype
lvim.autocommands = {
  {
    { "BufEnter", "Filetype" },
    {
      desc = "Open mini.map and exclude some filetypes",
      pattern = { "*" },
      callback = function()
        local exclude_ft = {
          "qf", -- Quickfix
          "NvimTree", -- File explorer
          "toggleterm", -- Terminal
          "TelescopePrompt", -- Telescope prompts
          "alpha", -- Dashboard
          "netrw", -- Netrw file browser
          "dirvish", -- Dirvish file browser
          "lir", -- Lir file browser
        }

        local map = require("mini.map")
        -- Disable minimap for excluded filetypes
        if vim.tbl_contains(exclude_ft, vim.o.filetype) then
          vim.b.minimap_disable = true
          map.close()
        -- Open minimap only for regular file buffers (not directories)
        elseif vim.o.buftype == "" then
          local bufname = vim.api.nvim_buf_get_name(0)
          -- Only open minimap if buffer has a name and it's a file (not a directory)
          if bufname ~= "" and vim.fn.filereadable(bufname) == 1 and vim.fn.isdirectory(bufname) == 0 then
            map.open()
          else
            -- Close minimap for directories or empty buffers
            map.close()
          end
        end
      end,
    },
  },
}

-- Enable word wrap for all files
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = { "*.*" },
  command = "setlocal wrap",
})
