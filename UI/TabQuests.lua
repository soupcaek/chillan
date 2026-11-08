-- Chillan? – fanen "Quests": felles quests og gruppe-quests i gjengen
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("quests", "Quests", "Book", function(tab)

  local function column(title, sub, empty)
    local col = CreateFrame("Frame", nil, tab)
    col.h = UI.Text(col, 15, "semi", C.text)
    col.h:SetPoint("TOPLEFT")
    col.h:SetText(title)
    col.sub = UI.Text(col, 11, nil, C.dim)
    col.sub:SetPoint("TOPLEFT", col.h, "BOTTOMLEFT", 0, -4)
    col.sub:SetPoint("RIGHT", col, "RIGHT", 0, 0)
    col.sub:SetText(sub)

    local function createRow(list)
      local row = CreateFrame("Button", nil, list)
      row.panel = UI.Panel(row, C.card, C.line, false)
      row.panel:SetAllPoints()
      row.panel:SetFrameLevel(row:GetFrameLevel())
      row.title = UI.Text(row, 13, "semi", C.text)
      row.title:SetPoint("TOPLEFT", 12, -9)
      row.title:SetPoint("RIGHT", -70, 0)
      row.who = UI.Text(row, 11, nil, C.muted)
      row.who:SetPoint("BOTTOMLEFT", 12, 9)
      row.who:SetPoint("RIGHT", -70, 0)
      row.pill = UI.Pill(row)
      row.pill:SetPoint("RIGHT", -10, 0)
      row:SetScript("OnEnter", function(self)
        self.panel:SetColors(C.cardHover, C.line)
        local e = self.item
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.Quests:Title(e.id), 1, 1, 1)
        for _, p in ipairs(e.holders) do
          local c = ns:PersonChar(p) or {}
          local r, g, b = ns.ClassColor(c.class)
          GameTooltip:AddDoubleLine(ns:PersonName(p) .. (ns:PersonAlias(p) and (" (" .. ns:PersonAlias(p) .. ")") or ""),
            ns:IsOnline(p) and ("online" .. (ns.InMyGroup(p) and " · in your group" or "")) or "offline", r, g, b, 0.6, 0.63, 0.66)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: whisper the first one online", 0.52, 0.55, 0.57)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function(self) self.panel:SetColors(C.card, C.line) GameTooltip:Hide() end)
      row:SetScript("OnClick", function(self)
        for _, p in ipairs(self.item and self.item.holders or {}) do
          if ns:IsOnline(p) then ns.Whisper((p.live and p.live.char) or p.main) return end
        end
      end)
      return row
    end

    local function updateRow(row, e)
      row.title:SetText(ns.Quests:Title(e.id))
      local names, on = {}, 0
      for _, p in ipairs(e.holders) do
        local online = ns:IsOnline(p)
        if online then on = on + 1 end
        if #names < 4 then
          names[#names + 1] = online and ns:ShortWho(p) or ns.Colorize(ns:PersonAlias(p) or ns:PersonName(p), C.dim)
        end
      end
      local extra = #e.holders > 4 and ns.Colorize(" +" .. (#e.holders - 4), C.dim) or ""
      row.who:SetText(table.concat(names, ns.Colorize(", ", C.dim)) .. extra)
      if e.mine and e.group then row.pill:Set("Group · you have it", C.green)
      elseif e.mine then row.pill:Set("You have it", C.green)
      else row.pill:Set("Group", C.amber) end
      row.pill:SetWidth(row.pill.text:GetStringWidth() + 16)
      row:SetAlpha(on > 0 and 1 or 0.6)
    end

    col.list = UI.List(col, 48, 6, createRow, updateRow)
    col.list:SetPoint("TOPLEFT", col.sub, "BOTTOMLEFT", 0, -10)
    col.list:SetPoint("BOTTOMRIGHT", 0, 0)
    col.list.emptyText = empty
    return col
  end

  -- one list: quests you share with someone first, then group quests others have
  local col = column("Quests in the gang", "Quests you share with a friend come first, then elite/group/dungeon quests someone has – click to whisper",
    "No shared or group quests right now. When you pick up a quest a friend has, you'll get a heads-up.")
  col:SetPoint("TOPLEFT", 16, -16)
  col:SetPoint("BOTTOMRIGHT", -16, 14)

  function tab:Refresh()
    local shared, group = ns.Quests:Overview()
    local data, seen = {}, {}
    for _, e in ipairs(shared) do data[#data + 1] = e seen[e.id] = true end
    for _, e in ipairs(group) do if not seen[e.id] then data[#data + 1] = e end end
    col.list:SetData(data)
  end
end)
