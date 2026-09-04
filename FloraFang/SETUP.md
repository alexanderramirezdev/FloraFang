# FloraFang — Project Setup & Architecture Guide

## Environment Requirements

* **Xcode**: Version 16.0 or higher (with iOS 27 SDK support).
* **Target OS**: iOS 27.0 beta.
* **Testing Hardware**: Physical iPhone running iOS 27 beta (Apple Silicon Neural Engine required for on-device Foundation Models).

---

## Required Permissions (Info.plist)

FloraFang runs 100% on-device and requires three privacy keys configured in `Info.plist`:

| Key | Purpose |
| :--- | :--- |
| `NSCameraUsageDescription` | Required to capture photos of spiders and plants for on-device identification. |
| `NSLocationWhenInUseUsageDescription` | Optional coarse location (~1 km) used solely to assist in narrowing geographic ranges. |
| `NSPhotoLibraryAddUsageDescription` | Allows users to save exported field log photos to their photo library. |

---

## Active Codebase Map

### Core Identification & AI
* `IdentificationCascade.swift`: Central coordinator for multi-tier evaluation, routing, and refusal generation.
* `HazardClassifier.swift`: Core ML wrapper with **Mathematical Temperature Scaling ($T = 1.6$)** and **Shannon Entropy ($H$)** calculation.
* `ConfidenceGate.swift`: Calibrated asymmetric confidence thresholds (`dangerousFloor = 0.22`, `benignFloor = 0.55`, `minimumMargin = 0.06`).
* `FeatureExtractor.swift`: Apple Intelligence multimodal feature extractor using on-device `SystemLanguageModel`.
* `SubjectSegmenter.swift`: Apple Vision foreground instance masking (`VNGenerateForegroundInstanceMaskRequest`).
* `ImageProcessor.swift`: Downscales and pre-processes images for Apple Foundation Model inference.
* `SpiderClasses.swift`: Label space for the 10 spider classes, clinical hazard notes, and diagnostic features.
* `PlantClasses.swift` & `PlantClassifier.swift`: Tier 2 toxic plant identification.
* `DiagnosticFeatures.swift`: Rule definitions for medical features (hourglass, violin, eye patterns).
* `Catalog.swift`: Taxonomy match terms, hazard ratings, and coarse category definitions.

### Camera & UI
* `CameraService.swift`: AVFoundation capture session manager with macro switching and tap-to-focus.
* `CameraPreview.swift`: Metal/UIKit video preview layer bridge.
* `CameraScreen.swift`: Viewfinder UI, quadrat capture brackets, zoom controls, and shutter.
* `ImageCropping.swift`: Aspect-fill quadrat geometry calculation.
* `ResultScreen.swift`: Identification card, decision traces, and save/discard actions.
* `FieldLogScreen.swift`: SwiftData observation history with search and filtering.
* `EntryDetailScreen.swift`: Full entry review, notes, and the **Field Naturalist AI** chat interface.
* `EmergencyScreen.swift`: 1-tap poison hotline dials and exposure intake checklist.
* `OnboardingView.swift`: 3-screen welcome flow explaining safety philosophy.
* `ExportService.swift` & `ExportConfirmSheet.swift`: Offline CSV and ZIP export generator.
* `LabelInspector.swift`: Developer debugging tool activated by long-pressing the camera shutter.

---

## Debugging & Verification

* **Label Inspector**: Long-press the camera shutter in `CameraScreen` to view raw Vision labels without filtering.
* **Cascade Decision Trace**: Scroll to the bottom of any saved entry in the Field Log to review the step-by-step trace (`tier1`, `tier2a`, `gate`, `tier2b`, `combine`).
