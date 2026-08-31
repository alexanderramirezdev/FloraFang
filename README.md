# FloraFang

An iOS nature identification app that tells you what you're looking at — and, more importantly, tells you when it doesn't know.

FloraFang identifies plants and spiders from a photo using on-device Core ML models. It runs entirely on the device: there is no backend, no account, and no network layer anywhere in the app. Photos never leave the phone.

---

## Why the "confidence gate" matters

Most classifier-backed apps show you their top prediction no matter how uncertain the model is. For a nature app that surfaces hazard information, that's the wrong default — a confidently wrong answer about whether a plant or spider is dangerous is worse than no answer at all.

FloraFang wraps every prediction in a confidence gate. A classification is only surfaced when it clears a threshold; below that, the app returns an explicit "not confident enough to say" state rather than falling back to the highest-scoring label.

The refusal is the product. Accuracy is not the differentiator against a Cornell-scale training set — calibrated refusal is.

### Calibration status

The gate is enforced in code. The thresholds it enforces are **not yet calibrated**. Current values are reasoned defaults, not measured ones.

The app is in external TestFlight, and threshold calibration against tester ground truth is the next piece of work. Until that lands, this README does not claim a false-refusal rate, because there isn't a measured one to claim.

## Models

Two compiled Core ML classifiers ship with the app:

| Model | Purpose |
|---|---|
| `PlantHazard.mlmodel` | Plant identification and hazard classification |
| `SpiderHazard.mlmodel` | Spider identification and hazard classification |

Both are committed to the repository, so the project builds and runs after a clone with no additional setup.

## Architecture

- **SwiftUI** throughout, with a `Palette` type holding shared visual tokens so screens don't drift apart as the app grows.
- **SwiftData** for local persistence of field log entries.
- **Vision + Core ML** for image classification, with `IdentificationCascade` sitting between raw model output and anything the user sees.
- **No networking layer.** Not "we don't send data" as a policy — there is no code in the project capable of making a network request.

### Branches

`main` is the shipping app and builds against the current public SDK.

`foundation-models` holds an in-progress second extraction tier built on Apple's Foundation Models framework, using guided generation over a closed diagnostic vocabulary — visible field marks a user can actually verify by looking, rather than expert terminology they can't check. **That branch requires the iOS 27 SDK and does not build against the current public Xcode.** It will merge once the SDK ships publicly.

## Requirements

- Xcode 26
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

In external TestFlight. Published as a portfolio and reference project — see the license below regarding reuse.

## A note on the name

Earlier commit history refers to this project as *Quadrat*. The app was renamed to FloraFang during development; the two names refer to the same project.

## License

See [LICENSE](LICENSE). The source is published for reading, evaluation, and reference. It is not licensed for redistribution or for shipping derivative applications.

---

Built by Alexander Ramirez · [Ramirez Labs](https://ramirezlabs.app)
