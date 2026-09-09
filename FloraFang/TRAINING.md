# Training the FloraFang Hazard Classifier

Goal: A Core ML image classification cascade that answers **"is this a widow or a recluse?"** with clinical sensitivity, followed by family level resolution for harmless spiders. The primary question users have in the field is whether a specimen presents a medical emergency. Once safety is confirmed, identifying whether a spider is a jumping spider, orb weaver, or wolf spider provides valuable natural history context.

Budget roughly **2 to 3 weeks part-time**. Most of that time is invested in data curation, not model training.

***

## Step 0: Understand What You Are Optimizing

Two failure modes carry wildly different real-world consequences:

| Failure Mode | Clinical & Practical Consequence |
|---|---|
| Model says "not medically significant," but it is a widow or recluse | Someone gets bitten, leading to a medical emergency |
| Model flags "possible hazard," but it is a harmless wolf spider | User exercises caution, cup relocates the specimen |

Every design decision follows from that fundamental asymmetry. **Overall accuracy is the wrong headline metric.** What matters above all is *recall on medically significant classes*: what fraction of actual widows and recluses did the system catch. A model reporting 96% accuracy that misses 1 widow in 5 is unacceptable for this application.

***

## Step 1: The Two Stage Cascade Architecture

Early experiments with a single 10 class model revealed a biological roadblock: wandering brown spiders (such as wolf spiders, huntsman spiders, grass spiders, and nursery web spiders) share broad visual morphology with brown recluses (long legs, neutral brown coloration, minimal abdominal patterning). When forced to distinguish ten fine-grained classes simultaneously at 299 by 299 resolution, the classifier confused brown wanderers with recluses, capping dangerous class recall at 66.5% to 79.0%.

FloraFang solves this by separating concerns into a **two stage Core ML cascade**:

1. **Stage 1 (Tier 2a): The 3 Class Primary Hazard Gate** (`SpiderHazard-training dangerous.mlmodel`).
   * Evaluates three target classes: `widow`, `recluse`, and `not_medically_significant`.
   * Aggregates all harmless spider families, non-spider organisms, and ambient background clutter into a single unified benign class.
   * Optimizes solely for clinical sensitivity, achieving **95% Recluse recall** (89% precision) and **90% Widow recall** (93% precision) with **85% validation accuracy**.
2. **Stage 2 (Tier 2c): The 10 Class Benign Family Resolver** (`SpiderHazard-tier2c.mlmodel`).
   * Only called after Stage 1 has cleared the specimen as `not_medically_significant`.
   * Resolves the specific harmless family: jumping spiders, wolf spiders, orb weavers, cellar spiders, huntsman spiders, or tarantulas.
   * Clinical safety masking: dangerous classes (`widow`, `recluse`) are masked out by default in Tier 2c because Stage 1 already ruled them out. As an extreme backup safeguard, if Tier 2c exhibits extreme conviction (85% or higher) for a dangerous class, the cascade halts and flags the hazard.

### Dataset Folder Structures

Create ML reads class labels directly from parent folder names.

#### 1. Primary Hazard Gate Dataset (`hazard3/`)
```
hazard3/
├── widow/
├── recluse/
└── not_medically_significant/
```
The `not_medically_significant/` folder combines verified benign spiders (jumping spiders, wolf spiders, cellar spiders, orb weavers, huntsman spiders, tarantulas) along with non-spider clutter (insects, leaves, carpets, shadows, drywall cracks).

#### 2. Fine-Grained Family Resolver Dataset (`raw-curated/`)
```
raw-curated/
├── widow/
├── recluse/
├── wolf_spider/
├── orb_weaver/
├── jumping_spider/
├── cellar_spider/
├── huntsman/
├── tarantula/
├── other_spider/
└── not_a_spider/
```

The `not_a_spider` class is essential. Without it, the model is mathematically forced to assign every frame to a spider class, including carpets, baseboards, and fingers.

***

## Step 2: Pull Images from iNaturalist Open Data

Source images from iNaturalist licensed observation records, published through the AWS Open Data program, accompanied by their taxonomy export. Start at <https://www.inaturalist.org/pages/developers>.

Target **1,000 to 2,000 images per class**. Key filtering requirements:

* **Research grade only.** Community verified observations. Unverified records contain misidentifications that introduce invisible label noise.
* **Permissive license check.** Verify licensing on each photo (CC0, CC-BY, CC-BY-NC).
* **Deduplicate by observation ID.** A single observation often includes 4 to 5 photos of the identical individual from slightly shifted angles. These near duplicates artificially inflate validation scores without teaching the model genuine variance.
* **Broad geographic spread.** Widows from Arizona will not generalize to specimens across Florida, California, or the Mediterranean.

Genus mappings for dangerous classes:
* `widow` includes *Latrodectus* (mactans, hesperus, variolus, geometricus)
* `recluse` includes *Loxosceles* (reclusa, deserta, laeta)

***

## Step 3: Clean the Data & Curate Weak Classes

Curating training data is where the battle is won. Plan for 3 to 5 days of manual inspection.

Remove or correct:
* Captures where the organism is a tiny speck in a corner (crop tightly or delete).
* Captures that depict mostly empty web without a visible specimen body.
* Multiple organisms in a single frame.
* Pinned museum specimens. Their stiff poses and white card backgrounds teach the network to classify paper rather than live spiders on walls.
* Mislabeled brown wandering spiders. In particular, inspect cellar spiders, huntsman spiders, and nursery web spiders that community volunteers misidentified as recluses.

**Framing and Subject Cropping**:
A tight crop around the organism consistently outperforms full-frame shots. Otherwise, the convolutional network learns background context (such as widows on weathered wood versus orb weavers in green leaves) and achieves high validation scores while failing completely in a household setting.

***

## Step 4: Handle Class Imbalance

Real-world datasets naturally accumulate far more widow and orb weaver photos than cellar spider or tarantula photos, because users photograph conspicuous or alarming organisms.

Left uncorrected, a model learns to default to the majority class when uncertain.

Recommended approaches:
1. **Cap majority classes** to match the volume of representative mid-sized classes.
2. **Augment minority classes** using natural geometric rotations and gentle exposure shifts.
3. **Consolidate ambiguous groups** into `other_spider` or `not_medically_significant`.

Keep a record of per-class counts in a documentation log for future retraining cycles.

***

## Step 5: Build the Independent Held-Out Test Set

Do not skip this step. It separates a model that scores well on an isolated split from one that functions reliably on an iPhone.

Naturalist photographs from iNaturalist are primarily daylight macro captures taken with dedicated cameras. The app's real-world input is an iPhone photo taken in a garage or behind a sink at midnight, half blurred, lit by a harsh LED flash, from an awkward perspective.

That difference is known as domain shift, and it is the primary reason why a model with 94% validation in Create ML can fail on hardware.

To construct a robust test set:
1. Photograph real spiders encountered in daily life using an iPhone camera.
2. Secure ground-truth identification from an arachnologist or community consensus on iNaturalist.
3. Hold these photographs out completely. Never include them in training sets.
4. Target at least 100 to 200 real-world phone captures.

***

## Step 6: Train in Create ML

1. Launch Xcode and navigate to **Open Developer Tool > Create ML**.
2. Select **New Document > Image Classification**.
3. Point Training Data to `hazard3/` for the primary gate, or `raw-curated/` for the family resolver.
4. Set Validation Data to **Automatic** (Create ML carves out a randomized split).
5. Preprocessing setting: Choose **Scale to Fill** (`.scaleToFill`).

### Preprocessing and Augmentation Rules

* **Do not use synthetic blur or artificial noise augmentations.** Four controlled experimental runs demonstrated that synthetic blur slashed validation accuracy from 68.0% down to 41.0%. Blur corrupts the fine-grained ocular patterns and leg spine structures that distinguish recluses from wandering spiders.
* **Safe augmentations to select**: Horizontal flip, modest rotation (within 15 degrees), and subtle exposure variation.
* **Avoid letterboxing**: Letterboxing (`.scaleToFit`) adds artificial black borders that degrade dangerous recall by 11.3 percentage points compared to `.scaleToFill`.

Start iterations at 25 to 30. Monitor whether training accuracy climbs while validation accuracy plateaus, which signals overfitting. Training typically completes in 15 to 45 minutes on Apple Silicon.

***

## Step 7: Evaluate Empirical Metrics

Create ML presents overall accuracy as the headline metric. In a clinical hazard triage pipeline, overall accuracy is secondary. Focus on the **per-class precision and recall matrix**.

### Primary Hazard Gate Performance (`hazard3`)

| Class | Recall | Precision | Clinical Role |
|---|---|---|---|
| **Recluse** | **95.0%** | **89.0%** | High sensitivity screening for *Loxosceles* |
| **Widow** | **90.0%** | **93.0%** | High sensitivity screening for *Latrodectus* |
| **Not Medically Significant** | **83.0%** | **88.0%** | Safe aggregation of benign families and non-spiders |
| **Overall Validation** | **85.0%** | **85.0%** | Robust 3-class separation on Create ML split |

### Benign Family Resolver Performance (`raw-curated`)

| Metric | Curated 10 Class Model | Finding |
|---|---|---|
| **Training Accuracy** | **66.0%** | Reflects subtle visual overlap across brown wandering spiders |
| **Validation Accuracy** | **59.0%** | Fine-grained family resolution on natural captures |
| **Role in Cascade** | **Tier 2c Resolver** | Resolves harmless families only after hazard gate clears safe |

By running the 3 class hazard gate first, the system achieves 90% to 95% sensitivity on critical hazards, while the 10 class model provides granular family taxonomy for benign spiders without threatening patient safety.

***

## Step 8: Calibrate the Confidence Gate and Defense Layers

Inference in `HazardClassifier.swift` and `ConfidenceGate.swift` applies mathematical calibration:

1. **Empirical Temperature Scaling ($T = 1.53$)**:
   Softmax probability distributions from deep neural networks are systematically overconfident. Fitting temperature parameter $T$ via Negative Log Likelihood minimization over **1,946 unseen, held-out images** yielded $T = 1.53$ (NLL 1.2014).
   * Uncalibrated ECE ($T = 1.0$): 0.1014 (predictions in the 0.8 to 0.9 confidence bucket were only 67.9% accurate).
   * Calibrated ECE ($T = 1.53$): 0.0274 (a 73% reduction in calibration error).
2. **Shannon Entropy Filter ($H$)**:
   Theoretical maximum entropy across ten classes is $\log_2(10) \approx 3.32$ bits. If entropy $H > 2.35$ and top probability is $< 0.55$, the model is guessing across multiple classes on an unfamiliar input. The gate halts and issues a structured refusal.
3. **Calibrated Operating Thresholds**:
   * `benignFloor = 0.86`: Derived from empirical calibration curves. A benign classification requires at least 0.86 calibrated confidence to guarantee 95% precision.
   * `dangerousFloor = 0.22`: Set permissively to capture faint hazard signals for secondary verification.
   * `minimumMargin = 0.06`: Ensures the top prediction significantly beats the second-place candidate.

***

## Step 9: Install Models in the Xcode Project

1. Add both compiled models to the Xcode project:
   * **Primary Hazard Gate**: `SpiderHazard-training dangerous.mlmodel` (or `SpiderHazard.mlmodel`).
   * **Secondary Family Resolver**: `SpiderHazard-tier2c.mlmodel` (or `SpiderFamily.mlmodel`).
2. Ensure both models are checked under the **FloraFang** app target in the Target Membership pane.
3. Build the project (`Cmd + B`).

`HazardClassifier.swift` automatically inspects the app bundle for candidate names:
* Primary gate candidates: `["SpiderHazard-training dangerous", "SpiderHazard"]`
* Family resolver candidates: `["SpiderHazard-tier2c", "SpiderFamily"]`

If the primary model is absent, the console reports `[FloraFang] No SpiderHazard primary model in bundle`. When present, Tier 2a and Tier 2c activate automatically.

Inspect runtime decisions via the **Cascade Trace** by tapping the bottom trace indicator on any scan result screen. A complete trace displays:
```
tier1: spider (confidence 0.94)
tier2a: not_medically_significant (calibrated 0.91)
tier2c: jumping_spider (calibrated 0.88, family resolved)
```

***

## Step 10: Field Testing and Refusal Validation

Capture 30 to 50 spiders under challenging conditions: dim lighting, motion blur, steep angles, or partially hidden specimens.

Watch for two primary outcomes:
* Any widow or recluse labeled as benign: If this occurs, stop immediately, inspect the specimen photograph, and retrain.
* Refusal rate: If the app refuses 60% of clear photographs, the confidence gate is overly strict. If it never refuses on blurry or ambiguous photos, the gate is overly loose.

Change only one variable at a time between iterations: adjust the model, the threshold, or the image preprocessing, never multiple variables at once.

***

## Ongoing Model Maintenance

Retrain whenever 200 to 500 new real-world field captures are gathered. Your own field log accumulates localized data that standard web scrapers lack: photos taken by your users under genuine mobile capture conditions.

If dangerous class recall plateaus in difficult angles, rely on Tier 2b (multimodal visual feature inspection using Apple Intelligence Foundation Models) or Tier 4 (honest refusal). The cascade is engineered to protect users even when visual classification alone reaches its physical limits.
