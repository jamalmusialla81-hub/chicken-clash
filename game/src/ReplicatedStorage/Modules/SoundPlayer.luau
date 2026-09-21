local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SoundPlayer = {}

function SoundPlayer.Play(soundName)
	local soundTemplate = nil

	for _, descendant in SoundService:GetDescendants() do
		if descendant.Name == soundName and descendant:IsA("Sound") then
			soundTemplate = descendant
			break
		end
	end

	if soundTemplate == nil then
		warn(`Sound "{soundName}" was not found in SoundService.`)
		return nil
	end

	local sound = soundTemplate:Clone()
	sound.Parent = SoundService
	sound:Play()

	Debris:AddItem(sound, math.max(sound.TimeLength, 1))

	return sound
end

return SoundPlayer
