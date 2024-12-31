local addonName, addon = ...

if not addon then
  print("Test file error: addon namespace not available")
  return
end

local testData = {
  testParty = {
    ["Wibber"] = true,
    ["Schmaco"] = true,
    ["Cowfarther"] = true,
    ["Tswift"] = true,
    ["Indelible"] = true
  },
  testDungeonID = 1337,
  testDungeonName = "Indelible's Dungeon"
}

-- Simulate complete test scenario
local function RunFullTest()
  -- Simulate entering dungeon
  addon.Core.SetCurrentDungeonID(testData.testDungeonID)
  addon.Core.UpdateDungeonInfo(testData.testDungeonName, testData.testDungeonID)
  addon.UI.UpdatePartyList(testData.testParty)
  addon.UI.mainFrame:Show()
 end

print("Test data initialized")

SLASH_PRATINGTEST1 = "/prtest"
SlashCmdList["PRATINGTEST"] = function(msg)
  if msg == "full" then
    print("Running full test scenario")
    RunFullTest()
  elseif msg == "party" then
    addon.UI.UpdatePartyList(testData.testParty)
    addon.Core.UpdateDungeonInfo(testData.testDungeonName, testData.testDungeonID)
    addon.UI.mainFrame:Show()
  else
  print("Running full test scenario")
    RunFullTest()
  end
end