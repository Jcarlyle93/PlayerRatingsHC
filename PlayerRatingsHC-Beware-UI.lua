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
  bewareUI.currentNoteEntry = currentEntry
    
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

  local activeNotePlayerName = nil
  if bewareUI.activeNotePanel then
      activeNotePlayerName = bewareUI.activeNotePanel.playerName
  end

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

    if data.notes and data.notes ~= "" then
      local noteButton = CreateFrame("Button", nil, entry)
      noteButton:SetSize(16, 16)
      noteButton:SetPoint("LEFT", nameText, "RIGHT", 0, 0)
      noteButton:SetNormalTexture("Interface/Buttons/UI-GuildButton-PublicNote-Up")
      entry.noteButton = noteButton

      noteButton:SetScript("OnClick", function()
        local currentWidth = math.floor(bewareUI.frame:GetWidth() + 0.5)
      
        if bewareUI.activeNotePanel and bewareUI.activeNotePanel.playerName == playerName then
          bewareUI.activeNotePanel:Hide()
          bewareUI.activeNotePanel = nil
          bewareUI.frame:SetWidth(FRAME_WIDTH)
          return
        end

        if currentWidth <= FRAME_WIDTH + 1 then
          bewareUI.frame:SetWidth(FRAME_WIDTH_EXPANDED)
        end
          
        if bewareUI.activeNotePanel then
          bewareUI.activeNotePanel:Hide()
          bewareUI.activeNotePanel = nil
        end
    
        local notePanel = CreateFrame("Frame", nil, bewareUI.frame, "BackdropTemplate")
        notePanel:SetSize(290, bewareUI.frame:GetHeight() - 40)
        notePanel:SetPoint("BOTTOMRIGHT", bewareUI.frame, "BOTTOMRIGHT", -10, 10)
        notePanel:SetBackdrop(BACKDROP_SECONDARY)
        notePanel:SetBackdropColor(0, 0, 0, 0.5)
    
        local title = notePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("BOTTOMLEFT", notePanel, "TOPLEFT", 10, 5)
        title:SetText(format("Notes for %s", playerName))
    
        local yOffset = -10
        if data.notes then
          for _, noteData in ipairs(data.notes) do
            local noteContainer = CreateFrame("Frame", nil, notePanel)
            noteContainer:SetSize(270, 30)
            noteContainer:SetPoint("TOPLEFT", notePanel, "TOPLEFT", 10, yOffset)
            
            local noteText = noteContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noteText:SetPoint("TOPLEFT")
            noteText:SetPoint("TOPRIGHT", -25, 0)
            noteText:SetText(noteData.text)
            noteText:SetJustifyH("LEFT")
            noteText:SetWordWrap(true)
            
            local addedBy = noteContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            addedBy:SetPoint("TOPLEFT", noteText, "BOTTOMLEFT", 0, -2)
            addedBy:SetText(format("Added by: %s", noteData.addedBy))
            addedBy:SetTextColor(0.7, 0.7, 0.7)

            if noteData.addedBy == UnitName("player") then
              local removeButton = CreateFrame("Button", nil, noteContainer)
              removeButton:SetSize(16, 16)
              removeButton:SetPoint("RIGHT", 0, 0)
              removeButton:SetNormalTexture("Interface/Buttons/UI-StopButton")
              removeButton:SetScript("OnClick", function()
                addon.Core.RemoveNote(playerName, noteData)
                bewareUI.activeNotePanel:Hide()
                bewareUI.activeNotePanel = nil
                noteButton:GetScript("OnClick")()
              end)
            end
            
            yOffset = yOffset - 50
          end
          bewareUI.activeNotePanel = notePanel
          bewareUI.activeNotePanel:Show()
        end
      end)

      noteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to view notes")
        GameTooltip:Show()
      end)
      noteButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
      end)
    end

    local addedByText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addedByText:SetPoint("RIGHT", -25, 0)
    addedByText:SetText(format("Added by: %s", data.addedBy))
    
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
 
  local mainContentPanel = CreateFrame("Frame", nil, frame)
  mainContentPanel:SetSize(FRAME_WIDTH - 20, FRAME_HEIGHT - 20)
  mainContentPanel:SetPoint("LEFT", frame, "LEFT", 10, 0)
  bewareUI.mainContentPanel = mainContentPanel
 
  local title = mainContentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.title = title
  title:SetPoint("TOP", mainContentPanel, "TOP", 0, -10)
  title:SetText("Player Beware List")

  local nameLabel = mainContentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.nameLabel = nameLabel
  nameLabel:SetPoint("TOP", title, "TOP", 0, -20) 
  nameLabel:SetText("Player Name:")

  local nameBox = CreateFrame("EditBox", nil, mainContentPanel, "InputBoxTemplate")
  bewareUI.nameBox = nameBox
  nameBox:SetSize(230, 20)
  nameBox:SetPoint("TOP", nameLabel, "BOTTOM", 0, -5)
  nameBox:SetAutoFocus(false)

  local noteLabel = mainContentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.noteLabel = noteLabel
  noteLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
  noteLabel:SetText("Note (optional, max 150):")
 
  local charCounter = mainContentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bewareUI.charCounter = charCounter
  charCounter:SetPoint("TOPRIGHT", nameBox, "BOTTOMRIGHT", 0, -10)
  charCounter:SetText("150")

  local noteBoxBackground = CreateFrame("Frame", nil, mainContentPanel, "BackdropTemplate")
  bewareUI.noteBoxBackground = noteBoxBackground
  noteBoxBackground:SetSize(230, 60)
  noteBoxBackground:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -5)
  noteBoxBackground:SetBackdrop(BACKDROP_SECONDARY)
  noteBoxBackground:SetBackdropColor(0, 0, 0, 0.5)
 
  local noteBox = CreateFrame("EditBox", nil, noteBoxBackground)
  bewareUI.noteBox = noteBox
  noteBox:SetMultiLine(true)
  noteBox:SetMaxLetters(150)
  noteBox:SetFontObject("GameFontNormal")
  noteBox:SetSize(230, 50)
  noteBox:SetPoint("TOPLEFT", noteBoxBackground, "TOPLEFT", 5, -5)
  noteBox:SetPoint("BOTTOMRIGHT", noteBoxBackground, "BOTTOMRIGHT", -5, 5)
  noteBox:SetAutoFocus(false)
  noteBox:EnableMouse(true)
  noteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  noteBox:SetScript("OnTextChanged", function(self)
    charCounter:SetText(150 - strlen(self:GetText()) .. " Remaning")
  end)

  local addButton = CreateFrame("Button", nil, mainContentPanel, "UIPanelButtonTemplate")
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

  local scrollFrame = CreateFrame("ScrollFrame", nil, mainContentPanel, "UIPanelScrollFrameTemplate")
  bewareUI.scrollFrame = scrollFrame
  scrollFrame:SetSize(230, 180)
  scrollFrame:SetPoint("TOP", addButton, "BOTTOM", 0, -10)

  bewareUI.listContentFrame = CreateFrame("Frame", nil, scrollFrame)
  bewareUI.listContentFrame:SetSize(230, 280)
  scrollFrame:SetScrollChild(bewareUI.listContentFrame)
 
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  bewareUI.closeButton = closeButton
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
  closeButton:SetScript("OnClick", function() 
    frame:Hide()
    if bewareUI.activeNotePanel then
      bewareUI.activeNotePanel:Hide()
      bewareUI.frame:SetWidth(FRAME_WIDTH)
    end
  end)
 
  frame:SetScript("OnHide", function()
    frame:EnableMouse(false)
    if bewareUI.activeNotePanel then
      bewareUI.activeNotePanel:Hide()
    end
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