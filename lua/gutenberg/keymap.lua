--- Adapters that turn gutenberg's sugar verbs into well-behaved
--- keymaps: dot-repeatable, count-aware normal-mode edits, operator
--- maps, and visual-mode maps that read the live selection. gutenberg
--- still ships no keymaps — user mappings consume these (see
--- `:h gutenberg-recommended-config`).
---
--- This module is a sanctioned UI edge: every adapter runs its
--- callback under `pcall` and surfaces failures through `vim.notify`
--- at WARN, so the error messages the library throws double as UI
--- copy.

---@class gutenberg.keymap
local M = {}

--- Run `fn`, surfacing any error as a WARN notification. The public
--- escape hatch for one-off mappings (motions, pickers) that don't
--- need `repeatable` / `operator` / `visual`.
---@param fn fun()
function M.notify(fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
  end
end

---@type fun(ctx: gutenberg.Context.Partial)?
local pending

--- The operatorfunc behind `repeatable`. The count is read HERE, not
--- when the mapping fires, so `.` replays the last count and `5.`
--- overrides it — exactly like builtin operators.
function M._repeat_opfunc()
  local fn = pending
  if fn == nil then
    return
  end
  M.notify(function()
    fn({ count = vim.v.count1 })
  end)
end

--- Wrap a sugar verb as a dot-repeatable, count-aware normal-mode
--- edit. Returns a function for an `expr = true` mapping:
--- >lua
---   vim.keymap.set('n', '<leader>mx', keymap.repeatable(function(ctx)
---     require('gutenberg').list.toggle_checkbox(ctx)
---   end), { expr = true })
--- <
--- `fn` receives `{ count = vim.v.count1 }`; `3<lhs>`, `.`, and `5.`
--- all deliver the right count. Known caveat: the `g@l` trampoline
--- this rides on no-ops on empty lines.
---@param fn fun(ctx: gutenberg.Context.Partial)
---@return fun(): string
function M.repeatable(fn)
  return function()
    pending = fn
    vim.go.operatorfunc = "v:lua.require'gutenberg.keymap'._repeat_opfunc"
    return 'g@l'
  end
end

--- The operatorfunc behind `operator`: builds an inclusive Range from
--- the `'[` / `']` marks the motion set.
---@param motion 'char' | 'line' | 'block'
function M._operator_opfunc(motion)
  local fn = pending
  if fn == nil then
    return
  end
  if motion == 'block' then
    vim.notify(
      'gutenberg: blockwise selections are not supported',
      vim.log.levels.WARN
    )
    return
  end

  local start = vim.api.nvim_buf_get_mark(0, '[')
  local stop = vim.api.nvim_buf_get_mark(0, ']')
  M.notify(function()
    fn({
      range = {
        mode = motion,
        start = { start[1], start[2] },
        stop = { stop[1], stop[2] },
      },
    })
  end)
end

--- Wrap a sugar verb as an operator: the mapping waits for a motion or
--- textobject and hands `fn` the covered range. Returns a function for
--- an `expr = true` mapping:
--- >lua
---   vim.keymap.set('n', '<leader>ml', keymap.operator(function(ctx)
---     require('gutenberg').link.wrap({}, ctx)
---   end), { expr = true })
--- <
--- `fn` receives `{ range = ... }` with the motion's inclusive
--- char/line range. Dot-repeat comes free with `g@`. Blockwise-forced
--- motions notify and do nothing.
---@param fn fun(ctx: gutenberg.Context.Partial)
---@return fun(): string
function M.operator(fn)
  return function()
    pending = fn
    vim.go.operatorfunc = "v:lua.require'gutenberg.keymap'._operator_opfunc"
    return 'g@'
  end
end

--- Wrap a sugar verb as a visual-mode edit. The live selection is read
--- from `getpos('v')` / `getpos('.')` — never the `'<` / `'>` marks,
--- which still describe the PREVIOUS selection while visual mode is
--- active — with swapped anchors normalized. Visual mode is left
--- before `fn` runs, so the edit lands in normal mode like builtin
--- visual commands:
--- >lua
---   vim.keymap.set('x', '<leader>mx', keymap.visual(function(ctx)
---     require('gutenberg').list.toggle_checkbox(ctx)
---   end))
--- <
--- `fn` receives `{ range = ... }`. Blockwise selections notify and do
--- nothing.
---@param fn fun(ctx: gutenberg.Context.Partial)
---@return fun()
function M.visual(fn)
  return function()
    local mode = vim.fn.mode()
    if mode ~= 'v' and mode ~= 'V' then
      vim.notify(
        'gutenberg: blockwise selections are not supported',
        vim.log.levels.WARN
      )
      return
    end

    local anchor = vim.fn.getpos('v')
    local head = vim.fn.getpos('.')
    local start = { anchor[2], anchor[3] - 1 }
    local stop = { head[2], head[3] - 1 }
    if stop[1] < start[1] or (stop[1] == start[1] and stop[2] < start[2]) then
      start, stop = stop, start
    end

    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
      'nx',
      false
    )
    M.notify(function()
      fn({
        range = {
          mode = mode == 'V' and 'line' or 'char',
          start = start,
          stop = stop,
        },
      })
    end)
  end
end

return M
