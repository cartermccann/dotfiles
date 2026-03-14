-- Square — custom colorscheme for the square theme
-- Mostly black. White text. Blue is rare — only for active/focused states.

vim.cmd("hi clear")
vim.g.colors_name = "square"

local c = {
  bg = "NONE",
  fg = "#e0e0e0",
  black = "#000000",
  blue = "#0055ff",
  blue_dark = "#003388",
  blue_tint = "#0c1628",
  white = "#ffffff",
  grey_light = "#b0b0b0",
  grey = "#707070",
  grey_dark = "#505050",
  grey_darker = "#333333",
  grey_darkest = "#111111",
  panel = "#000000",
  panel_lift = "#0a0a0a",
  comment = "#3a3a3a",
  red = "#ff3333",
  yellow = "#ffaa00",
  green = "#44cc44",
}

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- ── Editor ──
hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalNC", { fg = c.fg, bg = c.bg })
hl("NormalFloat", { fg = c.fg, bg = c.panel_lift })
hl("FloatBorder", { fg = c.grey_darker, bg = c.panel_lift })
hl("FloatTitle", { fg = c.white, bg = c.panel_lift, bold = true })
hl("Visual", { bg = c.blue_tint })
hl("VisualNOS", { bg = c.blue_tint })
hl("Search", { fg = c.white, bg = c.blue_dark })
hl("IncSearch", { fg = c.black, bg = c.blue })
hl("CurSearch", { fg = c.black, bg = c.blue })
hl("Substitute", { fg = c.black, bg = c.blue })
hl("CursorLine", { bg = c.panel_lift })
hl("CursorColumn", { bg = c.panel_lift })
hl("ColorColumn", { bg = c.panel_lift })
hl("LineNr", { fg = c.grey_darker })
hl("CursorLineNr", { fg = c.blue, bold = true })
hl("SignColumn", { fg = c.grey_darker, bg = c.bg })
hl("FoldColumn", { fg = c.grey_darker, bg = c.bg })
hl("Folded", { fg = c.grey_dark, bg = c.panel_lift })
hl("VertSplit", { fg = c.grey_darker })
hl("WinSeparator", { fg = c.grey_darker })
hl("StatusLine", { fg = c.fg, bg = c.panel })
hl("StatusLineNC", { fg = c.grey_dark, bg = c.panel })
hl("TabLine", { fg = c.grey_dark, bg = c.panel })
hl("TabLineSel", { fg = c.white, bg = c.panel, bold = true })
hl("TabLineFill", { bg = c.panel })
-- NOTE: StatusLine/TabLine use panel (#000000) = true black
hl("WinBar", { fg = c.fg, bg = c.bg })
hl("WinBarNC", { fg = c.grey_dark, bg = c.bg })
hl("Pmenu", { fg = c.fg, bg = c.panel_lift })
hl("PmenuSel", { fg = c.white, bg = c.blue })
hl("PmenuSbar", { bg = c.grey_darkest })
hl("PmenuThumb", { bg = c.grey_darker })
hl("WildMenu", { fg = c.black, bg = c.blue })
hl("Directory", { fg = c.fg })
hl("Title", { fg = c.white, bold = true })
hl("MatchParen", { fg = c.white, bg = c.grey_darker, bold = true })
hl("NonText", { fg = c.grey_darker })
hl("SpecialKey", { fg = c.grey_darker })
hl("Whitespace", { fg = c.grey_darkest })
hl("EndOfBuffer", { fg = c.grey_darkest })
hl("Conceal", { fg = c.grey_dark })
hl("QuickFixLine", { bg = c.blue_tint })
hl("MsgArea", { fg = c.fg })
hl("ModeMsg", { fg = c.white, bold = true })
hl("MoreMsg", { fg = c.fg })
hl("Question", { fg = c.fg })
hl("WarningMsg", { fg = c.yellow })
hl("ErrorMsg", { fg = c.red, bold = true })

-- ── Cursor ──
hl("Cursor", { fg = c.black, bg = c.white })
hl("lCursor", { fg = c.black, bg = c.white })
hl("CursorIM", { fg = c.black, bg = c.white })
hl("TermCursor", { fg = c.black, bg = c.white })
hl("TermCursorNC", { fg = c.black, bg = c.grey_dark })

-- ── Diff ──
hl("DiffAdd", { bg = "#0a1a0a" })
hl("DiffChange", { bg = "#0a0a1a" })
hl("DiffDelete", { fg = c.red, bg = "#1a0a0a" })
hl("DiffText", { bg = c.blue_tint })

-- ── Spell ──
hl("SpellBad", { undercurl = true, sp = c.red })
hl("SpellCap", { undercurl = true, sp = c.grey })
hl("SpellRare", { undercurl = true, sp = c.grey })
hl("SpellLocal", { undercurl = true, sp = c.grey })

-- ── Legacy syntax ──
-- Philosophy: white/grey hierarchy for structure, blue ONLY for keywords
hl("Comment", { fg = c.comment, italic = true })
hl("Constant", { fg = c.fg })
hl("String", { fg = c.grey_light })
hl("Character", { fg = c.grey_light })
hl("Number", { fg = c.fg })
hl("Boolean", { fg = c.fg })
hl("Float", { fg = c.fg })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.white })
hl("Statement", { fg = c.white, bold = true })
hl("Conditional", { fg = c.white, bold = true })
hl("Repeat", { fg = c.white, bold = true })
hl("Label", { fg = c.white })
hl("Operator", { fg = c.grey })
hl("Keyword", { fg = c.white, bold = true })
hl("Exception", { fg = c.white, bold = true })
hl("PreProc", { fg = c.grey })
hl("Include", { fg = c.grey })
hl("Define", { fg = c.grey })
hl("Macro", { fg = c.fg })
hl("PreCondit", { fg = c.grey })
hl("Type", { fg = c.grey_light })
hl("StorageClass", { fg = c.white })
hl("Structure", { fg = c.grey_light })
hl("Typedef", { fg = c.grey_light })
hl("Special", { fg = c.fg })
hl("SpecialChar", { fg = c.grey_light })
hl("Tag", { fg = c.white })
hl("Delimiter", { fg = c.grey_dark })
hl("SpecialComment", { fg = c.grey_dark, italic = true })
hl("Debug", { fg = c.yellow })
hl("Underlined", { underline = true })
hl("Ignore", { fg = c.grey_darker })
hl("Error", { fg = c.red, bold = true })
hl("Todo", { fg = c.white, bg = c.grey_darker, bold = true })

-- ── Treesitter ──
-- Mostly white/grey. Blue reserved for nothing here — just contrast via weight.
hl("@comment", { link = "Comment" })
hl("@constant", { fg = c.fg })
hl("@constant.builtin", { fg = c.fg, bold = true })
hl("@constant.macro", { fg = c.fg, bold = true })
hl("@string", { fg = c.grey_light })
hl("@string.escape", { fg = c.grey })
hl("@string.regex", { fg = c.grey })
hl("@string.special", { fg = c.grey_light })
hl("@character", { fg = c.grey_light })
hl("@number", { fg = c.fg })
hl("@boolean", { fg = c.fg })
hl("@float", { fg = c.fg })
hl("@function", { fg = c.white })
hl("@function.builtin", { fg = c.white })
hl("@function.call", { fg = c.white })
hl("@function.macro", { fg = c.white, bold = true })
hl("@method", { fg = c.white })
hl("@method.call", { fg = c.white })
hl("@constructor", { fg = c.grey_light })
hl("@parameter", { fg = c.fg })
hl("@keyword", { fg = c.white, bold = true })
hl("@keyword.function", { fg = c.white, bold = true })
hl("@keyword.operator", { fg = c.grey })
hl("@keyword.return", { fg = c.white, bold = true })
hl("@keyword.import", { fg = c.grey })
hl("@keyword.export", { fg = c.grey })
hl("@conditional", { fg = c.white, bold = true })
hl("@repeat", { fg = c.white, bold = true })
hl("@exception", { fg = c.white, bold = true })
hl("@label", { fg = c.fg })
hl("@operator", { fg = c.grey })
hl("@type", { fg = c.grey_light })
hl("@type.builtin", { fg = c.grey_light })
hl("@type.definition", { fg = c.grey_light })
hl("@type.qualifier", { fg = c.white })
hl("@namespace", { fg = c.fg })
hl("@include", { fg = c.grey })
hl("@variable", { fg = c.fg })
hl("@variable.builtin", { fg = c.fg, italic = true })
hl("@property", { fg = c.fg })
hl("@field", { fg = c.fg })
hl("@tag", { fg = c.white })
hl("@tag.attribute", { fg = c.fg })
hl("@tag.delimiter", { fg = c.grey_dark })
hl("@punctuation.bracket", { fg = c.grey_dark })
hl("@punctuation.delimiter", { fg = c.grey_dark })
hl("@punctuation.special", { fg = c.grey })
hl("@text", { fg = c.fg })
hl("@text.strong", { bold = true })
hl("@text.emphasis", { italic = true })
hl("@text.underline", { underline = true })
hl("@text.strike", { strikethrough = true })
hl("@text.title", { fg = c.white, bold = true })
hl("@text.literal", { fg = c.grey_light })
hl("@text.uri", { fg = c.grey_light, underline = true })
hl("@text.reference", { fg = c.fg })
hl("@text.todo", { link = "Todo" })
hl("@text.note", { fg = c.fg, bg = c.grey_darkest })
hl("@text.warning", { fg = c.yellow })
hl("@text.danger", { fg = c.red })

-- ── Diagnostics ──
hl("DiagnosticError", { fg = c.red })
hl("DiagnosticWarn", { fg = c.yellow })
hl("DiagnosticInfo", { fg = c.grey })
hl("DiagnosticHint", { fg = c.grey_dark })
hl("DiagnosticOk", { fg = c.green })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = c.grey })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = c.grey_dark })
hl("DiagnosticVirtualTextError", { fg = c.red, bg = "#1a0a0a" })
hl("DiagnosticVirtualTextWarn", { fg = c.yellow, bg = "#1a1500" })
hl("DiagnosticVirtualTextInfo", { fg = c.grey, bg = c.panel })
hl("DiagnosticVirtualTextHint", { fg = c.grey_dark, bg = c.panel })

-- ── LSP ──
hl("LspReferenceText", { bg = c.grey_darkest })
hl("LspReferenceRead", { bg = c.grey_darkest })
hl("LspReferenceWrite", { bg = c.grey_darkest })
hl("LspSignatureActiveParameter", { fg = c.white, bold = true })
hl("LspInlayHint", { fg = c.grey_dark, italic = true })

-- ── Git signs ──
hl("GitSignsAdd", { fg = c.green })
hl("GitSignsChange", { fg = c.grey })
hl("GitSignsDelete", { fg = c.red })
hl("GitSignsAddNr", { fg = c.green })
hl("GitSignsChangeNr", { fg = c.grey })
hl("GitSignsDeleteNr", { fg = c.red })

-- ── Telescope ──
hl("TelescopeNormal", { fg = c.fg, bg = c.panel_lift })
hl("TelescopeBorder", { fg = c.grey_darker, bg = c.panel_lift })
hl("TelescopeTitle", { fg = c.white, bold = true })
hl("TelescopeSelection", { bg = c.grey_darkest })
hl("TelescopeSelectionCaret", { fg = c.white })
hl("TelescopeMatching", { fg = c.white, bold = true })
hl("TelescopePromptPrefix", { fg = c.white })
hl("TelescopePromptNormal", { fg = c.fg, bg = c.panel_lift })
hl("TelescopePromptBorder", { fg = c.grey_darker, bg = c.panel_lift })
hl("TelescopeResultsNormal", { fg = c.fg, bg = c.panel_lift })
hl("TelescopeResultsBorder", { fg = c.grey_darker, bg = c.panel_lift })
hl("TelescopePreviewNormal", { fg = c.fg, bg = c.panel_lift })
hl("TelescopePreviewBorder", { fg = c.grey_darker, bg = c.panel_lift })

-- ── Neo-tree ──
hl("NeoTreeNormal", { fg = c.fg, bg = c.bg })
hl("NeoTreeNormalNC", { fg = c.fg, bg = c.bg })
hl("NeoTreeDirectoryName", { fg = c.fg })
hl("NeoTreeDirectoryIcon", { fg = c.grey })
hl("NeoTreeRootName", { fg = c.white, bold = true })
hl("NeoTreeFileName", { fg = c.fg })
hl("NeoTreeGitModified", { fg = c.grey })
hl("NeoTreeGitDirty", { fg = c.grey })
hl("NeoTreeGitUntracked", { fg = c.grey_dark })
hl("NeoTreeGitAdded", { fg = c.green })
hl("NeoTreeGitDeleted", { fg = c.red })
hl("NeoTreeIndentMarker", { fg = c.grey_darkest })
hl("NeoTreeDimText", { fg = c.grey_dark })

-- ── Indent-blankline ──
hl("IblIndent", { fg = c.grey_darkest })
hl("IblScope", { fg = c.grey_darker })
hl("IndentBlanklineChar", { fg = c.grey_darkest })
hl("IndentBlanklineContextChar", { fg = c.grey_darker })

-- ── Rainbow delimiters (monochrome greys) ──
hl("RainbowDelimiterRed", { fg = c.grey })
hl("RainbowDelimiterYellow", { fg = c.grey_light })
hl("RainbowDelimiterBlue", { fg = c.grey_dark })
hl("RainbowDelimiterOrange", { fg = c.grey })
hl("RainbowDelimiterGreen", { fg = c.grey_light })
hl("RainbowDelimiterViolet", { fg = c.grey_dark })
hl("RainbowDelimiterCyan", { fg = c.grey })

-- ── Which-key ──
hl("WhichKey", { fg = c.white })
hl("WhichKeyGroup", { fg = c.grey_light })
hl("WhichKeyDesc", { fg = c.fg })
hl("WhichKeySeparator", { fg = c.grey_darker })
hl("WhichKeyFloat", { bg = c.panel_lift })
hl("WhichKeyBorder", { fg = c.grey_darker })

-- ── Noice ──
hl("NoiceCmdlinePopup", { fg = c.fg, bg = c.panel_lift })
hl("NoiceCmdlinePopupBorder", { fg = c.grey_darker })
hl("NoiceCmdlineIcon", { fg = c.white })
hl("NoicePopupmenu", { fg = c.fg, bg = c.panel_lift })
hl("NoicePopupmenuBorder", { fg = c.grey_darker })
hl("NoicePopupmenuSelected", { bg = c.grey_darkest })
hl("NoicePopupmenuMatch", { fg = c.white, bold = true })

-- ── Snacks ──
hl("SnacksDashboardHeader", { fg = c.white })
hl("SnacksDashboardIcon", { fg = c.grey })
hl("SnacksDashboardKey", { fg = c.white, bold = true })
hl("SnacksDashboardDesc", { fg = c.fg })
hl("SnacksDashboardFooter", { fg = c.grey_dark })
hl("SnacksNotifierInfo", { fg = c.fg })
hl("SnacksNotifierWarn", { fg = c.yellow })
hl("SnacksNotifierError", { fg = c.red })

-- ── Blink cmp ──
hl("BlinkCmpMenu", { fg = c.fg, bg = c.panel_lift })
hl("BlinkCmpMenuBorder", { fg = c.grey_darker, bg = c.panel_lift })
hl("BlinkCmpMenuSelection", { bg = c.grey_darkest })
hl("BlinkCmpLabel", { fg = c.fg })
hl("BlinkCmpLabelMatch", { fg = c.white, bold = true })
hl("BlinkCmpKind", { fg = c.grey })
hl("BlinkCmpDoc", { fg = c.fg, bg = c.panel_lift })
hl("BlinkCmpDocBorder", { fg = c.grey_darker, bg = c.panel_lift })

-- ── Flash ──
hl("FlashLabel", { fg = c.black, bg = c.white, bold = true })
hl("FlashMatch", { fg = c.fg, bg = c.grey_darkest })
hl("FlashCurrent", { fg = c.white, bg = c.grey_darker })

-- ── Mini ──
hl("MiniIconsBlue", { fg = c.grey })
hl("MiniIconsGrey", { fg = c.grey })

-- ── Lazy ──
hl("LazyButton", { fg = c.fg, bg = c.panel_lift })
hl("LazyButtonActive", { fg = c.black, bg = c.white, bold = true })
hl("LazyH1", { fg = c.black, bg = c.white, bold = true })
hl("LazySpecial", { fg = c.white })
