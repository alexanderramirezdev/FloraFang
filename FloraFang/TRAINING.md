# Training the FloraFang Hazard Classifier

Goal: A Core ML image classifier that distinguishes medically significant spiders (widows and recluses) from common harmless families, evaluated with clinical rigor against unseen holdout captures.

Budget roughly **2 to 3 weeks part-time**. Most of that time is invested in data curation, not model training.

***

## Step 0: Understand What You Are Optimizing

Two failure modes carry wildly different real-world consequences:

| Failure Mode | Clinical & Practical Consequence |
|---|---|
| Model says "not medically significant," but it is a widow or recluse | Someone gets bitten, leading to a medical emergency |
| Model flags "possible hazard," but it is a harmless wolf spider | User exercises caution, cup relocates the specimen |

Every design decision follows from that fundamental asymmetry. **Overall accuracy is the wrong headline metric.** What matters above all is *controlling false reassurance on dangerous classes*: what fraction of actual widows and recluses did the system falsely label as safe.

***

## Step 1: Set Up the Production 10-Class Dataset Structure

Create ML reads class labels directly from folder names. These match `SpiderClasses.swift` exactly:

```
training_data/
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

## Step 3: Clean the Data and Eliminate Clutter

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

## Step 4: Build the Independent Held-Out Test Set

Do not skip this step. It is the step that separates an academic model from one that protects people in the real world.

When evaluating image classifiers, models always score high on their own internal validation splits because the validation photos share the same cameras, lighting, photographers, and conditions as the training set.

To test honest real-world performance, build an **independent holdout set** (`florafang-training/holdout`):
1. Pull fresh research-grade observations using `fetch_holdout.py`.
2. Explicitly read every observation ID already present in the training set and exclude them, ensuring zero data leakage.
3. Our production holdout set contains **1,946 unseen images**, including 346 verified real widows and recluses.
4. Never train on the holdout set. It is held sacred as the ground truth benchmark.

***

## Step 5: Train in Create ML

1. Launch Xcode and navigate to **Open Developer Tool > Create ML**.
2. Select **New Document > Image Classification**.
3. Point Training Data to your `training_data/` folder.
4. Set Validation Data to **Automatic** (Create ML carves out a randomized split).
5. Preprocessing setting: Choose **Scale to Fill** (`.scaleToFill`).

### Preprocessing and Augmentation Findings

* **Do not use synthetic blur or artificial noise augmentations.** Four controlled experimental runs demonstrated that synthetic blur slashed validation accuracy from 68.0% down to 41.0%. Blur corrupts the fine-grained ocular patterns and leg spine structures that distinguish recluses from wandering spiders.
* **Safe augmentations to select**: Horizontal flip, modest rotation (within 15 degrees), and subtle exposure variation.
* **Avoid letterboxing**: Letterboxing (`.scaleToFit`) adds artificial black borders that degrade dangerous recall by 11.3 percentage points compared to `.scaleToFill`.

Start iterations at 25 to 30. Monitor whether training accuracy climbs while validation accuracy plateaus, which signals overfitting. Training typically completes in 20 to 60 minutes on Apple Silicon.

***

## Step 6: Empirical Calibration on the Holdout Set

After exporting `SpiderHazard.mlmodel`, run `calibrate.py` over the 1,946-image holdout set:

```bash
python3 calibrate.py --model SpiderHazard.mlmodel --holdout florafang-training/holdout
```

### Empirical Calibration Findings

1. **Empirical Temperature Scaling ($T = 1.53$)**:
   Fitting temperature parameter $T$ via Negative Log Likelihood minimization over 1,946 unseen images converged at $T = 1.53$ (NLL 1.2014):
   * Uncalibrated ECE ($T = 1.0$): 0.1014 (predictions in the 0.8 to 0.9 confidence bucket were only 67.9% accurate).
   * Calibrated ECE ($T = 1.53$): 0.0274 (a 73% drop in calibration error).
2. **Deriving `benignFloor = 0.86`**:
   To ensure benign claims are at least 95% reliable, the benign confidence floor must be set to 0.86.
3. **Controlling False Reassurance (0.29%)**:
   On 346 real dangerous spiders in the holdout, an uncalibrated 0.38 floor emitted false reassurance on 76 of 346 (22.0%). At the calibrated 0.86 floor, false reassurance dropped to **1 of 346 (0.29%)**.
4. **Dangerous Recall Plateau (66.5%)**:
   On the holdout set, the vision classifier alone achieved 66.5% top-1 recall on dangerous species, meaning 33.5% were assigned a benign top-1 label. This proved why Tier 2b (Apple Intelligence multimodal feature extraction) and Tier 4 (structured refusal) are mandatory safety layers.

***

## Step 7: Case Study: The 3-Class Triage Experiment

We conducted a controlled experiment exploring a dedicated 3-class primary gate (`hazard3`: `widow`, `recluse`, `not_medically_significant`) designed to ask "is this a widow or recluse?" before resolving taxonomy.

### The Contrast: Validation Flattery vs Holdout Reality

| Metric | Create ML Validation Split | Independent Holdout Test Set (1,946 images) |
|---|---|---|
| **Overall Accuracy** | 85.0% | 61.2% |
| **Widow Recall** | 90.0% | 62.5% |
| **Recluse Recall** | 95.0% | 76.7% |
| **Combined Dangerous Recall** | N/A | 68.5% (237 / 346) |
| **False Reassurance Rate** | N/A | **14.5%** (50 / 346) |

### Why the 3-Class Gate Failed on Safety

While Create ML reported 90% to 95% recall on its randomized split, the model's true performance on unseen holdout photos was 68.5% dangerous recall: only 2 points better than the 10-class model (66.5%).

More critically, the 3-class model produced a **14.5% false reassurance rate**: **50 out of 346 real venomous spiders** were confidently classified as harmless (`not_medically_significant` with confidence exceeding its 0.68 floor).

In the 10-class model, ambiguous dangerous spiders scatter probability across multiple harmless families, failing the strict 0.86 floor and triggering refusal. In the 3-class model, all uncertainty between widow and recluse dumps directly into `not_medically_significant`, creating high-confidence false all-clears.

Because mislabeling 1 in 7 venomous spiders as safe is unacceptable in medical triage, the 3-class gate was rejected for production. The calibrated 10-class model remains the production classifier.

***

## Step 8: v1.1 Research Roadmap for Hierarchical Gates

To realize the theoretical benefits of a hierarchical gate in v1.1 without the safety penalty:
1. **Dataset Expansion**: Expand the primary gate training set significantly beyond 3,013 images to teach the network subtle distinctions across thousands of natural variations.
2. **Asymmetric Loss Weighting**: Apply higher penalty loss to false negatives during training in PyTorch before exporting via `coremltools`.
3. **Mandatory Safety Criterion**: Any prospective gate model must achieve a false reassurance rate below 0.3% on the 1,946-image holdout set before deployment.
