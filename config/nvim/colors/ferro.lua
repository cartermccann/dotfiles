-- Ferro — neovim colorscheme derived from lib/ferro-palette.nix
-- Warm espresso/cream monochrome base + azure accent + phosphor-green motif.
-- Mirrors the Hyprland (Ferro) rice so the editor matches the desktop.
--
-- Palette source of truth: ~/dotfiles/lib/ferro-palette.nix (Base16).
-- A few shades below are derived tints (string-green, bg washes, selection)
-- kept tasteful for code over a full file — noted inline.
--
-- Transparency: defaults ON so the espresso comes from the terminal/compositor
-- blur (matches square.lua + the catppuccin/transparent roster). Set
-- `vim.g.ferro_transparent = false` before `:colorscheme ferro` for a solid bg.

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "ferro"

local transparent = vim.g.ferro_transparent ~= false

local c = {
  -- ── Base16 slots (ferro-palette.nix) ──
  bg = "#141210", -- base00 espresso black
  surface = "#1b1917", -- base01 raised bg / status
  raised = "#211e1a", -- base02 selection / raised
  muted = "#6b655d", -- base03 comments / disabled
  taupe = "#8a847c", -- base04 dark fg
  fg = "#e8e4df", -- base05 warm cream (default fg)
  fg_light = "#c5bfb5", -- base06 light fg
  white = "#f2efe9", -- base07 lightest
  red = "#e06c5e", -- base08
  orange = "#d99a5c", -- base09
  yellow = "#cbb46a", -- base0A
  green = "#3ddc84", -- base0B phosphor
  cyan = "#72b8ff", -- base0C azure-bright
  azure = "#7b7bff", -- base0D PRIMARY accent (focus/active)
  periwinkle = "#a98bff", -- base0E magenta
  green_deep = "#2d8a4e", -- base0F brand deep green
  dim = "#a39d94", -- textDim

  -- ── Derived tints (kept restrained for full-file readability) ──
  overlay = "#26221e", -- cursorline / subtle raise above raised
  green_soft = "#8fcf9d", -- gentler phosphor for strings
  sel = "#2b2a3a", -- visual: faint azure-tinted selection
  hairline = "#332f2a", -- inactive separators / borders (japandi hairline)
  border_active = "#4a4960", -- active win separator (azure-leaning)
  red_bg = "#241715",
  green_bg = "#13231a",
  blue_bg = "#171a2b",
  yellow_bg = "#23200f",
  none = "NONE",
}

-- background helpers honoring transparency
local NB = transparent and c.none or c.bg -- normal bg
local FB = c.surface -- float bg (always solid for separation)

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- ── Editor ──
hl("Normal", { fg = c.fg, bg = NB })
hl("NormalNC", { fg = c.fg, bg = NB })
hl("NormalFloat", { fg = c.fg, bg = FB })
hl("FloatBorder", { fg = c.hairline, bg = FB })
hl("FloatTitle", { fg = c.azure, bg = FB, bold = true })
hl("Visual", { bg = c.sel })
hl("VisualNOS", { bg = c.sel })
hl("Search", { fg = c.white, bg = "#3a3414" })
hl("IncSearch", { fg = c.bg, bg = c.azure })
hl("CurSearch", { fg = c.bg, bg = c.azure })
hl("Substitute", { fg = c.bg, bg = c.orange })
hl("CursorLine", { bg = c.overlay })
hl("CursorColumn", { bg = c.overlay })
hl("ColorColumn", { bg = c.surface })
hl("LineNr", { fg = "#46413a" })
hl("CursorLineNr", { fg = c.azure, bold = true })
hl("SignColumn", { fg = c.muted, bg = NB })
hl("FoldColumn", { fg = c.muted, bg = NB })
hl("Folded", { fg = c.taupe, bg = c.surface })
hl("VertSplit", { fg = c.hairline })
hl("WinSeparator", { fg = c.border_active })
hl("StatusLine", { fg = c.fg, bg = c.surface })
hl("StatusLineNC", { fg = c.taupe, bg = c.surface })
hl("TabLine", { fg = c.taupe, bg = c.surface })
hl("TabLineSel", { fg = c.azure, bg = NB, bold = true })
hl("TabLineFill", { bg = NB })
hl("WinBar", { fg = c.fg, bg = NB })
hl("WinBarNC", { fg = c.taupe, bg = NB })
hl("Pmenu", { fg = c.fg, bg = FB })
hl("PmenuSel", { fg = c.white, bg = c.sel, bold = true })
hl("PmenuSbar", { bg = c.raised })
hl("PmenuThumb", { bg = c.taupe })
hl("WildMenu", { fg = c.bg, bg = c.azure })
hl("Directory", { fg = c.azure })
hl("Title", { fg = c.azure, bold = true })
hl("MatchParen", { fg = c.azure, bg = c.raised, bold = true })
hl("NonText", { fg = "#3a352f" })
hl("SpecialKey", { fg = "#3a352f" })
hl("Whitespace", { fg = "#2a2622" })
hl("EndOfBuffer", { fg = NB == c.none and c.bg or c.bg })
hl("Conceal", { fg = c.muted })
hl("QuickFixLine", { bg = c.sel })
hl("MsgArea", { fg = c.fg })
hl("ModeMsg", { fg = c.azure, bold = true })
hl("MoreMsg", { fg = c.green })
hl("Question", { fg = c.green })
hl("WarningMsg", { fg = c.yellow })
hl("ErrorMsg", { fg = c.red, bold = true })

-- ── Cursor ──
hl("Cursor", { fg = c.bg, bg = c.azure })
hl("lCursor", { fg = c.bg, bg = c.azure })
hl("CursorIM", { fg = c.bg, bg = c.azure })
hl("TermCursor", { fg = c.bg, bg = c.azure })
hl("TermCursorNC", { fg = c.bg, bg = c.taupe })

-- ── Diff ──
hl("DiffAdd", { bg = c.green_bg })
hl("DiffChange", { bg = c.blue_bg })
hl("DiffDelete", { fg = c.red, bg = c.red_bg })
hl("DiffText", { bg = "#22305a" })

-- ── Spell ──
hl("SpellBad", { undercurl = true, sp = c.red })
hl("SpellCap", { undercurl = true, sp = c.yellow })
hl("SpellRare", { undercurl = true, sp = c.periwinkle })
hl("SpellLocal", { undercurl = true, sp = c.cyan })

-- ── Legacy syntax ──
-- Palette logic: azure = keywords/flow, periwinkle = functions, yellow = types,
-- green = strings, orange = numbers/constants, cyan = props/builtins,
-- cream = plain identifiers, muted = punctuation/comments.
hl("Comment", { fg = c.muted, italic = true })
hl("Constant", { fg = c.orange })
hl("String", { fg = c.green_soft })
hl("Character", { fg = c.green_soft })
hl("Number", { fg = c.orange })
hl("Boolean", { fg = c.orange })
hl("Float", { fg = c.orange })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.periwinkle })
hl("Statement", { fg = c.azure })
hl("Conditional", { fg = c.azure })
hl("Repeat", { fg = c.azure })
hl("Label", { fg = c.cyan })
hl("Operator", { fg = c.taupe })
hl("Keyword", { fg = c.azure })
hl("Exception", { fg = c.azure })
hl("PreProc", { fg = c.periwinkle })
hl("Include", { fg = c.azure })
hl("Define", { fg = c.periwinkle })
hl("Macro", { fg = c.periwinkle })
hl("PreCondit", { fg = c.periwinkle })
hl("Type", { fg = c.yellow })
hl("StorageClass", { fg = c.yellow })
hl("Structure", { fg = c.yellow })
hl("Typedef", { fg = c.yellow })
hl("Special", { fg = c.cyan })
hl("SpecialChar", { fg = c.cyan })
hl("Tag", { fg = c.azure })
hl("Delimiter", { fg = c.taupe })
hl("SpecialComment", { fg = c.taupe, italic = true })
hl("Debug", { fg = c.orange })
hl("Underlined", { fg = c.cyan, underline = true })
hl("Ignore", { fg = c.muted })
hl("Error", { fg = c.red, bold = true })
hl("Todo", { fg = c.bg, bg = c.yellow, bold = true })

-- ── Treesitter ──
hl("@comment", { link = "Comment" })
hl("@comment.error", { fg = c.bg, bg = c.red, bold = true })
hl("@comment.warning", { fg = c.bg, bg = c.yellow, bold = true })
hl("@comment.todo", { link = "Todo" })
hl("@comment.note", { fg = c.bg, bg = c.cyan, bold = true })
hl("@constant", { fg = c.orange })
hl("@constant.builtin", { fg = c.cyan })
hl("@constant.macro", { fg = c.periwinkle })
hl("@string", { fg = c.green_soft })
hl("@string.escape", { fg = c.cyan })
hl("@string.regexp", { fg = c.orange })
hl("@string.special", { fg = c.cyan })
hl("@string.special.url", { fg = c.cyan, underline = true })
hl("@character", { fg = c.green_soft })
hl("@character.special", { fg = c.cyan })
hl("@number", { fg = c.orange })
hl("@number.float", { fg = c.orange })
hl("@boolean", { fg = c.orange })
hl("@function", { fg = c.periwinkle })
hl("@function.builtin", { fg = c.cyan })
hl("@function.call", { fg = c.periwinkle })
hl("@function.macro", { fg = c.periwinkle })
hl("@function.method", { fg = c.periwinkle })
hl("@function.method.call", { fg = c.periwinkle })
hl("@method", { fg = c.periwinkle })
hl("@method.call", { fg = c.periwinkle })
hl("@constructor", { fg = c.yellow })
hl("@parameter", { fg = c.fg_light, italic = true })
hl("@keyword", { fg = c.azure })
hl("@keyword.function", { fg = c.azure })
hl("@keyword.operator", { fg = c.azure })
hl("@keyword.return", { fg = c.azure, italic = true })
hl("@keyword.import", { fg = c.azure, italic = true })
hl("@keyword.export", { fg = c.azure, italic = true })
hl("@keyword.conditional", { fg = c.azure })
hl("@keyword.repeat", { fg = c.azure })
hl("@keyword.exception", { fg = c.azure })
hl("@keyword.coroutine", { fg = c.azure })
hl("@conditional", { fg = c.azure })
hl("@repeat", { fg = c.azure })
hl("@exception", { fg = c.azure })
hl("@label", { fg = c.cyan })
hl("@operator", { fg = c.taupe })
hl("@type", { fg = c.yellow })
hl("@type.builtin", { fg = c.yellow, italic = true })
hl("@type.definition", { fg = c.yellow })
hl("@type.qualifier", { fg = c.azure })
hl("@namespace", { fg = c.fg_light })
hl("@module", { fg = c.fg_light })
hl("@include", { fg = c.azure })
hl("@variable", { fg = c.fg })
hl("@variable.builtin", { fg = c.red, italic = true })
hl("@variable.parameter", { fg = c.fg_light, italic = true })
hl("@variable.member", { fg = c.cyan })
hl("@property", { fg = c.cyan })
hl("@field", { fg = c.cyan })
hl("@attribute", { fg = c.periwinkle })
hl("@tag", { fg = c.azure })
hl("@tag.builtin", { fg = c.azure })
hl("@tag.attribute", { fg = c.periwinkle, italic = true })
hl("@tag.delimiter", { fg = c.muted })
hl("@punctuation.bracket", { fg = c.taupe })
hl("@punctuation.delimiter", { fg = c.taupe })
hl("@punctuation.special", { fg = c.cyan })
hl("@text", { fg = c.fg })
hl("@markup", { fg = c.fg })
hl("@markup.strong", { fg = c.orange, bold = true })
hl("@markup.italic", { italic = true })
hl("@markup.underline", { underline = true })
hl("@markup.strikethrough", { strikethrough = true })
hl("@markup.heading", { fg = c.azure, bold = true })
hl("@markup.raw", { fg = c.green_soft })
hl("@markup.link", { fg = c.cyan, underline = true })
hl("@markup.link.url", { fg = c.cyan, underline = true })
hl("@markup.link.label", { fg = c.periwinkle })
hl("@markup.list", { fg = c.azure })
hl("@markup.quote", { fg = c.taupe, italic = true })
hl("@diff.plus", { fg = c.green })
hl("@diff.minus", { fg = c.red })
hl("@diff.delta", { fg = c.cyan })

-- ── LSP semantic tokens ──
hl("@lsp.type.namespace", { link = "@namespace" })
hl("@lsp.type.type", { link = "@type" })
hl("@lsp.type.class", { link = "@type" })
hl("@lsp.type.enum", { link = "@type" })
hl("@lsp.type.interface", { link = "@type" })
hl("@lsp.type.struct", { link = "@type" })
hl("@lsp.type.typeParameter", { fg = c.yellow, italic = true })
hl("@lsp.type.parameter", { link = "@variable.parameter" })
hl("@lsp.type.variable", { link = "@variable" })
hl("@lsp.type.property", { link = "@property" })
hl("@lsp.type.enumMember", { fg = c.cyan })
hl("@lsp.type.function", { link = "@function" })
hl("@lsp.type.method", { link = "@function.method" })
hl("@lsp.type.macro", { fg = c.periwinkle })
hl("@lsp.type.decorator", { fg = c.periwinkle })
hl("@lsp.type.keyword", { link = "@keyword" })
hl("@lsp.typemod.variable.readonly", { fg = c.orange })
hl("@lsp.typemod.variable.defaultLibrary", { fg = c.cyan })
hl("@lsp.typemod.function.defaultLibrary", { fg = c.cyan })
hl("@lsp.mod.deprecated", { strikethrough = true })

-- ── Diagnostics ──
hl("DiagnosticError", { fg = c.red })
hl("DiagnosticWarn", { fg = c.yellow })
hl("DiagnosticInfo", { fg = c.cyan })
hl("DiagnosticHint", { fg = c.periwinkle })
hl("DiagnosticOk", { fg = c.green })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = c.cyan })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = c.periwinkle })
hl("DiagnosticVirtualTextError", { fg = c.red, bg = c.red_bg })
hl("DiagnosticVirtualTextWarn", { fg = c.yellow, bg = c.yellow_bg })
hl("DiagnosticVirtualTextInfo", { fg = c.cyan, bg = c.blue_bg })
hl("DiagnosticVirtualTextHint", { fg = c.periwinkle, bg = c.surface })

-- ── LSP ──
hl("LspReferenceText", { bg = c.raised })
hl("LspReferenceRead", { bg = c.raised })
hl("LspReferenceWrite", { bg = c.raised, underline = true })
hl("LspSignatureActiveParameter", { fg = c.azure, bold = true })
hl("LspInlayHint", { fg = c.muted, bg = c.surface, italic = true })
hl("LspCodeLens", { fg = c.muted, italic = true })

-- ── AI ghost text (minuet virtualtext / inline completion) ──
hl("MinuetVirtualText", { fg = c.muted, italic = true })
hl("ComplHint", { fg = c.muted, italic = true })
hl("ComplHintMore", { fg = c.muted, italic = true })

-- ── Git signs ──
hl("GitSignsAdd", { fg = c.green })
hl("GitSignsChange", { fg = c.azure })
hl("GitSignsDelete", { fg = c.red })
hl("GitSignsAddNr", { fg = c.green })
hl("GitSignsChangeNr", { fg = c.azure })
hl("GitSignsDeleteNr", { fg = c.red })
hl("GitSignsAddInline", { bg = c.green_bg })
hl("GitSignsDeleteInline", { bg = c.red_bg })
hl("Added", { fg = c.green })
hl("Changed", { fg = c.azure })
hl("Removed", { fg = c.red })

-- ── Telescope ──
hl("TelescopeNormal", { fg = c.fg, bg = FB })
hl("TelescopeBorder", { fg = c.hairline, bg = FB })
hl("TelescopeTitle", { fg = c.azure, bold = true })
hl("TelescopeSelection", { bg = c.sel })
hl("TelescopeSelectionCaret", { fg = c.azure })
hl("TelescopeMatching", { fg = c.azure, bold = true })
hl("TelescopePromptPrefix", { fg = c.azure })
hl("TelescopePromptNormal", { fg = c.fg, bg = FB })
hl("TelescopePromptBorder", { fg = c.hairline, bg = FB })
hl("TelescopeResultsNormal", { fg = c.fg, bg = FB })
hl("TelescopeResultsBorder", { fg = c.hairline, bg = FB })
hl("TelescopePreviewNormal", { fg = c.fg, bg = FB })
hl("TelescopePreviewBorder", { fg = c.hairline, bg = FB })

-- ── Neo-tree ──
hl("NeoTreeNormal", { fg = c.fg, bg = NB })
hl("NeoTreeNormalNC", { fg = c.fg, bg = NB })
hl("NeoTreeDirectoryName", { fg = c.azure })
hl("NeoTreeDirectoryIcon", { fg = c.azure })
hl("NeoTreeRootName", { fg = c.azure, bold = true })
hl("NeoTreeFileName", { fg = c.fg })
hl("NeoTreeGitModified", { fg = c.azure })
hl("NeoTreeGitDirty", { fg = c.azure })
hl("NeoTreeGitUntracked", { fg = c.green })
hl("NeoTreeGitAdded", { fg = c.green })
hl("NeoTreeGitDeleted", { fg = c.red })
hl("NeoTreeGitConflict", { fg = c.orange })
hl("NeoTreeIndentMarker", { fg = "#2a2622" })
hl("NeoTreeDimText", { fg = c.muted })
hl("NeoTreeTabActive", { fg = c.azure, bold = true })
hl("NeoTreeTabInactive", { fg = c.taupe })

-- ── Indent-blankline ──
hl("IblIndent", { fg = "#221f1b" })
hl("IblScope", { fg = c.hairline })
hl("IndentBlanklineChar", { fg = "#221f1b" })
hl("IndentBlanklineContextChar", { fg = c.hairline })

-- ── Rainbow delimiters (warm spectrum from the palette) ──
hl("RainbowDelimiterRed", { fg = c.red })
hl("RainbowDelimiterYellow", { fg = c.yellow })
hl("RainbowDelimiterBlue", { fg = c.azure })
hl("RainbowDelimiterOrange", { fg = c.orange })
hl("RainbowDelimiterGreen", { fg = c.green })
hl("RainbowDelimiterViolet", { fg = c.periwinkle })
hl("RainbowDelimiterCyan", { fg = c.cyan })

-- ── Which-key ──
hl("WhichKey", { fg = c.azure })
hl("WhichKeyGroup", { fg = c.periwinkle })
hl("WhichKeyDesc", { fg = c.fg })
hl("WhichKeySeparator", { fg = c.muted })
hl("WhichKeyFloat", { bg = FB })
hl("WhichKeyBorder", { fg = c.hairline, bg = FB })
hl("WhichKeyValue", { fg = c.taupe })

-- ── Noice ──
hl("NoiceCmdlinePopup", { fg = c.fg, bg = FB })
hl("NoiceCmdlinePopupBorder", { fg = c.hairline })
hl("NoiceCmdlineIcon", { fg = c.azure })
hl("NoicePopupmenu", { fg = c.fg, bg = FB })
hl("NoicePopupmenuBorder", { fg = c.hairline })
hl("NoicePopupmenuSelected", { bg = c.sel })
hl("NoicePopupmenuMatch", { fg = c.azure, bold = true })
hl("NoiceConfirmBorder", { fg = c.hairline })

-- ── Snacks ──
hl("SnacksDashboardHeader", { fg = c.azure })
hl("SnacksDashboardIcon", { fg = c.periwinkle })
hl("SnacksDashboardKey", { fg = c.azure, bold = true })
hl("SnacksDashboardDesc", { fg = c.fg })
hl("SnacksDashboardFooter", { fg = c.muted })
hl("SnacksDashboardSpecial", { fg = c.green })
hl("SnacksNotifierInfo", { fg = c.cyan })
hl("SnacksNotifierWarn", { fg = c.yellow })
hl("SnacksNotifierError", { fg = c.red })
hl("SnacksNotifierDebug", { fg = c.muted })
hl("SnacksIndent", { fg = "#221f1b" })
hl("SnacksIndentScope", { fg = c.hairline })

-- ── Blink cmp ──
hl("BlinkCmpMenu", { fg = c.fg, bg = FB })
hl("BlinkCmpMenuBorder", { fg = c.hairline, bg = FB })
hl("BlinkCmpMenuSelection", { bg = c.sel })
hl("BlinkCmpLabel", { fg = c.fg })
hl("BlinkCmpLabelMatch", { fg = c.azure, bold = true })
hl("BlinkCmpLabelDeprecated", { fg = c.muted, strikethrough = true })
hl("BlinkCmpKind", { fg = c.cyan })
hl("BlinkCmpKindFunction", { fg = c.periwinkle })
hl("BlinkCmpKindMethod", { fg = c.periwinkle })
hl("BlinkCmpKindKeyword", { fg = c.azure })
hl("BlinkCmpKindClass", { fg = c.yellow })
hl("BlinkCmpKindVariable", { fg = c.fg })
hl("BlinkCmpKindSnippet", { fg = c.green })
hl("BlinkCmpDoc", { fg = c.fg, bg = FB })
hl("BlinkCmpDocBorder", { fg = c.hairline, bg = FB })
hl("BlinkCmpGhostText", { fg = c.muted, italic = true })

-- ── Flash ──
hl("FlashLabel", { fg = c.bg, bg = c.azure, bold = true })
hl("FlashMatch", { fg = c.fg, bg = c.raised })
hl("FlashCurrent", { fg = c.bg, bg = c.cyan })

-- ── Mini ──
hl("MiniIconsAzure", { fg = c.azure })
hl("MiniIconsBlue", { fg = c.azure })
hl("MiniIconsCyan", { fg = c.cyan })
hl("MiniIconsGreen", { fg = c.green })
hl("MiniIconsGrey", { fg = c.taupe })
hl("MiniIconsOrange", { fg = c.orange })
hl("MiniIconsPurple", { fg = c.periwinkle })
hl("MiniIconsRed", { fg = c.red })
hl("MiniIconsYellow", { fg = c.yellow })

-- ── Bufferline ──
hl("BufferLineFill", { bg = NB })
hl("BufferLineBackground", { fg = c.taupe, bg = NB })
hl("BufferLineBufferVisible", { fg = c.fg_light, bg = NB })
hl("BufferLineBufferSelected", { fg = c.azure, bg = NB, bold = true })
hl("BufferLineModified", { fg = c.green, bg = NB })
hl("BufferLineModifiedVisible", { fg = c.green, bg = NB })
hl("BufferLineModifiedSelected", { fg = c.green, bg = NB })
hl("BufferLineIndicatorSelected", { fg = c.azure, bg = NB })
hl("BufferLineSeparator", { fg = c.bg, bg = NB })
hl("BufferLineSeparatorSelected", { fg = c.bg, bg = NB })

-- ── Lazy ──
hl("LazyButton", { fg = c.fg, bg = c.surface })
hl("LazyButtonActive", { fg = c.bg, bg = c.azure, bold = true })
hl("LazyH1", { fg = c.bg, bg = c.azure, bold = true })
hl("LazySpecial", { fg = c.azure })
hl("LazyProgressDone", { fg = c.green })
hl("LazyProgressTodo", { fg = c.raised })

-- ── Diffview ──
hl("DiffviewFilePanelTitle", { fg = c.azure, bold = true })
hl("DiffviewFilePanelCounter", { fg = c.periwinkle })
hl("DiffviewFilePanelFileName", { fg = c.fg })
hl("DiffviewNormal", { link = "Normal" })

-- ── Terminal ANSI palette ──
vim.g.terminal_color_0 = c.bg
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_2 = c.green
vim.g.terminal_color_3 = c.yellow
vim.g.terminal_color_4 = c.azure
vim.g.terminal_color_5 = c.periwinkle
vim.g.terminal_color_6 = c.cyan
vim.g.terminal_color_7 = c.fg
vim.g.terminal_color_8 = c.muted
vim.g.terminal_color_9 = c.red
vim.g.terminal_color_10 = c.green
vim.g.terminal_color_11 = c.yellow
vim.g.terminal_color_12 = c.azure
vim.g.terminal_color_13 = c.periwinkle
vim.g.terminal_color_14 = c.cyan
vim.g.terminal_color_15 = c.white
