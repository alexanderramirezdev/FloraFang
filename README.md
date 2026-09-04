# FloraFang

*Know what bites and what is toxic.*

An on-device iOS app designed for field naturalists, hikers, and parents that identifies potentially hazardous spiders and plants from the camera — and, crucially, **refuses to guess** when evidence is uncertain.

Everything runs 100% on-device on Apple Silicon using a combination of **Apple Vision**, **Core ML**, and **Apple Intelligence (`FoundationModels`)**.

---

## The Premise: Calibrated Honesty Over Confident Guesses

Most nature identification apps will output a species name at 40% confidence and present it as fact. For casual flower identification, a wrong answer is harmless. For a spider in a child's bedroom or a plant a pet just chewed, **a confident wrong answer is a medical emergency.**

FloraFang is engineered around asymmetric risk:
* **False Positive** (e.g., calling a harmless wolf spider a "Possible Recluse"): User exercises caution. Nobody gets hurt.
* **False Negative** (e.g., calling a Black Widow a "Huntsman — Safe"): User lets down their guard. Potential envenomation.

Because of this asymmetry, FloraFang rejects false certainty. It never promises that a wild organism is "harmless," never rules out dangerous species on weak evidence, and treats structured refusal as a first-class safety feature rather than an error state.

---

## The Four-Layer "Defense in Depth" Architecture

Modern deep neural networks suffer from systemic miscalibration and overconfidence: a model outputting an 86% softmax score on a closed-world set of 10 classes is often only 60% accurate in the real world, and will happily emit 86% on an out-of-distribution image (like a photo of an LCD computer screen).

To combat this, FloraFang employs a four-layer **Defense in Depth** pipeline:

```
                  [ Camera Frame / Quadrat Square ]
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1: Out-of-Distribution (OOD) & Shannon Entropy Filter     │
│  H = -Σ p log₂(p). Rejects monitor moiré, screen glare, carpets, │
│  and blur when entropy exceeds 2.35.                             │
└──────────────────────────────────────────────────────────────────┘
                                  │ (Natural, clear image)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 2: Mathematical Temperature Scaling (T = 1.6)             │
│  P_calibrated ∝ P^(1/T). Flattens artificial softmax spikes.     │
│  An overconfident 86% drops to an honest, calibrated ~61%.       │
└──────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 3: Dual-Tier Corroboration (Foundation Models Shield)     │
│  Apple Intelligence checks Core ML's homework. Uncorroborated   │
│  benign calls are downgraded to caution. Widows/Recluses can     │
│  never be ruled out without dual-tier agreement.                 │
└──────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 4: Honest Clinical UX Framing                             │
│  Eliminates "Harmless" and "Generally safe". Replaced with the   │
│  clinical standard "Not medically significant" + bite warnings.  │
└──────────────────────────────────────────────────────────────────┘
```

1. **Layer 1 (Entropy & OOD Detection)**: Located in `HazardClassifier.swift` and `ConfidenceGate.swift`. Calculates Shannon Entropy across the 10-class distribution. When probability is scattered erratically across multiple classes, the gate escalates to refusal rather than accepting a hallucination.
2. **Layer 2 (Mathematical Temperature Scaling)**: Located in `HazardClassifier.swift`. Applies T = 1.6 to the probability distribution, softening extreme softmax peaks and aligning reported confidence with empirical real-world accuracy.
3. **Layer 3 (Dual-Tier Corroboration)**: Located in `IdentificationCascade.swift`. Compares Core ML's hazard prediction against Apple Intelligence's multimodal visual feature extraction. A benign call is never accepted as definitive on one model's vote alone.
4. **Layer 4 (Honest Clinical Framing)**: Located in `Catalog.swift` and `SpiderClasses.swift`. Uses clinical toxicology terminology (*"Not medically significant"* instead of *"Safe"*), reminding users that any wild animal can bite defensively if pinched.

---

## Identification Cascade

Identification runs through four orchestrated tiers:

| Tier | Component | Function | Cost / Latency |
|---|---|---|---|
| **1** | **Apple Vision (`ClassifyImageRequest`)** | Coarse category identification (spider, plant, bird, insect). Non-spiders resolve immediately from local catalog. | Offline, ~40ms |
| **2a** | **Core ML Hazard Model (`SpiderHazard.mlmodel`)** | 10-class image classifier trained on medically significant vs. common benign spider families. Evaluated with `.scaleToFit` to preserve all 8 legs. | Offline, ~60ms |
| **2b** | **Apple Intelligence (`SystemLanguageModel`)** | Multimodal feature extraction. Inspects eye arrangements (e.g. 6 eyes in 3 pairs for Recluse), hourglass markings, and violin patterns. Isolates subject via Vision foreground instance masking. | Offline, on-device |
| **3** | **Remote Cloud Fallback** | Remote API seam. **Disabled by default** to preserve 100% offline privacy and zero-network operation. | Disabled |
| **4** | **Structured Refusal** | Delivers dynamic AI-generated feedback explaining what markings weren't visible (e.g., *"Not visible in photo: underside of abdomen"*), plain-English disagreement notes, and angle retake advice. | Instant |

---

## Key App Features

* **Instant Shutter Viewfinder**: Zero-lag camera capture using `AVCaptureSession` photo preset. Square quadrat frame guides framing without edge clipping.
* **On-Device Field Naturalist Chat**: Chat directly with Apple's Foundation Model in `EntryDetailScreen.swift`. Tap quick prompt chips (*"🐾 Dangerous to pets?"*, *"📦 Safe way to move it?"*, *"🩺 What if bitten?"*) or ask custom questions offline.
* **Emergency Exposure Protocol**: In `EmergencyScreen.swift`, one-tap direct dialing to **US Poison Control (1-800-222-1222)** and the **ASPCA Animal Poison Control Center (888-426-4435)**. Structures exposure notes for first responders before they pick up.
* **Privacy-Preserving Field Log**: Entries saved in SwiftData. Optional location capture rounds coordinates to ~1 km (2 decimal places) and reverse-geocodes city names locally. Zero tracking, zero telemetry.
* **Research Data Export**: Generates a standard `.zip` containing a `field_log.csv` and full-resolution images for offline data analysis and Create ML re-training.

---

## Build & Testing Setup

1. Open `FloraFang.xcodeproj` in **Xcode 16+** (with iOS 27 SDK support).
2. Set the run destination to your **physical iPhone** running iOS 27 beta.
3. In **Signing & Capabilities**, select your development team.
4. Press **Cmd + R** to run.
5. **Testing Tips**:
   * Test with real-world specimens or clear reference photographs.
   * Long-press the camera shutter to bring up the **Label Inspector** to see raw Vision classifications.
   * Scroll to the bottom of any saved field entry to inspect the full **Cascade Decision Trace** (`tier1`, `tier2a`, `gate`, `tier2b`, `combine`).
