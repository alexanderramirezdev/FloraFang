# Quadrat

*A closer look at what's around you.*

An iOS app that identifies plants, animals, and fungi from the camera — and,
unusually for this category, tells you when it doesn't know.

---

## The premise

The "point your phone at nature" space is crowded. Seek, Merlin, PictureThis,
Nature ID, Wildex, Fieldbook all exist and several are good. Quadrat isn't
trying to have the biggest species database.

The bet is on a different axis: **an app that refuses to guess.**

Every competitor names a species at 40% confidence. For "is this flower
pretty," that's fine. For "is this spider in my daughter's room dangerous," a
confident wrong answer is worse than no answer. Quadrat is built so that
"I can't tell you, and here's what to do instead" is a first-class result
rather than an error state.

---

## Architecture: the cascade

Identification runs through four tiers. Each fires only when the one above it
isn't confident enough.

| Tier | What | Cost | Status |
|---|---|---|---|
| 1 | Apple Vision coarse category | offline, ~50ms | **live** |
| 2 | Core ML spider hazard model | offline, ~100ms | **awaiting trained model** |
| 3 | Remote model | network, per-request | **off by default** |
| 4 | Structured refusal | free | **live** |

Tier 4 always answers, so the cascade never fails to return something honest.

Tier 3 is deliberately disabled rather than merely unimplemented. With it off,
Quadrat makes **zero network calls** — no accounts, no photo uploads, no
telemetry. That's a real differentiator against the competition and shouldn't
be traded away casually.

### Why a cascade rather than one model

The expensive, accurate options are the ones you want to use rarely. Routing
through cheap-and-offline first means the common cases never touch the network,
and the architecture stays useful even if the trained model underperforms —
which is a real possibility worth designing for rather than hoping against.

---

## Scope: what this can and cannot do

**Apple's on-device classifier identifies categories, not species.** It will
say "spider." It will not say "black widow." There is no bundled species model
in iOS and no public API to iNaturalist's.

So the plan is deliberately narrow: rather than a 4,000-class species model,
Tier 2 targets a ~10-class **hazard** model — widow, recluse, and the common
harmless groups. Species-level spider ID from a phone photo is often impossible
even for arachnologists (many species separate only on microscopic features),
but "is this one of the two medically significant groups" is tractable and is
the question users actually have.

---

## File map

**Entry & shell**
- `QuadratApp.swift` — app entry, SwiftData container, `Palette` design tokens

**Identification**
- `IdentificationCascade.swift` — tier orchestration, hazard-aware routing
- `Assessment.swift` — the unified result type every tier produces
- `Catalog.swift` — category knowledge: hazards, field notes, match terms
- `SpiderClasses.swift` — the label space for the hazard model
- `HazardClassifier.swift` — Core ML wrapper (degrades gracefully with no model)
- `ConfidenceGate.swift` — asymmetric thresholds, escalation logic
- `RemoteIdentifier.swift` — Tier 3 seam, disabled

**Camera**
- `CameraService.swift` — session lifecycle, virtual device, zoom, focus
- `CameraPreview.swift` — UIKit bridge, tap-to-focus, pinch-to-zoom
- `ImageCropping.swift` — orientation normalization, quadrat-square cropping

**UI**
- `CameraScreen.swift` — viewfinder, zoom control, capture
- `ResultScreen.swift` — assessment display, cascade trace
- `FieldLogScreen.swift` — saved entries list
- `EntryDetailScreen.swift` — entry detail, editable note, zoomable photo
- `LabelInspector.swift` — dev tool: raw Vision labels

**Data**
- `FieldEntry.swift` — SwiftData model

**Docs**
- `SETUP.md` — Xcode project setup
- `TRAINING.md` — how to train the Tier 2 model
- `TEST-PASS.md` — manual test checklist

---

## Design decisions worth not undoing

**Word-boundary matching in `Catalog.swift`.** The original used substring
matching, which called a gravel driveway a "Plant" because *street* contains
*tree*. Same trap: *owl* in *bowl*, *fox* in *foxglove*, *bat* in *bathroom*.
Substring matching on short natural-language terms is always wrong here.

**Crop before classify.** A spider on a wall is ~2% of the pixels. Classifying
the full frame means the model describes stucco. Cropping to the framed subject
is the single largest accuracy lever available without training anything.

**Hazard-aware routing, not first-match-wins.** Vision confuses spiders and
insects constantly. If "insect" scores 0.25 and "spider" 0.20, rank order sends
it down the insect path and the hazard classifier never runs — meaning a widow
gets reported as "most insects are harmless." Dangerous categories now win
ties. Being wrong toward caution costs the user nothing.

**Asymmetric confidence thresholds.** Missing a widow is categorically worse
than over-flagging a wolf spider. Dangerous classes have a *lower* bar to be
surfaced; benign classes have a *higher* bar, because "this is harmless" is the
claim that gets someone hurt. This will look backwards if you're used to a
single global threshold.

**No confidence number on a refusal.** A percentage next to "couldn't
determine" reads as partial certainty.

**Guidance text is stored, not regenerated.** A log entry shows what the app
told you at the time, not what it would say today. A refusal's wording is built
at runtime and can't be reconstructed from the catalog at all.

**Virtual camera device, not `.builtInWideAngleCamera`.** Requesting the wide
angle explicitly opts out of automatic macro switching, which is the hardware's
only answer to the main lens's ~10cm minimum focus distance.

---

## Known gaps

**`SubjectCropper.swift` is orphaned.** It implements Vision-based subject
detection — find the organism, crop to *it* — which is strictly better than the
current approach of assuming the subject is centered in the quadrat square. It
compiles but nothing calls it. Either wire it into `CameraScreen.capture()`
ahead of `croppedToQuadrat`, or delete it. Leaving dead code in the project is
how you end up debugging a file that never runs.

**Confidence gate is uncalibrated.** The thresholds in `ConfidenceGate.swift`
are placeholders. Softmax confidence is not probability — a model reporting
0.85 is not right 85% of the time. See `TRAINING.md` step 8.

**No location capture.** `FieldEntry` has `latitude`/`longitude` waiting.
Geographic priors would meaningfully improve accuracy — a recluse is plausible
in New Mexico, a Sydney funnel-web is not — and filtering candidates by range
is cheaper than a bigger model.

**Save is manual and easy to forget.** The scan is the effortful step and the
save is the valuable one, which is backwards. Consider auto-saving every scan
with delete as the escape hatch.

**No onboarding.** First launch drops you straight into a viewfinder with no
explanation of what the app will and won't tell you. For an app whose whole
premise is calibrated honesty, that's a gap.

---

## Development notes

- **Real device required.** No camera in the simulator.
- **`NSCameraUsageDescription` is mandatory** — the app hard-crashes on launch
  without it, with an unhelpful `__abort_with_payload` trace.
- **Cascade trace** is at the bottom of every result screen. Shows which tiers
  ran and what each said. Hide behind a debug flag before shipping.
- **Label inspector**: long-press the shutter. Shows Vision's full ranked list
  with matched/unmatched status — more useful than the trace when tuning
  `matchTerms`, because it shows what you *missed*.
- **SwiftData migrations**: several properties were added to `FieldEntry` with
  defaults. If you hit a store-incompatibility crash, delete and reinstall.

---

## Naming

"Quadrat" is the square frame ecologists lay on the ground to sample a patch —
which is also the viewfinder gesture and the icon. App Store search showed no
bare "Quadrat" app; existing uses (a puzzle game, an Egyptian hieroglyphics
tool) are unrelated compounds in different categories.

**Still to do before shipping:** USPTO TESS search for Class 9, and a domain
check. App Store availability is not trademark availability.

---

## Roadmap

1. Complete the manual test pass with the fixed matcher (`TEST-PASS.md`)
2. Begin accumulating phone photos of real spiders for the test set — this
   takes weeks and everything downstream waits on it
3. Pull and clean iNaturalist training data (`TRAINING.md` steps 2–4)
4. Train, evaluate, calibrate the gate (steps 6–8)
5. Resolve the `SubjectCropper` question
6. Trademark clearance, App Store listing

Deliberately *not* on the list yet: location capture, sharing, iCloud sync,
onboarding polish. None of them matter until the identification is trustworthy.
