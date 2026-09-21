local GlobalFunctions = {}

function GlobalFunctions.FormatTime(seconds)
	seconds = math.floor(seconds)

	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	local function pad(n)
		return string.format("%02d", n)
	end

	if days > 0 then
		return string.format("%d:%s:%s:%s", days, pad(hours), pad(minutes), pad(secs))
	elseif hours > 0 then
		return string.format("%s:%s:%s", pad(hours), pad(minutes), pad(secs))
	elseif minutes > 0 then
		return string.format("%s:%s", pad(minutes), pad(secs))
	else
		return tostring(secs)
	end
end

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa",
	"Qi", "Sx", "Sp", "Oc", "No",
	"De", "Ud", "Dd", "Td", "Qad",
	"Qid", "Sxd", "Spd", "Ocd", "Nod",
	"Vg", "Uvg", "Dvg", "Tvg", "Qavg",
	"Qivg", "Sxvg", "Spvg", "Ocvg",
	"Novg", "Tg",
}

function GlobalFunctions.FormatNumber(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	end

	local index = math.floor(math.log10(value) / 3)

	if index >= #SUFFIXES then
		return string.format("%.2e", value)
	end

	local suffix = SUFFIXES[index + 1]
	local shortValue = value / math.pow(10, 3 * index)
	local truncated = math.floor(shortValue * 100) / 100

	return string.format("%.2f%s", truncated, suffix)
end

function GlobalFunctions.Retry(callback, retries: number)
	local success, result

	for attempt = 1, retries do
		success, result = pcall(callback)

		if success then
			return true, result
		end

		task.wait(0.5)
	end

	return false, result
end

return GlobalFunctions
