
local NearestMarker = {}

NearestMarker.IsLooping = false

function NearestMarker.OnStop(track)
	local marker = track:GetNearestMarker(track._time)
	track:_BeginReverse(marker and marker.Time or 0)
end

function NearestMarker.OnPlay(track)
end

return NearestMarker
