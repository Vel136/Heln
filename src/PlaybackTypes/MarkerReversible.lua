local MarkerReversible = {}

MarkerReversible.IsLooping = false

function MarkerReversible.OnStop(track)
	local marker = track:GetPreviousMarker(track._time)
	track:_BeginReverse(marker and marker.Time or 0)
end


function MarkerReversible.OnPlay(track)
end

return MarkerReversible
