//
//  FeatureExtractor.swift
//  FloraFang
//
//  Tier 2b. Apple's on-device language model, asked what it can see rather
//  than what the thing is.
//
//  AVAILABILITY: image input arrived with iOS 27. On earlier systems, and on
//  hardware without Apple Intelligence, isAvailable returns false and the
//  cascade skips this tier entirely. Nothing downstream requires it.
//
//  GUIDED GENERATION IS NOT OPTIONAL HERE. FeatureReport is @Generable, so
//  the schema constrains sampling and the model is structurally incapable of
//  emitting a feature outside the sixteen cases in DiagnosticFeature.
//
//  Do not replace generate(prompt:) with a request for JSON in a string that
//  then gets decoded. That compiles, looks equivalent, and quietly removes
//  the constraint: a free text model can emit any feature name it likes, or
//  a species name in a field that is supposed to hold a marking. The decoder
//  would catch some of that and silently accept the rest. Constrained
//  decoding means the problem cannot occur rather than being caught later.
//

import Foundation
import FoundationModels
import UIKit

struct ExtractionResult: Sendable {
    let report: FeatureReport
    let verdict: FeatureVerdict
    /// Segmented input actually shown to the model, kept for the trace and
    /// for showing the user what was analyzed.
    let analyzedImage: UIImage?
}

actor FeatureExtractor {

    private let segmenter = SubjectSegmenter()
    private let processor = ImageProcessor()

    /// Written to constrain, not to encourage. Every line is a restriction.
    private let instructions = """
    You report visible markings on whatever is in an image. You do not \
    identify species.

    The image may not contain an animal at all. It may be a leaf, a wall, a \
    shadow, or too blurry to tell. Say so rather than describing an animal \
    that is not there. Nothing upstream has confirmed an animal is present.

    Rules you must follow:

    Report a feature only if you can see it in this image. Never infer a \
    feature from what the animal probably is. If the photo is taken from \
    above, you cannot see the underside of the abdomen, so you must not \
    report markings there.

    An empty feature list is a correct answer. A photo that is blurry, poorly \
    lit, or shows the animal too small will not show diagnostic detail, and \
    saying so is more useful than guessing.

    Never name a species, genus, or family. Never state whether the animal is \
    dangerous. Those judgements are made elsewhere from the features you report.

    List what the photo does not show, so the user knows what angle to \
    photograph next.
    """

    var isAvailable: Bool {
        get async {
            if #available(iOS 27.0, *) {
                return SystemLanguageModel.default.isAvailable
            } else {
                return false
            }
        }
    }

    /// Segments the subject, then asks the model which features are visible.
    func extract(from image: UIImage) async throws -> ExtractionResult? {
        guard #available(iOS 27.0, *) else { return nil }
        guard await isAvailable else { return nil }

        // Downscale first. A full resolution capture pushed through the
        // Neural Engine is a memory spike for no benefit, since the model
        // resizes internally anyway.
        let sized = try await processor.prepareForInference(image)

        // Isolating the subject matters more here than for Core ML. A
        // language model asked about a photo of a wall with a spider on it
        // will describe the wall, and the stucco will end up in the plain
        // description.
        let isolated = (try? await segmenter.isolateSubject(from: sized)) ?? sized

        guard let cgImage = isolated.cgImage else { throw IdentificationError.badImage }

        let report = try await requestFeatures(from: cgImage)

        // Segmentation grabs whatever the strongest foreground object is,
        // which on a photo of a leaf is the leaf. If the model says there is
        // no animal, believe it and contribute nothing rather than feeding
        // features from a plant into the spider rules.
        guard report.animalVisible else { return nil }

        let verdict = FeatureRules.evaluate(report.visibleFeatures)

        return ExtractionResult(report: report, verdict: verdict, analyzedImage: isolated)
    }

    // MARK: - The one API dependent call

    /// The only function in this file whose signature depends on the iOS 27
    /// multimodal API. Images attach to a Prompt and structured output comes
    /// back from respond(to:generating:).
    @available(iOS 27.0, *)
    private func requestFeatures(from cgImage: CGImage) async throws -> FeatureReport {
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: Instructions(instructions)
        )

        let prompt = Prompt {
            "Describe what is in this image and list any markings from the vocabulary that you can actually see."
            Attachment(cgImage)
        }

        // Return type drives the schema. FeatureReport is @Generable, so this
        // is constrained decoding, not a parsed string.
        let response = try await session.respond(to: prompt, generating: FeatureReport.self)
        return response.content
    }
}
