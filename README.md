# GestureEdit

A macOS photo editor you control with hand gestures through the Mac's built-in camera.
Everything runs on-device. See [PRD.md](PRD.md) for the full plan.

## Run it

1. Install **Xcode** from the Mac App Store (free, large download) and open it once so it finishes setup.
2. Clone this repo, then double-click `GestureEdit.xcodeproj`.
3. Press **⌘R** (Product → Run). A window titled GestureEdit should appear.
4. Press **⌘U** (Product → Test) to run the tests.

If Xcode shows a signing error, open the project's **Signing & Capabilities** tab and pick
your Apple ID under **Team** (add it in Xcode → Settings → Accounts first).

## Gestures (so far)

| Gesture | When | Does |
| --- | --- | --- |
| ✋ Open palm, hold 0.8 s | Idle | Arm editing |
| 🤏 Pinch + move up/down | Armed | Change the active tool's value |
| ✋ Fast swipe right / left | Armed | Next / previous tool |
| ☝️ Point, hold still 0.8 s | Armed | Click |
| ✌️ Peace | Armed | Undo |
| 👍 Thumbs up, hold 1 s | Armed | Export |
| ✊ Fist | Armed | Cancel a pinch, or disarm |

All thresholds live in `Shared/Gestures/GestureConfig.swift`.

## Layout

| Folder | What goes there |
| --- | --- |
| `Shared/` | All app logic and SwiftUI views. No macOS-only code, so it can move to iPhone later. |
| `macOS/` | The app entry point and anything macOS-only (file panels, keyboard shortcuts). |
| `Tests/` | Swift Testing unit tests. |

## Progress

See [NEXT_STEPS.md](NEXT_STEPS.md) for where things stand and how to continue.


- [x] Phase 0: project setup
- [x] Phase 1: camera preview
- [x] Phase 2: hand tracking
- [x] Phase 3: rule-based gestures (needs testing on the Mac)
- [ ] Phase 4: editing with gestures
- [ ] Phase 5: polish
- [ ] Phase 6: custom ML classifier
