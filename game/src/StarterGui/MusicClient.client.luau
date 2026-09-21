
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local NORMAL_VOLUME = 0.5
local FADE_TIME = 1.2

local tiOut = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local music = SoundService:WaitForChild("BackgroundMusic", 10)
if not music then
	warn("[MusicClient] Nie znaleziono BackgroundMusic!")
	return
end

-- Make sure BackgroundMusic is actually a Sound
if not music:IsA("Sound") then
	warn("[MusicClient] BackgroundMusic is not a Sound!")
	return
end

-- FIX: Sound.SoundGroup must be a SoundGroup, never a Sound.
-- Only assign it if the existing object is actually a SoundGroup.
local musicGroup = SoundService:FindFirstChild("Music")

if musicGroup then
	if musicGroup:IsA("SoundGroup") then
		music.SoundGroup = musicGroup
	else
		warn("[MusicClient] SoundService.Music exists but is not a SoundGroup. SoundGroup was not assigned.")
	end
end

if not music.IsPlaying then
	music:Play()
end

music.Volume = NORMAL_VOLUME

-- Functions exported through BindableFunction for EventClient
local fadeFunc = Instance.new("BindableFunction")
fadeFunc.Name = "MusicFade"
fadeFunc.Parent = SoundService

-- fadeFunc:Invoke("out") -> fade volume to 0 and pause
-- fadeFunc:Invoke("in")  -> play and fade volume to normal
fadeFunc.OnInvoke = function(direction)
	if direction == "out" then
		local tw = TweenService:Create(music, tiOut, {Volume = 0})
		tw:Play()
		tw.Completed:Wait()
		music:Pause()

	elseif direction == "in" then
		music.Volume = 0
		music:Resume()

		local tw = TweenService:Create(music, tiOut, {Volume = NORMAL_VOLUME})
		tw:Play()
		tw.Completed:Wait()
	end
end
