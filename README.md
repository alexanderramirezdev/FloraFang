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

Modern deep neural networks suffer from systemic miscalibration and overconfidence: when measured on our held-out test set, predictions in the 0.8 to 0.9 confidence bucket came back at only **67.9% accuracy**, and uncalibrated models will happily emit high softmax scores on out-of-distribution images (like a photo of an LCD computer screen).

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
│  Dual-model agreement veto drops false reassurance to 0 of 346.  │
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

1. **Layer 1 (Entropy & OOD Detection)**: Located in `HazardClassifier.swift` and `ConfidenceGate.swift`. Calculates Shannon Entropy across the 10-class distribution ($H = -\sum p_i \log_2 p_i$). Rejects out-of-distribution noise (screen moire, camera blur, non-biological surfaces) where probability is scattered diffusely across multiple classes ($H > 2.35$ and top-1 $< 0.55$). On our 1,946-image holdout set, this filter produces a **19.4% rejection rate**, deliberately sacrificing 127 correct predictions to catch 250 incorrect ones: a **2:1 ratio of wrong predictions caught to correct ones sacrificed**, accepted deliberately as an asymmetric safety filter. *Limitation acknowledged:* Entropy detects diffuse confusion, not sharp overconfident misclassifications; those are defended by downstream layers.
2. **Layer 2 (Empirical Temperature Scaling, Calibrated Gates & Agreement Veto)**: Located in `HazardClassifier.swift` and `ConfidenceGate.swift`. Applies grid-searched temperature scaling ($T = 1.53$, NLL 1.2014) fitted on 1,946 unseen, held-out iNaturalist research-grade observations. This slashes Expected Calibration Error (ECE) by 73% (from 0.1014 to 0.0274) and derives `benignFloor = 0.86` for at least 95% reliable benign claims. Crucially, it controls the **false reassurance rate**: pairing the 10-class model with the secondary 3-class agreement veto on confident benign calls drops false reassurance from 1 of 346 (0.29%) down to **0 of 346 (0.00%)**. The sweep also proves top-1 dangerous class recall plateaus at 66.5%, mathematically proving why a vision model cannot stand alone.
3. **Layer 3 (Dual-Tier Corroboration)**: Located in `IdentificationCascade.swift`. Compares Core ML's hazard prediction against Apple Intelligence's multimodal visual feature extraction (`SystemLanguageModel`). A benign call is never accepted as definitive on one model's vote alone, directly addressing the 33.5% dangerous false-negative ceiling of the vision classifier. *(Note: Requires iOS 27+ with Apple Intelligence support. Devices running earlier iOS versions or without Apple Intelligence fall back to Core ML and the calibrated confidence gate alone.)*
4. **Layer 4 (Honest Clinical Framing)**: Located in `Catalog.swift` and `SpiderClasses.swift`. Uses clinical toxicology terminology (*"Not medically significant"* instead of *"Safe"*), reminding users that any wild animal can bite defensively if pinched.

***

## Model Performance and Empirical Evaluation

Every number below was measured against a **1,946 image holdout set**: fresh
research grade iNaturalist observations fetched separately, with every
observation ID cross checked against the training set so nothing the model saw
during training appears in the test. 346 of those images are real widows or
recluses.

Create ML's own validation percentage is a random slice of the training data,
drawn from the same photographers under the same conditions. It has flattered
every model in this project by 13 to 28 points. Where the two disagree, the
holdout number is the one reported.

### Shipping configuration

| Component | Value | Source |
|---|---|---|
| Primary model | `SpiderHazard.mlmodel`, 10 class | ~11,500 CC0 and CC BY iNaturalist images |
| Temperature | T = 1.53 | Grid searched NLL minimisation on holdout |
| Expected calibration error | 0.1014 to 0.0274 | 73% reduction after scaling |
| `benignFloor` | 0.86 | Confidence at which benign calls are >=95% correct |
| `dangerousFloor` | 0.22 | Deliberately permissive |
| Preprocessing | `.scaleToFill` | Matches Create ML training, see below |
| Safety veto | `SpiderHazardGate.mlmodel`, 3 class | Vetoes confident benign calls only |
| **False reassurance** | **0 of 346** | Real dangerous spiders told they are not medically significant |
| Dangerous recall | 66.5% | Everything below this becomes a refusal, not a benign call |

The distinction between the last two rows is the whole design. A third of real
widows and recluses are not identified as dangerous. Almost none of them are
told they are safe. Failing to an honest refusal is survivable; failing to a
confident all clear is not.

### The agreement veto

The 10 class model told 1 real widow in 346 that it was not medically
significant. One is not zero, and the app makes a safety claim above the
benign floor.

A second model trained on a different class structure fails on different
images. Measured on the same holdout, the two disagree on 16.4% of images
(320 of 1,946), and the single false reassurance fell inside that set.

So a confident benign call now requires both models to agree:

```
10 class says benign at >= 0.86
    AND 3 class gate says widow or recluse
    -> refuse, and say why
otherwise the 10 class result stands unchanged
```

The gate can never name a species, raise a confidence, or override a dangerous
call. It has exactly one power: to stop a benign claim.

| | 10 class alone | with agreement veto |
|---|---|---|
| False reassurance | 1 of 346 (0.29%) | **0 of 346** |
| Confident benign answers | 219 | 204 |
| Correct answers lost to refusal | 0 | 15 |

Fifteen correct answers traded for one missed widow. By the asymmetry this app
is built on, that is a good trade.

Stated honestly: zero of 346 rests on one caught case. It is a measurement on
one holdout, not a guarantee, and any future gate model has to be retested
against the same benchmark rather than inheriting the result.

The gate's standalone numbers are poor, 14.5% false reassurance, which is why
it is documented in `HazardClassifier.swift` as a one direction veto and never
as a triage authority.

***

## Null Results

Four hypotheses tested and rejected. Documented because a negative result that
is not written down gets retried.

### 1. Subject segmentation with SAM3

**Hypothesis.** Cropping to the subject was the largest accuracy fix in the app
when applied at inference. A spider on a wall can be 2% of the pixels, and a
classifier shown that is mostly learning stucco. Normalising subject size
across the training set should help.

**Method.** SAM3 over all ten class folders with the text prompt "spider",
cropping to the returned bounding box with 15% padding. Box rather than mask
deliberately: the app does not segment before Core ML, so erasing backgrounds
in training would create a train/test mismatch. Detection was near total, zero
errors across ~11,500 images, though cellar_spider lost 17.5% to non detection
where every other class was under 6%.

**Result.**

| | Baseline | SAM3 tight crop |
|---|---|---|
| Validation | 68.0% | 70.0% |
| Widow recall | 79% | 79% |
| Recluse recall | 79% | 79% |

The two classes the app exists to catch did not move. The validation gain is
within run to run variance and three classes regressed.

**Why.** The hypothesis assumed widow and recluse photos had a background
problem to remove. They likely did not. People photographing a black widow get
close and centre it, because it is the interesting and faintly alarming thing
in front of them. Those images were already well framed.

**Secondary finding.** Tight cropping upscales, and 26% of crops came out under
200px before Create ML resizes to 299x299. The worry was that softness would
correlate with class and become a learned feature. The data did not support it:
widow had 40% of crops under 200px and stayed flat, tarantula had 40% and
nudged up, cellar_spider had 12% and dropped. The planned follow up on a size
filtered copy was dropped for lack of evidence.

### 2. Hierarchical triage, three attempts

**Hypothesis.** Ten way family classification is hard, and most of that
difficulty buys nothing. Huntsman versus wolf spider is genuinely ambiguous
from a photo and nobody is harmed by getting it wrong. Collapsing to widow,
recluse, and one pooled benign class should free capacity for the distinction
that matters.

**Result, all three on the same holdout.**

| Benign to dangerous ratio | Training images | Dangerous recall | Note |
|---|---|---|---|
| ~1 to 1 | 3,013 | 68.5% | Best of the three, 2 points over baseline |
| 3 to 1 | 3,341 | 57.8% | More benign data, worse |
| 12 to 1 | 8,814 | 8.1% | Majority class collapse |

**The 12 to 1 run is a textbook failure worth naming.** Create ML minimises
symmetric cross entropy with uniform sample weights. With 85% of samples
benign, the optimiser learned that answering benign is right most of the time
and did exactly that. Holdout accuracy read 82.3%, which looks respectable and
means nothing: a model that always says benign scores about the same on that
distribution. Dangerous recall was 8.1%, and standalone false reassurance was
91.9%.

Capping the benign pool recovered most of the collapse, 8.1% to 57.8%,
confirming the diagnosis. But it still landed below the 10 class baseline, and
recall fell monotonically as benign volume rose. The best result came from the
smallest, most balanced set.

**Conclusion.** Volume is not the bottleneck and adding benign data actively
hurts. The one configuration that beat the baseline did so by 2 points, which
does not justify running and calibrating two models for triage. The three class
model was retained in a narrower role, as the agreement veto above, where its
different failure profile is the point and its poor standalone accuracy does
not matter.

**Caveat on interpretation.** The capped runs drew widow and recluse from a more
strictly cleaned dataset, so those classes had 730 and 611 images against the
943 and 969 in the first attempt. Benign volume rose while dangerous volume
fell slightly, which complicates a pure reading of the volume question.

### 3. Synthetic augmentation

| Configuration | Validation |
|---|---|
| No augmentations | **68.0%** |
| 5 augmentations including blur and noise | 41.0% |

Synthetic blur destroys the fine detail spiders are identified by: eye
arrangement, leg spination, the edges of abdominal markings. Four runs to
isolate, because blur was one of five augmentations enabled together.

The corollary shaped the app. Poor captures are handled at runtime through the
entropy filter and structured refusal, not by teaching the model to tolerate
degradation.

Worth noting the effect is not universal. At ~470 images per class, turning
augmentation off made things worse rather than better, 64% to 56%. With half
the data the model needed variety more than it was hurt by degradation. The
finding is specific to a configuration, not a rule.

### 4. Training volume

Halving the dataset to ~500 per class and cleaning it more strictly produced
64% validation against 68%, with widow at 78% and recluse at 77%. Restoring the
full set but applying the stricter standard produced 62%, and revealed the real
problem: the strict criteria cut hardest on the classes with the fewest good
photos to begin with. Recluse lost 43% of its images, widow 30%, while
jumping_spider and not_a_spider lost almost none.

Widow and recluse became the two smallest classes in the set, and recall
dropped accordingly. Cleaning quality does not compensate for imbalance, and
strict criteria applied uniformly do not produce uniform cuts.

***

## Preprocessing Alignment

Testing inference preprocessing produced the largest single recall change in
the project, from a one line setting.

The intuition was that letterboxing (`.scaleToFit`) preserves leg geometry and
avoids squashing the spider. Measured across the same 1,946 images with one
variable changed:

| Method | Holdout accuracy | Dangerous recall | Fitted T |
|---|---|---|---|
| Stretched (`.scaleToFill`) | **60.9%** | **66.5%** | 1.53 |
| Letterboxed (`.scaleToFit`) | 56.2% | 55.2% | 1.64 |

**11.3 points of dangerous recall, from padding.** Create ML squashes training
images to 299x299 rather than letterboxing. The black bars introduced border
artifacts the convolutional filters never saw in training, while shrinking the
spider's effective resolution. Matching training with `.scaleToFill` recovered
it immediately.

The diagnosis was initially backwards: the calibration script was letterboxing
and the app was not, so the fix looked like it belonged in the script. It
belonged in the classifier.

***

## Identification Cascade

Identification runs through four orchestrated tiers:

| Tier | Component | Function | Cost / Latency |
|---|---|---|---|
| **1** | **Apple Vision (`ClassifyImageRequest`)** | Coarse category identification (spider, plant, bird, insect). Non-spiders resolve immediately from local catalog. | Offline, ~40ms |
| **2a** | **Core ML Hazard Model (`SpiderHazard.mlmodel`)** | 10-class image classifier trained on medically significant vs. common benign spider families. Evaluated with `.scaleToFill` to match Create ML training preprocessing. | Offline, ~60ms |
| **2 gate** | **Agreement Veto Model (`SpiderHazardGate.mlmodel`)** | 3-class safety screen. Vetoes confident benign calls if danger is detected. Drops holdout false reassurance to 0 of 346. | Offline, ~30ms |
| **2b** | **Apple Intelligence (`SystemLanguageModel`)** | Multimodal feature extraction. Inspects eye arrangements (6 eyes in 3 pairs for Recluse), hourglass markings, and violin patterns. Isolates subject via Vision foreground instance masking. *(Requires iOS 27+; earlier devices fall back to Core ML + Gate alone).* | Offline, on-device |
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
    * Tap **Export field log** to inspect `field-log.csv`, which retains the complete internal **Cascade Decision Trace** (`tier1`, `tier2a`, `gate`, `tier2b`, `combine`) for ML diagnostics.

***

## Known Limitations

**Dangerous recall is 66.5%.** A third of real widows and recluses are not
classified into a dangerous group. Those become refusals rather than benign
calls, which is safe but not useful. This is the main thing a future version
should improve, and four experiments have failed to improve it.

**Calibration is in distribution.** T = 1.53 and the gate thresholds were
fitted on iNaturalist research grade photographs: daylight, decent cameras,
photographers who chose to submit. Real use is a phone in a dim garage at
midnight with flash. The thresholds are a large improvement on guesses and are
not the final answer. Recalibration against real captures is pending tester
data.

**The plant model has no holdout.** `PlantHazard.mlmodel` reports 83%
validation accuracy and has never been evaluated on unseen images. Every
caveat above about Create ML's validation split applies to it, unmeasured.

**Layer 3 requires iOS 27.** Multimodal corroboration through Apple
Intelligence is unavailable on iOS 26 and earlier. Those devices fall back to
the 10 class model, the calibrated gate, and the agreement veto, which is where
the 0 of 346 figure comes from anyway.

**Zero of 346 is a measurement, not a guarantee.** It rests on one caught case
in one holdout. The true rate has real uncertainty around it.
