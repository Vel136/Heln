---
sidebar_position: 2
sidebar_label: "Overview"
---

# Heln

*Play. Blend. React.*

A multi-track animation controller for Roblox rigs.

Heln reads a `KeyframeSequence` into per-joint timelines once, then evaluates those timelines against a `Model`'s `Motor6D` joints every frame and writes directly to `Motor6D.Transform`. This bypasses `AnimationController` and `Animator` entirely, so animations do not need to be published to Roblox and can run on any rig with matching joint names.

---

## One File. One Require.

```lua
local Heln = require(ReplicatedStorage.Heln)
```

---

## Creating a Track

```lua
local track = Heln.new(rig, keyframeSequence)
```

`rig` must be a `Model` containing `Motor6D` instances. `keyframeSequence` is a `KeyframeSequence` with `Keyframe` and `Pose` children, exactly as produced by the Roblox animation editor before publishing.

Internally, Heln walks the sequence once at construction time, building a timeline per pose name (sorted by time) and recording every named keyframe as a marker. `track.Length` is the time of the last keyframe.

---

## How Joints Are Resolved

Each rig gets one shared controller behind the scenes, keyed by the rig instance. That controller finds `Motor6D`s by matching `Motor6D.Part1.Name` against each timeline's pose name, and caches the result per joint name.

The cache is invalidated whenever a `Motor6D` is added to or removed from the rig, so joints that do not exist yet at `Heln.new` still start animating once they are parented in. If a rig has more than one `Motor6D` sharing the same `Part1.Name` (for example, mirrored joints on a viewmodel), all of them receive the same pose.

---

## Playing

```lua
track:Play(fadeTime, fadeStyle, weight, speed)
```

| Argument | Default | Description |
|----------|---------|--------------|
| `fadeTime` | instant | Seconds to blend `WeightCurrent` toward `weight`. |
| `fadeStyle` | `"Linear"` | Easing curve for the fade: `Linear`, `Constant`, `Elastic`, `Cubic`, or `Bounce`. |
| `weight` | current `WeightTarget` | Target blend weight. |
| `speed` | current `Speed` | Playback speed multiplier. Negative values play backward. |

Calling `Play` on a track that is already playing does not restart it. Instead it re-fades toward the new weight, which is how you crossfade between two states of the same track.

If the track had already reached the end of its length and was not paused, `Play` resets `TimePosition` to 0 before starting.

---

## Pausing

```lua
track:Pause()
```

Freezes the track at its current `TimePosition`. Calling `Play` again resumes from there.

---

## Stopping and Playback Types

```lua
track:Stop(fadeTime, fadeStyle)
```

What happens on `Stop` depends on `track.PlaybackType`:

```lua
track.PlaybackType = "Reversible"
```

| PlaybackType | Loops | On Stop |
|--------------|-------|---------|
| `Persistent` | No | Nothing extra; the track simply stops or fades out, holding its pose. |
| `Reversible` | No | Begins playing backward toward time 0. |
| `ReversibleResume` | No | Begins playing backward toward time 0. If `Play` is called again mid-reverse, playback resumes forward from the current time instead of restarting. |
| `MarkerReversible` | No | Begins playing backward toward the previous marker (or time 0 if none). |
| `NearestMarker` | No | Begins playing backward or forward toward whichever marker is nearest. |
| `LoopPersistent` | Yes | Same as `Persistent`, but loops while playing. |
| `LoopMarkerReversible` | Yes | Same as `MarkerReversible`, but loops while playing. |

Setting an unrecognized value on `PlaybackType` raises an error immediately, so typos are caught at assignment time rather than silently falling back to `Persistent`.

When a reverse is in progress, the track keeps contributing to the rig's pose until it finishes reversing, at which point `Stopped` fires.

---

## Blending

Every joint's final pose is composed from all tracks currently registered on the rig, grouped by `Priority`:

1. Tracks are grouped by `Enum.AnimationPriority` (`Core`, `Idle`, `Movement`, `Action`).
2. Within a priority level, tracks are weight-blended together using `CFrame:Lerp`, ordered by track creation order.
3. Priority levels are then composed highest-over-lowest, so `Action` fully overrides `Movement` where its weight is 1, and partially blends where its weight is less than 1.

```lua
local idle = Heln.new(rig, idleSequence)
idle.Priority = Enum.AnimationPriority.Idle
idle:Play()

local wave = Heln.new(rig, waveSequence)
wave.Priority = Enum.AnimationPriority.Action
wave:Play(0.2)
```

Only joints present in a track's timelines are touched. Joints with no timeline entry in any playing track are left alone.

---

## Time Position

```lua
track.TimePosition = 1.5
```

Setting `TimePosition` clamps to `[0, Length]` and fires any markers between the old and new time, so scrubbing forward still triggers `KeyframeReached` for anything skipped over.

---

## Markers

Keyframe names become markers automatically:

```lua
local time = track:GetTimeOfKeyframe("Footstep")
```

You can also register custom markers that are not tied to a keyframe:

```lua
track:SetMarker(0.75, "Footstep", "Left")
```

Lookups search both keyframe-derived and custom markers together:

```lua
local previous = track:GetPreviousMarker(1.0)
local next = track:GetNextMarker(1.0)
local nearest = track:GetNearestMarker(1.0)
```

`GetNearestMarker` breaks ties in favor of the next marker when the distances are equal.

---

## Listening for Markers

```lua
track.KeyframeReached:Connect(function(name, value)
    print(name, value)
end)

track:GetMarkerReachedSignal("Footstep"):Connect(function(name, value)
    print("stepped:", value)
end)
```

`KeyframeReached` fires for every marker. `GetMarkerReachedSignal(name)` returns a signal scoped to markers with that exact name, created lazily on first request.

---

## Signals

| Signal | Fires when |
|--------|-----------|
| `DidLoop` | The track wraps past `Length` and continues, either because `Looped` is set or the `PlaybackType` loops. |
| `Ended` | The track reaches the end (or start, when playing backward) without looping and stops. |
| `KeyframeReached(name, value)` | Any marker, keyframe-derived or custom, is crossed during a frame. |
| `Stopped` | The track stops advancing: after `Stop` with no fade, after a fade-out completes, or after a reverse driven by `PlaybackType` finishes. |

---

## Cleaning Up

```lua
track:Destroy()
```

Stops the track, disconnects it from the rig's per-frame update loop, and destroys all of its signals, including any per-marker signals created via `GetMarkerReachedSignal`. Reading or writing properties on a destroyed track raises an error.

---

## Design Notes

- **Per-rig controller:** all tracks on the same rig share one controller and one `RunService.PreSimulation` connection, created on first `Play` and torn down when no tracks remain active.
- **Weak rig registry:** controllers are keyed by rig instance in a weak table, so they do not keep destroyed rigs alive.
- **Joint cache invalidation:** the joint-to-motor cache clears on `Motor6D` add or remove, not on `Motor6D.Part1` reassignment or rename.
- **Priority resolution order:** unrecognized `Enum.AnimationPriority` values are treated as `Action`, the highest rank.
