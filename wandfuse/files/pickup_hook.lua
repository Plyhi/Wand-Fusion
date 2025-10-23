-- mods/WandFusion/files/pickup_hook.lua
-- Save as UTF-8 (no BOM), LF
dofile_once("data/scripts/lib/utilities.lua")


local function is_wand(eid)
    if not eid or eid == 0 then return false end
    local root = EntityGetRootEntity(eid)
    if root == 0 then root = eid end
    return (EntityHasTag ~= nil) and (EntityHasTag(root, "wand") == true)
end


function item_pickup(entity_item, entity_who_picked, name)
    -- Only react to player pickups
    if (EntityHasTag == nil) or (not EntityHasTag(entity_who_picked, "player_unit")) then return end
    -- Donor must be a wand
    if not is_wand(entity_item) then return end

    -- Need at least two equipped wands (so there is a target to fuse into)
    local function count_equipped_wands(player)
        if player == 0 then return 0 end
        local cnt = 0
        local children = EntityGetAllChildren(player) or {}
        for _,c in ipairs(children) do
            if EntityGetName(c) == "inventory_quick" then
                local quick = EntityGetAllChildren(c) or {}
                for _,it in ipairs(quick) do
                    if EntityGetFirstComponentIncludingDisabled(it, "AbilityComponent") ~= nil then
                        cnt = cnt + 1
                    end
                end
            end
        end
        return cnt
    end
    if count_equipped_wands(entity_who_picked) < 2 then return end

    -- Optional perk gate
    local need_perk = (ModSettingGetNextValue("WandFusion.enable_perk") == true)
    if need_perk and (GlobalsGetValue("WAND_FUSION_PERK_OWNED", "0") ~= "1") then
        return
    end

    -- Open fusion prompt after a configurable delay
    GlobalsSetValue("WAND_FUSION_PENDING", "1")
    GlobalsSetValue("WAND_FUSION_DONOR", tostring(entity_item or 0))
    GlobalsSetValue("WAND_FUSION_PICKER", tostring(entity_who_picked or 0))
    local delay = tonumber(ModSettingGetNextValue("WandFusion.prompt_delay_frames") or 1) or 1
    GlobalsSetValue("WAND_FUSION_OPEN_FRAME", tostring(GameGetFrameNum() + math.max(0, delay)))
end
