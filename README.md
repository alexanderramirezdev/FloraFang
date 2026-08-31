# FloraFang

An iOS nature identification app that tells you what you're looking at — and, more importantly, tells you when it doesn't know.

FloraFang identifies plants and spiders from a photo using on-device Core ML models. It runs entirely on the device: there is no backend, no account, and no network layer anywhere in the app. Photos never leave the phone.

---

## Why the "confidence gate" matters

Most classifier-backed apps show you their top prediction no matter how uncertain the model is. For a nature app that surfaces hazard information, that's the wrong default — a confidently-wrong answer about whether a plant or spider is dangerous is worse than no answer at all.

FloraFang wraps every prediction in a confidence gate. A classification is only surfaced to the user when it clears a threshold; below that, the app returns an explicit "not confident enough to say" state rather than falling back to the highest-scoring label.

This has a few consequences that shaped the architecture:

- **The uncertain state is a real result, not an error.** It's modeled explicitly rather than represented as a nil or a failure case, so the UI can't accidentally render an ungated prediction.
- **Hazard information is never shown without a gated identification behind it.** The order of operations is enforced in code, not by convention.
- **Thresholds are tunable per model.** Plant and spider classifiers have different error profiles and different costs of being wrong.

## Models

Two compiled Core ML classifiers ship with the app:

| Model | Purpose |
|---|---|
| `PlantHazard.mlmodel` | Plant identification and hazard classification |
| `SpiderHazard.mlmodel` | Spider identification and hazard classification |

Both are compiled artifacts committed to the repository, so the project builds and runs after a clone with no additional setup.

## Architecture

- **SwiftUI** throughout, with a `Palette` type holding shared visual tokens so screens don't drift apart as the app grows.
- **SwiftData** for local persistence of identification history.
- **Vision + Core ML** for image classification, with the confidence gate sitting between the raw model output and anything the user sees.
- **No networking layer.** Not "we don't send data" as a policy — there is no code in the project capable of making a network request.

## Requirements

- Xcode 26 or later
- iOS 26 or later
- Swift 6 / SwiftUI

## Building

```bash
git clone https://github.com/alexanderramirezdev/FloraFang.git
cd FloraFang
open FloraFang.xcodeproj
```

Select an iOS Simulator or a connected device and run. Camera capture requires a physical device; the photo library path works in the Simulator.

## Status

In external TestFlight. This repository is published as a portfolio and reference project — see the license below regarding reuse.

## A note on the name

Earlier commit history in this repository refers to the project as *Quadrat*. The app was renamed to FloraFang during development; the two names refer to the same project.

## License

See [LICENSE](LICENSE). The source is published for reading, evaluation, and reference. It is not licensed for redistribution or for shipping derivative applications.

---

Built by Alexander Ramirez · [Ramirez Labs](https://ramirezlabs.app)
