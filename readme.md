# Heln

A multi-track animation controller for Roblox rigs, playing keyframe sequences directly without AnimationController or Animator.

**Private use, no Creator Store listing.**

Heln evaluates KeyframeSequences on the CPU each frame and writes the result straight to Motor6D.Transform, so it works on any rig with named joints, does not require publishing animations to Roblox, and can blend multiple tracks by priority and weight. It supports several playback behaviors (looping, reversing on stop, snapping back to markers) and per-track events for markers and keyframes.

No external dependencies.

---

## Install

Drop `Heln` into `ReplicatedStorage` and require it:

```lua
local Heln = require(ReplicatedStorage.Heln)
```

---

## Quick Start

```lua
local Heln = require(ReplicatedStorage.Heln)

local rig = workspace.MyRig
local keyframeSequence = script.MyAnimation -- a KeyframeSequence instance

local track = Heln.new(rig, keyframeSequence)

track:Play()

track.Ended:Connect(function()
    print("done")
end)
```

`Heln.new` returns a `Track`, the same shape as a Roblox `AnimationTrack`, but keyframes are evaluated in Luau against the rig's Motor6D joints instead of going through the Animator.

---

## Playing and Stopping

```lua
track:Play(fadeTime, fadeStyle, weight, speed)
track:Pause()
track:Stop(fadeTime, fadeStyle)
```

- `fadeTime` (number?) - seconds to blend weight in or out. Defaults to an instant snap.
- `fadeStyle` (string?) - one of `"Linear"`, `"Constant"`, `"Elastic"`, `"Cubic"`, `"Bounce"`. Defaults to `"Linear"`.
- `weight` (number?) - target blend weight for `Play`. Defaults to the track's current `WeightTarget`.
- `speed` (number?) - playback speed multiplier for `Play`. Negative values play backward.

Calling `Play` while a track is already playing re-fades it to the new weight instead of restarting.

---

## Playback Types

Set `track.PlaybackType` to control what happens on `Stop`:

| PlaybackType | Looping | Behavior on Stop |
|--------------|---------|-------------------|
| `Persistent` (default) | No | Holds its current pose. |
| `Reversible` | No | Plays backward to time 0. |
| `ReversibleResume` | No | Plays backward to time 0; also resumable mid-reverse by calling `Play` again. |
| `MarkerReversible` | No | Plays backward to the previous marker. |
| `NearestMarker` | No | Plays backward (or forward) to the nearest marker. |
| `LoopPersistent` | Yes | Holds its current pose. |
| `LoopMarkerReversible` | Yes | Plays backward to the previous marker. |

```lua
track.PlaybackType = "Reversible"
track:Play()
task.wait(1)
track:Stop() -- eases back to the start instead of freezing in place
```

---

## Blending Multiple Tracks

Multiple tracks can play on the same rig at once. Heln composes them per joint using `Priority` and `WeightCurrent`, the same rules as Roblox's Animator: higher `Enum.AnimationPriority` wins outright, and tracks sharing a priority level are weight-blended together.

```lua
local idle = Heln.new(rig, idleSequence)
idle.Priority = Enum.AnimationPriority.Idle
idle:Play()

local wave = Heln.new(rig, waveSequence)
wave.Priority = Enum.AnimationPriority.Action
wave:Play(0.2) -- fades in over the idle
```

---

## Markers and Keyframes

Keyframe names on the sequence become markers automatically. You can also add your own with `SetMarker`.

```lua
track:SetMarker(0.5, "Footstep", "Left")

track.KeyframeReached:Connect(function(name, value)
    print(name, value)
end)

track:GetMarkerReachedSignal("Footstep"):Connect(function(name, value)
    print("stepped:", value)
end)
```

Lookup helpers:

```lua
local time = track:GetTimeOfKeyframe("Footstep")
local before = track:GetPreviousMarker(1.0)
local after = track:GetNextMarker(1.0)
local closest = track:GetNearestMarker(1.0)
```

---

## Track Properties

| Property | Type | Read-only | Description |
|----------|------|-----------|-------------|
| `Animation` | `Animation?` | Yes | Always `nil`; Heln plays KeyframeSequences directly, not published Animations. |
| `IsPlaying` | `boolean` | Yes | Whether the track is currently advancing. |
| `Length` | `number` | Yes | Duration of the sequence in seconds. |
| `Looped` | `boolean` | No | Loop even for non-looping playback types. |
| `PlaybackType` | `string` | No | One of the names in the Playback Types table. |
| `Priority` | `Enum.AnimationPriority` | No | Blend priority, same semantics as `AnimationTrack.Priority`. |
| `Speed` | `number` | No | Playback speed multiplier. Negative plays backward. |
| `TimePosition` | `number` | No | Current time, clamped to `[0, Length]`. Setting it fires any markers crossed. |
| `WeightCurrent` | `number` | No | Current blend weight, driven by fades. |
| `WeightTarget` | `number` | No | Weight that `Play` fades toward. |

---

## Signals

| Signal | Fires when |
|--------|-----------|
| `DidLoop` | The track wraps around and loops. |
| `Ended` | The track finishes and stops playing. |
| `KeyframeReached(name, value)` | Any marker (keyframe-named or custom) is crossed. |
| `Stopped` | The track stops, including after a fade-out or reverse completes. |

---

## API

**Constructor**

| Method | Description |
|--------|-------------|
| `Heln.new(rig, keyframeSequence)` | Creates a `Track` that animates `rig` using `keyframeSequence`. |

**Playback**

| Method | Description |
|--------|-------------|
| `track:Play(fadeTime?, fadeStyle?, weight?, speed?)` | Starts or re-fades the track. |
| `track:Pause()` | Freezes the track at its current time. |
| `track:Stop(fadeTime?, fadeStyle?)` | Stops the track, honoring its `PlaybackType`. |
| `track:Destroy()` | Stops the track and disconnects all its signals. |

**Markers**

| Method | Description |
|--------|-------------|
| `track:SetMarker(time, name?, value?)` | Adds a custom marker at `time`. |
| `track:GetTimeOfKeyframe(keyframeName)` | Returns the time of a named keyframe, or `nil`. |
| `track:GetPreviousMarker(fromTime)` | Returns the closest marker before `fromTime`. |
| `track:GetNextMarker(fromTime)` | Returns the closest marker after `fromTime`. |
| `track:GetNearestMarker(fromTime)` | Returns whichever marker is closest to `fromTime`. |
| `track:GetMarkerReachedSignal(name)` | Returns a signal that fires only for markers named `name`. |

---

## License

MIT License. Copyright (c) 2026 Ve Development.
