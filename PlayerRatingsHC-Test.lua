local addonName, addon = ...

if not addon then
  print("Test file error: addon namespace not available")  -- Debug
  return
end

local function NormalizeTestName(name)
  if not string.find(name, "-") then
    local realm = GetNormalizedRealmName()
    if realm then
      print("Adding realm to", name, ":", realm)  -- Debug
      return name .. "-" .. realm
    else
      print("Warning: Could not get realm name for", name)  -- Debug
      return name
    end
  end
  return name
end

local testData = {
  testParty = {
    [NormalizeTestName("Wibber")] = true,
    [NormalizeTestName("Schmaco")] = true,
    [NormalizeTestName("Cowfarther")] = true,
    [NormalizeTestName("Tswift")] = true
  },
  testDungeonID = 6969,
  testDungeonName = "Indelible's Dungeon"
}

addon.Core.SetCurrentDungeonID(testData.testDungeonID)

-- Simulate complete test scenario
local function RunFullTest()
  -- Simulate entering dungeon
  addon.Core.SetCurrentDungeonID(testData.testDungeonID)
  addon.Core.UpdateDungeonInfo(testData.testDungeonName, testData.testDungeonID)
  addon.UI.UpdatePartyList(testData.testParty)
  addon.UI.mainFrame:Show()
 end

print("Test data initialized")  -- Debug

SLASH_PRATINGTEST1 = "/prtest"
SlashCmdList["PRATINGTEST"] = function(msg)
  if msg == "full" then
    print("Running full test scenario")  -- Debug
    RunFullTest()
  elseif msg == "party" then
    addon.UI.UpdatePartyList(testData.testParty)
    addon.Core.UpdateDungeonInfo(testData.testDungeonName, testData.testDungeonID)
    addon.UI.mainFrame:Show()
  else
  print("Running full test scenario")  -- Debug
    RunFullTest()
  end
end