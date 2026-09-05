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

Modern deep neural networks suffer from systemic miscalibration and overconfidence: when measured on our held-out test set, predictions in the 0.8–0.9 confidence bucket came back at only **67.9% accuracy**, and uncalibrated models will happily emit high softmax scores on out-of-distribution images (like a photo of an LCD computer screen).

To combat this, FloraFang employs a four-layer **Defense in Depth** pipeline:

```
                  [ Camera Frame / Quadrat Square ]
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1: Out-of-Distribution (OOD) & Shannon Entropy Filter     │
│  H = -Σ p log₂(p). 19.4% rejection rate on holdout (2:1 ratio:   │
│  catches 250 errors at the cost of 127 correct predictions).     │
└──────────────────────────────────────────────────────────────────┘
                                  │ (Natural, clear image)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 2: Empirical Temperature Scaling (T = 1.53)               │
│  P_calibrated ∝ P^(1/T). Fitted via NLL on 1,946 held-out photos.│
│  Slashes ECE from 0.1014 to 0.0274. Sets benignFloor = 0.86.     │
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

1. **Layer 1 (Entropy & OOD Detection)**: Located in `HazardClassifier.swift` and `ConfidenceGate.swift`. Calculates Shannon Entropy across the 10-class distribution ($H = -\sum p_i \log_2 p_i$). Rejects out-of-distribution noise (screen moiré, camera blur, non-biological surfaces) where probability is scattered diffusely across multiple classes ($H > 2.35$ and top-1 $< 0.55$). On our 1,946-image holdout set, this filter produces a **19.4% rejection rate**, deliberately sacrificing 127 correct predictions to catch 250 incorrect ones—a **2:1 ratio of wrong predictions caught to correct ones sacrificed**, accepted deliberately as an asymmetric safety filter. *Limitation acknowledged:* Entropy detects diffuse confusion, not sharp overconfident misclassifications; those are defended by downstream layers.
2. **Layer 2 (Empirical Temperature Scaling & Calibrated Gates)**: Located in `HazardClassifier.swift` and `ConfidenceGate.swift`. Applies grid-searched temperature scaling ($T = 1.53$, NLL 1.2014) fitted on 1,946 unseen, held-out iNaturalist research-grade observations. This slashes Expected Calibration Error (ECE) by 73% (from 0.1014 to 0.0274) and derives `benignFloor = 0.86` for $\ge$95% reliable benign claims. Crucially, it controls the **false reassurance rate**: on 346 held-out real widows and recluses, an uncalibrated 0.38 floor emits a benign reassurance on **76 of 346 (22.0%)**, whereas the calibrated 0.86 floor drops false reassurance to just **2 of 346 (0.58%)**—a 38x reduction in dangerous false safety. The sweep also proves top-1 dangerous class recall plateaus at 66.5%—mathematically proving why a vision model cannot stand alone.
3. **Layer 3 (Dual-Tier Corroboration)**: Located in `IdentificationCascade.swift`. Compares Core ML's hazard prediction against Apple Intelligence's multimodal visual feature extraction (`SystemLanguageModel`). A benign call is never accepted as definitive on one model's vote alone, directly addressing the 33.5% dangerous false-negative ceiling of the vision classifier. *(Note: Requires iOS 27+ with Apple Intelligence support. Devices running earlier iOS versions or without Apple Intelligence fall back to Core ML and the calibrated confidence gate alone.)*
4. **Layer 4 (Honest Clinical Framing)**: Located in `Catalog.swift` and `SpiderClasses.swift`. Uses clinical toxicology terminology (*"Not medically significant"* instead of *"Safe"*), reminding users that any wild animal can bite defensively if pinched.

---

## Model Performance & Empirical Evaluation

The Core ML hazard classifier (`SpiderHazard.mlmodel`) was trained on **~11,500 CC0 and CC-BY research-grade iNaturalist images** across ten classes (`widow`, `recluse`, `wolf_spider`, `orb_weaver`, `jumping_spider`, `cellar_spider`, `huntsman`, `tarantula`, `other_spider`, `not_a_spider`).

### Validation vs. Holdout Generalization

| Metric | Validation Set (Create ML split) | Held-Out Test Set (1,946 unseen images) | Finding / Tradeoff |
|---|---|---|---|
| **Overall Accuracy** | **68.0%** | **60.9%** | **7.1-point generalization gap** reflecting honest domain shift to unseen observers |
| **Exact Class Recall (Widow)** | **79.0%** | — | Create ML exact-class recall (true widow $\to$ predicted widow) |
| **Exact Class Recall (Recluse)** | **79.0%** | — | Create ML exact-class recall (true recluse $\to$ predicted recluse) |
| **Combined Dangerous Recall (Widow + Recluse)** | — | **66.5%** | Measured by `calibrate.py`: 33.5% of real dangerous spiders classified as benign top-1 |
| **Expected Calibration Error (ECE)** | 0.1014 (uncalibrated) | 0.0274 (calibrated) | 73% drop in calibration error via temperature scaling ($T = 1.53$) |

> [!NOTE]
> **Measurement Distinction**: Create ML's validation recall is *exact-class recall* (e.g. true widow classified specifically as widow). In contrast, `calibrate.py` measures *group safety recall* across 346 real held-out widows and recluses (evaluating whether a dangerous spider is classified into *any* dangerous class). Even under this broader safety grouping, dangerous recall plateaus at 66.5% on holdout—meaning 33.5% of real medically significant spiders are assigned a benign class as their top-1 prediction.

The **7.1-point generalization gap** (68.0% validation vs. 60.9% holdout) is the honest measure of real-world generalization across new observers and locations. Rather than assuming validation numbers hold in production, FloraFang designs its confidence gates, entropy filter, and refusal cascade around this delta.

### The Augmentation & Blur Finding

During model training in Create ML, adding the standard synthetic augmentation suite degraded model performance severely:
* **No synthetic augmentations**: **68.0% validation accuracy**
* **With 5 augmentations (including blur and noise)**: **41.0% validation accuracy**

Isolated across **four controlled training runs**, synthetic blur and noise corrupted fine-grained biological features (such as eye arrangements and subtle spine structures on legs) that the classifier relied on to separate families. Rejecting synthetic blur in favor of clean training data—and handling bad captures via runtime entropy and refusal instead—was a key empirical discovery.

### Experimental Null Result: SAM3 Segmentation & Tight Cropping

A standard hypothesis in biological classification is that background clutter (bark, gravel, stucco, leaf litter) creates spurious correlations, and isolating the organism will improve accuracy.

* **Hypothesis**: Tightening crops around the spider using Segment Anything 3 (SAM3) bounding boxes will eliminate extraneous background pixels and boost recall on difficult dangerous classes.
* **Method**: Processed training data via `segment_training_data.py` using SAM3 to generate tight instance-bounding box crops (+15% context padding). Retrained the 10-class classifier in Create ML under identical conditions.
* **Results**:

| Preprocessing Pipeline | Overall Validation Accuracy | Widow Recall | Recluse Recall |
|---|---|---|---|
| **Baseline Quadrat Square Crop** | **68.0%** | **79.0%** | **79.0%** |
| **SAM3 Tight Bounding Box Crop** | **70.0%** | **79.0%** | **79.0%** |

* **Conclusion**: **A documented null result.** While overall validation accuracy nudged up slightly from 68% to 70%, the safety-critical metric—dangerous class recall—remained completely unmoved: widow recall stayed at 79.0% and recluse recall stayed at 79.0%. In research-grade naturalist photos, human observers already frame the organism near the center. Full background erasure (`--mode mask`) was deliberately excluded: masking backgrounds during training creates a fatal train/test domain mismatch against natural camera frames at inference unless a 600MB+ segmentation model is shipped on-device. Testing this hypothesis proved that automated segmentation added significant pipeline complexity for zero gain in dangerous-species safety.

---

## Identification Cascade

Identification runs through four orchestrated tiers:

| Tier | Component | Function | Cost / Latency |
|---|---|---|---|
| **1** | **Apple Vision (`ClassifyImageRequest`)** | Coarse category identification (spider, plant, bird, insect). Non-spiders resolve immediately from local catalog. | Offline, ~40ms |
| **2a** | **Core ML Hazard Model (`SpiderHazard.mlmodel`)** | 10-class image classifier trained on medically significant vs. common benign spider families. Evaluated with `.scaleToFill` to match Create ML's training preprocessing (recovering 11.3 points of dangerous recall over letterboxing). | Offline, ~60ms |
| **2b** | **Apple Intelligence (`SystemLanguageModel`)** | Multimodal feature extraction. Inspects eye arrangements (e.g. 6 eyes in 3 pairs for Recluse), hourglass markings, and violin patterns. Isolates subject via Vision foreground instance masking. *(Requires iOS 27+; earlier devices fall back to Core ML + Gate alone).* | Offline, on-device |
| **3** | **Remote Cloud Fallback** | Remote API seam. **Disabled by default** to preserve 100% offline privacy and zero-network operation. | Disabled |
| **4** | **Structured Refusal** | Delivers dynamic AI-generated feedback explaining what markings weren't visible (e.g., *"Not visible in photo: underside of abdomen"*), plain-English disagreement notes, and angle retake advice. | Instant |

---

## Key App Features

* **Instant Shutter Viewfinder**: Zero-lag camera capture using `AVCaptureSession` photo preset. Square quadrat frame guides framing without edge clipping.
* **Onboarding & Safety Framing (`OnboardingView.swift`)**: A 4-card illustrated first-launch flow explaining the app's triage philosophy, macro framing techniques (e.g. using the digital zoom slider to avoid iPhone minimum focal distance limits), clinical refusal boundaries (why an algorithm can never confirm a plant is safe to eat), and emergency protocol access.
* **Dynamic Natural Seasonal Palette (`FloraFangApp.swift`)**: Automatically tunes organic botanical slate, moss, and foliage accents to match the four natural seasons (Spring Sprout, Summer Canopy, Autumn Cedar, Winter Spruce). Lifted from pitch-black for high outdoor sunlight readability with an interactive manual switcher in Settings.
* **Emergency Exposure Protocol & Incident Log (`EmergencyScreen.swift`)**: Pinned 24/7 one-tap access to **US Poison Control (1-800-222-1222)** and the **ASPCA Animal Poison Control Center (888-426-4435)**. Features a subject-gated intake checklist (Child, Adult, Dog, Cat, Other Animal), streamlined specimen photo capture, and persistent SwiftData incident logging with history review (`ExposureHistoryView.swift`).
* **Focused Triage Diagnostic Guidance (`FieldGuidanceView.swift`)**: Replaces walls of raw text with clean diagnostic chips focused strictly on medically decisive markers (eye arrangements, violin pattern, underside hourglass, dorsal spots) while discarding benign anatomical clutter.
* **On-Device Field Naturalist Chat (`EntryDetailScreen.swift`)**: Chat directly with Apple's Foundation Model on-device. Protected by a deterministic pre-model Swift filter that intercepts symptom, bite, treatment, and dosage queries before the LLM can run, displaying unbypassable poison control hotlines instead.
* **Privacy-Preserving Field Log**: Saved locally via SwiftData. Optional location capture rounds coordinates to ~1 km (2 decimal places) and reverse-geocodes city names locally.
* **Hardened Research Data Export (`ExportService.swift`)**: Generates a standard `.zip` containing `field-log.csv` (retaining full cascade decision traces for ML evaluation) and full-resolution images, hardened against spreadsheet formula injection.

---

## Security, Privacy & Safety Architecture

FloraFang is engineered for high-consequence field situations, where data exfiltration and software overreach can create legal, medical, and privacy liabilities:

1. **100% Offline by Design**: FloraFang makes zero network calls. The Tier 3 remote seam defaults to `DisabledRemoteIdentifier`, failing closed. The app contains no third-party tracking, crash reporting, or analytics SDKs.
2. **Location Coarsening**: When location capture is enabled, `LocationService.swift` deliberately rounds latitude and longitude to 2 decimal places (~1 km precision) and limits reverse-geocoding to city and region. Stored coordinates can never pinpoint a private home or backyard.
3. **CSV Formula Injection Sanitization**: In `ExportService.swift`, user notes and labels are sanitized before CSV serialization. Any cell beginning with formula triggers (`=`, `+`, `-`, `@`, `\t`, `\r`) is safely escaped to prevent Dynamic Data Exchange (DDE) or formula execution in Microsoft Excel, Numbers, or LibreOffice.
4. **Deterministic Clinical Interception**: Apple Intelligence is never allowed to freelance on emergency medical advice. A deterministic Swift keyword and regex validator checks queries for symptoms, bites, doses, or treatment terms before invoking `SystemLanguageModel`.
5. **Static Dialer Integrity**: Emergency hotline URLs (`PoisonResources.swift`) use hardcoded digit strings without runtime string interpolation, preventing arbitrary scheme execution.

---

## Build & Testing Setup

1. Open `FloraFang.xcodeproj` in **Xcode 27** (with iOS 27 SDK support).
2. Set the run destination to your **physical iPhone** running iOS 27 beta.
3. In **Signing & Capabilities**, select your development team.
4. Press **Cmd + R** to run.
5. **Testing Tips**:
    * Test with real-world specimens or clear reference photographs.
    * Long-press the camera shutter to bring up the **Label Inspector** to see raw Vision classifications.
    * In **Field Log > Settings**, test the **Seasonal Palette** picker to switch between Spring, Summer, Autumn, and Winter themes in real time.
    * Tap **Export field log** to inspect `field-log.csv`, which retains the complete internal **Cascade Decision Trace** (`tier1`, `tier2a`, `gate`, `tier2b`, `combine`) for ML diagnostics.

---

## Known Limitations

* **Dangerous Recall Ceiling on Legacy Devices (pre-iOS 27)**: On held-out testing, the vision classifier alone maxes out at 66.5% recall on dangerous species (missing ~33.5% of real widows/recluses as top-1). While Layer 3 (Apple Intelligence multimodal feature corroboration) is designed to catch these missed cases, it requires iOS 27+ on supported Apple Silicon. On iOS 26 and earlier, devices fall back to Core ML and the confidence gate alone—meaning ambiguous specimens are escalated to caution rather than verified.
* **In-Distribution Calibration**: Temperature scaling ($T = 1.53$) and gate thresholds (`benignFloor = 0.86`, `dangerousFloor = 0.22`) were fitted on 1,946 held-out iNaturalist research-grade photos. While unseen during training, these still represent naturalist photography with decent lighting. Calibration has not yet been validated against uncurated phone captures under adverse field conditions (e.g. flash blowout, baseboards at midnight).
* **Plant Model Evaluation**: While the spider hazard model was evaluated on a 1,946-image holdout test set with temperature scaling and entropy gating, the plant hazard classifier currently relies on internal validation accuracy alone and has not yet undergone a separate held-out test sweep.
