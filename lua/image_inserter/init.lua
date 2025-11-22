local configs = require("image_inserter.configs")
local state   = require("image_inserter.state")

local M = {}

local function ensure_png(name)
  if not name or name == "" then return nil end
  if not name:match("%.png$") then return name .. ".png" end
  return name
end

local function save_clipboard_png(dst_path)
  local clipboard_cmd
  if os.getenv("WAYLAND_DISPLAY") then
    clipboard_cmd = "wl-paste -t image/png > "
  else
    clipboard_cmd = "xclip -selection clipboard -t image/png -o > "
  end
  return vim.fn.system(clipboard_cmd .. dst_path)
end

local function insert_at_cursor(text)
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_text(0, line - 1, col, line - 1, col, { text })
end

local function make_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.system("mkdir -p " .. path)
  end
end

local function set_keymap(bufnr)
  vim.keymap.set("n", state.opts.keys.insert_image, function()
    local ft = vim.bo[bufnr].filetype

    vim.ui.input({ prompt = "Image name (png): " }, function(inp)
      local name = ensure_png(inp)
      if not name then return end

      local base = vim.fn.expand("%:p:h")

      if ft == "tex" then
        -- LaTeX path = ./figures/
        local figures = base .. "/figures"
        make_dir(figures)
        local rel_path = "./figures/" .. name
        local abs_path = figures .. "/" .. name

        save_clipboard_png(abs_path)
        insert_at_cursor([[\includegraphics[width=\linewidth]{]] .. rel_path .. [[}]])
        return
      end

      if ft == "md" then
        -- Neorg path = ./.resources/
        local resources = base .. "/.resources"
        make_dir(resources)
        local rel_path = "./.resources/" .. name
        local abs_path = resources .. "/" .. name

        save_clipboard_png(abs_path)
        insert_at_cursor("xdg-open \"openimage:" .. rel_path .. "\"")
        return
      end

      -- Fallback (default to LaTeX style)
      local figures = base .. "/figures"
      make_dir(figures)
      local rel_path = "./figures/" .. name
      local abs_path = figures .. "/" .. name

      save_clipboard_png(abs_path)
      insert_at_cursor([[\includegraphics[width=\linewidth]{]] .. rel_path .. "}")
    end)
  end, { remap = false, buffer = bufnr, silent = true, desc = "Insert clipboard image" })
end

function M.setup(opts)
  state.opts = vim.tbl_deep_extend("keep", opts or {}, configs)

  local aug = vim.api.nvim_create_augroup("ImageInserterMaps", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    pattern = { "tex", "norg" },
    callback = function(args)
      set_keymap(args.buf)
    end,
  })
end

return M
