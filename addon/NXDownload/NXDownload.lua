-- Read-only streaming diagnostics. Never claims that the CASC store is complete.
local frame = CreateFrame("Frame", "NXDownloadPanel", UIParent, "BackdropTemplate")
frame:SetSize(285, 146)
frame:SetPoint("TOP", UIParent, "TOP", 0, -70)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
frame:SetBackdropColor(0.055,0.075,0.095,0.94)
frame:SetBackdropBorderColor(0.28,0.48,0.55,1)
local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("TOPLEFT",12,-10)
title:SetText("Nexions Download Manager")
local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
close:SetPoint("TOPRIGHT",2,2)
local bar=CreateFrame("StatusBar",nil,frame)
bar:SetSize(255,16)
bar:SetPoint("TOPLEFT",12,-34)
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetStatusBarColor(0.19,0.66,0.74)
bar:SetMinMaxValues(0,1)
local bg=bar:CreateTexture(nil,"BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.12,0.17,0.2,1)
local percent=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
percent:SetPoint("CENTER")
local details=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
details:SetPoint("TOPLEFT",12,-59)
details:SetWidth(260)
details:SetJustifyH("LEFT")
local note=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
note:SetPoint("BOTTOMLEFT",12,10)
note:SetWidth(260)
note:SetJustifyH("LEFT")
note:SetText("Client-reported progress; not a full CASC verification.")
local function numeric(fn)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn)
    if not ok or (issecretvalue and issecretvalue(v)) or type(v)~="number" or v~=v or math.abs(v)==math.huge then return nil end
    return v
end
local function display(v) return v and tostring(v) or "Unavailable" end
local lastP,lastTime,rate
local function refresh()
    local p=numeric(GetDownloadedPercentage)
    local now=GetTime()
    if p and p>=0 and p<=1 then
        bar:SetValue(p)
        percent:SetText(string.format("%.2f%%",p*100))
        if lastP and now-lastTime>=10 then
            rate=p>=lastP and (p-lastP)*100*60/(now-lastTime) or nil
            lastP,lastTime=p,now
        elseif not lastP then lastP,lastTime=p,now end
    else
        bar:SetValue(0)
        percent:SetText("Progress unavailable")
        lastP,lastTime,rate=nil,nil,nil
    end
    local stream=numeric(GetFileStreamingStatus)
    local background=numeric(GetBackgroundLoadingStatus)
    local bandwidth=numeric(GetAvailableBandwidth)
    details:SetText("Streaming status: "..display(stream).."  |  Background: "..display(background)
      .."\nAvailable bandwidth (API): "..display(bandwidth)
      .."\nProgress change: "..(rate and string.format("%.3f pp/min",rate) or "Measuring…"))
end
local elapsed=0
frame:SetScript("OnUpdate",function(self,dt)
    elapsed=elapsed+dt
    if elapsed>=1 then elapsed=0; refresh() end
end)
frame:SetScript("OnShow",function() lastP,lastTime,rate=nil,nil,nil; refresh() end)
frame:SetScript("OnHide",function()
    if type(NXDownloadDB)=="table" then NXDownloadDB.visible=false end
end)
frame:Hide()
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    if type(NXDownloadDB)~="table" then NXDownloadDB={visible=true} end
    if NXDownloadDB.visible~=false then frame:Show() end
end)
SLASH_NEXIONSDOWNLOAD1="/nxdownload"
SLASH_NEXIONSDOWNLOAD2="/nxd"
SlashCmdList.NEXIONSDOWNLOAD=function()
    if frame:IsShown() then frame:Hide() else
        NXDownloadDB=NXDownloadDB or {}
        NXDownloadDB.visible=true
        frame:Show()
    end
end
