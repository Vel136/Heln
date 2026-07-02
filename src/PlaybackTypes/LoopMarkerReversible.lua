local LoopMarkerReversible = {}

LoopMarkerReversible.IsLooping = true

function LoopMarkerReversible.OnStop(track)
	local marker = track:GetPreviousMarker(track._time)
	track:_BeginReverse(marker and marker.Time or 0)
end

function LoopMarkerReversible.OnPlay(track)
end

return LoopMarkerReversible
