# Where we are and what's next

_Last updated: 18 Oct 2026_

## Done

| Phase | What | Status |
| --- | --- | --- |
| 0 | Xcode project, sandbox, camera permission, PRD + CLAUDE.md | Built and run on the Mac ✅ |
| 1 | Mirrored camera preview (PiP), permission screen, pauses in background | Tested on the Mac ✅ (30 fps) |
| 2 | Vision hand tracking, One Euro smoothing, skeleton overlay, FPS panel | Tested on the Mac ✅ |
| 3 | Pose classifier, 4-of-5 vote, gesture state machine, status pill, arming ring, gesture recorder, tests | Written in PR #2, **not yet built or tested** |

## Next, in order

1. **Finish Phase 3.** Merge PR #2, pull in Xcode, press ⌘R, then ⌘U.
   - Fix any build errors first (paste them to Claude).
   - Check every item in PRD Section 8, Phase 3. If a pose is misread, look at "Raw pose" in the debug panel and tune `Shared/Gestures/GestureConfig.swift`.
2. **Phase 4: editing with gestures** (ED, HI, IO requirements). This is the second half of plan step 3: open a photo, have the tool values drive Core Image filters, undo/redo history and export.
   - `AppModel.toolValues` and `apply(_:)` are placeholders. Replace them with `EditState`, `EditHistory` and `RenderPipeline`.
3. **Phase 5: polish** (UI-1, UI-4, UI-6…8: gesture cursor, before/after, onboarding, Settings).
4. **Phase 6: custom ML gesture classifier** (PRD Section 9). `GestureClassifier` is already a protocol, so `MLClassifier` slots in next to `RuleBasedClassifier`.

## How to keep going with Claude

- **Claude Code on your Mac** is best, because it can run `xcodebuild` and fix errors itself. Open Terminal in this folder and run `claude`, or connect the folder in the Claude desktop app. It reads `CLAUDE.md` automatically.
- Prompt for the next phase (from PRD Section 11):

  ```text
  Read PRD.md, CLAUDE.md and NEXT_STEPS.md. Finish checking Phase 3, then implement
  Phase 4 (ED, HI, IO requirements). Render a 2048 px proxy on a background task with
  coalescing. Log gesture-to-render latency. Build with xcodebuild, fix all errors and
  warnings, run the tests, and give me the Phase 4 manual test checklist.
  ```

- Work one phase at a time, test with your hands, tick the boxes in PRD Section 8 and commit.

## Notes for whoever picks this up

- New files under `Shared/`, `macOS/` and `Tests/` are picked up by Xcode automatically. Don't edit `project.pbxproj`.
- Hand tracking runs on the camera's video queue, and late frames are dropped there. Hand frames reach the `@MainActor` `AppModel` through an `AsyncStream` that keeps only the newest frame. The gesture pipeline currently runs on the main actor (cheap); move it to an actor only if profiling says so.
- The gesture classifier stretches x by 16/9 (`GestureConfig.aspectRatio`) so distances are real proportions.
- Point and peace ignore the thumb. A pinch requires the index finger to reach out, so a fist isn't read as a pinch.
