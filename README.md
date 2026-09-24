# BKeyboard

Personal Arabic/English keyboard for iPhone. Native Swift, local-first.

```
BKeyboard.xcodeproj
App/                  Containing app (SwiftUI): setup + test bench of field types
KeyboardExtension/    Custom keyboard (UIKit): layout, touch handling, UITextDocumentProxy glue
Packages/KeyboardCore Pure-Swift engine: layouts, shift/autocap, double space, delete repeat, latency
Config/               Extension Info.plist
docs/                 Spikes and specs
```

Current phase: **Phase 0 / TS-01**. See [docs/TS-01-Keyboard-Foundation.md](docs/TS-01-Keyboard-Foundation.md) for build steps and the on-device test matrix.

Core tests:

```bash
cd Packages/KeyboardCore && swift test
```
