//
//  EntryDetailScreen.swift
//  FloraFang
//
//  Tapping a field log row. Shows what the app told you at the time, plus an
//  editable note and a zoomable photo.
//

import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

struct EntryDetailScreen: View {
    @Bindable var entry: FieldEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFullImage = false
    @State private var confirmDelete = false

    // On-device Field Naturalist (Apple Foundation Models)
    @State private var naturalistQuery = ""
    @State private var naturalistAnswer = ""
    @State private var isNaturalistThinking = false
    @State private var showEmergencySheet = false
    @State private var interceptedMedicalQuery = false

    var body: some View {
        ZStack {
            Palette.bark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    photo
                    headline
                    hazardBox
                    if !entry.ruledOut.isEmpty { ruledOutBox }
                    notes
                    noteEditor
                    naturalistChatSection
                    verdictSection
                    traceSection
                    metadata
                    deleteButton
                }
                // Extra bottom inset so the delete button clears the tab bar.
                // Without it the button rendered underneath and read as a
                // duplicate of itself.
                .padding(20)
                .padding(.bottom, 44)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bark, for: .navigationBar)
        .fullScreenCover(isPresented: $showFullImage) {
            if let data = entry.imageData, let image = UIImage(data: data) {
                ZoomableImageView(image: image)
            }
        }
        .sheet(isPresented: $showEmergencySheet) {
            if let data = entry.imageData, let img = UIImage(data: data) {
                EmergencyScreen(prefilledImage: img)
            } else {
                EmergencyScreen()
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var photo: some View {
        if let data = entry.imageData, let image = UIImage(data: data) {
            Button { showFullImage = true } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.parchment)
                            .padding(7)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(9)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.displayGroup.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.lichen)
                Spacer()
                if !entry.tierRaw.isEmpty {
                    Text(entry.tierRaw)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.lichen.opacity(0.75))
                }
            }

            Text(entry.displayTitle)
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)

            // Same rule as the result screen: no confidence number on a refusal.
            if !entry.wasRefusal {
                Text("\(Int(entry.confidence * 100))% confidence")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)
            }
        }
    }

    private var hazardBox: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: entry.hazard.symbol)
                .foregroundStyle(hazardTint)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.hazard.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hazardTint)
                Text(entry.displayHazardNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.parchment.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(hazardTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(hazardTint.opacity(0.5), lineWidth: 1))
    }

    private var ruledOutBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RULED OUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)
            ForEach(entry.ruledOut, id: \.self) { item in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.moss)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.parchment.opacity(0.85))
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.moss.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }

    private var hazardTint: Color {
        switch entry.hazard {
        case .safe:    return Palette.moss
        case .caution: return Palette.ochre
        case .avoid:   return Palette.rust
        case .unknown: return Palette.lichen
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.displayFieldNotes, id: \.self) { line in
                HStack(alignment: .top, spacing: 7) {
                    Text("—").foregroundStyle(Palette.ochre)
                    Text(line)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !entry.displayNextStep.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 11))
                    Text(entry.displayNextStep).font(.system(size: 11.5))
                }
                .foregroundStyle(Palette.lichen)
                .padding(.top, 4)
            }
        }
    }

    /// Editable in place — @Bindable writes straight through to SwiftData,
    /// so there's no explicit save call.
    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("YOUR NOTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)
            TextField("add a note…", text: $entry.note, axis: .vertical)
                .lineLimit(2...6)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.parchment)
                .padding(9)
                .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    // MARK: - On-Device Field Naturalist (Apple Foundation Models)

    @ViewBuilder
    private var naturalistChatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ochre)
                Text("FIELD NATURALIST")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.lichen)
                Spacer()
                Text("On-device AI")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.lichen.opacity(0.6))
            }

            Text("Ask about this observation — habitat, visible markings, photography advice, or safe non-contact relocation.")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.parchment.opacity(0.75))

            // Quick Prompt Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showEmergencySheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cross.case.fill")
                            Text("Exposure Protocol")
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Palette.rust.opacity(0.35), in: Capsule())
                        .overlay(Capsule().stroke(Palette.rust.opacity(0.7), lineWidth: 1))
                        .foregroundStyle(Palette.parchment)
                    }
                    .buttonStyle(.plain)

                    quickChip("📦 Safe way to move it?")
                    quickChip("🏠 Typical habitat?")
                    quickChip("📸 Best photo angles?")
                }
            }

            if interceptedMedicalQuery {
                poisonControlCard
            } else if !naturalistAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ANSWER")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(Palette.moss)
                        Spacer()
                    }
                    Text(naturalistAnswer)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Palette.moss.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.moss.opacity(0.3), lineWidth: 1))
            }

            if isNaturalistThinking {
                HStack(spacing: 8) {
                    ProgressView().tint(Palette.ochre)
                    Text("Consulting on-device model…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.lichen)
                }
                .padding(.vertical, 4)
            }

            // Custom Question Input
            HStack(spacing: 8) {
                TextField("ask about habitat, markings, or relocation…", text: $naturalistQuery)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.parchment)
                    .padding(9)
                    .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                    .onSubmit {
                        submitNaturalistQuery(naturalistQuery)
                    }

                Button {
                    submitNaturalistQuery(naturalistQuery)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(naturalistQuery.trimmingCharacters(in: .whitespaces).isEmpty ? Palette.lichen.opacity(0.4) : Palette.ochre)
                }
                .disabled(naturalistQuery.trimmingCharacters(in: .whitespaces).isEmpty || isNaturalistThinking)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    private var poisonControlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.rust)
                    .font(.system(size: 13, weight: .bold))
                Text("EXPOSURE ADVISORY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Palette.rust)
            }

            Text("FloraFang is not an emergency medical service and the AI chat does not provide bite, symptom, or treatment advice. For any bite, sting, or ingestion, contact Poison Control immediately.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.parchment)
                .lineSpacing(2)

            VStack(spacing: 8) {
                if let url = URL(string: "tel://18002221222") {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Call Poison Control: 1-800-222-1222")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("Free · 24/7")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.parchment.opacity(0.7))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Palette.rust.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.rust.opacity(0.6), lineWidth: 1))
                        .foregroundStyle(Palette.parchment)
                    }
                }

                if let url = URL(string: "tel://8884264435") {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "pawprint.fill")
                            Text("ASPCA Pet Poison: (888) 426-4435")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("Animal Hotline")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.parchment.opacity(0.7))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Palette.moss.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.moss.opacity(0.5), lineWidth: 1))
                        .foregroundStyle(Palette.parchment)
                    }
                }

                Button {
                    showEmergencySheet = true
                } label: {
                    HStack {
                        Image(systemName: "cross.case.fill")
                        Text("Open Full Exposure Intake Checklist")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(Palette.ochre)
                }
            }
        }
        .padding(12)
        .background(Palette.rust.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rust.opacity(0.4), lineWidth: 1))
    }

    private func quickChip(_ text: String) -> some View {
        Button {
            submitNaturalistQuery(text)
        } label: {
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Palette.moss.opacity(0.25), in: Capsule())
                .foregroundStyle(Palette.parchment)
        }
        .buttonStyle(.plain)
    }

    private func isMedicalOrEmergencyQuery(_ query: String) -> Bool {
        let lower = query.lowercased()

        let biteTerms = ["bit", "bite", "bitten", "biting", "stung", "sting", "stings", "stinging", "fang", "fangs", "puncture", "nip", "nipped"]
        let symptomTerms = ["symptom", "symptoms", "swelling", "swollen", "swell", "pain", "painful", "hurt", "hurts", "hurting", "ache", "aching", "necrosis", "necrotic", "rot", "rotting", "fever", "cramp", "cramps", "cramping", "spasm", "spasms", "nausea", "vomit", "vomiting", "dizzy", "dizziness", "itch", "itching", "itchy", "rash", "redness", "blister", "blisters", "wound", "pus", "infection", "infected", "hives", "allergic", "allergy", "anaphylaxis"]
        let treatmentTerms = ["treatment", "treat", "treating", "cure", "curing", "remedy", "antivenom", "antidote", "first aid", "doctor", "hospital", "ambulance", "urgent care", "emergency room", "er", "911", "poison control", "call doctor"]
        let medicationTerms = ["dose", "dosage", "medication", "medicine", "pill", "pills", "ointment", "cream", "ice", "tourniquet", "benadryl", "aspirin", "ibuprofen", "tylenol", "antihistamine", "prednisone", "epipen", "antibiotic"]
        let ingestionTerms = ["ate", "eaten", "eat", "eating", "swallow", "swallowed", "swallowing", "ingest", "ingested", "ingesting", "chew", "chewed", "in mouth", "poisoned", "poisoning", "toxic reaction"]

        let allCategories = [biteTerms, symptomTerms, treatmentTerms, medicationTerms, ingestionTerms]

        for category in allCategories {
            for term in category {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
                    return true
                }
            }
        }

        let phrasePatterns = [
            "what do i do if",
            "what should i do if",
            "what to do if",
            "is my dog going to die",
            "is my cat going to die",
            "is my child going to",
            "call 911",
            "need a doctor",
            "how to treat"
        ]
        for phrase in phrasePatterns {
            if lower.contains(phrase) {
                return true
            }
        }

        return false
    }

    private func submitNaturalistQuery(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !isNaturalistThinking else { return }

        // Change 1: Deterministic Swift filter before the model.
        // If the query touches symptoms, bites, treatments, or dosages,
        // do NOT call the model at all — display the unbypassable Poison Control card.
        if isMedicalOrEmergencyQuery(q) {
            interceptedMedicalQuery = true
            naturalistAnswer = ""
            naturalistQuery = ""
            return
        }

        interceptedMedicalQuery = false
        isNaturalistThinking = true
        naturalistAnswer = ""

        Task {
            defer { isNaturalistThinking = false }
            #if canImport(FoundationModels)
            if #available(iOS 27.0, *) {
                do {
                    let fieldNotesSummary = entry.displayFieldNotes.isEmpty ? "None recorded" : entry.displayFieldNotes.joined(separator: "; ")
                    let nextStepText = entry.nextStep.isEmpty ? "None provided" : entry.nextStep
                    let locationContext = entry.placeName != nil ? "\nObservation region: \(entry.placeName!)" : ""

                    let instructions = """
                    You are FloraFang's on-device field naturalist assistant. You are strictly grounded in this specific saved field log entry.

                    LOGGED OBSERVATION CONTEXT:
                    - Group: "\(entry.displayTitle)" (Category: \(entry.categoryKey))
                    - Recorded field markings: \(fieldNotesSummary)
                    - Retake & photo guidance: "\(nextStepText)"\(locationContext)

                    STRICT OPERATIONAL RULES:
                    1. NEVER RE-EVALUATE OR RESTATE A HAZARD VERDICT: The hazard assessment was computed exclusively by the app's deterministic confidence gate above. You must NEVER declare this organism "safe", "harmless", "dangerous", "deadly", or "not medically significant". If the user asks if this organism can hurt them, is venomous/poisonous, or is safe, instruct them: "Please refer to the hazard assessment banner at the top of this entry. FloraFang's chat does not render safety verdicts."
                    2. NO MEDICAL ADVICE: Never answer questions about bites, stings, symptoms, treatments, medications, or first aid. If asked about exposure, direct the user to tap 'Exposure Protocol' or call Poison Control (1-800-222-1222).
                    3. STRICTLY GROUNDED: Answer only regarding:
                       - What visible physical markings were recorded in this scan.
                       - Recommended photographic angles and lighting to improve identification on retakes.
                       - Typical natural habitats and seasonal patterns for this group.
                       - Safe, non-contact relocation techniques (e.g. cup-and-cardboard).
                       Do NOT engage in open-ended zoological speculation or claim species-level identification beyond the group noted above.
                    4. Answer concisely in 1-2 calm, factual paragraphs.
                    """
                    let session = LanguageModelSession(
                        model: SystemLanguageModel.default,
                        instructions: Instructions(instructions)
                    )

                    let prompt: Prompt
                    if let data = entry.imageData, let img = UIImage(data: data), let cg = img.cgImage {
                        prompt = Prompt {
                            q
                            Attachment(cg)
                        }
                    } else {
                        prompt = Prompt {
                            q
                        }
                    }

                    let response = try await session.respond(to: prompt)
                    await MainActor.run {
                        self.naturalistAnswer = response.content
                        self.naturalistQuery = ""
                    }
                    return
                } catch {
                    await MainActor.run {
                        self.naturalistAnswer = "On-device query unavailable: \(error.localizedDescription)"
                    }
                    return
                }
            }
            #endif
            await MainActor.run {
                self.naturalistAnswer = "Apple Intelligence Foundation Models require an iOS 27 compatible device."
            }
        }
    }

    /// The most valuable thing a tester can do, so it sits above the fold of
    /// the metadata rather than buried at the bottom.
    private var verdictSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WAS THIS RIGHT?")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.lichen)

            Text("Only you know what it actually was. Marking this is what lets the app learn where it is overconfident.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.lichen.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(Verdict.allCases) { option in
                    Button {
                        entry.verdict = (entry.verdict == option) ? nil : option
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 16))
                            Text(option.label)
                                .font(.system(size: 10))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            (entry.verdict == option ? verdictTint(option) : Palette.moss.opacity(0.15)),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(
                            entry.verdict == option ? Palette.parchment : Palette.lichen
                        )
                    }
                }
            }

            if entry.verdict == .wrong {
                VStack(alignment: .leading, spacing: 5) {
                    Text("What was it actually?")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.lichen)
                    TextField("wolf spider, oleander, a rock…", text: $entry.actualIdentity)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.parchment)
                        .padding(9)
                        .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                    Text("A guess is fine. If you had it identified by someone, say so.")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.lichen.opacity(0.7))
                }
            }
        }
        .padding(.top, 4)
    }

    private func verdictTint(_ v: Verdict) -> Color {
        switch v {
        case .correct: return Palette.moss
        case .wrong:   return Palette.rust
        case .unsure:  return Palette.lichen.opacity(0.5)
        }
    }

    /// Collapsed by default. This is a developer and tester affordance, not
    /// something a normal user needs, but it is the only explanation of why
    /// a scan came out the way it did and it has to survive the result screen.
    @State private var showTrace = false

    @ViewBuilder
    private var traceSection: some View {
        if !entry.traceLines.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Button {
                    withAnimation { showTrace.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showTrace ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                        Text("cascade trace")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(Palette.lichen.opacity(0.7))
                }

                if showTrace {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(entry.traceLines, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Palette.lichen.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.top, 4)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.capturedAt.formatted(date: .long, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(Palette.lichen)
            Text("classifier label: \(entry.rawLabel)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.lichen.opacity(0.6))
        }
        .padding(.top, 4)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Text("Delete entry")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(Palette.rust)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Palette.rust.opacity(0.5), lineWidth: 1)
                )
        }
        .padding(.top, 8)
    }
}

// MARK: - Full-screen zoomable photo

struct ZoomableImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value.magnification, 1), 6)
                        }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.25)) {
                        scale = scale > 1 ? 1 : 3
                        lastScale = scale
                    }
                }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .padding(18)
                }
                Spacer()
            }
        }
    }
}
