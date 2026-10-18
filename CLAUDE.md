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
- Keep all gesture thresholds in GestureConfig.
- The owner is new to Swift: explain new code in plain language when handing it over.

## Project file

- Shared/, macOS/ and Tests/ are synchronized folders: any file added under them is
  picked up by Xcode automatically. Don't edit project.pbxproj to add files.
- Shared/ and macOS/ build into the GestureEdit app target; Tests/ builds into GestureEditTests.
- Camera permission text and sandbox settings live in the target build settings
  (INFOPLIST_KEY_NSCameraUsageDescription) and GestureEdit.entitlements.
- Cloud sessions can't run xcodebuild (no macOS there). Builds and camera tests happen on the owner's Mac.
