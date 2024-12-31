local addonName, addon = ...

local bewareUI = {
  listContentFrame = nil,
  frame = nil
}

local function UpdateBewareList()
  if not bewareUI.listContentFrame then
    return 
  end

  local children = {bewareUI.listContentFrame:GetChildren()}
  for _, child in pairs(children) do
    child:Hide()
  end

  local yOffset = -5
  for playerName, data in pairs(PlayerRatingsHCDB.playerBewareList) do
    local entry = CreateFrame("Frame", nil, bewareUI.listContentFrame, "BackdropTemplate")
    entry:SetSize(230, 25)
    entry:SetPoint("TOP", 0, yOffset)
    
    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 5, 0)
    nameText:SetText(playerName)

    if data.note and data.note ~= "" then
      print("Creating note button for", playerName, "with note:", data.note)  -- Debug print
      
      local noteButton = CreateFrame("Button", nil, entry)
      noteButton:SetSize(16, 16)
      noteButton:SetPoint("LEFT", nameText, "RIGHT", 0, 0)
      noteButton:SetNormalTexture("Interface/Buttons/UI-GuildButton-PublicNote-Up")
      noteButton:SetScript("OnClick", function()
        if bewareUI.frame:GetWidth() == 300 then
          bewareUI.frame:SetWidth(600)
          if not entry.notePanel then
            entry.notePanel = CreateFrame("Frame", nil, bewareUI.frame, "BackdropTemplate")
            entry.notePanel:SetSize(270, bewareUI.frame:GetHeight())
            entry.notePanel:SetPoint("RIGHT", 0, 0)

            local noteText = entry.notePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noteText:SetPoint("TOPLEFT", 10, -10)
            noteText:SetPoint("BOTTOMRIGHT", -10, 10)
            noteText:SetText(data.note)
            noteText:SetJustifyH("LEFT")

            bewareUI.listContentFrame:SetSize(230, 280)
            bewareUI.listContentFrame:SetPoint("LEFT", bewareUI.frame, "LEFT", -10, -30)
          end
          entry.notePanel:Show()
        else
          bewareUI.frame:SetWidth(300)
          if entry.notePanel then
            entry.notePanel:Hide()
          end
        end
      end)

      noteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to view notes")
        GameTooltip:Show()
      end)
      noteButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    end

    local addedByText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addedByText:SetPoint("RIGHT", -25, 0)
    addedByText:SetText("Added by: " .. data.addedBy)
    
    local removeButton = CreateFrame("Button", nil, entry)
    removeButton:SetSize(16, 16)
    removeButton:SetPoint("RIGHT", -5, 0)
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
  frame:SetSize(300, 400)
  frame:SetPoint("CENTER")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  
  frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  frame:SetBackdropColor(0, 0, 0, 0.8)

  frame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self:StartMoving()
    end
  end)

  frame:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      self:StopMovingOrSizing()
    end
  end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Player Beware List")

  local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  nameBox:SetSize(200, 20)
  nameBox:SetPoint("TOP", title, "BOTTOM", 0, -20)
  nameBox:SetAutoFocus(false)

  local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  noteLabel:SetPoint("TOP", nameBox, "BOTTOM", 0, -10)
  noteLabel:SetText("Note (optional, max 150):")

  local charCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  charCounter:SetPoint("TOPRIGHT", nameBox, "BOTTOMRIGHT", 0, -10)
  charCounter:SetText("150")

  local noteBoxBackground = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  noteBoxBackground:SetSize(200, 60)
  noteBoxBackground:SetPoint("TOP", noteLabel, "BOTTOM", 0, -5)
  noteBoxBackground:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  noteBoxBackground:SetBackdropColor(0, 0, 0, 0.5)
  
  local noteBox = CreateFrame("EditBox", nil, noteBoxBackground)
  noteBox:SetMultiLine(true)
  noteBox:SetMaxLetters(150)
  noteBox:SetFontObject("GameFontNormal")
  noteBox:SetSize(200, 50)  -- Slightly smaller than background
  noteBox:SetPoint("TOPLEFT", noteBoxBackground, "TOPLEFT", 5, -5)
  noteBox:SetPoint("BOTTOMRIGHT", noteBoxBackground, "BOTTOMRIGHT", -5, 5)
  noteBox:SetAutoFocus(false)
  noteBox:EnableMouse(true)
  noteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  noteBox:SetScript("OnTextChanged", function(self)
      local remaining = 150 - strlen(self:GetText())
      charCounter:SetText(remaining)
  end)

  local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
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
            if bewareUI.listContentFrame then
              UpdateBewareList()
            else
            end
        end
    end
  end)

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetSize(230, 280)
  scrollFrame:SetPoint("TOP", addButton, "BOTTOM", 0, -10)

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -3, -3)
  closeButton:SetScript("OnClick", function() frame:Hide() end)

  bewareUI.listContentFrame = CreateFrame("Frame", nil, scrollFrame)
  bewareUI.listContentFrame:SetSize(230, 280)
  scrollFrame:SetScrollChild(bewareUI.listContentFrame)

  frame:SetScript("OnHide", function()
    frame:EnableMouse(false)
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