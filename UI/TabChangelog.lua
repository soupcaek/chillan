-- Chillan? – "What's new" tab: changelog, newest first
local ADDON, ns = ...
local UI, C, hex = ns.UI, ns.C, ns.hex

ns:RegisterTab("changelog", "New", "Scroll", function(tab)
  local h = UI.Text(tab, 15, "semi", C.text)
  h:SetPoint("TOPLEFT", 16, -16)
  h:SetText("What's new in Chillan?")
  local sub = UI.Text(tab, 11, nil, C.dim)
  sub:SetPoint("LEFT", h, "RIGHT", 10, 0)

  local box = UI.Panel(tab, C.card, C.line, false)
  box:SetPoint("TOPLEFT", 16, -44)
  box:SetPoint("BOTTOMRIGHT", -16, 14)
  local m = UI.MessageFrame(box, 13)
  m:SetPoint("TOPLEFT", 16, -12)
  m:SetPoint("BOTTOMRIGHT", -16, 12)
  m:SetSpacing(4)
  m:SetInsertMode("TOP")

  local lastSeen
  function tab:Refresh()
    sub:SetText("you have v" .. tostring(ns.VERSION) .. "  ·  update in WowUp and /reload")
    m:Clear()
    -- written oldest → newest because the frame inserts at the top
    local list = ns.CHANGELOG or {}
    local seenV = lastSeen or (ns.db.seen and ns.db.seen.changelogPrev) or "0"
    for i = #list, 1, -1 do
      local e = list[i]
      local isNew = ns.NewerVersion and ns.NewerVersion(e.v, seenV)
      for j = #e.items, 1, -1 do
        m:AddMessage("     " .. ns.Colorize("•", C.accent) .. "  " .. ns.Colorize(e.items[j], C.text2))
      end
      m:AddMessage(ns.Colorize("v" .. e.v, C.text) .. ns.Colorize("   " .. (e.date or ""), C.dim)
        .. (isNew and ("   " .. ns.Colorize("NEW", C.green)) or "")
        .. ((e.v == ns.VERSION) and ns.Colorize("   (installed)", C.dim) or ""))
      if i > 1 then m:AddMessage(" ") end
    end
  end

  tab:HookScript("OnShow", function()
    -- remember which version you had seen before, so "NEW" marks everything since then
    ns.db.seen = ns.db.seen or {}
    if ns.db.seen.changelog ~= ns.VERSION then
      ns.db.seen.changelogPrev = ns.db.seen.changelog or "0"
    end
    lastSeen = ns.db.seen.changelogPrev
  end)
end)
