local CreateFrame = CreateFrame
local pairs = pairs
local strlen = strlen
local format = string.format
local GameTooltip = GameTooltip

local BACKDROP_MAIN = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local BACKDROP_SECONDARY = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local FRAME_WIDTH = 300
local FRAME_WIDTH_EXPANDED = 600
local FRAME_HEIGHT = 400
local ENTRY_HEIGHT = 25
local SPACING = 5

local addonName, addon = ...

local bewareUI = {
    listContentFrame = nil,
    frame = nil,
    title = nil,
    nameBox = nil,
    noteLabel = nil,
    charCounter = nil,
    noteBoxBackground = nil,
    noteBox = nil,
    addButton = nil,
    scrollFrame = nil,
    closeButton = nil,
    activeNotePanel = nil
}

local function HideNotePanel()
    if bewareUI.activeNotePanel then
        bewareUI.activeNotePanel:Hide()
        bewareUI.activeNotePanel = nil
    end
end

local function CreateNotePanel(frame, playerName, noteText)
    local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    panel:SetSize(290, frame:GetHeight() - 20)
    panel:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    panel:SetBackdrop(BACKDROP_SECONDARY)
    panel:SetBackdropColor(0, 0, 0, 0.5)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(format("Notes for %s", playerName))

    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
    text:SetText(noteText)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)

    return panel
end

local function UpdateBewareList()
    local listFrame = bewareUI.listContentFrame
    if not listFrame then return end

    local children = {listFrame:GetChildren()}
    for i = 1, #children do
        children[i]:Hide()
        children[i]:SetParent(nil)
    end

    local yOffset = -SPACING
    for playerName, data in pairs(PlayerRatingsHCDB.playerBewareList) do
        local entry = CreateFrame("Frame", nil, listFrame, "BackdropTemplate")
        entry:SetSize(230, ENTRY_HEIGHT)
        entry:SetPoint("TOP", 0, yOffset)

        local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", SPACING, 0)
        nameText:SetText(playerName)

        local addedByText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        addedByText:SetPoint("RIGHT", -25, 0)
        addedByText:SetText(format("Added by: %s", data.addedBy))

        if data.note and data.note ~= "" then
            local noteButton = CreateFrame("Button", nil, entry)
            noteButton:SetSize(16, 16)
            noteButton:SetPoint("LEFT", nameText, "RIGHT", 0, 0)
            noteButton:SetNormalTexture("Interface/Buttons/UI-GuildButton-PublicNote-Up")

            noteButton:SetScript("OnClick", function()
                if bewareUI.frame:GetWidth() == FRAME_WIDTH then
                    bewareUI.frame:SetWidth(FRAME_WIDTH_EXPANDED)
                    bewareUI.frame:ClearAllPoints()
                    bewareUI.frame:SetPoint("LEFT", UIParent, "CENTER", -150, 0)

                    HideNotePanel()
                    bewareUI.activeNotePanel = CreateNotePanel(bewareUI.frame, playerName, data.note)
                    bewareUI.activeNotePanel:Show()
                else
                    bewareUI.frame:SetWidth(FRAME_WIDTH)
                    bewareUI.frame:ClearAllPoints()
                    bewareUI.frame:SetPoint("CENTER")
                    HideNotePanel()
                end
            end)

            noteButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Click to view notes")
                GameTooltip:Show()
            end)
            noteButton:SetScript("OnLeave", GameTooltip.Hide)
        end

        local removeButton = CreateFrame("Button", nil, entry)
        removeButton:SetSize(16, 16)
        removeButton:SetPoint("RIGHT", -SPACING, 0)
        removeButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        removeButton:SetScript("OnClick", function()
            if addon.Core.RemoveFromBewareList(playerName) then
                UpdateBewareList()
            end
        end)

        yOffset = yOffset - 30
    end
end

local function CreateBewareListUI()
  local frame = CreateFrame("Frame", "PlayerBewareWindow", UIParent, "BackdropTemplate")
  bewareUI.frame = frame
  frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  frame:SetPoint("CENTER")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetBackdrop(BACKDROP_MAIN)
  frame:SetBackdropColor(0, 0, 0, 0.8)

  frame:SetScript("OnMouseDown", function(self, button)
      if button == "LeftButton" then self:StartMoving() end
  end)

  frame:SetScript("OnMouseUp", function(self, button)
      if button == "LeftButton" then self:StopMovingOrSizing() end
  end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.title = title
  title:SetPoint("TOP", 0, -10)
  title:SetText("Player Beware List")

  local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  bewareUI.nameBox = nameBox
  nameBox:SetSize(200, 20)
  nameBox:SetPoint("TOP", title, "BOTTOM", 0, -20)
  nameBox:SetAutoFocus(false)

  local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.noteLabel = noteLabel
  noteLabel:SetPoint("TOP", nameBox, "BOTTOM", 0, -10)
  noteLabel:SetText("Note (optional, max 150):")

  local charCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.charCounter = charCounter
  charCounter:SetPoint("TOPRIGHT", nameBox, "BOTTOMRIGHT", 0, -10)
  charCounter:SetText("150")

  local noteBoxBackground = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  bewareUI.noteBoxBackground = noteBoxBackground
  noteBoxBackground:SetSize(200, 60)
  noteBoxBackground:SetPoint("TOP", noteLabel, "BOTTOM", 0, -5)
  noteBoxBackground:SetBackdrop(BACKDROP_SECONDARY)
  noteBoxBackground:SetBackdropColor(0, 0, 0, 0.5)

  local noteBox = CreateFrame("EditBox", nil, noteBoxBackground)
  bewareUI.noteBox = noteBox
  noteBox:SetMultiLine(true)
  noteBox:SetMaxLetters(150)
  noteBox:SetFontObject("GameFontNormal")
  noteBox:SetSize(200, 50)
  noteBox:SetPoint("TOPLEFT", noteBoxBackground, "TOPLEFT", 5, -5)
  noteBox:SetPoint("BOTTOMRIGHT", noteBoxBackground, "BOTTOMRIGHT", -5, 5)
  noteBox:SetAutoFocus(false)
  noteBox:EnableMouse(true)
  noteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  noteBox:SetScript("OnTextChanged", function(self)
      charCounter:SetText(150 - strlen(self:GetText()))
  end)

  -- Add Button
  local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  bewareUI.addButton = addButton
  addButton:SetSize(80, 25)
  addButton:SetPoint("TOP", noteBox, "BOTTOM", 0, -5)
  addButton:SetText("Add")
  addButton:SetScript("OnClick", function()
      local name = nameBox:GetText()
      local note = noteBox:GetText()
      if name and name ~= "" then
          if addon.Core.AddToBewareList(name, note) then
              nameBox:SetText("")
              noteBox:SetText("")
              UpdateBewareList()
          end
      end
  end)

  -- Scroll Frame
  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  bewareUI.scrollFrame = scrollFrame
  scrollFrame:SetSize(230, 280)
  scrollFrame:SetPoint("TOP", addButton, "BOTTOM", 0, -10)

  -- Close Button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  bewareUI.closeButton = closeButton
  closeButton:SetPoint("TOPRIGHT", -3, -3)
  closeButton:SetScript("OnClick", function() 
      frame:Hide()
      HideNotePanel()
  end)

  -- List Content Frame
  bewareUI.listContentFrame = CreateFrame("Frame", nil, scrollFrame)
  bewareUI.listContentFrame:SetSize(230, 280)
  scrollFrame:SetScrollChild(bewareUI.listContentFrame)

  -- Frame Scripts
  frame:SetScript("OnHide", function()
      frame:EnableMouse(false)
      HideNotePanel()
  end)

  frame:SetScript("OnShow", function()
      frame:EnableMouse(true)
      UpdateBewareList()
  end)

  frame:Hide()
  return frame
end

addon.BewareUI = {
  CreateBewareListUI = CreateBewareListUI
}

SLASH_PLAYERBEWARE1 = "/beware"
SlashCmdList["PLAYERBEWARE"] = function(msg)
  if not addon.bewareFrame then
      addon.bewareFrame = CreateBewareListUI()
  end
  addon.bewareFrame:Show()
end