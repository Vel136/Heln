local Reversible = {}

Reversible.IsLooping = false

function Reversible.OnStop(track)
	track:_BeginReverse(0)
end

function Reversible.OnPlay(track)
end

return Reversible
