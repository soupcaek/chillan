# 1.3.12 feed rows: real icons, no time column (time on hover), dividers between groups, short dungeon names
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
LA, GA, nsA = A; LB, GB, nsB = B
run(4)
print("short:", LA.eval('ADDON_NS.ShortDungeon("Blackrock Depths")'), "|", LA.eval('ADDON_NS.ShortDungeon("Scarlet Monastery - Library")'), "|", LA.eval('ADDON_NS.ShortDungeon("Nowhere")'))
LA.execute('''C_Item = C_Item or {}; C_Item.GetItemIconByID = function(id) return 135000 + id end
local fr = ADDON_NS.UI.FeedRows(UIParent); fr:SetSize(300, 300); FR = fr
local now = time()
fr:AddMessage("x", { kind = "ev", base = "x", t = now - 3600, item = { kind = "DUNGEON", a = "Blackrock Depths", t = now - 3600 } })
fr:AddMessage("y", { kind = "ev", base = "y", t = now - 3500, item = { kind = "LOOT", a = "item:6585", b = 3, t = now - 3500 } })
fr:AddMessage("z", { kind = "ev", base = "z", t = now - 60, item = { kind = "DING", a = 42, t = now - 60 } })
fr:Layout()''')
print("dividers:", LA.eval('(function() local n, out = 0, {} for _, d in ipairs(FR.divs) do if d:IsShown() then n = n + 1 out[#out+1] = d.text:GetText() end end return n .. " " .. table.concat(out, ",") end)()'))
print("loot icon:", LA.eval('tostring((FR.rows[2].tile:GetTexture()))'), "dungeon:", LA.eval('tostring((FR.rows[3].tile:GetTexture()))'))
print("time hidden:", LA.eval('tostring((FR.rows[1].time:IsShown()))'))
print("FEIL:", list(GA.ERRORS.values())[:3])
