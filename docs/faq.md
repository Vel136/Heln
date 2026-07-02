---
sidebar_position: 4
---

# FAQ

Answers to the questions that come up most often.

---

## General

**What is Heln?**

Heln is a multi-track animation controller for Roblox Luau. It plays `KeyframeSequence` instances directly against a rig's `Motor6D` joints, instead of going through `AnimationController` and `Animator`.

---

**What does Heln depend on?**

Nothing. Heln is a self-contained module with no external dependencies.

---

**Why not just use Animator and AnimationTrack?**

Heln does not require animations to be published as Roblox `Animation` assets, gives you direct control over per-frame blending logic, and adds playback types (like reversing back to a marker on stop) that `AnimationTrack` does not have built in. The tradeoff is that evaluation happens in Luau instead of the engine's native animation system.

---

**Can I use Heln on both server and client?**

Yes. Heln has no service dependencies beyond `RunService`. Each rig gets its own controller the first time a track is created for it, regardless of which side creates it.

---

**Is Heln free to use?**

Yes. Heln is released under the MIT License.

---

## Setup

**What does my rig need for Heln to work?**

A `Model` with `Motor6D` instances whose `Part1` names match the Pose names in your `KeyframeSequence`. This is the same rig structure Roblox's own animation system expects.

---

**Why isn't my track animating anything?**

The most common cause is that the rig's `Motor6D`s were not present yet when `Heln.new` was called and have still not been added. Heln resolves joints lazily and re-scans whenever a `Motor6D` is added or removed from the rig, so as long as the joints eventually exist under the rig, animation will start. Renaming an existing `Motor6D`'s `Part1`, or reassigning `Part1` to a different part, does not trigger a re-scan.

---

**What happens if two Motor6Ds share the same Part1 name?**

Both receive the same pose for that joint name. This is intentional and is useful for mirrored joints, such as a viewmodel with duplicate joints on both arms.

---

## Playback

**What is the difference between Pause and Stop?**

`Pause` freezes the track at its current time; calling `Play` again resumes from there. `Stop` triggers the track's `PlaybackType` behavior (holding, reversing, or reversing to a marker) and eventually removes the track from the rig's active set once it finishes.

---

**Why does calling Play again not restart my track?**

If the track is already playing, `Play` treats the call as a re-fade toward the given weight instead of a restart. To force a restart, call `Stop()` first, or set `track.TimePosition = 0` before calling `Play`.

---

**What is the difference between Reversible and ReversibleResume?**

Both play backward to time 0 on `Stop`. `ReversibleResume` additionally lets you call `Play` again while it is reversing, and playback will resume forward from wherever the reverse had gotten to, instead of restarting from 0.

---

**How does MarkerReversible pick where to reverse to?**

It calls `GetPreviousMarker` using the track's time at the moment `Stop` is called, and reverses to that marker's time (or 0 if there is no earlier marker).

---

**Can I loop a Persistent track without changing PlaybackType?**

Yes. Set `track.Looped = true`. This loops regardless of `PlaybackType`; the `LoopPersistent` and `LoopMarkerReversible` playback types just set that behavior on by default.

---

## Blending

**How does Heln decide which track wins when two play at once?**

By `Priority` first, then by weight within the same priority. Higher `Enum.AnimationPriority` values fully take precedence over lower ones wherever their weight reaches 1; tracks that share a priority level are blended together by weight using `CFrame:Lerp`.

---

**What happens to a joint with no timeline in any active track?**

Nothing. Heln only writes to `Motor6D.Transform` for joints that have pose data in at least one currently-contributing track.

---

## Markers

**What is the difference between a keyframe marker and a custom marker via SetMarker?**

None functionally. Named keyframes in the `KeyframeSequence` are converted to markers automatically at construction time. `SetMarker` adds an additional marker the same way, without needing a corresponding `Keyframe` instance. Both are searched together by `GetPreviousMarker`, `GetNextMarker`, and `GetNearestMarker`.

---

**Does scrubbing TimePosition fire markers I skip over?**

Yes, as long as you move forward. Setting `TimePosition` to a later time fires every marker strictly between the old and new time. Setting it to an earlier time does not fire markers.

---

## Cleanup

**Do I need to call Destroy?**

Yes, if you are done with a track permanently. `Destroy` disconnects the track from the rig's update loop and destroys its signals, including any created via `GetMarkerReachedSignal`. Letting a track simply go out of scope without calling `Destroy` will keep its signals alive and, if it is still playing or paused, keep it registered on the rig.
