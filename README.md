# GestureEdit

**Edit photos on your Mac by waving your hand at the camera.**

GestureEdit is a macOS photo editor you control with hand gestures through the Mac's built-in camera. Raise an open palm to start, pinch and move your hand to adjust exposure or contrast, swipe to switch tools, make a peace sign to undo and give a thumbs-up to export. Everything runs on your Mac. No images or camera frames ever leave it.

Built by **sohan** with Claude, starting from a product requirements document ([PRD.md](PRD.md)).

## What it does

- **Live hand tracking.** Apple's Vision framework finds 21 points on your hand 30 times a second. A smoothing filter keeps the skeleton steady without lag.
- **Gesture control.** The app recognizes seven hand poses and turns them into editing actions. Edits only happen after you deliberately arm editing, so stray movements don't change your photo.
- **Photo editing.** Nine adjustments: exposure, brightness, contrast, saturation, warmth, highlights, shadows, vignette and sharpness. There are also six one-click presets: Original, Vivid, Warm Film, Cool Matte, Noir and Chrome.
- **Smooth preview.** Edits render on a 2048-pixel copy in the background, so the photo updates live while your hand moves.
- **Undo and redo.** Up to 50 steps, where one pinch counts as one step.
- **Export.** Saves a full-size JPEG copy. Your original photo is never changed.
- **Private by design.** It has no network code, and the camera is used only while the window is in front.

## Gestures

| Gesture | When | Does |
| --- | --- | --- |
| ✋ Open palm, hold 0.8 s | Idle | Arm editing (a ring fills up) |
| 🤏 Pinch, move up or down | Armed | Raise or lower the current tool's value |
| ✋ Fast swipe right or left | Armed | Next or previous tool |
| ✌️ Peace sign | Armed | Undo |
| 👍 Thumbs up, hold 1 s | Armed | Export a JPEG |
| ✊ Fist | Armed | Cancel the current pinch, or disarm |

Editing disarms by itself if your hand is out of view for 5 seconds. Every threshold lives in one file, `Shared/Gestures/GestureConfig.swift`, so the gestures are easy to tune.

## Keyboard shortcuts

| Keys | Does |
| --- | --- |
| ⌘O | Open a photo (or drag one into the window) |
| ⌘S | Export |
| ⌘Z / ⌘⇧Z | Undo / redo |
| ⌘+ / ⌘− / ⌘0 | Zoom in / zoom out / actual size |

## Run it

You need a Mac with macOS 15 or later and Xcode.

1. Install **Xcode** from the Mac App Store and open it once so it finishes setup.
2. Clone this repo, then double-click `GestureEdit.xcodeproj`.
3. Press **⌘R** to run, and allow camera access when asked.
4. Press **⌘U** to run the tests.

If Xcode shows a signing error, open the project's **Signing & Capabilities** tab and pick your Apple ID under **Team**. If your Apple ID isn't listed, add it first in Xcode → Settings → Accounts.

## How it works

```
Camera (30 fps) → Vision hand tracking → smoothing → pose classifier
  → 4-of-5 frame vote → gesture state machine → edit commands
  → edit state + undo history → Core Image render → preview
```

- **Pose classifier.** It compares finger lengths to hand size, so it works near or far from the camera.
- **Frame vote.** A pose only counts after it shows up in 4 of the last 5 frames, which stops flicker.
- **State machine.** Idle, Armed, Adjusting and Pointing decide what each pose means at that moment.

## Built with

Swift 6, SwiftUI, AVFoundation, Vision, Core Image and Swift Testing. It uses Apple frameworks only, with no third-party packages.

| Folder | Contents |
| --- | --- |
| `Shared/Camera`, `Shared/Vision` | Camera capture, hand tracking and smoothing |
| `Shared/Gestures` | Pose classifier, frame vote, gesture state machine and thresholds |
| `Shared/Editing` | Edit state, undo history, presets and the Core Image render pipeline |
| `Shared/Views` | SwiftUI screens and overlays |
| `macOS/` | App entry point, menus and keyboard shortcuts |
| `Tests/` | Unit tests for tracking, gestures and editing, including recorded-gesture replay |

## Status

| Phase | What | |
| --- | --- | --- |
| 0 | Project setup, sandbox, camera permission | ✅ |
| 1 | Mirrored camera preview | ✅ |
| 2 | Hand tracking and skeleton overlay | ✅ |
| 3 | Gesture recognition | ✅ |
| 4 | Photo editing, presets, undo, export | ✅ |

Ideas for later (gesture zoom, onboarding, a custom ML gesture model) are in [NEXT_STEPS.md](NEXT_STEPS.md).
