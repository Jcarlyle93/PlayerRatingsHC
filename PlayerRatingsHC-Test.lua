local addonName, addon = ...

if not addon then
  print("Test file error: addon namespace not available")
  return
end

local testData = {
  testParty = {
    ["TestPlayer1"] = true,
    ["TestPlayer2"] = true,
    ["TestPlayer3"] = true,
    ["TestPlayer4"] = true
  },
  testDungeonID = 1234,
  testDungeonName = "Test Dungeon"
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
   addon.UI.mainFrame:Show()
 elseif msg == "dungeon" then
   addon.Core.UpdateDungeonInfo(testData.testDungeonName, testData.testDungeonID)
 end
end