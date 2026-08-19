# Validation status

## Completed in this environment

- Every Swift source file passes the Swift compiler's `-parse` grammar check.
- The project contains an Xcode project file, Info.plist, asset catalog, SwiftData model, navigation shell, and feature source tree.
- The app source is committed in a local Git repository.

## Requires Xcode on macOS

This runtime does not include Apple's iOS/SwiftUI SDKs or an iPhone Simulator, so the following must be verified in Xcode:

- full SwiftUI/SwiftData type-check and compile
- SF Symbol availability on the chosen deployment target
- code signing / bundle identifier
- real Dynamic Island and bottom safe-area spacing
- accessibility at larger Dynamic Type sizes
- performance of map gestures on-device
- exact visual fidelity on the intended iPhone

The first Xcode build is therefore a deliberate validation milestone, not just an installation step.
