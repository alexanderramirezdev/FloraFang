# Quadrat — build setup

## Create the project

1. Xcode → **New Project → iOS → App**
2. Product Name: `Quadrat`
3. Interface: **SwiftUI**, Language: **Swift**, Storage: **None**
4. Minimum Deployment: **iOS 26.0**
5. Delete the generated `ContentView.swift` and the generated `QuadratApp.swift`

## Add the files

Drag these in individually (not as a folder or zip — zips create duplicate references):

- `QuadratApp.swift`
- `FieldEntry.swift`
- `Catalog.swift`
- `IdentificationService.swift`
- `CameraService.swift`
- `CameraPreview.swift`
- `CameraScreen.swift`
- `ResultScreen.swift`
- `FieldLogScreen.swift`

Check **Copy items if needed** and confirm the Quadrat target is ticked.

## Required Info.plist key

Target → **Info** tab → add:

| Key | Value |
|---|---|
| `NSCameraUsageDescription` | Quadrat uses the camera to identify plants and animals you point it at. |

Without this the app hard-crashes the moment it touches the camera.

## Must run on a real device

The simulator has no camera. Build to your iPhone. Signing → select your personal team; a free Apple ID works for on-device testing.

---

## What this build actually does

Apple's on-device classifier identifies **categories, not species.**

It will tell you "spider." It will not tell you "black widow."

That's a real ceiling, not a bug in this code — the OS taxonomy is roughly a
few thousand general labels, and no species-level model is bundled. So v1 is:

**camera → category → local hazard + field guidance**

which is honest and useful for the "should I be worried about this thing in my
bedroom" case, and useless for the "what exact flower is this" case.

### Finding the ceiling yourself

`IdentificationService.debugLabels(_:)` returns the full ranked label list.
Wire it to a temporary button and photograph 20–30 things around the house and
yard. Write down what Vision emits. That tells you two things:

1. Which `matchTerms` in `Catalog.swift` need to change to match reality
2. Whether category-level ID is enough for the app you want

Do this before writing another line of feature code. It's a 30-minute test that
decides the whole architecture.

### If category-level isn't enough

Three paths, in order of effort:

1. **External API** — Pl@ntNet (plants, free tier) or iNaturalist's computer
   vision endpoint. Species-level, needs network, needs a key. Fastest to real
   accuracy.
2. **Bundled Core ML model** — train on iNaturalist data with Create ML, convert
   with `coremltools`. Offline, but you're now maintaining a model and the
   accuracy bar set by Seek and Merlin is high.
3. **Hybrid** — Vision decides the coarse category offline, then routes to a
   category-specific model or API only when the user asks for species detail.
   Keeps the fast path offline and private, spends network only when it pays.

Path 3 is where a real differentiator lives, given the competitive landscape.

## Known rough edges

- No location capture yet. `FieldEntry` has `latitude`/`longitude` fields
  waiting; add CoreLocation when you want habitat context.
- Photo orientation from `fileDataRepresentation()` is usually correct but
  worth verifying in landscape.
- The center-crop happens inside Vision, so it crops the *full frame*, not the
  on-screen square. They're close but not identical — if results feel off, crop
  the `UIImage` to the visible square before handing it to the classifier.

---

# UPDATE — cascade architecture added

## Revised file list

Delete `IdentificationService.swift` if you already added it. It's been folded
into the cascade.

Add all of these:

- `QuadratApp.swift`
- `FieldEntry.swift`
- `Catalog.swift`
- `Assessment.swift`          ← new
- `SpiderClasses.swift`       ← new
- `ConfidenceGate.swift`      ← new
- `HazardClassifier.swift`    ← new
- `RemoteIdentifier.swift`    ← new
- `IdentificationCascade.swift` ← new
- `CameraService.swift`
- `CameraPreview.swift`
- `CameraScreen.swift`        ← replaced
- `ResultScreen.swift`        ← replaced
- `FieldLogScreen.swift`

## App icon

`AppIcon/AppIcon-1024.png` — drag into `Assets.xcassets` → `AppIcon`, into the
1024pt single-size slot. Xcode 16+ derives the rest.

`AppIcon/icon-preview.png` is just a legibility check at 180/120/87/60/40px,
not for the project.

## How the cascade behaves right now

With no trained model in the bundle:

1. **Tier 1** classifies the coarse category (spider / plant / bird / …)
2. Non-spiders resolve here from the catalog — same as before
3. Spiders skip Tier 2 (no model), skip Tier 3 (disabled), and land on
4. **Tier 4** — an honest refusal that tells the user it's a spider, that it is
   *not* ruling out a widow or recluse, and how to get a better answer

That's a shippable v1. It makes no network calls and no claims it can't support.

## The trace

Every result screen has a collapsed **cascade trace** at the bottom showing
which tiers ran and what each said. Leave it in during development — it's what
you'll read while calibrating. Hide it behind a debug flag before shipping.

## Next: training

See `TRAINING.md`.
