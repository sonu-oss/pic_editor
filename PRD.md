# GestureEdit — Product Requirements Document

Oct 18, 2026 · @sohan

## 1. Overview

GestureEdit is a native macOS photo editor controlled entirely by hand gestures seen through the MacBook's built-in camera, with all processing on-device. It is built with Apple frameworks only, so 90% of the code ports to iOS unchanged.

**One-line pitch:** a touch-free, privacy-first photo editor — pinch the air to brighten a photo, swipe to change tools, flash a peace sign to undo.

### Goals (v1)

| # | Goal | Measured by |
| --- | --- | --- |
| G1 | Edit a photo end to end (open, adjust, apply a preset, undo, export) without touching keyboard or trackpad | Manual demo run, start to finish |
| G2 | Gestures feel reliable | ≥ 90% recognition accuracy; < 1 false trigger per minute of normal hand movement |
| G3 | Edits feel live | Camera + hand tracking ≥ 30 fps; gesture-to-visible-change latency < 100 ms |
| G4 | Fully private | Zero network calls; no photo or camera frame leaves the Mac |
| G5 | iOS-ready | All logic lives in a `Shared` module with no AppKit imports |
| G6 | Real ML component | A custom gesture classifier trained in Create ML, with a reported confusion matrix |

### Non-goals (v1)

- Generative AI edits (sky replacement, inpainting, text-to-edit)
- Cloud features, accounts, sync, or any server
- Video editing or RAW processing
- iPhone build (planned for v2; the architecture prepares for it)
- App Store release (needs the paid developer account)
- Using any camera other than the MacBook's built-in camera

## 2. Target environment and tech stack

The app targets a MacBook Air M5 (16 GB RAM) and uses only Apple's free, on-device frameworks; total cost is ₹0.

### Environment

| Item | Choice |
| --- | --- |
| Hardware | MacBook Air, Apple M5, 16 GB RAM, built-in FaceTime camera |
| OS / IDE | Latest macOS + latest Xcode from the Mac App Store |
| Xcode project type | Multiplatform App (macOS target now, iOS target added in v2) |
| Deployment targets | macOS 15+, iOS 18+ (allows the modern Swift Vision API) |
| Language | Swift 6 with strict concurrency |
| Signing | Free Personal Team (Apple ID in Xcode → Settings → Accounts) |
| Tests | Swift Testing (`@Test`) for logic; manual camera tests |
| Version control | Git + a private GitHub repo from day 1 |

### Frameworks

| Job | Framework / API | Same on iOS? |
| --- | --- | --- |
| UI | SwiftUI, `@Observable` models | Yes |
| Camera frames | AVFoundation: `AVCaptureSession`, `AVCaptureVideoDataOutput` | Yes |
| Hand tracking (21 joints per hand) | Vision: `DetectHumanHandPoseRequest` (or `VNDetectHumanHandPoseRequest`) | Yes |
| Photo adjustments + presets | Core Image: `CIFilter` built-ins, Metal-backed `CIContext` | Yes |
| Background removal (stretch) | Vision foreground instance mask request | Yes |
| Custom gesture model | Create ML app → Hand Pose Classifier template | Trained on Mac only |
| Running the model | Core ML | Yes |
| Open / export images | `NSOpenPanel` / `NSSavePanel` (macOS); `PhotosPicker` (iOS v2) | Platform-specific wrapper |

### Hard rules

1. No third-party dependencies in v1. Apple frameworks only.
2. No network code anywhere. App Sandbox on, with only *Camera* and *User Selected File (Read/Write)* enabled.
3. Nothing in `Shared/` may import AppKit or UIKit.
4. `Info.plist` must contain `NSCameraUsageDescription`: "GestureEdit uses the camera to read your hand gestures. Video never leaves your Mac."

## 3. Users and user stories

The primary user is someone at a MacBook who wants quick, good-looking edits without menus. A secondary user is a presenter demoing edits to a room.

| ID | As a… | I want to… | So that… | Priority |
| --- | --- | --- | --- | --- |
| US1 | User | open a photo and see it beside my camera feed | I can edit while watching my hand | Must |
| US2 | User | see which gesture the app thinks I'm making | I trust it and can correct myself | Must |
| US3 | User | arm editing with a deliberate gesture | random hand movement never changes my photo | Must |
| US4 | User | pinch and move my hand up/down to change a value | adjusting feels like turning a dial | Must |
| US5 | User | swipe to switch between tools | I can reach brightness, contrast, warmth, etc. | Must |
| US6 | User | point at a preset and hold to apply it | I get a good look in one move | Must |
| US7 | User | undo with a gesture | mistakes cost nothing | Must |
| US8 | User | export with a gesture or ⌘S | I keep the result | Must |
| US9 | User | do every action from the keyboard too | I can work when lighting is bad | Must |
| US10 | User | see a before/after comparison | I can judge my edit | Should |
| US11 | User | zoom and pan with two hands | I can check details | Could |
| US12 | User | remove the background with one gesture | I can make clean cut-outs | Could |
| US13 | User | teach the app a custom gesture | it fits how my hands move | Could (Phase 6) |

## 4. Gesture vocabulary

Eight static poses plus hand motion drive every action, and no edit happens unless editing is armed first. Each action also has a keyboard shortcut.

**Mnemonic:** *Palm Plans, Pinch Tunes, Point Picks, Peace Undoes, Thumb Keeps, Fist Stops.*

### Gesture → action map

| Gesture | Works when | Action | Keyboard fallback |
| --- | --- | --- | --- |
| Open palm, held 0.8 s | Idle | Arm editing | Space |
| Pinch (thumb + index) + move up/down | Armed | Change active tool's value (full camera height = full range) | ↑ / ↓ |
| Open palm, fast swipe right / left | Armed | Next / previous tool | → / ← |
| Point (index only) | Armed | Move on-screen cursor | Mouse |
| Point, held still 0.8 s | Armed, cursor on a button | Click (apply preset, press button) | Click |
| Peace sign (index + middle) | Armed | Undo (one step per gesture) | ⌘Z |
| Thumbs up, held 1 s | Armed | Export | ⌘S |
| Fist | Armed | Cancel current pinch (revert) or disarm | Esc |
| Two-hand pinch, spread / close | Armed | Zoom in / out (Phase 5 stretch) | ⌘+ / ⌘− |

**Tools, in swipe order:** Exposure → Brightness → Contrast → Saturation → Warmth → Highlights → Shadows → Vignette → Sharpness.

### Gesture states

&#91;embedded content: gesture states · 4 states, arming required\]

Every edit starts from Armed, so a hand that wanders into view in Idle can never change the photo.

### Detection rules (rule-based v1)

All distances are normalized by hand size, so rules work near and far from the camera.

- **Hand scale** `s` = distance(wrist, middle-finger MCP).
- **Joint confidence:** ignore any joint below 0.3; ignore the whole hand if fewer than 15 joints pass.
- **Finger extended:** distance(wrist, tip) > 1.3 × distance(wrist, PIP). The thumb uses distance(thumbTip, index MCP) > 0.6 × s.
- **Pinch:** distance(thumbTip, indexTip) / s < 0.25 to enter, > 0.40 to exit (hysteresis stops flicker).
- **Open palm:** all 5 fingers extended.
- **Point:** only the index extended.
- **Peace:** only index + middle extended.
- **Thumbs up:** only the thumb extended and thumbTip above the wrist (y larger in Vision coordinates).
- **Fist:** no finger extended.
- **Swipe:** open palm whose wrist x-velocity > 1.5 screen-widths per second for ≥ 3 frames; 0.5 s cooldown after each swipe.
- **Stable pose:** a pose counts only after it wins 4 of the last 5 frames.
- **Pinch drag:** value delta = −Δy of the pinch midpoint × tool range. Movement starts counting only after the pinch is held 150 ms.

All numbers above are starting values. They live in one `GestureConfig` struct so they can be tuned without code changes.

### Safety behaviours

- Auto-disarm after 5 s with no hand in view.
- When the hand is lost mid-pinch, the value freezes (not reverted). A fist reverts.
- A gesture ends one action. Undo does not repeat while the peace sign is held; the hand must leave the pose first.
- Vision coordinates have the origin at bottom-left. Convert once in `HandTracker`, and mirror x so moving right moves the cursor right.

## 5. Functional requirements

The app has seven modules; each requirement below has an ID so prompts and commits can reference it.

### 5.1 Camera (`CameraManager`)

- **CAM-1** Use the default built-in video device; request permission on first launch and show a clear screen if denied, with a button to open System Settings.
- **CAM-2** Capture at 1280×720, 30 fps, BGRA pixel buffers, on a background queue.
- **CAM-3** Set `alwaysDiscardsLateVideoFrames = true` so tracking never lags behind reality.
- **CAM-4** Show a mirrored live preview (picture-in-picture, bottom-right, resizable, can be hidden).
- **CAM-5** Stop the session when the window is minimized or the app is inactive; restart on return.

### 5.2 Hand tracking (`HandTracker`)

- **HT-1** Run Vision hand pose on every frame, up to 2 hands.
- **HT-2** Output a `HandFrame`: timestamp + list of `Hand` (chirality, 21 joints with normalized point and confidence).
- **HT-3** Convert to top-left origin and mirror x here, nowhere else.
- **HT-4** Smooth each joint with a One Euro filter (start values: minCutoff 1.0, beta 0.007, dCutoff 1.0).
- **HT-5** If Vision is still busy with the previous frame, drop the new one.

### 5.3 Gesture engine (`GestureRecognizer` + `GestureStateMachine`)

- **GE-1** `GestureClassifier` protocol: `Hand → HandPose` (`.openPalm, .pinch, .point, .peace, .thumbsUp, .fist, .none`). Two implementations: `RuleBasedClassifier` (v1) and `MLClassifier` (Phase 6), switchable in Settings.
- **GE-2** Pose stabilizer: 4-of-5 frame vote (Section 4).
- **GE-3** Motion tracker: wrist and pinch-midpoint velocity for swipes and drags.
- **GE-4** State machine with states `idle`, `armed`, `adjusting`, `pointing`, emitting `EditCommand` values. Pure Swift, no frameworks, fully unit-tested.
- **GE-5** All thresholds in `GestureConfig`.

### 5.4 Editor (`EditState` + `RenderPipeline`)

- **ED-1** `EditState` is a `Codable`, `Equatable` struct of all tool values plus the selected preset.
- **ED-2** Tool → Core Image mapping:

| Tool | Core Image filter | Range | Default |
| --- | --- | --- | --- |
| Exposure | `exposureAdjust` (EV) | −2 … +2 | 0 |
| Brightness | `colorControls.brightness` | −0.5 … +0.5 | 0 |
| Contrast | `colorControls.contrast` | 0.5 … 1.5 | 1 |
| Saturation | `colorControls.saturation` | 0 … 2 | 1 |
| Warmth | `temperatureAndTint` (Kelvin) | 4000 … 9000 | 6500 |
| Highlights | `highlightShadowAdjust.highlightAmount` | 0 … 1 | 1 |
| Shadows | `highlightShadowAdjust.shadowAmount` | −1 … 1 | 0 |
| Vignette | `vignette.intensity` | 0 … 2 | 0 |
| Sharpness | `sharpenLuminance.sharpness` | 0 … 2 | 0 |

- **ED-3** Presets (6): Original, Vivid, Warm Film, Cool Matte, Noir (`photoEffectNoir`), Chrome (`photoEffectChrome`). A preset sets a base look; tool sliders still apply on top.
- **ED-4** Live preview renders a downscaled proxy (longest side 2048 px) with one shared Metal-backed `CIContext`. Export renders full resolution.
- **ED-5** Render off the main thread and coalesce: if a render is running, keep only the newest pending `EditState`.

### 5.5 History (`EditHistory`)

- **HI-1** Undo/redo stack of `EditState` snapshots, max 50.
- **HI-2** One pinch = one history entry (pushed when the pinch ends, not every frame).
- **HI-3** Applying a preset = one entry.

### 5.6 HUD and UI

- **UI-1** Main window: photo canvas (center), tool strip (bottom), preset strip (right), camera PiP (bottom-right).
- **UI-2** Status pill (top-center): state (Idle / Armed / Adjusting), detected pose name + icon, active tool + value.
- **UI-3** Arming progress ring around the palm while the 0.8 s hold fills.
- **UI-4** Gesture cursor: a circle that fills over 0.8 s during dwell-click.
- **UI-5** Draw hand skeleton over the PiP (toggle in Settings; on by default during development).
- **UI-6** Before/after: hold B key, or a dedicated button clicked by dwell.
- **UI-7** Onboarding sheet on first launch: one card per gesture with an SF Symbol illustration.
- **UI-8** Settings: classifier choice, skeleton overlay, sensitivity slider (scales `GestureConfig`), dominant hand.

### 5.7 File I/O

- **IO-1** Open JPEG, PNG and HEIC via open panel or drag-and-drop.
- **IO-2** Export JPEG (quality 0.9) or HEIC, with the original's orientation and color space preserved.
- **IO-3** Never overwrite the original; default name `<original>-edited.jpg`.

## 6. Architecture

Data flows one way: camera → hands → poses → commands → one `@MainActor` model → rendered image. Keyboard and mouse send the same `EditCommand`s straight to `AppModel`, so gesture and keyboard paths share one code path.

&#91;embedded content: app architecture · 8 components, one-way data flow\]

Only `AppModel` changes `EditState`; every other component is either a producer of commands or a consumer of state.

### Project structure

```text
GestureEdit/
├── PRD.md, CLAUDE.md, README.md
├── Shared/                       ← no AppKit/UIKit; reused on iOS
│   ├── App/AppModel.swift        (@MainActor @Observable, owns EditState)
│   ├── Camera/CameraManager.swift
│   ├── Vision/HandTracker.swift, HandFrame.swift, OneEuroFilter.swift
│   ├── Gestures/GestureClassifier.swift      (protocol + HandPose)
│   ├── Gestures/RuleBasedClassifier.swift
│   ├── Gestures/MLClassifier.swift           (Phase 6)
│   ├── Gestures/GestureStateMachine.swift, GestureConfig.swift, EditCommand.swift
│   ├── Editing/EditState.swift, Tool.swift, Preset.swift
│   ├── Editing/RenderPipeline.swift, EditHistory.swift
│   ├── Debug/SessionRecorder.swift           (HandFrame record/replay)
│   ├── ML/GestureClassifier.mlmodel          (Phase 6)
│   └── Views/ (CanvasView, HUDView, CameraPiPView, ToolStrip, PresetStrip, OnboardingView, SettingsView)
├── macOS/   (GestureEditApp.swift, FilePanels.swift, KeyboardShortcuts.swift)
├── iOS/     (v2)
└── Tests/   (GestureTests, StateMachineTests, RenderTests, HistoryTests, Fixtures/*.json)
```

### Key types (sketch)

```swift
enum HandPose: String, Sendable, Codable, CaseIterable {
    case openPalm, pinch, point, peace, thumbsUp, fist, none
}

struct Joint: Sendable, Codable { var x, y: Double; var confidence: Double }
struct Hand: Sendable, Codable { var isLeft: Bool; var joints: [JointName: Joint] }
struct HandFrame: Sendable, Codable { var timestamp: TimeInterval; var hands: [Hand] }

protocol GestureClassifier: Sendable {
    func classify(_ hand: Hand) -> HandPose
}

enum EditCommand: Sendable, Equatable {
    case arm, disarm
    case beginAdjust, adjust(delta: Double), endAdjust, cancelAdjust
    case nextTool, previousTool
    case cursor(x: Double, y: Double), click
    case undo, redo, export
    case zoom(scale: Double)
}

struct GestureStateMachine {
    var config: GestureConfig
    mutating func consume(_ frame: HandFrame, poses: [HandPose]) -> [EditCommand]
}

struct EditState: Sendable, Codable, Equatable {
    var exposure = 0.0, brightness = 0.0, contrast = 1.0, saturation = 1.0
    var warmth = 6500.0, highlights = 1.0, shadows = 0.0, vignette = 0.0, sharpness = 0.0
    var preset: Preset = .original
}
```

### Concurrency plan

| Component | Runs on | Rule |
| --- | --- | --- |
| `CameraManager` | Its own serial `DispatchQueue` (sample-buffer delegate) | Never touches UI |
| `HandTracker` | Its own actor | Drops a frame if still busy |
| Classifier + `GestureStateMachine` | Inside a `GesturePipeline` actor | Value types in, `[EditCommand]` out |
| `AppModel` | `@MainActor` | The only owner of `EditState` and `EditHistory` |
| `RenderPipeline` | Its own actor | Keeps only the newest pending `EditState`; returns a `CGImage` to the main actor |

## 7. Non-functional requirements

The app must feel instant, stay private, and run cool on a fanless MacBook Air.

| Area | Requirement | How to check |
| --- | --- | --- |
| Tracking speed | Hand tracking ≥ 30 fps at 720p | FPS counter in debug HUD |
| Latency | Gesture → visible change < 100 ms | Log timestamps: frame captured → render done |
| Preview render | < 33 ms per proxy render | Instruments: Time Profiler |
| Export | 12 MP image exported in < 2 s | Stopwatch / log |
| CPU / heat | < 40% CPU while armed; camera paused when idle in background | Activity Monitor; Instruments |
| Memory | < 500 MB with a 12 MP photo open | Xcode memory gauge |
| Privacy | No network APIs used; no frames written to disk (except Phase 6 data-capture mode, opt-in, saved to a user-chosen folder) | Code search for `URLSession`; sandbox has no network entitlement |
| Reliability | No crash in a 15-minute continuous session | Manual soak test |
| Accessibility | Every action has a keyboard path; HUD text supports Dynamic Type sizes; VoiceOver labels on all buttons | Manual check |
| Code quality | Swift 6 strict concurrency, zero warnings; logic modules ≥ 70% test coverage | Xcode build + coverage report |

## 8. Build phases and acceptance criteria

Seven phases, about 6–7 weeks part-time; each phase ends with a working, committed app. Do not start a phase until the previous one's boxes are ticked.

### Phase 0 — Setup (½ day)

- [ ] Xcode Multiplatform App project `GestureEdit` created, builds and runs on Mac
- [ ] Folder structure from Section 6 in place, git repo pushed to GitHub
- [ ] Camera usage description + sandbox camera entitlement added
- [ ] `PRD.md` and `CLAUDE.md` in the repo root

### Phase 1 — Camera preview (2–3 days) · CAM-1…5

- [ ] Permission prompt appears on first launch; denied state shows a helpful screen
- [ ] Mirrored live preview at \~30 fps in the PiP
- [ ] Camera stops when the app goes to background

### Phase 2 — Hand tracking (2–3 days) · HT-1…5, UI-5

- [ ] 21 joints drawn on the PiP, lined up with the real hand
- [ ] Moving the hand right moves the skeleton right
- [ ] Debug HUD shows tracking FPS ≥ 30
- [ ] Smoothing on/off toggle visibly reduces jitter

### Phase 3 — Rule-based gestures (\~1 week) · GE-1…5, UI-2, UI-3

- [ ] Status pill shows the correct pose for all 6 poses
- [ ] Arming works only after a 0.8 s palm hold, with progress ring
- [ ] State machine unit tests pass (arm, disarm, pinch start/end, swipe cooldown, auto-disarm)
- [ ] Replay test: a recorded landmark session produces the expected command list

### Phase 4 — Editing with gestures (\~1 week) · ED-1…5, HI-1…3, IO-1…3

- [ ] Open a photo; pinch-drag changes the active tool live
- [ ] Swipe cycles tools; dwell-click applies presets
- [ ] Peace sign undoes one step; ⌘Z/⌘⇧Z work
- [ ] Thumbs-up exports a correct full-resolution file
- [ ] Gesture → visible change < 100 ms (logged)

### Phase 5 — Polish (4–5 days) · UI-1, UI-4, UI-6…8

- [ ] Onboarding sheet, Settings, before/after
- [ ] Two-hand zoom (stretch)
- [ ] 15-minute soak test with no crash; < 1 false trigger per minute
- [ ] Demo video recorded

### Phase 6 — Custom ML classifier (\~1 week) · Section 9

- [ ] In-app data-capture mode saves labelled frames
- [ ] Create ML model trained; accuracy and confusion matrix recorded in README
- [ ] `MLClassifier` switchable in Settings; side-by-side comparison with rule-based

### Phase 7 — Stretch

- [ ] Background removal via Vision foreground mask (US12)
- [ ] v2: add iOS target reusing `Shared/`

## 9. ML component: custom gesture classifier

Phase 6 replaces hand-written rules with a Create ML Hand Pose Classifier and proves it with numbers. This is the project's main ML talking point.

### Pipeline

1. **Capture:** a data-capture mode in the app. Pick a label, press Space, and it saves 1 frame every 200 ms into `<chosen folder>/<label>/`.
2. **Train:** Create ML app → new project → *Hand Pose Classification*, pointing at the folder.
3. **Export:** `GestureClassifier.mlmodel` dropped into `Shared/ML/`.
4. **Run:** feed `observation.keypointsMultiArray()` from Vision to the model; keep the existing 4-of-5 vote.

### Dataset plan

| Item | Target |
| --- | --- |
| Classes | openPalm, pinch, point, peace, thumbsUp, fist, **background** |
| Images per class | ≥ 300 (≥ 2,100 total) |
| People | ≥ 4 (you + 3 friends), both hands |
| Conditions | Daylight, room light, dim; near (40 cm) and far (90 cm); plain and busy backgrounds |
| Split | By person: 3 people train, 1 person test (avoids memorising one hand) |
| Augmentation | Create ML's built-in options (rotation, scaling, flip) |

The **background** class is essential. It holds random hand positions, hands moving between poses, and scratching or typing. Without it the model forces every frame into a gesture, and false triggers rise.

### Metrics to report in the README

| Metric | Rule-based | ML | Target |
| --- | --- | --- | --- |
| Accuracy on held-out person | measure | measure | ≥ 90% |
| Per-class precision / recall | measure | measure | ≥ 85% each |
| False triggers per minute (typing + talking) | measure | measure | < 1 |
| Inference time per frame | measure | measure | < 5 ms |

Add the confusion matrix image from Create ML, plus one paragraph on which poses get confused and why.

## 10. Testing, risks and success metrics

The gesture logic is tested without a camera by recording landmark sessions once and replaying them.

### Testing plan

| Layer | Method | Tool |
| --- | --- | --- |
| Gesture rules + state machine | Unit tests on hand-made `Hand` fixtures (one per pose + edge cases) | Swift Testing |
| End-to-end gesture logic | **Record/replay:** a debug toggle saves `HandFrame`s to JSON; tests replay a session and assert the `EditCommand` sequence | Swift Testing |
| Render pipeline | Render a fixed `EditState` on a test image; compare against a saved reference within a tolerance | Swift Testing |
| History | Undo/redo sequences, 50-step cap | Swift Testing |
| Camera + real hands | Manual checklist per phase (Section 8) | You |
| Performance | Time Profiler, FPS/latency logs | Instruments |

### Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Jittery landmarks make sliders shake | High | One Euro filter, 150 ms pinch settle, hysteresis |
| Accidental triggers while typing or talking | High | Arming gesture, 4-of-5 vote, cooldowns, background class (Phase 6) |
| Poor lighting lowers joint confidence | Medium | Confidence gate, low-light warning in HUD, keyboard fallback |
| Arm fatigue from holding hands up | Medium | Small movements, sensitivity setting, hand can rest low in frame |
| Main thread blocked by Vision or Core Image | High | Separate queues, frame dropping, render coalescing |
| Swift 6 concurrency errors slow progress | Medium | Clear actor plan (Section 6), `Sendable` value types |
| Thermal throttling on the fanless Air | Low | Pause camera when idle/background; proxy render |
| Scope creep (AI features) | Medium | Non-goals list; stretch items only after Phase 5 |

### Success metrics (v1 done)

- All Must user stories pass the Section 8 checklists
- ≥ 90% gesture accuracy, < 1 false trigger/minute, < 100 ms latency
- README with demo GIF, architecture diagram, metrics table, and confusion matrix
- 60–90 s demo video for LinkedIn and your resume

## 11. How to build this with Claude

Create the Xcode project yourself, then let Claude write code one phase at a time while you run and test on the Mac. Claude cannot see your camera, so you are the tester.

### Setup steps

1. In Xcode: File → New → Project → **Multiplatform → App**, name `GestureEdit`, interface SwiftUI, testing system Swift Testing. Save it inside a new git repo.
2. Export this doc as Markdown and save it as `PRD.md` in the repo root.
3. Create `CLAUDE.md` in the repo root with the content below.
4. Open the repo folder in Claude (Claude Code in Terminal, or the desktop app with the folder connected).
5. After each phase: build and run in Xcode (⌘R), test with your hands, tick the boxes in Section 8, commit.

### `CLAUDE.md`

```markdown
# GestureEdit — rules for Claude

Read PRD.md before any work. Requirement IDs (CAM-1, GE-4…) come from it.

- Swift 6, strict concurrency, SwiftUI, macOS 15+ / iOS 18+.
- Apple frameworks only. No third-party packages. No networking code.
- Nothing in Shared/ may import AppKit or UIKit. Platform code goes in macOS/.
- Value types (structs, enums) for data; mark them Sendable.
- One phase at a time. Stop at the end of the phase and list what to test manually.
- Every logic change in Shared/Gestures, Shared/Editing comes with Swift Testing tests.
- Build check: xcodebuild -scheme GestureEdit -destination 'platform=macOS' build
- Test check: xcodebuild -scheme GestureEdit -destination 'platform=macOS' test
- Never edit project.pbxproj by hand unless asked; tell me which files to add in Xcode if needed.
- Keep all gesture thresholds in GestureConfig.
```

### Kickoff prompt

```text
Read PRD.md and CLAUDE.md. Do Phase 0 and Phase 1 only (CAM-1 to CAM-5).
First give me a short plan: files you will create and the concurrency design
(which actor/queue owns the capture session, how frames reach SwiftUI).
Wait for my OK, then implement, build with xcodebuild, fix all errors
and warnings, and give me the Phase 1 manual test checklist.
```

### Prompts for later phases

| Phase | Prompt |
| --- | --- |
| 2 | `Implement Phase 2 (HT-1…HT-5, UI-5). Add a OneEuroFilter with unit tests. Show an FPS counter in a debug overlay.` |
| 3 | `Implement Phase 3 (GE-1…GE-5, UI-2, UI-3). Write the state machine as pure Swift with full unit tests first, then wire it up. Add the HandFrame record/replay debug feature.` |
| 4 | `Implement Phase 4 (ED, HI, IO requirements). Render a 2048 px proxy on a background task with coalescing. Log gesture-to-render latency.` |
| 5 | `Implement Phase 5 polish (UI-1, UI-4, UI-6…UI-8). Then review the whole codebase for main-thread work and concurrency warnings.` |
| 6 | `Add data-capture mode from Section 9, then an MLClassifier conforming to GestureClassifier that loads GestureClassifier.mlmodel. Add a Settings switch.` |

### Working tips

- When something misbehaves, describe what you saw ("pinch shows as point when my hand is far") and paste logs. Claude fixes faster with symptoms than with "it's broken".
- Tune thresholds yourself in `GestureConfig` before asking for logic changes.
- Ask Claude to explain any code you don't understand. You need to defend it in interviews.
