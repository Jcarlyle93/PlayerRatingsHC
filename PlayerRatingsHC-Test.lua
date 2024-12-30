local addonName, addon = ...

local testData = {
    testParty = {
        ["TestPlayer1-Soulseeker"] = true,
        ["TestPlayer2-Soulseeker"] = true,
        ["TestPlayer3-Soulseeker"] = true,
        ["TestPlayer4-Soulseeker"] = true
    },
    testDungeonID = 1234,
    testDungeonName = "Test Dungeon"
}

SLASH_PRATINGTEST1 = "/prtest"
SlashCmdList["PRATINGTEST"] = function(msg)
    print("Running test:", msg)
    if msg == "party" then
        addon.UI.UpdatePartyList(testData.testParty)
        addon.UI.mainFrame:Show()
    elseif msg == "dungeon" then
        addon.Core.UpdateDungeonInfo(testData.testDungeonName, testData.testDungeonID)
    end
end