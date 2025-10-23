local MOD_ID = "WandFusion"

-- Treat common vanilla wand labels as "vanilla-like" so we don't keep them.
function wf_is_vanilla_like(s)
    if s == nil then return true end
    local t = tostring(s)
    if t == "" then return true end
    if t == "DEFAULT_GUN" or t == "default_gun" then return true end
    if t == "$item_wand" or t == "item_wand" then return true end
    if t == "Wand" then return true end
    if t:sub(1,1) == "$" then return true end
    if t:match("^[%u_]+$") then return true end
    if t:match("^[%l_]+$") then return true end
    local low = string.lower(t)
    if low:find("bolt") then return true end
    if low:find("bomb") then return true end
    if low:find("spark") then return true end
    if low:find("rapid") then return true end
    if low:find("shuffle") then return true end
    if low:find("wand") and not low:find(" of ") then return true end
    return false
end
dofile_once("data/scripts/lib/utilities.lua")


local NameGen = dofile_once("mods/WandFusion/files/scripts/namegen.lua")
local MODPATH = "mods/WandFusion/"
local PICKUP_SCRIPT = MODPATH .. "files/pickup_hook.lua"

-- === WandFusion helper: get alignment (grip_x, grip_y, tip_dx, tip_dy) for a wand sprite path ===
local function wf_lookup_alignment(sprite_path)
    if sprite_path == nil or sprite_path == "" then return nil end
    local ok = pcall(function() dofile_once("data/scripts/gun/procedural/wands.lua") end)
    if ok and type(wands) == "table" then
        for i=1,#wands do
            local w = wands[i]
            if w and w.file == sprite_path then
                local gx, gy = w.grip_x or 0, w.grip_y or 0
                local tdx = (w.tip_x or 0) - gx
                local tdy = (w.tip_y or 0) - gy
                return gx, gy, tdx, tdy
            end
        end
    end
    return nil
end
-- === WandFusion helper: copy sprite (or override with PNG) and align shoot tip ===
local function set_wand_sprite(target_wand, donor_wand, override_png)
    if (target_wand or 0) == 0 then return end
    local target_ability = EntityGetFirstComponentIncludingDisabled(target_wand, "AbilityComponent")
    local target_sprite  = EntityGetFirstComponentIncludingDisabled(target_wand, "SpriteComponent", "item")
    local target_tip     = EntityGetFirstComponentIncludingDisabled(target_wand, "HotspotComponent", "shoot_pos")

    local sprite_file, offx, offy, tipx, tipy = "", 0, 0, 0, 0
    if override_png ~= nil and override_png ~= "" then
        sprite_file = override_png
        local gx, gy, tdx, tdy = wf_lookup_alignment(sprite_file)
        if gx ~= nil then
            offx, offy = gx, gy
            tipx, tipy = tdx, tdy
        else
            offx, offy = 2, 2
            tipx, tipy = 8, 0
        end
    elseif (donor_wand or 0) ~= 0 then
        local donor_ability = EntityGetFirstComponentIncludingDisabled(donor_wand, "AbilityComponent")
        if donor_ability ~= nil then
            sprite_file = ComponentGetValue2(donor_ability, "sprite_file") or ""
        end
        local donor_sprite = EntityGetFirstComponentIncludingDisabled(donor_wand, "SpriteComponent", "item")
        if donor_sprite ~= nil then
            if sprite_file == "" then
                sprite_file = ComponentGetValue2(donor_sprite, "image_file") or ""
            end
            offx = ComponentGetValue2(donor_sprite, "offset_x") or 0
            offy = ComponentGetValue2(donor_sprite, "offset_y") or 0
        end
        local donor_tip = EntityGetFirstComponentIncludingDisabled(donor_wand, "HotspotComponent", "shoot_pos")
        if donor_tip ~= nil then
            local dx, dy = ComponentGetValue2(donor_tip, "offset")
            tipx, tipy = dx or 0, dy or 0
        end
    end

    if target_ability ~= nil and sprite_file ~= "" then
        ComponentSetValue2(target_ability, "sprite_file", sprite_file)
    end
    if target_sprite ~= nil and sprite_file ~= "" then
        ComponentSetValue2(target_sprite, "image_file", sprite_file)
        ComponentSetValue2(target_sprite, "offset_x", offx or 0)
        ComponentSetValue2(target_sprite, "offset_y", offy or 0)
        EntityRefreshSprite(target_wand, target_sprite)
    end
    if target_tip ~= nil then
        ComponentSetValue2(target_tip, "offset", tipx or 0, tipy or 0)
    end
end
-- === end helper ===
-- === WandFusion helper: pick a random vanilla wand sprite ===
local function pick_random_wand_sprite(target_wand)
    local x, y = 0, 0
    if (target_wand or 0) ~= 0 then
        x, y = EntityGetTransform(target_wand)
    end
    SetRandomSeed((x or 0) + GameGetFrameNum(), (y or 0) + 1337)
    local idx = Random(0, 1000)
    return string.format("data/items_gfx/wands/wand_%04d.png", idx)
end
-- === end helper ===
-- === WandFusion: fusion naming helpers (clean) ===
local function wf_get_var(ent, name, vtype, default)
    local comps = EntityGetComponentIncludingDisabled(ent, "VariableStorageComponent") or {}
    for _,c in ipairs(comps) do
        if ComponentGetValue2(c, "name") == name then
            if vtype == "int" then return ComponentGetValue2(c, "value_int") or default, c end
            if vtype == "string" then return ComponentGetValue2(c, "value_string") or default, c end
            return default, c
        end
    end
    return default, nil
end

local function wf_set_var(ent, name, vtype, val, handle)
    local c = handle
    if c == nil then
        c = EntityAddComponent(ent, "VariableStorageComponent", {name=name})
    end
    if c ~= nil then
        if vtype == "int" then ComponentSetValue2(c, "value_int", val)
        elseif vtype == "string" then ComponentSetValue2(c, "value_string", val)
        end
    end
    return c
end

local function wf_strip_plus_suffix(s)
    if s == nil then return "", 0 end
    local base, num = string.match(s, "^(.-)%s*%+(%d+)%s*$")
    if base then return (base:gsub("%s+$","")), tonumber(num) or 0 end
    return s, 0
end

local function wf_is_bad_base(s)
    if s == nil then return true end
    if s == "" then return true end
    local t = tostring(s)
    if t == "DEFAULT_GUN" or t == "default_gun" then return true end
    if t == "$item_wand" or t == "item_wand" then return true end
    if t == "Wand" then return true end
    if t:sub(1,1) == "$" then return true end
    if t:match("^[%u_]+$") then return true end  -- token-like (ALLCAPS_UNDERSCORE)
    if t:match("^[%l_]+$") then return true end  -- token-like (lowercase_underscores)
    return false
end

local function wf_derive_base_from_entity(ent)
    local item = EntityGetFirstComponentIncludingDisabled(ent, "ItemComponent")
    local candidate = ""
    if item ~= nil then
        candidate = ComponentGetValue2(item, "item_name") or ""
    end
    if wf_is_bad_base(candidate) then
        local abil = EntityGetFirstComponentIncludingDisabled(ent, "AbilityComponent")
        if abil ~= nil then
            local ui = ComponentGetValue2(abil, "ui_name") or ""
            if ui ~= "" then
                candidate = GameTextGetTranslatedOrNot(ui) or ""
            end
        end
    end
    local base = candidate
    if wf_is_bad_base(base) then
        base = generate_wand_title(ent)
    end
    base = (wf_strip_plus_suffix(base))
    return base
end

local function wf_set_display_name(ent, base, count)
    local item = EntityGetFirstComponentIncludingDisabled(ent, "ItemComponent")
    if item ~= nil then
        local display = base or "Wand"
        if count ~= nil and count > 0 then
            display = (display .. " +" .. tostring(count))
        end
        ComponentSetValue2(item, "item_name", display)
        ComponentSetValue2(item, "always_use_item_name_in_ui", true)
    end
end

local function wf_get_fusion_meta(ent)
    local count, vc = wf_get_var(ent, "wandfusion_count", "int", 0)
    local base,  vb = wf_get_var(ent, "wandfusion_base",  "string", "")
    return count or 0, base or "", vc, vb
end

local function wf_set_fusion_meta(ent, base, count, vc, vb)
    vb = wf_set_var(ent, "wandfusion_base",  "string", base,  vb)
    vc = wf_set_var(ent, "wandfusion_count", "int",    count, vc)
    return vc, vb
end
-- === end helpers ===

-- === WandFusion helper: random name generator ===
local WF_PREFIXES = {
    "Burning","Frozen","Shocking","Venomous","Luminous","Ancient","Cursed","Lucky",
    "Dwarven","Elven","Volcanic","Gilded","Rusty","Meteoric","Clockwork","Quantum",
    "Chaotic","Shimmering","Whispering","Wild","Wicked","Arcane","Eldritch","Prismatic"
}
local WF_CORES = {"Wand","Rod","Staff","Sceptre","Twig","Channel","Focus"}
local WF_SUFFIXES = {
    "Stasis","Entropy","Fortune","Havoc","Silence","Thunder","Pyres","Frost",
    "Tides","Decay","Growth","the Void","the Stars","Alchemy","Echoes","Dreams",
    "Transposition","Shattering","Multiplicity","Chaos","the Depths","Stillness"
}

local function wf_pick(tbl) return tbl[1 + (Random(0, #tbl-1))] end

local function generate_wand_title(ent)
    local x, y = 0, 0
    if (ent or 0) ~= 0 then x, y = EntityGetTransform(ent) end
    SetRandomSeed((x or 0) + GameGetFrameNum(), (y or 0) + 4242)

    -- choose pattern: 0 = "<Core>", 1 = "<Prefix> <Core>", 2 = "<Core> of <Suffix>", 3 = "<Prefix> <Core> of <Suffix>"
    local pattern = Random(0, 3)
    local core = wf_pick(WF_CORES)
    if pattern == 0 then
        return core
    elseif pattern == 1 then
        return wf_pick(WF_PREFIXES) .. " " .. core
    elseif pattern == 2 then
        return core .. " of " .. wf_pick(WF_SUFFIXES)
    else
        return wf_pick(WF_PREFIXES) .. " " .. core .. " of " .. wf_pick(WF_SUFFIXES)
    end
end
-- === end helper ===

function OnModPreInit()

		-- translation
	  ModLuaFileAppend("data/scripts/perks/perk_list.lua", MODPATH .. "files/perk_append.lua")
	
	  local base = ModTextFileGetContent("data/translations/common.csv") or ""
	  local add  = ModTextFileGetContent(MODPATH .. "files/translation.csv") or ""
	  if add ~= "" then
		-- ensure there is a newline between the old file and our first row
		if base ~= "" and base:sub(-1) ~= "\n" then base = base .. "\n" end
		ModTextFileSetContent("data/translations/common.csv", base .. add)
	  end
	  
	
    -- Optionally add Wand Fusion perk
    local enable_perk = ModSettingGetNextValue("WandFusion.enable_perk") or false
    if enable_perk then
        ModLuaFileAppend("data/scripts/perks/perk_list.lua", MODPATH .. "files/perk_append.lua")
    end

    local path = "data/entities/base_wand_pickup.xml"
    local content = ModTextFileGetContent(path) or ""
    if content == "" then return end
    if string.find(content, PICKUP_SCRIPT, 1, true) then return end

    local injection = ([[ 
    <LuaComponent
        _enabled="1"
        script_item_picked_up="%s"
        execute_every_n_frame="-1"
        remove_after_executed="0"
    ></LuaComponent>
    ]]):format(PICKUP_SCRIPT)

    local patched, count = content:gsub("%s*</Entity>%s*$", injection .. "\n</Entity>", 1)
    if count == 1 then
        ModTextFileSetContent(path, patched)
    else
        print("[WandFusion] Failed to patch base_wand_pickup.xml")
    end
end

-- UI state
-- Track quick-inventory wand set across frames (fallback trigger)

local function wf_quick_wand_set(player)
    local set = {}
    if player == 0 then return set end
    local children = EntityGetAllChildren(player) or {}
    for _,c in ipairs(children) do
        if EntityGetName(c) == "inventory_quick" then
            local quick = EntityGetAllChildren(c) or {}
            for _,it in ipairs(quick) do
                if (EntityHasTag ~= nil) and EntityHasTag(it, "wand") then
                    set[it] = true
                end
            end
        end
    end
    return set
end


local function wf_set_to_csv(set)
    local t = {}
    for k,_ in pairs(set) do table.insert(t, tostring(k)) end
    return table.concat(t, ",")
end

local function wf_csv_to_set(s)
    local set = {}
    for id in string.gmatch(s or "", "([^,]+)") do
        local n = tonumber(id)
        if n and n ~= 0 then set[n] = true end
    end
    return set
end

local gui = nil
local ui_open = false
local donor_id = 0
local picker_id = 0

local function get_setting_num(key, default_val)
    local v = ModSettingGetNextValue("WandFusion."..key)
    if v == nil then return default_val end
    return tonumber(v) or default_val
end

local function get_leftmost_equipped_wand(player)
    if player == 0 or not EntityGetIsAlive(player) then return 0 end
    local children = EntityGetAllChildren(player) or {}
    for _,child in ipairs(children) do
        if EntityGetName(child) == "inventory_quick" then
            local quick = EntityGetAllChildren(child) or {}
            for _,it in ipairs(quick) do
                if EntityGetFirstComponentIncludingDisabled(it, "AbilityComponent") ~= nil then
                    return it
                end
            end
        end
    end
    return 0
end

local function drop_child_actions_around(entity_who, wand_entity)
    local px, py = EntityGetTransform(entity_who)
    local children = EntityGetAllChildren(wand_entity) or {}
    local actions = {}
    for _,child in ipairs(children) do
        if EntityGetFirstComponentIncludingDisabled(child, "ItemActionComponent") ~= nil then
            table.insert(actions, child)
        end
    end
    local n = #actions
    if n == 0 then return end
    -- Rain from above with wider horizontal spread
    for i,card in ipairs(actions) do
        SetRandomSeed(GameGetFrameNum() + (px or 0), (py or 0) + 777)
        local dx = (Random(-70,70)) -- wide spread
        local dy = -(28 + Random(0,24)) -- spawn above
        EntityRemoveFromParent(card)
        EntitySetTransform(card, px + dx, py + dy)
        EntitySetComponentsWithTagEnabled(card, "enabled_in_world", true)
        EntitySetComponentsWithTagEnabled(card, "enabled_in_inventory", false)
        local item_comp = EntityGetFirstComponentIncludingDisabled(card, "ItemComponent")
        if item_comp ~= nil then
            ComponentSetValue2(item_comp, "has_been_picked_by_player", false)
            ComponentSetValue2(item_comp, "permanently_attached", false)
        end
    end
end



-- === Always-cast helpers =====================================================
local function wf_collect_always_cast_ids(wand)
    local ids = {}
    if not wand or wand == 0 then return ids end
    local children = EntityGetAllChildren(wand) or {}
    for _,c in ipairs(children) do
        if EntityGetFirstComponentIncludingDisabled(c, "ItemActionComponent") ~= nil then
            local item = EntityGetFirstComponentIncludingDisabled(c, "ItemComponent")
            local perm = false
            if item ~= nil then perm = ComponentGetValue2(item, "permanently_attached") or false end
            if perm then
                local ac = EntityGetFirstComponentIncludingDisabled(c, "ItemActionComponent")
                if ac ~= nil then
                    local id = ComponentGetValue2(ac, "action_id") or ""
                    if id ~= nil and id ~= "" then table.insert(ids, id) end
                end
            end
        end
    end
    return ids
end

local function wf_clear_always_cast(wand)
    if not wand or wand == 0 then return end
    local children = EntityGetAllChildren(wand) or {}
    for _,c in ipairs(children) do
        if EntityGetFirstComponentIncludingDisabled(c, "ItemActionComponent") ~= nil then
            local item = EntityGetFirstComponentIncludingDisabled(c, "ItemComponent")
            local perm = (item ~= nil) and (ComponentGetValue2(item, "permanently_attached") or false)
            if perm then
                EntityKill(c)
            end
        end
    end
end

local function wf_shuffle_list(list, seed_a, seed_b)
    if #list <= 1 then return list end
    if SetRandomSeed ~= nil then SetRandomSeed(seed_a or GameGetFrameNum(), (seed_b or 1337)) end
    for i = #list, 2, -1 do
        local j = Random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function wf_add_always_casts(wand, ids)
    if not wand or wand == 0 then return end
    local x,y = EntityGetTransform(wand)
    for _,id in ipairs(ids or {}) do
        if AddGunActionPermanent ~= nil then
            AddGunActionPermanent(wand, id)
        else
            -- Fallback: spawn a card, mark as permanent, attach to wand
            if CreateItemActionEntity ~= nil then
                local card = CreateItemActionEntity(id, x, y)
                if card ~= nil then
                    local item = EntityGetFirstComponentIncludingDisabled(card, "ItemComponent")
                    if item ~= nil then
                        ComponentSetValue2(item, "permanently_attached", true)
                        ComponentSetValue2(item, "has_been_picked_by_player", true)
                    end
                    EntityAddChild(wand, card)
                end
            end
        end
    end
end
-- === end Always-cast helpers ================================================
-- helper for better stat policy (4 modes)
-- mode 0: replace then apply fusion bonus
-- mode 1: replace only
-- mode 2: % of difference then apply fusion bonus
-- mode 3: % of difference only
-- If donor is NOT better, we still apply the base fusion bonus.
local function apply_better_rule(a, b, better_high, mode, diff_pct, bonus_pct)
    -- Applies the fusion logic for stats that can be either "higher is better" or "lower is better".
    -- "better_high" indicates whether a higher numerical value is desirable for this stat.
    -- "mode" controls how donor values are blended (0=replace+bonus, 1=replace, 2=move towards donor+bonus, 3=move towards donor).
    -- "diff_pct" is used in modes 2/3 and represents the fraction (0..1) of the difference to add.
    -- "bonus_pct" is a flat percentage improvement applied only to the resulting value.

    -- Determine if the donor's value is actually better for this stat.
    local donor_better = (better_high and (b > a)) or ((not better_high) and (b < a))

    -- Helper to apply the flat bonus. For "lower is better" stats, negative values should become more negative
    -- when applying the bonus. Positive values should decrease. For "higher is better" stats, the value always
    -- increases. If no bonus_pct is supplied (0), the value is returned unchanged.
    local function apply_bonus(v)
        if bonus_pct and bonus_pct > 0 then
            if better_high then
                -- Higher is better: simply multiply upwards
                return v * (1 + bonus_pct)
            else
                -- Lower is better: shrink positive numbers, magnify negative numbers
                if v >= 0 then
                    return v * (1 - bonus_pct)
                else
                    return v * (1 + bonus_pct)
                end
            end
        end
        return v
    end

    -- If the donor isn't strictly better, just apply the bonus to the original value.
    if not donor_better then
        return apply_bonus(a)
    end

    -- Blend according to the mode.
    if mode == 0 then
        -- Mode 0: replace with donor and then apply bonus
        return apply_bonus(b)
    elseif mode == 1 then
        -- Mode 1: replace with donor value only (no bonus)
        return b
    elseif mode == 2 then
        -- Mode 2: move towards donor by diff_pct then apply bonus
        local v = a + diff_pct * (b - a)
        return apply_bonus(v)
    else
        -- Mode 3: move towards donor by diff_pct only (no bonus)
        return a + diff_pct * (b - a)
    end
end


-- Append +X to wand name and persist count/base
local function wf_append_plus_name(target, ability)
    if target == 0 or ability == nil then return end
    local item_comp = EntityGetFirstComponentIncludingDisabled(target, "ItemComponent")
    if item_comp == nil then return end

    -- read VSCs
    local count, base = 0, ""
    local vscs = EntityGetComponent(target, "VariableStorageComponent") or {}
    for _,v in ipairs(vscs) do
        local n = ComponentGetValue2(v, "name")
        if n == "wandfusion_count" then count = ComponentGetValue2(v, "value_int") end
        if n == "wandfusion_base" then base = ComponentGetValue2(v, "value_string") end
    end

    -- derive base if empty
    if (base == nil or base == "") then
        base = ComponentGetValue2(item_comp, "item_name") or ""
        if base == nil or base == "" then
            local ui_name = ComponentGetValue(ability, "ui_name") or ""
            if ui_name ~= "" then base = GameTextGetTranslatedOrNot(ui_name) end
            if base == nil or base == "" then base = "Wand" end
        end
    end

    count = (tonumber(count) or 0) + 1
    local newname = string.format("%s +%d", base, count)
    ComponentSetValue2(item_comp, "item_name", newname)
    ComponentSetValue2(item_comp, "always_use_item_name_in_ui", true)

    -- write back VSCs
    local has_count, has_base = false, false
    vscs = EntityGetComponent(target, "VariableStorageComponent") or {}
    for _,v in ipairs(vscs) do
        local n = ComponentGetValue2(v, "name")
        if n == "wandfusion_count" then ComponentSetValue2(v, "value_int", count); has_count = true end
        if n == "wandfusion_base" then ComponentSetValue2(v, "value_string", base); has_base = true end
    end
    if not has_count then
        local vc = EntityAddComponent(target, "VariableStorageComponent", {name="wandfusion_count"})
        if vc ~= nil then ComponentSetValue2(vc, "value_int", count) end
    end
    if not has_base then
        local vb = EntityAddComponent(target, "VariableStorageComponent", {name="wandfusion_base"})
        if vb ~= nil then ComponentSetValue2(vb, "value_string", base) end
    end
end

local function fuse_into_leftmost(player, donor)
    local new_count = 0
    if player == 0 or donor == 0 then return false end
    local target = get_leftmost_equipped_wand(player)
    if target == 0 then
        GamePrint("WandFusion: no target wand found")
        return false
    end

    local ability = EntityGetFirstComponentIncludingDisabled(target, "AbilityComponent")
    if ability == nil then return false end

    -- target (A)
    local mana_max         = ComponentGetValue2(ability, "mana_max")
    local mana_charge      = ComponentGetValue2(ability, "mana_charge_speed")
    local actions_per_round= tonumber(ComponentObjectGetValue(ability, "gun_config", "actions_per_round")) or 1
    local reload_time      = tonumber(ComponentObjectGetValue(ability, "gun_config", "reload_time")) or 0
    local deck_capacity    = tonumber(ComponentObjectGetValue(ability, "gun_config", "deck_capacity")) or 0
    local fire_rate_wait   = tonumber(ComponentObjectGetValue(ability, "gunaction_config", "fire_rate_wait")) or 0
    local spread_degrees   = tonumber(ComponentObjectGetValue(ability, "gunaction_config", "spread_degrees")) or 0
    local speed_multiplier = tonumber(ComponentObjectGetValue(ability, "gunaction_config", "speed_multiplier")) or 1

    -- donor (B)
    local d_ability = EntityGetFirstComponentIncludingDisabled(donor, "AbilityComponent")
    local d_mana_max, d_mana_charge, d_actions, d_reload, d_deck, d_frw, d_spread, d_speedmult = 0,0,0,0,0,0,0,1
    if d_ability ~= nil then
        d_mana_max    = ComponentGetValue2(d_ability, "mana_max")
        d_mana_charge = ComponentGetValue2(d_ability, "mana_charge_speed")
        d_actions     = tonumber(ComponentObjectGetValue(d_ability, "gun_config", "actions_per_round")) or 1
        d_reload      = tonumber(ComponentObjectGetValue(d_ability, "gun_config", "reload_time")) or 0
        d_deck        = tonumber(ComponentObjectGetValue(d_ability, "gun_config", "deck_capacity")) or 0
        d_frw         = tonumber(ComponentObjectGetValue(d_ability, "gunaction_config", "fire_rate_wait")) or 0
        d_spread      = tonumber(ComponentObjectGetValue(d_ability, "gunaction_config", "spread_degrees")) or 0
        d_speedmult   = tonumber(ComponentObjectGetValue(d_ability, "gunaction_config", "speed_multiplier")) or 1
    end

    -- settings
    local mode      = get_setting_num("betterstat_mode", 0)
    local diff_pct  = (get_setting_num("betterstat_diff_pct", 50) or 50) * 0.01
    local bonus_pct = (get_setting_num("improve_pct", 10) or 10) * 0.01
    local extra     = get_setting_num("extra_slots", 1)
    -- chance to gain an additional spells-per-cast
    -- We treat the setting as a percentage directly (0-100). Avoid double
    -- scaling: get_setting_num returns a number (or default), and we compare
    -- Random(1,100) against this value. This fixes the prior behaviour where
    -- the slider always behaved like 100% due to unintended scaling.
    local sc_plus_chance = get_setting_num("plus_spellcast_chance", 20)

    
    -- shuffle rule: keep No Shuffle if either wand has it
    local t_shuffle = tonumber(ComponentObjectGetValue(ability, "gun_config", "shuffle_deck_when_empty")) or 1
    local d_shuffle = (d_ability ~= nil) and (tonumber(ComponentObjectGetValue(d_ability, "gun_config", "shuffle_deck_when_empty")) or t_shuffle) or t_shuffle
    local WFF_SHUFFLE_RESULT = ((t_shuffle == 0) or (d_shuffle == 0)) and 0 or 1
-- compute
    local mana_max_new    = apply_better_rule(mana_max,         d_mana_max,    true,  mode, diff_pct, bonus_pct)
    local mana_charge_new = apply_better_rule(mana_charge,      d_mana_charge, true,  mode, diff_pct, bonus_pct)
    -- actions_per_round is treated specially: we never apply the fusion bonus and instead use donor logic
    local actions_new
    do
        local base_actions  = actions_per_round
        local donor_actions = d_actions
        -- Determine the base new actions value using the fusion mode logic. Modes 0 and 1 replace
        -- with the higher of the two; modes 2 and 3 move a fraction of the difference from base
        -- towards the donor (ceil to int). We never reduce below the original value.
        if mode == 0 or mode == 1 then
            actions_new = math.max(base_actions, donor_actions)
        else
            if donor_actions > base_actions then
                actions_new = base_actions + math.ceil(diff_pct * (donor_actions - base_actions))
            else
                actions_new = base_actions
            end
        end
        -- Apply chance to gain +1 spell cast per cast. The slider specifies a
        -- percentage (0-100). Roll once per fusion. Use player position and
        -- current frame to generate a deterministic random roll. If the roll
        -- succeeds, add +1 to the computed actions. Do nothing if chance is
        -- zero or nil.
        if sc_plus_chance and sc_plus_chance > 0 then
            local px, py = 0, 0
            if player and player ~= 0 then
                px, py = EntityGetTransform(player)
            end
            SetRandomSeed((px or 0) + GameGetFrameNum(), (py or 0) + 999)
            if Random(1, 100) <= sc_plus_chance then
                actions_new = actions_new + 1
            end
        end
    end
    local reload_new      = apply_better_rule(reload_time,      d_reload,      false, mode, diff_pct, bonus_pct)
    local deck_new        = deck_capacity  -- exclude from % rules; only add flat extra slots
    local frw_new         = apply_better_rule(fire_rate_wait,   d_frw,         false, mode, diff_pct, bonus_pct)
    local spread_new      = apply_better_rule(spread_degrees,   d_spread,      false, mode, diff_pct, bonus_pct)
    local speedmult_new   = apply_better_rule(speed_multiplier, d_speedmult,   true,  mode, diff_pct, bonus_pct)

    -- defer cap until autocasts known
    local base_deck_no_ac = math.max(1, math.floor(deck_new + (extra or 0)))
    actions_new   = math.max(1, math.floor(actions_new + 0.5))
    reload_new    = reload_new
    frw_new       = frw_new
    spread_new    = spread_new
    speedmult_new = math.max(0, speedmult_new)
    -- apply shuffle flag
    ComponentObjectSetValue(ability, "gun_config", "shuffle_deck_when_empty", tostring(WFF_SHUFFLE_RESULT))

    -- Always-cast transfer & randomize:
    

local ac_target = wf_collect_always_cast_ids(target)
local ac_donor  = wf_collect_always_cast_ids(donor)
-- Respect toggle: if OFF, do not inherit donor autocasts
local inherit_on = ModSettingGetNextValue("WandFusion.inherit_autocast")
if inherit_on == false then ac_donor = {} end
wf_clear_always_cast(target)
-- === Autocast randomization logic ===
local total_autocast = #ac_target + #ac_donor
local final_autocasts = {}
local randomization = ModSettingGetNextValue("WandFusion.autocast_randomization") or 100

local spell_pool = {}
for _, id in ipairs(ac_target) do table.insert(spell_pool, id) end
for _, id in ipairs(ac_donor) do table.insert(spell_pool, id) end

local all_spells = {}
if actions ~= nil then
  for _, act in ipairs(actions) do
    if act.id ~= nil then table.insert(all_spells, act.id) end
  end
end

for i=1,total_autocast do
  if #spell_pool > 0 and math.random(1,100) > randomization then
    local pick_index = math.random(1, #spell_pool)
    local pick = spell_pool[pick_index]
    table.insert(final_autocasts, pick)
    table.remove(spell_pool, pick_index)
  elseif #all_spells > 0 then
    local new_spell = all_spells[math.random(1, #all_spells)]
    table.insert(final_autocasts, new_spell)
  end
end

-- Adjust deck capacity so Always-Cast spells don't eat into normal slots.
-- We raise both the cap and the value by the number of attached autocasts.
local ac_count_now = #(wf_collect_always_cast_ids(target))
-- Ensure we never regress below the pre-fusion target OR the "base without autocasts".
deck_new = math.max(deck_new, base_deck_no_ac)
-- Final capacity: base + autocasts, capped at (30 + autocasts)
deck_new = math.min(30 + ac_count_now, deck_new + ac_count_now)
wf_add_always_casts(target, final_autocasts)
-- NEVER WORSE GUARD: ensure fusion result is not worse than the pre-fusion target in any stat
    mana_max_new    = math.max(mana_max_new, mana_max)
    mana_charge_new = math.max(mana_charge_new, mana_charge)
    actions_new     = math.max(actions_new, actions_per_round)
    deck_new        = math.max(deck_new, deck_capacity)
    -- lower is better for these:
    reload_new      = math.min(reload_new, reload_time)
    frw_new         = math.min(frw_new, fire_rate_wait)
    spread_new      = math.min(spread_new, spread_degrees)
    -- higher is better:
    speedmult_new   = math.max(speedmult_new, speed_multiplier)


    -- write back
    ComponentSetValue2(ability, "mana_max", mana_max_new)
    ComponentSetValue2(ability, "mana", mana_max_new)
    ComponentSetValue2(ability, "mana_charge_speed", mana_charge_new)
    ComponentObjectSetValue(ability, "gun_config", "actions_per_round", tostring(actions_new))
    ComponentObjectSetValue(ability, "gun_config", "reload_time", tostring(reload_new))
    ComponentObjectSetValue(ability, "gun_config", "deck_capacity", tostring(deck_new))
    ComponentObjectSetValue(ability, "gunaction_config", "fire_rate_wait", tostring(frw_new))
    ComponentObjectSetValue(ability, "gunaction_config", "spread_degrees", tostring(spread_new))
    ComponentObjectSetValue(ability, "gunaction_config", "speed_multiplier", tostring(speedmult_new))

    -- donor behavior
    local donor_behavior = get_setting_num("donor_spell_behavior", 0)
    -- Handle donor spells: if donor_behavior = 0, drop spells; if 1, delete spells. In both cases the donor wand is killed.
    if donor_behavior == 0 then
        drop_child_actions_around(player, donor)
    end
    -- Always kill the donor after handling its spells
    EntityKill(donor)
    -- === WandFusion: randomize appearance after fusion (only on first-ever fusion) ===
    do
        -- Respect the change_shape setting: skip randomization when false. If nil, treat as true.
        local change_shape = ModSettingGetNextValue("WandFusion.change_shape")
        if change_shape == nil or change_shape then
            local pre_count = 0
            do
                local c, _ = wf_get_var(target, "wandfusion_count", "int", 0)
                pre_count = c or 0
            end
            -- Only randomize sprite when this is the first fusion on this wand
            if pre_count == 0 then
                local random_png = pick_random_wand_sprite(target)
                set_wand_sprite(target, 0, random_png)
            end
        end
    end
    -- === end randomize appearance ===

    local px, py = EntityGetTransform(player)
    
-- === WandFusion: fusion counter & name tagging (clean) ===
do
    -- read pre-count & base (stored)
    local pre_count, saved_base, vc, vb = wf_get_fusion_meta(target)

    -- lock/generate base on first fusion; otherwise keep saved
    if pre_count == 0 then
        saved_base = wf_derive_base_from_entity(target)
    end
    if saved_base == nil or saved_base == "" or wf_is_vanilla_like(saved_base) then
        saved_base = (NameGen and NameGen.generate and NameGen.generate()) or "Wand"
    end

    -- donor carried count
    local donor_count = 0
    do
        local dc, _ = wf_get_var(donor, "wandfusion_count", "int", 0)
        donor_count = dc or 0
    end

    -- new total
        new_count = (pre_count or 0) + 1 + (donor_count or 0)

    -- persist & show
    vc, vb = wf_set_fusion_meta(target, saved_base, new_count, vc, vb)
    -- Respect the change_name setting: only update the display name when enabled
    do
        local change_name = ModSettingGetNextValue("WandFusion.change_name")
        if change_name == nil or change_name then
            wf_set_display_name(target, saved_base, new_count)
        end
    end
end
-- === end name tagging ===

GamePrintImportant("Wand fused", string.format("mode %d, +%d slots", mode, extra or 0))
    EntityLoad("data/entities/particles/image_emitters/wand_effect.xml", px, py)

    -- tinker grace
    local grace_minutes = get_setting_num("tinker_grace_min", 1)
    if grace_minutes ~= nil and grace_minutes > 0 then
        local frames = math.floor(grace_minutes * 60 * 60)
        local effect = EntityLoad("data/entities/misc/effect_edit_wands_everywhere.xml", px, py)
        if effect ~= nil and effect ~= 0 then
            local gec = EntityGetFirstComponentIncludingDisabled(effect, "GameEffectComponent")
            if gec ~= nil then ComponentSetValue2(gec, "frames", frames) end
            EntityAddChild(player, effect)
            GamePrintImportant("Tinker grace", string.format("Wand editing enabled for %d min", grace_minutes))
        end
    end

    
-- Gift: randomized per-try spawning
do
    local chance = math.max(0, math.min(100, get_setting_num("gift_chance_pct", 0) or 0))
    local tries  = math.max(1, math.floor(get_setting_num("gift_tries", 3)+0.5))
    if new_count % tries == 0 and chance > 0 then
        dofile_once("data/scripts/gun/gun_actions.lua")
        local gx, gy = EntityGetTransform(player)
        SetRandomSeed(GameGetFrameNum(), gx + gy + (donor or 0))
        local pool = actions or {}
           if Random(1,100) <= chance and (#pool > 0) then
                local idx = Random(1, #pool)
                local action_id = pool[idx].id or "LIGHT_BULLET"
                if CreateItemActionEntity ~= nil then
                    CreateItemActionEntity(action_id, gx + Random(-12,12), gy - (18 + Random(0,16)))
                end
            end
     end
end
        return true
end

function OnWorldPostUpdate()
    -- Fallback: if pickup hook missed (e.g., enemies repeatedly picked the wand), detect newly added wand in quick inventory
    do
        local player = EntityGetWithTag("player_unit")[1] or 0
        if player ~= 0 then
            local now = wf_quick_wand_set(player)
            local prev_csv = GlobalsGetValue("WAND_FUSION_QSET", "")
            -- If this is the first time tracking wands this run (prev_csv is empty),
            -- initialize the quick set and skip scheduling fusion. Without this guard
            -- the fallback would treat the starting wands as a newly added wand and
            -- immediately open the fusion prompt on game start.
            if prev_csv == "" then
                GlobalsSetValue("WAND_FUSION_QSET", wf_set_to_csv(now))
            else
                local prev = wf_csv_to_set(prev_csv)
                -- detect addition
                local added = nil
                local count_now, count_prev = 0, 0
                for _ in pairs(now) do count_now = count_now + 1 end
                for _ in pairs(prev) do count_prev = count_prev + 1 end
                if count_now > count_prev then
                    for id,_ in pairs(now) do if not prev[id] then added = id break end end
                    if added ~= nil then
                        -- schedule fusion prompt if not already pending, require 2+ wands
                        local function count_quick_wands() return count_now end
                        local need_perk = (ModSettingGetNextValue("WandFusion.enable_perk") == true)
                        local has_perk = (GlobalsGetValue("WAND_FUSION_PERK_OWNED", "0") == "1")
                        if (not need_perk) or has_perk then
                            if GlobalsGetValue("WAND_FUSION_PENDING", "0") ~= "1" and count_quick_wands() >= 2 then
                                GlobalsSetValue("WAND_FUSION_PENDING", "1")
                                GlobalsSetValue("WAND_FUSION_DONOR", tostring(added))
                                GlobalsSetValue("WAND_FUSION_PICKER", tostring(player))
                                local delay = ModSettingGetNextValue("WandFusion.prompt_delay_frames") or 1
                                delay = tonumber(delay) or 1
                                GlobalsSetValue("WAND_FUSION_OPEN_FRAME", tostring(GameGetFrameNum() + math.max(0, delay)))
                            end
                        end
                    end
                end
                -- Update QSET with current wand set
                GlobalsSetValue("WAND_FUSION_QSET", wf_set_to_csv(now))
            end
        end
    end

    local pending = GlobalsGetValue("WAND_FUSION_PENDING", "0")
if pending == "1" then
        local open_at = tonumber(GlobalsGetValue("WAND_FUSION_OPEN_FRAME", "0")) or 0
        if GameGetFrameNum() >= open_at then
            local new_donor_id = tonumber(GlobalsGetValue("WAND_FUSION_DONOR", "0")) or 0
            local new_picker_id = tonumber(GlobalsGetValue("WAND_FUSION_PICKER", "0")) or 0
            if new_donor_id ~= 0 and new_picker_id ~= 0 then
                donor_id = new_donor_id
                picker_id = new_picker_id
                ui_open = true
            end
            GlobalsSetValue("WAND_FUSION_PENDING", "0")
        end
    end

    if not ui_open then return end
    if gui == nil then gui = GuiCreate() end
    GuiStartFrame(gui)

-- draw in white,text on top,prompt at bottom
    GuiZSet(gui, 100000)
    GuiBeginAutoBox(gui)
    GuiLayoutBeginVertical(gui, 50, 90)
    GuiColorSetForNextWidget(gui, 1,1,1,1)
    GuiZSetForNextWidget(gui, 1)
    GuiText(gui, 0, 0, "Fuse wand?")
    GuiLayoutBeginHorizontal(gui, 0, 0, false, 4, 0)
        GuiColorSetForNextWidget(gui, 1,1,1,1)
        GuiZSetForNextWidget(gui, 1)
    	local yes = GuiButton(gui, 2001, 0, 0, "Yes")
        GuiColorSetForNextWidget(gui, 1,1,1,1)
        GuiZSetForNextWidget(gui, 1)
    	local no  = GuiButton(gui, 2002, 0, 0, "No")
    GuiLayoutEnd(gui)
    GuiLayoutEnd(gui)
    GuiColorSetForNextWidget(gui, 1,1,1,1)
    GuiEndAutoBoxNinePiece(gui)


    if yes then
        fuse_into_leftmost(picker_id, donor_id)
        ui_open = false
        donor_id = 0
        picker_id = 0
    elseif no then
        ui_open = false
        donor_id = 0
        picker_id = 0
    end
end


-- === Updated slot capacity logic (robust) ===
do
  local function get_deck_capacity(entity)
    local comps = EntityGetComponentIncludingDisabled(entity, "AbilityComponent") or {}
    for _, c in ipairs(comps) do
      local capacity = ComponentGetValue2(c, "deck_capacity")
      if capacity and capacity > 0 then return capacity end
    end
    return 0
  end

  local slot_bonus = ModSettingGetNextValue("WandFusion.extra_slots") or 1
  local slots_A = get_deck_capacity(target)
  local slots_B = get_deck_capacity(donor)
  local ac_count_now = #(wf_collect_always_cast_ids(target))
  local new_slots = math.min(30 + ac_count_now, math.max(slots_A, slots_B) + slot_bonus + ac_count_now)

  local comps_target = EntityGetComponentIncludingDisabled(target, "AbilityComponent") or {}
  for _, c in ipairs(comps_target) do
    ComponentSetValue2(c, "deck_capacity", new_slots)
  end
end

