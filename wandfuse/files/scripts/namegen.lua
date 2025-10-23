-- mods/WandFusion/files/scripts/namegen.lua
dofile_once("data/scripts/lib/utilities.lua")
local NameGen = {}
local PREFIXES = {
  "Ancient","Angry","Arcane","Balanced","Baneful","Chaotic","Cunning","Cursed",
  "Elder","Empowered","Enchanted","Fiery","Frigid","Furious","Gilded","Glorious",
  "Grand","Grim","Hallowed","Heavy","Hidden","Infernal","Jeweled","Lesser",
  "Light","Lucky","Majestic","Mighty","Mythic","Mystic","Prime","Primal","Quick",
  "Radiant","Runed","Savage","Seething","Shocking","Small","Soothing","Sorcerous",
  "Spectral","Spiteful","Stalwart","Stormforged","Supreme","Swift","Thundering",
  "Unstable","Vicious","Wicked"
}
local BASE_TYPES = {
  "Wand","Staff","Rod","Scepter","Focus","Catalyst","Conduit","Totem","Twig",
  "Channeler","Talisman","Magestick","Spellbinder","Arc Rod","Rune Wand"
}
local SUFFIXES = {
  "of Flames","of the Glacier","of Storms","of Thunder","of Sparks","of Embers",
  "of the Magus","of the Archon","of Radiance","of Shadows","of Venom","of Rot",
  "of the Void","of Chaos","of Order","of Balance","of Ruin","of Fury","of Grace",
  "of Wisdom","of the Fox","of the Bear","of the Eagle","of the Whale","of Courage",
  "of Malice","of Blessings","of Focus","of Power","of Empower","of Massacre",
  "of Accuracy","of Haste","of Stillness","of Echoes","of the Rift","of Reverie"
}
local function rng(min, max) if Random then return Random(min, max) end return math.random(min, max) end
local function pick(t) return t[rng(1, #t)] end
local function build_name()
  local use_prefix = rng(1,100) <= 70
  local use_suffix = rng(1,100) <= 60
  local base  = pick(BASE_TYPES)
  local name  = base
  if use_prefix then name = pick(PREFIXES) .. " " .. name end
  if use_suffix then name = name .. " " .. pick(SUFFIXES) end
  if rng(1,100) <= 10 then name = name:gsub("Magestick", "Mage Stick") end
  return name
end
function NameGen.generate() return build_name() end
function NameGen.assign_if_missing(wand_entity_id)
  if not wand_entity_id or wand_entity_id == 0 then return end
  local item = EntityGetFirstComponentIncludingDisabled(wand_entity_id, "ItemComponent")
  if not item then return end
  local cur = ComponentGetValue2(item, "item_name") or ""
  if cur and cur ~= "" then return end
  ComponentSetValue2(item, "always_use_item_name_in_ui", true)
  ComponentSetValue2(item, "item_name", build_name())
end
return NameGen
