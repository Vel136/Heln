local ReversibleResume = {}

ReversibleResume.IsLooping = false

ReversibleResume.ReversesFromFinished = true

function ReversibleResume.OnStop(track)
	track:_BeginReverse(0)
end

function ReversibleResume.OnPlay(track)
	track._reversing = false
end

return ReversibleResume
