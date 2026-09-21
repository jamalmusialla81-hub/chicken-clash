local MUSIC_IDS = {
	normal      = "rbxassetid://rbxassetid://5409360995",
	radioactive = "rbxassetid://1840055641",
}

local SoundService = game:GetService("SoundService")
local RS           = game:GetService("ReplicatedStorage")

local oldSound = SoundService:FindFirstChild("BackgroundMusic")
if oldSound then oldSound:Destroy() end

local music         = Instance.new("Sound")
music.Name          = "BackgroundMusic"
music.SoundId       = MUSIC_IDS.normal
music.Looped        = true
music.Volume        = 0.5
music.Parent        = SoundService
music:Play()

local oldCfg = RS:FindFirstChild("MusicConfig")
if oldCfg then oldCfg:Destroy() end

local cfg    = Instance.new("Folder")
cfg.Name     = "MusicConfig"
cfg.Parent   = RS

for key, id in pairs(MUSIC_IDS) do
	local sv       = Instance.new("StringValue")
	sv.Name        = key
	sv.Value       = id
	sv.Parent      = cfg
end
