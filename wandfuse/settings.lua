-- mods/WandFusion/settings.lua
-- Full settings using mod_settings helper + a custom radio group
-- for betterstat_mode (0..3). Adds a spacer to avoid overlap.

dofile_once("data/scripts/lib/mod_settings.lua")

local MOD_ID = "WandFusion"

-- Small util to get/set numbers safely
local function getn(key, default)
  local v = ModSettingGetNextValue(MOD_ID.."."..key)
  if v == nil then return default end
  return tonumber(v) or default
end
local function setn(key, val)
  ModSettingSetNextValue(MOD_ID.."."..key, tonumber(val) or 0, false)
end

-- No longer needed: betterstat_mode will use a vanilla enum for reliability.


-- Custom UI helpers for section separators and titles. These functions draw simple
-- lines and section names using the game's GUI API. They respect the current
-- indentation via the global `mod_setting_group_x_offset` variable defined in
-- mod_settings.lua.

-- Draw a dashed horizontal separator. This is used to visually separate groups
-- of settings. Because `ui_fn` is defined, the auto GUI logic will not
-- interpret this as a number setting and thus avoids the missing value bug.
local function ui_separator(mod_id, gui, in_main_menu, im_id, setting)
  local line = "-----------------------"
  -- Draw the separator at the current X offset. Provide all required
  -- parameters to GuiText: gui handle, x, y and text.
  GuiText(gui, mod_setting_group_x_offset or 0, 0, line)
end

-- Draw a section title. This prints the `ui_name` associated with the
-- setting. It uses the current indentation.
local function ui_title(mod_id, gui, in_main_menu, im_id, setting)
  local title = setting.ui_name or ""
  GuiText(gui, mod_setting_group_x_offset or 0, 0, title)
end

local mod_settings = {
  -- Top-level MISC section
  -- MISC section
  { id = "sep_misc",    ui_name = "", ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_separator, not_setting = true },
  { id = "title_misc",  ui_name = "MISC",                  ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_title,    not_setting = true },
  -- Require the wand fusion perk at new game start
  { id = "enable_perk", ui_name = "Wand Fusion Perk", ui_description = "( require perk to fuse; adds perk to spawn list )", value_default = false, scope = MOD_SETTING_SCOPE_NEW_GAME, ui_type = "bool" },
  -- Grace period and prompt delay
  { id = "tinker_grace_min", ui_name = "Tinker grace after fusion", ui_description = "Minutes of free tinkering after a fusion", value_default = 1, value_min = 0, value_max = 60, value_display_multiplier = 1, value_display_formatting = " $0 min", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },
  { id = "prompt_delay_frames", ui_name = "Prompt delay ( frames )", ui_description = "Frames to wait before showing the fusion prompt", value_default = 1, value_min = 0, value_max = 60, value_display_multiplier = 1, value_display_formatting = " $0", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },

  -- STATS section
  -- STATS section
  { id = "sep_stats",    ui_name = "", ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_separator, not_setting = true },
  { id = "title_stats",  ui_name = "STATS",                 ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_title,    not_setting = true },
  { id = "improve_pct",  ui_name = "Fusion stat bonus", ui_description = "Extra % applied to stats during fusion", value_default = 10, value_min = 0, value_max = 200, value_display_multiplier = 1, value_display_formatting = " $0 %", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },
  { id = "extra_slots",  ui_name = "Extra slots",      ui_description = "Add extra spell slots to the fused wand", value_default = 1, value_min = 0, value_max = 16, value_display_multiplier = 1, value_display_formatting = " $0", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },
  { id = "plus_spellcast_chance", ui_name = "Chance: +1 spells/cast", ui_description = "Chance to add one extra spell cast per cast", value_default = 20, value_min = 0, value_max = 100, value_display_multiplier = 1, value_display_formatting = " $0 %", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },

  -- FUSION MODE section
  -- FUSION MODE section
  { id = "sep_fusion",   ui_name = "", ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_separator, not_setting = true },
  { id = "title_fusion", ui_name = "FUSION MODE",          ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_title,    not_setting = true },
  { id = "betterstat_mode", ui_name = "Better value handling", ui_description = "Choose how to apply the donor’s better stat", value_default = "0", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "enum", values = {
      { "0", "replace + apply fusion bonus ( % )" },
      { "1", "replace with donor value" },
      { "2", "move toward donor by % of the difference + fusion bonus ( % )" },
      { "3", "move toward donor by % of the difference ( ignore fusion bonus )" }
    } },
  { id = "betterstat_diff_pct", ui_name = "difference percent", ui_description = "Power difference between the donor wand and the target wand", value_default = 10, value_min = 0, value_max = 100, value_display_multiplier = 1, value_display_formatting = " $0 %", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },

  -- SPELLS section
  -- SPELLS section
  { id = "sep_spells",   ui_name = "", ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_separator, not_setting = true },
  { id = "title_spells", ui_name = "SPELLS",               ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_title,    not_setting = true },
  -- Control how donor wand spells are handled. The bool option to keep donor spells
  -- has been removed in favor of this single enum. When a wand is fused, its
  -- spells are never transferred to the new wand; instead they are either dropped
  -- on the ground or deleted entirely. Choose the behavior here:
  { id = "donor_spell_behavior", ui_name = "Stored spells behavior", ui_description = "How to handle spells from the donor wand when fusing", value_default = "0", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "enum", values = {
      { "0", "drop spells to the ground" },
      { "1", "delete spells along with the wand" }
    } },
  { id = "gift_chance_pct", ui_name = "gift chance", ui_description = "Chance to get a reward per draw", value_default = 50, value_min = 0, value_max = 100, value_display_multiplier = 1, value_display_formatting = " $0 %", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },
  { id = "gift_tries", ui_name = "fusions required", ui_description = "Fusions required per reward draw", value_default = 3, value_min = 1, value_max = 20, value_display_multiplier = 1, value_display_formatting = " $0", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },

{ id = "inherit_autocast",
  ui_name = "Autocast inheritance",
  ui_description = "If ON, donor wand's Always Cast spells can be inherited during fusion.",
  value_default = true,
  scope = MOD_SETTING_SCOPE_RUNTIME,
  ui_type = "bool" },
  { id = "autocast_randomization", ui_name = "Autocast inheritance randomization", ui_description = "Chance (in %) that each autocast spell will be replaced by a random one instead of keeping the original.", value_default = 100, value_min = 0, value_max = 100, value_display_multiplier = 1, value_display_formatting = "%", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "slider" },

  -- COSMETIC section
  -- COSMETIC section
  { id = "sep_cosmetic",  ui_name = "", ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_separator, not_setting = true },
  { id = "title_cosmetic", ui_name = "COSMETIC",             ui_description = "", value_default = "", scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "custom", ui_fn = ui_title,    not_setting = true },
  { id = "change_shape", ui_name = "Change shape", ui_description = "Randomize wand sprite on first fusion", value_default = true, scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "bool" },
  { id = "change_name",  ui_name = "Change name",  ui_description = "Give fused wands a generated name and a fusion counter", value_default = true, scope = MOD_SETTING_SCOPE_RUNTIME, ui_type = "bool" },
}

-- Boilerplate ---------------------------------------------------------------
function ModSettingsUpdate(init_scope)
  mod_settings_update(MOD_ID, mod_settings, init_scope)
end

function ModSettingsGuiCount()
  return mod_settings_gui_count(MOD_ID, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
  mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
  -- Spacer so the next mod never overlaps
  GuiLayoutAddVerticalSpacing(gui, 10)
end
