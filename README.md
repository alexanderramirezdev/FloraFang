# FloraFang

*Know what bites and what is toxic.*

An on-device iOS app designed for field naturalists, hikers, and parents that identifies potentially hazardous spiders and plants from the camera, and crucially **refuses to guess** when evidence is uncertain.

Everything runs 100% on-device on Apple Silicon using a combination of **Apple Vision**, **Core ML**, and **Apple Intelligence (`FoundationModels`)**.

***

## The Premise: Calibrated Honesty Over Confident Guesses

Most nature identification apps will output a species name at 40% confidence and present it as fact. For casual flower identification, a wrong answer is harmless. For a spider in a child's bedroom or a plant a pet just chewed, **a confident wrong answer is a medical emergency.**

FloraFang is engineered around asymmetric risk:
* **False Positive** (e.g., calling a harmless wolf spider a "Possible Recluse"): User exercises caution. Nobody gets hurt.
* **False Negative** (e.g., calling a Black Widow a "Huntsman: Safe"): User lets down their guard. Potential envenomation.

Because of this asymmetry, FloraFang rejects false certainty. It never promises that a wild organism is "harmless," never rules out dangerous species on weak evidence, and treats structured refusal as a first-class safety feature rather than an error state.

***

## The Four-Layer "Defense in Depth" Architecture

Modern deep neural networks suffer from systemic miscalibration and overconfidence: when measured on held-out test sets, raw predictions in the 0.8 to 0.9 confidence bucket came back at only **67.9% accuracy**, and uncalibrated models will happily emit high softmax scores on out-of-distribution images (like a photo of an LCD computer screen).

To combat this, FloraFang employs a four-layer **Defense in Depth** pipeline:

```
                  [ Camera Frame / Quadrat Square ]
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1: Out-of-Distribution (OOD) & Shannon Entropy Filter     │
│  H = -Σ p log₂(p). Rejects diffuse confusion (2:1 ratio:         │
│  catches 250 errors at the cost of 127 correct predictions).     │
└──────────────────────────────────────────────────────────────────┘
                                  │ (Natural, clear image)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 2: Hierarchical Core ML Cascade & Empirical Calibration   │
│  Stage 1 (Tier 2a): 3-Class Hazard Gate (85% acc, 90 to 95% rec) │
│  Stage 2 (Tier 2c): 10-Class Benign Family Resolver (masked)     │
│  Temperature Scaling (T = 1.53) sets benignFloor = 0.86.         │
└──────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 3: Dual-Tier Corroboration (Foundation Models Shield)     │
│  Apple Intelligence checks Core ML's homework. Uncorroborated    │
│  benign calls are downgraded to caution. Widows/Recluses can     │
│  never be ruled out without dual-tier agreement. (iOS 27+)       │
└──────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 4: Honest Clinical UX Framing                             │
│  Eliminates "Harmless" and "Generally safe". Replaced with the   │
│  clinical standard "Not medically significant" + bite warnings.  │
└──────────────────────────────────────────────────────────────────┘
```

1. **Layer 1 (Entropy & OOD Detection)**: Located in `HazardClassifier.swift` and `ConfidenceGate.swift`. Calculates Shannon Entropy across the probability distribution ($H = -\sum p_i \log_2 p_i$). Rejects out-of-distribution noise (screen moire, camera blur, non-biological surfaces) where probability is scattered diffusely across multiple classes ($H > 2.35$ and top-1 $< 0.55$). On our 1,946-image holdout set, this filter produces a **19.4% rejection rate**, deliberately sacrificing 127 correct predictions to catch 250 incorrect ones: a **2:1 ratio of wrong predictions caught to correct ones sacrificed**, accepted deliberately as an asymmetric safety filter. *Limitation acknowledged:* Entropy detects diffuse confusion, not sharp overconfident misclassifications; those are defended by downstream layers.
2. **Layer 2 (Hierarchical Core ML Cascade & Empirical Calibration)**: Located in `HazardClassifier.swift`, `IdentificationCascade.swift`, and `ConfidenceGate.swift`. Rather than forcing a single model to solve fine-grained taxonomy and high-stakes medical triage simultaneously, FloraFang employs a two-stage Core ML cascade:
   * **Stage 1 (Tier 2a Hazard Gate)**: A specialized 3-class classifier (`SpiderHazard-training dangerous.mlmodel`) screens for `recluse`, `widow`, and `not_medically_significant`. It delivers **95.0% Recluse recall** and **90.0% Widow recall** with **85.0% validation accuracy**, eliminating the confusion caused when brown wandering spiders share visual features with recluses.
   * **Stage 2 (Tier 2c Family Resolver)**: Once Stage 1 clears the specimen as benign, the secondary 10-class model (`SpiderHazard-tier2c.mlmodel`) resolves the harmless family (jumping spider, cellar spider, wolf spider, huntsman, orb weaver, tarantula). Dangerous classes are masked out by default in Tier 2c to prevent false alarms, with an extreme conviction safeguard (85% or higher) if a hazard is flagged.
   * **Temperature Scaling ($T = 1.53$)**: Slashes Expected Calibration Error (ECE) by 73% (from 0.1014 down to 0.0274) and establishes `benignFloor = 0.86` for 95% reliable benign claims, dropping false reassurance on dangerous spiders to 0.58%.
3. **Layer 3 (Dual-Tier Corroboration)**: Located in `IdentificationCascade.swift`. Compares Core ML's hazard prediction against Apple Intelligence's multimodal visual feature extraction (`SystemLanguageModel`). A benign call is never accepted as definitive on one model's vote alone, directly addressing potential blind spots in the vision classifier. *(Note: Requires iOS 27+ with Apple Intelligence support. Devices running earlier iOS versions or without Apple Intelligence fall back to Core ML and the calibrated confidence gate alone.)*
4. **Layer 4 (Honest Clinical Framing)**: Located in `Catalog.swift` and `SpiderClasses.swift`. Uses clinical toxicology terminology (*"Not medically significant"* instead of *"Safe"*), reminding users that any wild animal can bite defensively if pinched.

***

## Model Performance & Empirical Evaluation

The FloraFang spider cascade was trained on **~11,500 CC0 and CC-BY research-grade iNaturalist images**, structured into two focused models:
1. `SpiderHazard-training dangerous.mlmodel` (Primary 3-class hazard gate trained on `hazard3`)
2. `SpiderHazard-tier2c.mlmodel` (Secondary 10-class benign family resolver trained on `raw-curated`)

### Primary Hazard Gate Evaluation (`hazard3`)

| Class / Metric | Recall | Precision | Significance |
|---|---|---|---|
| **Recluse (*Loxosceles*)** | **95.0%** | **89.0%** | Captures 19 in 20 actual brown recluses |
| **Widow (*Latrodectus*)** | **90.0%** | **93.0%** | High sensitivity screening for black widows |
| **Not Medically Significant** | **83.0%** | **88.0%** | Aggregated harmless families and non-spiders |
| **Overall Validation Accuracy** | **85.0%** | **85.0%** | Create ML randomized split |

### Benign Family Resolver Evaluation (`raw-curated`)

| Metric | Curated 10-Class Model | Role & Significance |
|---|---|---|
| **Training Accuracy** | **66.0%** | Visual overlap across brown wandering spiders |
| **Validation Accuracy** | **59.0%** | Resolves harmless families on natural captures |
| **Safety Masking** | **Active in Tier 2c** | Dangerous classes masked to prevent false alarms |

### Why the Hierarchical Cascade Outperformed Monolithic Models

In earlier monolithic 10-class models, top-1 recall on dangerous species plateaued at 66.5% on held-out data. Wandering brown spiders (wolf spiders, huntsman spiders, grass spiders, nursery web spiders) share neutral brown coloration, long legs, and lack conspicuous abdominal markings. When a single model was forced to separate ten families simultaneously, 33.5% of real widows and recluses were misclassified as benign wanderers.

Separating the clinical triage question ("is this a widow or recluse?") from the taxonomic family question ("which harmless family is it?") resolved this bottleneck. The 3-class gate reached **95.0% Recluse recall** and **90.0% Widow recall**, while Tier 2c provides rich family-level identification only after safety is established.

### Preprocessing Alignment: Stretched vs. Letterboxed

While testing inference preprocessing, we uncovered a striking demonstration of train/test mismatch. An initial intuition was that we should letterbox photos (`.scaleToFit`) to avoid squashing spiders and preserve their leg geometry. But when evaluated across 1,946 held-out images, changing only this single variable produced a decisive result:

| Preprocessing Method | Holdout Accuracy | Dangerous Class Recall | Fitted T (NLL) |
|---|---|---|---|
| **Stretched (`.scaleToFill`)** | **60.9%** | **66.5%** | 1.53 (1.2014) |
| Letterboxed (`.scaleToFit`) | 56.2% | 55.2% | 1.64 (1.3323) |

**Letterboxing caused an 11.3 percentage point collapse in dangerous class recall.** Apple's Create ML training pipeline squashes training images to 299 by 299 rather than letterboxing. The black padding bars introduced border artifacts the convolutional filters never saw in training, while shrinking the spider's pixel resolution. Setting `request.cropAndScaleAction` to `.scaleToFill` to match training recovered those 11.3 points instantly.

### The Augmentation & Blur Finding

During model training in Create ML, adding synthetic blur and noise degraded performance severely:
* **No synthetic augmentations**: **68.0% validation accuracy**
* **With 5 augmentations (including blur and noise)**: **41.0% validation accuracy**

Synthetic blur and noise corrupted fine-grained biological features (ocular arrangements and spine structures on legs) that the classifier relied on to separate families. Rejecting synthetic blur in favor of clean training data, and handling poor captures via runtime entropy and refusal instead, was a key empirical discovery.

***

## Identification Cascade

Identification runs through four orchestrated tiers:

| Tier | Component | Function | Cost / Latency |
|---|---|---|---|
| **1** | **Apple Vision (`ClassifyImageRequest`)** | Coarse category identification (spider, plant, bird, insect). Non-spiders resolve immediately from local catalog. | Offline, ~40ms |
| **2a** | **Core ML Primary Hazard Gate (`SpiderHazard-training dangerous.mlmodel`)** | 3-class classifier screening for *Latrodectus*, *Loxosceles*, and benign specimens. Evaluated with `.scaleToFill` to match Create ML training. | Offline, ~60ms |
| **2b** | **Apple Intelligence (`SystemLanguageModel`)** | Multimodal feature extraction. Inspects eye arrangements (6 eyes in 3 pairs for Recluse), hourglass markings, and violin patterns. Isolates subject via Vision foreground instance masking. *(Requires iOS 27+; earlier devices fall back to Core ML + Gate alone).* | Offline, on-device |
| **2c** | **Core ML Benign Family Resolver (`SpiderHazard-tier2c.mlmodel`)** | 10-class family resolver. When Tier 2a confirms non-medically significant, resolves jumping spider, wolf spider, huntsman, cellar spider, orb weaver, or tarantula with dangerous classes masked. | Offline, ~60ms |
| **3** | **Remote Cloud Fallback** | Remote API seam. **Disabled by default** to preserve 100% offline privacy and zero-network operation. | Disabled |
| **4** | **Structured Refusal** | Delivers dynamic AI-generated feedback explaining what markings were not visible (e.g., *"Not visible in photo: underside of abdomen"*), plain-English disagreement notes, and angle retake advice. | Instant |

***

## Key App Features

* **Instant Shutter Viewfinder**: Zero-lag camera capture using `AVCaptureSession` photo preset. Square quadrat frame guides framing without edge clipping.
* **Onboarding & Safety Framing (`OnboardingView.swift`)**: A 4-card illustrated first-launch flow explaining the app's triage philosophy, macro framing techniques (using the digital zoom slider to avoid iPhone minimum focal distance limits), clinical refusal boundaries (why an algorithm can never confirm a plant is safe to eat), and emergency protocol access.
* **Dynamic Natural Seasonal Palette (`FloraFangApp.swift`)**: Automatically tunes organic botanical slate, moss, and foliage accents to match the four natural seasons (Spring Sprout, Summer Canopy, Autumn Cedar, Winter Spruce). Lifted from pitch-black for high outdoor sunlight readability with an interactive manual switcher in Settings.
* **Emergency Exposure Protocol & Incident Log (`EmergencyScreen.swift`)**: Pinned 24/7 one-tap access to **US Poison Control (1.800.222.1222)** and the **ASPCA Animal Poison Control Center (888.426.4435)**. Features a subject-gated intake checklist (Child, Adult, Dog, Cat, Other Animal), streamlined specimen photo capture, and persistent SwiftData incident logging with history review (`ExposureHistoryView.swift`).
* **Focused Triage Diagnostic Guidance (`FieldGuidanceView.swift`)**: Replaces walls of raw text with clean diagnostic chips focused strictly on medically decisive markers (eye arrangements, violin pattern, underside hourglass, dorsal spots) while discarding benign anatomical clutter.
* **On-Device Field Naturalist Chat (`EntryDetailScreen.swift`)**: Chat directly with Apple's Foundation Model on-device. Protected by a deterministic pre-model Swift filter that intercepts symptom, bite, treatment, and dosage queries before the LLM can run, displaying unbypassable poison control hotlines instead.
* **Privacy-Preserving Field Log**: Saved locally via SwiftData. Optional location capture rounds coordinates to ~1 km (2 decimal places) and reverse-geocodes city names locally.
* **Hardened Research Data Export (`ExportService.swift`)**: Generates a standard `.zip` containing `field-log.csv` (retaining full cascade decision traces for ML evaluation) and full-resolution images, hardened against spreadsheet formula injection.

***

## Security, Privacy & Safety Architecture

FloraFang is engineered for high-consequence field situations, where data exfiltration and software overreach can create legal, medical, and privacy liabilities:

1. **100% Offline by Design**: FloraFang makes zero network calls. The Tier 3 remote seam defaults to `DisabledRemoteIdentifier`, failing closed. The app contains no third-party tracking, crash reporting, or analytics SDKs.
2. **Location Coarsening**: When location capture is enabled, `LocationService.swift` deliberately rounds latitude and longitude to 2 decimal places (~1 km precision) and limits reverse-geocoding to city and region. Stored coordinates can never pinpoint a private home or backyard.
3. **CSV Formula Injection Sanitization**: In `ExportService.swift`, user notes and labels are sanitized before CSV serialization. Any cell beginning with formula triggers (`=`, `+`, `-`, `@`, `\t`, `\r`) is safely escaped to prevent Dynamic Data Exchange (DDE) or formula execution in Microsoft Excel, Numbers, or LibreOffice.
4. **Deterministic Clinical Interception**: Apple Intelligence is never allowed to freelance on emergency medical advice. A deterministic Swift keyword and regex validator checks queries for symptoms, bites, doses, or treatment terms before invoking `SystemLanguageModel`.
5. **Static Dialer Integrity**: Emergency hotline URLs (`PoisonResources.swift`) use hardcoded digit strings without runtime string interpolation, preventing arbitrary scheme execution.

***

## Build & Testing Setup

1. Open `FloraFang.xcodeproj` in **Xcode 27** (with iOS 27 SDK support).
2. Set the run destination to your **physical iPhone** running iOS 27 beta.
3. In **Signing & Capabilities**, select your development team.
4. Press **Cmd + B** to build or **Cmd + R** to run.
5. **Testing Tips**:
    * Test with real-world specimens or clear reference photographs.
    * Long-press the camera shutter to bring up the **Label Inspector** to see raw Vision classifications.
    * In **Field Log > Settings**, test the **Seasonal Palette** picker to switch between Spring, Summer, Autumn, and Winter themes in real time.
    * Tap **Export field log** to inspect `field-log.csv`, which retains the complete internal **Cascade Decision Trace** (`tier1`, `tier2a`, `tier2c`, `gate`, `tier2b`, `combine`) for ML diagnostics.

***

## Known Limitations

* **Legacy Hardware Support (pre-iOS 27)**: While the two-stage Core ML cascade provides 90% to 95% hazard sensitivity on device, Layer 3 multimodal corroboration requires iOS 27+ on supported Apple Silicon. On iOS 26 and earlier, devices fall back to Core ML and the confidence gate alone, meaning ambiguous specimens are escalated to caution rather than verified.
* **In-Distribution Calibration**: Temperature scaling ($T = 1.53$) and gate thresholds (`benignFloor = 0.86`, `dangerousFloor = 0.22`) were fitted on 1,946 held-out iNaturalist research-grade photos. While unseen during training, these still represent naturalist photography with decent lighting. Calibration continues to be refined against uncurated phone captures under adverse field conditions (e.g. flash blowout, baseboards at midnight).
* **Plant Model Evaluation**: While the spider hazard model was evaluated on a 1,946-image holdout test set with temperature scaling and entropy gating, the plant hazard classifier currently relies on internal validation accuracy alone and has not yet undergone a separate held-out test sweep.
