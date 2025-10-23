-- Shared helpers for Wand Fusion (auto-patched)
function WF_IsWand(eid)
  if not eid then return false end
  local root = EntityGetRootEntity(eid)
  if root == 0 then root = eid end
  if EntityHasTag and EntityHasTag(root, "wand") then return true end
  return EntityGetFirstComponentIncludingDisabled(root, "AbilityComponent") ~= nil
end
