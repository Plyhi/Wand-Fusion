-- mods/WandFusion/files/perk_append.lua
-- Only add the perk to perk pools when the option "enable_perk" is ON.

-- Guard: if the user disabled the perk in mod options, do nothing so it never enters the pools.
do
    local enabled = ModSettingGetNextValue and ModSettingGetNextValue("WandFusion.enable_perk")
    if not enabled then
        return
    end
end

-- If we’re here, the perk is enabled — append it normally.
table.insert(perk_list, {
    id = "WAND_FUSION",
    ui_name = "$wandfusion_perk_name",
    ui_description = "$wandfusion_perk_desc",
    ui_icon = "mods/WandFusion/files/ui/perk_icons/wandfusionperk.png",
    perk_icon = "mods/WandFusion/files/ui/perk_icons/wandfusionperk.png",
    stackable = false,
    func = function(entity_perk_item, entity_who_picked, item_name)
        GlobalsSetValue("WAND_FUSION_PERK_OWNED", "1")
    end,
    remove_func = function(entity_who_picked)
        GlobalsSetValue("WAND_FUSION_PERK_OWNED", "0")
    end,
})
