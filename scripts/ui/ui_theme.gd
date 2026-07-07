class_name UITheme
extends RefCounted
## V3 UI skin pass — single source of StyleBox builders so every code-built
## menu (HUD, DialogBox, ShopScreen, CookingScreen, ForgeScreen,
## InventoryScreen, Journal, PauseMenu, Title) looks consistent instead of
## each screen inventing its own ad-hoc StyleBoxFlat.
##
## Art source: tools/gen_placeholders.gd's `_write_ui()` generates six PNGs
## under assets/placeholder/ (ui_panel, ui_slot, ui_slot_selected, ui_bar_bg,
## ui_bar_fill, ui_button). Ninepatch contract (MUST stay in sync with
## gen_placeholders.gd's UI_NINEPATCH_SIZE/UI_NINEPATCH_MARGIN consts):
##   - panel/slot/button pieces are 24x24 with an 8px margin on all sides.
##   - bar pieces are 32x16 with an 8px (bg) / 6px (fill) left/right margin.
## Callers ask for a StyleBoxTexture/StyleBoxFlat via the static builders
## below rather than touching the PNGs directly.
##
## Deliberately NO layout/anchor logic here — this file only returns
## StyleBox/Theme resources; every screen keeps its own tree structure and
## just calls add_theme_stylebox_override(...) / add_theme_color_override(...)
## with what this returns.

const PANEL_MARGIN := 8
const BAR_BG_MARGIN := 8
const BAR_FILL_MARGIN := 6

const TEXT_LIGHT := Color("f0e8d8")   # light text for dark/inset panels
const TEXT_DARK := Color("2b2233")    # dark text for light/parchment fills
const TEXT_MUTED := Color("c8b898")   # dimmer light text (hints/details)

static var _panel_tex: Texture2D
static var _slot_tex: Texture2D
static var _slot_selected_tex: Texture2D
static var _bar_bg_tex: Texture2D
static var _bar_fill_tex: Texture2D
static var _button_tex: Texture2D


static func _load(cache_field: String, path: String) -> Texture2D:
	# Small manual memo so repeated calls (many rows/slots per screen) don't
	# re-hit disk; static vars persist for the process lifetime same as any
	# other autoload-ish resource cache in this codebase.
	match cache_field:
		"panel":
			if _panel_tex == null:
				_panel_tex = load(path)
			return _panel_tex
		"slot":
			if _slot_tex == null:
				_slot_tex = load(path)
			return _slot_tex
		"slot_selected":
			if _slot_selected_tex == null:
				_slot_selected_tex = load(path)
			return _slot_selected_tex
		"bar_bg":
			if _bar_bg_tex == null:
				_bar_bg_tex = load(path)
			return _bar_bg_tex
		"bar_fill":
			if _bar_fill_tex == null:
				_bar_fill_tex = load(path)
			return _bar_fill_tex
		"button":
			if _button_tex == null:
				_button_tex = load(path)
			return _button_tex
	return null


static func _stylebox_texture(tex: Texture2D, margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	return sb


## Outer window panel for every menu screen (wood/parchment frame + dark
## inset). Used for ShopScreen/CookingScreen/ForgeScreen/InventoryScreen/
## Journal/PauseMenu/DialogBox's bottom panel/Title's banner.
static func panel_stylebox() -> StyleBoxTexture:
	var tex := _load("panel", "res://assets/placeholder/ui_panel.png")
	return _stylebox_texture(tex, PANEL_MARGIN)


## Recessed item/recipe/hotbar slot. Pass `selected = true` to additionally
## get the bright highlight ring baked into a second StyleBoxTexture the
## caller layers via a sibling control (see hud.gd's hotbar) OR — simpler for
## single-stylebox callers — just call slot_stylebox(false) for the base and
## selected_ring_stylebox() separately when both need to coexist.
static func slot_stylebox(_selected: bool = false) -> StyleBoxTexture:
	var tex := _load("slot", "res://assets/placeholder/ui_slot.png")
	return _stylebox_texture(tex, PANEL_MARGIN)


## Bright ring overlay for the currently-selected hotbar/grid slot. Meant to
## be applied as its own stylebox (e.g. on a thin overlay Panel/border) OR as
## the slot's own stylebox when selected, swapping with slot_stylebox(false)
## when not — whichever is simplest for the calling screen's existing node
## shape (documented per call site).
static func selected_ring_stylebox() -> StyleBoxTexture:
	var tex := _load("slot_selected", "res://assets/placeholder/ui_slot_selected.png")
	return _stylebox_texture(tex, PANEL_MARGIN)


## HP/RP/boss bar styleboxes: a shared recessed background plus a fill piece
## tinted per-bar via `fill_tint` (e.g. red for HP, green for RP). Returns
## {"bg": StyleBoxTexture, "fill": StyleBoxTexture} — callers do
## bar.add_theme_stylebox_override("background", result.bg) and same for
## "fill".
static func bar_styleboxes(fill_tint: Color) -> Dictionary:
	var bg_tex := _load("bar_bg", "res://assets/placeholder/ui_bar_bg.png")
	var fill_tex := _load("bar_fill", "res://assets/placeholder/ui_bar_fill.png")
	var bg := _stylebox_texture(bg_tex, BAR_BG_MARGIN)
	var fill := _stylebox_texture(fill_tex, BAR_FILL_MARGIN)
	fill.modulate_color = fill_tint
	return {"bg": bg, "fill": fill}


## Button ninepatch, one per state via modulate tint (contract: hover/pressed
## via modulate, no separate art) — returns a Theme so a screen can do
## `some_button.theme = UITheme.button_theme()` once and every Button state
## (normal/hover/pressed/disabled) is covered without per-button overrides.
static func button_theme() -> Theme:
	var theme := Theme.new()
	var tex := _load("button", "res://assets/placeholder/ui_button.png")

	var normal := _stylebox_texture(tex, PANEL_MARGIN)
	var hover := _stylebox_texture(tex, PANEL_MARGIN)
	hover.modulate_color = Color(1.15, 1.15, 1.1)
	var pressed := _stylebox_texture(tex, PANEL_MARGIN)
	pressed.modulate_color = Color(0.82, 0.82, 0.8)
	var disabled := _stylebox_texture(tex, PANEL_MARGIN)
	disabled.modulate_color = Color(0.6, 0.6, 0.6, 0.8)
	var focus := _stylebox_texture(tex, PANEL_MARGIN)
	focus.modulate_color = Color(1.25, 1.2, 1.0)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT_LIGHT)
	theme.set_color("font_hover_color", "Button", TEXT_LIGHT)
	theme.set_color("font_pressed_color", "Button", TEXT_LIGHT)
	theme.set_color("font_disabled_color", "Button", TEXT_MUTED)
	return theme


## Small dark backing panel for a single label (HUD gold/clock/day, dialog
## speaker name) so text stays legible over busy world art without a full
## window frame.
static func label_backing_stylebox() -> StyleBoxTexture:
	var tex := _load("slot", "res://assets/placeholder/ui_slot.png")
	return _stylebox_texture(tex, PANEL_MARGIN)
