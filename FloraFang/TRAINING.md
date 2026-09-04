# Training the FloraFang hazard classifier

Goal: a Core ML image classifier that answers **"is this a widow or a recluse?"**
— not "what species is this spider." The narrower question is the one users
actually have, and it's the one that's achievable from a phone photo.

Budget roughly **2–3 weeks part-time**. Most of that is data work, not training.

---

## Step 0 — Understand what you're optimizing

Two failure modes, wildly different costs:

| Failure | Cost |
|---|---|
| Model says "harmless," it's a widow | Someone gets hurt |
| Model says "possible widow," it's a wolf spider | Someone is briefly annoyed |

Every decision below follows from that asymmetry. **Overall accuracy is the
wrong headline metric.** You care about *recall on the dangerous classes* —
what fraction of actual widows did we catch. A model at 96% accuracy that
misses 1 widow in 5 is a bad model for this app.

---

## Step 1 — Set up the folder structure

Create ML reads class labels from folder names. These must match
`SpiderClasses.swift` exactly.

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

`not_a_spider` matters more than it sounds. Without it the model must call
everything a spider, including your carpet. Fill it with insects, lint, shadows,
cracks in drywall, houseplants — the things people actually point a phone at by
mistake.

---

## Step 2 — Pull images from iNaturalist open data

Source: iNaturalist's licensed observation images, published through the AWS
Open Data program, plus their taxonomy export for mapping taxa to your classes.
Start at <https://www.inaturalist.org/pages/developers>.

Target **1,000–2,000 images per class.** Filters that matter:

- **Research grade only.** Community-verified. Non-research-grade includes
  misidentifications, which become label noise you can't see.
- **License check.** Respect the license on each photo; not all are permissive.
- **Deduplicate by observation ID.** One observation often has 4–5 photos of
  the same individual from the same angle. Those are near-duplicates, and they
  inflate your validation score while teaching the model nothing.
- **Geographic spread.** All-Arizona widows will not generalize.

Genus mappings for the dangerous classes:

- `widow` → *Latrodectus* (mactans, hesperus, variolus, geometricus)
- `recluse` → *Loxosceles* (reclusa, deserta, laeta)

---

## Step 3 — Clean the data (this is the actual work)

Budget 3–5 days. Do it by eye, in batches, with a coffee.

Delete or fix:

- Photos where the spider is a speck in the corner → crop or drop
- Photos that are mostly web with no visible body
- Multiple spiders in frame
- Preserved/pinned museum specimens — they look nothing like a live spider on
  a wall, and the model will learn the white background instead of the spider
- Obvious misidentifications that slipped through

**Crop to the subject.** A tight crop of the spider outperforms a full frame,
because otherwise the model learns backgrounds. If your class folders each have
a characteristic background — widows on wood, orb weavers on foliage — the model
will happily classify the background and score beautifully on validation while
being useless in a bedroom.

---

## Step 4 — Handle class imbalance

You will end up with far more widow photos than cellar spider photos, because
people photograph scary spiders.

Left alone, the model learns "when unsure, say widow."

Options, roughly in order of preference:

1. **Cap the majority classes** at the size of a mid-sized class. Simplest,
   costs you data you had.
2. **Augment the minority classes** more aggressively (see step 6).
3. **Weight the loss** — not exposed in Create ML's GUI; requires dropping to
   Python/PyTorch and converting with `coremltools`.

For v1, capping is fine. Note the counts per class in a text file so future-you
knows what the model saw.

---

## Step 5 — Build the test set from YOUR photos

**Do not skip this.** It's the step that separates a model that works from a
model that scores well.

iNaturalist photos are daylight macro shots taken by people with real cameras
and patience. Your app's input is a phone photo of a spider on a baseboard at
11pm, half-blurred, lit by flash, at an awkward angle.

That gap is called domain shift, and it is the single most common reason a
model that hits 94% in Create ML falls apart on device.

So:

1. Over the next couple of weeks, photograph **every spider you actually
   encounter** with your phone, the way a user would. Garage, closet, porch,
   under the sink.
2. Get them identified by a human — post to iNaturalist and let the community
   confirm, or ask in an arachnology forum.
3. Hold these out entirely. They are your test set. Never train on them.

Aim for 100+ images minimum. Yes, this takes weeks. That's why you start now
and let it accumulate while you do everything else.

While you're at it, treat your own photos like a stranger's — don't mentally
supply "well I know that one was in the garage so it's probably a widow."
That context is exactly what the model won't have.

---

## Step 6 — Train in Create ML

1. Xcode → **Open Developer Tool → Create ML**
2. New Document → **Image Classification**
3. Training Data: your `training_data/` folder
4. Validation Data: leave on **Automatic** (it splits from training)
5. Testing Data: your phone photos from Step 5

Augmentations — check these:

- **Blur** (motion, hand shake)
- **Noise** (low light)
- **Rotate** (people don't hold phones level)
- **Flip** (spiders are roughly bilaterally symmetric)
- **Exposure** (flash blowout, dark corners)

Skip **Crop** if you already cropped tightly in Step 3.

Iterations: start at 25. Watch for the training accuracy climbing while
validation accuracy stalls — that's overfitting, and more iterations won't fix
it. More or better data will.

Training takes 20–60 minutes on Apple Silicon.

---

## Step 7 — Read the results correctly

Create ML shows you overall accuracy. Mostly ignore it. Open the **precision
and recall table per class** instead.

The number that matters:

> **Recall on `widow` and `recluse`.**
> Of all the real widows in the test set, what fraction did the model catch?

If widow recall is below ~90%, the model isn't ready regardless of what the
headline accuracy says.

Second number: **precision on the benign classes.** When the model says
"cellar spider, harmless," how often is that right? This is the claim that gets
someone hurt if it's wrong.

Also look at the confusion matrix specifically for **widow → anything**. Every
cell in that row that isn't `widow` is a potential injury.

---

## Step 8 — Calibrate the confidence gate & defense layers

The inference pipeline in `HazardClassifier.swift` and `ConfidenceGate.swift` uses an empirically calibrated defense pipeline:

1. **Empirical Temperature Scaling ($T = 1.53$)**:
   Modern deep neural networks produce severely miscalibrated, overconfident softmax distributions. Fitting $T$ via negative log likelihood minimization over **1,946 unseen, held-out iNaturalist research-grade images** yielded $T = 1.53$ (NLL 1.2014).
   * **Uncalibrated ECE ($T = 1.0$):** 0.1014 (raw predictions were systematically overconfident; e.g. 85% confidence bucket was only 67.9% accurate).
   * **Calibrated ECE ($T = 1.53$):** 0.0274 (a 73% drop in calibration error, pulling bucket accuracy onto the diagonal).
2. **Shannon Entropy Filter ($H$)**: Max entropy across 10 classes is $\log_2(10) \approx 3.32$. If entropy $H > 2.35$ and top confidence is $< 0.55$, the model is guessing across multiple classes on an unfamiliar/OOD image (like monitor glare, carpets, or motion blur). The gate escalates to refusal automatically. *Note:* Entropy catches diffuse confusion, not sharp overconfident misclassifications; those are guarded by Layers 2, 3, and 4.
3. **Empirically Derived Asymmetric Thresholds**:
   - `benignFloor = 0.86`: Derived from the calibration curve. A benign classification requires $\ge 0.86$ calibrated confidence to achieve $\ge 95\%$ empirical accuracy. Below this, benign claims are treated with caution or escalated.
   - `dangerousFloor = 0.22`: Set permissively to capture low-confidence hazard signals. *Critical finding:* On held-out data, top-1 recall on real widows and recluses plateaus at 66.5% because 33.5% of real specimens are ranked into benign classes by the vision model alone. This demonstrates why Tier 2b (multimodal Apple Intelligence feature inspection) and Tier 4 (structured refusal) are essential.
   - `minimumMargin = 0.06`: Ensures top prediction beats the runner-up.

Procedure used to measure (`calibrate.py`):
1. Pulled 1,946 fresh observations using `fetch_holdout.py`, excluding observation IDs present in training.
2. Ran `calibrate.py --model SpiderHazard.mlmodel --holdout florafang-training/holdout`.
3. Saved predictions to `calibration-predictions.csv` and derived $T = 1.53$ and `benignFloor = 0.86`.
4. Rerun this script whenever the model weights are retrained.

---

## Step 9 — Drop it into the app

1. Rename the exported model to **`SpiderHazard.mlmodel`**
2. Drag it into the Xcode project, target ticked
3. Build

`HazardClassifier` finds it by name and Tier 2 activates automatically. No
other code change. If it doesn't light up, check the Xcode console for
`[FloraFang] No SpiderHazard model in bundle`.

Verify with the **cascade trace** — tap it at the bottom of any result screen.
You should see `tier2:` lines with real labels instead of
`tier2: no model in bundle, skipped`.

---

## Step 10 — Test it like a stranger would

Photograph 30 spiders in genuinely bad conditions: dim, blurry, at an angle,
partially hidden. Record what the app says versus what it actually is.

You're looking for two things:

- Any widow the model called harmless → stop, retrain, this is the blocker
- How often it refuses → if it's refusing on 60% of real photos, the gate is
  too tight or the model is too weak; if it never refuses, the gate is too loose

Change **one variable at a time** between runs. Threshold or model or
preprocessing, never two at once, or you won't know what moved the number.

---

## Ongoing

Retrain when you've accumulated another few hundred real-world photos. Your own
field log becomes training data over time, which is a quiet advantage the
competition doesn't have — nobody else has photos taken by *your* users in
*your* region under *your* app's capture conditions.

## A note on scope

If widow recall plateaus below 90% no matter what you do, that's information,
not failure. It means photo-only hazard classification has a ceiling, and the
right move is Tier 3 (remote model) or Tier 4 (honest refusal), both of which
are already built. The app is designed to be useful even when the model isn't
good enough — that was the point of the cascade.
