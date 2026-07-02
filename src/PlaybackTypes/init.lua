
local Persistent = require(script.Persistent)
local Reversible = require(script.Reversible)
local ReversibleResume = require(script.ReversibleResume)
local MarkerReversible = require(script.MarkerReversible)
local NearestMarker = require(script.NearestMarker)
local LoopPersistent = require(script.LoopPersistent)
local LoopMarkerReversible = require(script.LoopMarkerReversible)

local PlaybackTypes = {
	Persistent = Persistent,
	Reversible = Reversible,
	ReversibleResume = ReversibleResume,
	MarkerReversible = MarkerReversible,
	NearestMarker = NearestMarker,
	LoopPersistent = LoopPersistent,
	LoopMarkerReversible = LoopMarkerReversible,
}

PlaybackTypes.Default = "Persistent"

return PlaybackTypes
