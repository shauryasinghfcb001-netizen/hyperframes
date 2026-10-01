---
name: short-polish
description: Take a short vertical talking-head video the user has ALREADY CUT (30-60s) and make it feel alive without re-cutting it - face-tracked punch-ins, smoothing of harsh jump cuts with SFX / music / flash-flicker effects, and 3D kinetic typography on the few most important words. Use when the user hands over a pre-cut reel/short and asks for polish, typography, face tracking, or "make the cuts smooth".
---

# Short polish (pre-cut short → alive)

The user cuts the video themselves. **Never re-cut, re-order, trim or speed up their footage.** The cut is theirs; this skill only adds camera movement, cut smoothing, sound and typography on top. Shorts only (up to ~90s), not long videos. No eye-contact correction (not possible, not wanted).

Credits rule: the user has been burned. Analysis runs locally and is free; renders and re-writes are what cost. One preview gate, one render.

## 1. Analyse (local, no gate)

Run these together, they are independent:

- **Face track** - `swift ~/.claude/skills/short-polish/scripts/facetrack.swift <video> 5 > face.json`
  Apple Vision, no installs. Returns `t, cx, cy, w, h` normalized, top-left origin. Verified on this Mac (31/31 frames on a test clip). Slow: about 2s per sampled frame, so 5 samples/s on a 60s clip is ~10 min - run it in the background. Python has no cv2/mediapipe here; don't go looking.
- **Transcript** - `whisper-cli` + `ggml-small.en.bin`, word timestamps. The video is already cut, so timestamps are used only to place words, not to cut.
- **Cut points** - the user's jump cuts. Find them from a jump in the face track (cx/cy/w changes sharply between two samples) confirmed by ffmpeg scene score (`select='gt(scene,0.08)',showinfo`; `scdetect` is not in this ffmpeg build). Same-shot jump cuts score low, so the face jump is the main signal. If unsure, ask the user for their cut times rather than guess.
- **Loudness** - `ffmpeg ebur128`. Only normalize (target -14 LUFS); don't re-process a voice the user already treated unless asked.

## 2. Plan on one screen (gate)

Show the user a short table before building anything: each cut time and how it will be smoothed, the 4-6 words getting typography, where punch-ins go. Get a yes. This is the only gate before render.

## 3. Build (HyperFrames)

Load `/hyperframes`, `/hyperframes-core`, `/hyperframes-keyframes`, `/media-use`. Init with `npx hyperframes init <name> --non-interactive --example=blank --skill=general-video`. Muted `<video>` + separate `<audio>`, one paused GSAP timeline at `window.__timelines["main"]`, deterministic code only.

**Face-tracked camera**
- Wrapper `#cam` > `#cam-inner` > video. Animate the wrapper, never the timed clip.
- Smooth `face.json` first (moving average over ~0.6s, and hold still when movement is under ~2% of frame) or the frame will jitter.
- Set `transform-origin` from the smoothed face centre, so zooms land on the face, not on a fixed point. The last edit used a fixed 50% 45% origin while the face sat at cx 0.72 - that is why the zooms looked off.
- Punch in (1.15-1.3) on emphasis words, ease back out. Reset at each cut. Clamp so the frame edge never shows.
- "Face aside": when a graphic or big word needs room, translate the camera so the face sits at ~30% or ~70% of the width, then bring it back. Max one of these every 8-10s.

**Smoothing harsh cuts** - pick one per cut, vary them, leave some cuts bare:
- scale change across the cut (punch in or out on the cut frame) - the cheapest and most effective
- 2-3 frame white/lime flash or flicker
- short whoosh or soft click under the cut, starting ~2 frames before
- 4-6 frame zoom-blur or whip
- a music bed under everything hides cuts the most. Low, -22 to -26 dB under the voice. Use a track the user supplies, else `/media-use`.
- SFX volumes 0.25-0.6, always under the voice. Earlier feedback: the SFX were good but sometimes excessive - not every cut gets a sound.

**3D typography** - only the 4-6 most important words in the whole video, not captions.
- CSS 3D: `perspective` on a stage, words enter with rotateX/rotateY/translateZ, settle, exit. One word or short phrase at a time, big.
- Anchor each word relative to the tracked face (beside or above it, following the smoothed track with a little lag) so it feels attached to the shot.
- This is tracked to the **face**, not true 3D camera tracking of the room. Real scene tracking is not available here; say so if asked.
- Text behind the head needs a person matte (`/media-use` remove-background). Untested on this Mac and expensive - only on request.
- Earlier feedback: the typography was "ordinary". So: fewer words, larger, real depth and motion, strong type contrast. No lower-third cards by default.

## 4. Check, one render, deliver

- `npx hyperframes check`, snapshot at each typography hit and each cut, look at the frames.
- Render once: `FFMPEG_PROCESS_TIMEOUT_MS=1500000`, `--video-frame-format jpg`.
- Social-safe export: `-c:v libx264 -profile:v high -pix_fmt yuv420p -r 30 -b:v 8M -maxrate 10M -bufsize 16M -c:a aac -ar 48000 -b:a 192k -movflags +faststart`. (An earlier Story upload failed and was never diagnosed; this recipe is untested against it.)
- Claude cannot hear or watch the result. Say so and ask the user to check the cuts with sound.

## Parallel agents

Only if the user asks. Agents multiply credit use, they don't reduce it. If used: one for the sound map (cuts → SFX/music), one for typography design; the main session owns the camera and the final composition. Give each the transcript, `face.json` and cut list so they don't redo analysis.

## Related
- `/talking-head-short` - when Claude must also do the cutting from a raw recording.
- `/embedded-captions` - full captions instead of key words.
