//
//  EmergencyScreen.swift
//  FloraFang
//
//  The "something ate this" flow.
//
//  DESIGN RULE, NON NEGOTIABLE: this screen has no safe outcome. There is no
//  path through it that tells someone not to worry. It routes to poison
//  control and helps them make that call well. It never answers the question
//  "is my dog going to be okay," because a wrong reassurance here is the
//  worst thing this app could produce.
//
//  Consequences of that rule, visible below:
//    - Hotline buttons render FIRST and stay pinned. Not behind a result,
//      not after a spinner. Three seconds of inference is three seconds not
//      spent dialing.
//    - The classifier result is framed as "tell them this", never as a
//      verdict.
//    - notKnownToxic escalates. It does not reassure.
//    - No confidence percentage is shown to the user. It reads as a
//      probability of safety, which is not what it is.
//

import SwiftUI

struct EmergencyScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var report = ExposureReport()
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var isClassifying = false
    @State private var classifierFailed = false
    @State private var showCopied = false

    private let classifier = PlantClassifier()

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        urgencyBanner
                        hotlines
                        Divider().overlay(Palette.moss.opacity(0.4))
                        photoSection
                        if report.suspectedPlant != nil || classifierFailed {
                            matchSection
                        }
                        intakeSection
                        relaySection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Exposure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Palette.lichen)
                }
            }
        }
    }

    // MARK: - Above the fold

    private var urgencyBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CALL FIRST")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Palette.rust)
            Text("Do not wait on this app. Poison control can start helping while you fill in the details below.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.rust.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rust.opacity(0.6), lineWidth: 1))
    }

    private var hotlines: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Who", selection: $report.subject) {
                ForEach(ExposureSubject.allCases) { subject in
                    Text(subject.label).tag(subject)
                }
            }
            .pickerStyle(.segmented)

            ForEach(PoisonResources.forAudience(report.subject.audience)) { resource in
                Link(destination: resource.telURL ?? URL(string: "tel://")!) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 15))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(resource.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text(resource.phone)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(resource.detail)
                                .font(.system(size: 10))
                                .opacity(0.8)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Palette.parchment)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.rust, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Text("US numbers. If you are outside the US, contact your local poison center or an emergency vet.")
                .font(.system(size: 10))
                .foregroundStyle(Palette.lichen)
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("THE PLANT")

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                showCamera = true
            } label: {
                Label(image == nil ? "Photograph the plant" : "Retake photo",
                      systemImage: "camera")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Palette.parchment)
            }

            Text("If you can do it safely, keep a cutting of the plant. The vet may want to see it.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.lichen)

            if isClassifying {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small).tint(Palette.ochre)
                    Text("checking against known toxic plants")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.lichen)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            EmergencyCaptureSheet { captured in
                image = captured
                showCamera = false
                classify(captured)
            }
        }
    }

    // MARK: - Match

    /// Framed as information to relay. Never as a conclusion, and never with
    /// a confidence number attached.
    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("TELL THEM THIS")

            if let plant = report.suspectedPlant, plant != .notKnownToxic {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Possible match: \(plant.displayName)")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.parchment)
                    if !plant.scientificName.isEmpty {
                        Text(plant.scientificName)
                            .font(.system(size: 12))
                            .italic()
                            .foregroundStyle(Palette.lichen)
                    }
                    Text("This is an unconfirmed photo match, not an identification. Say it as a possibility, not a fact.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.lichen)
                        .fixedSize(horizontal: false, vertical: true)

                    if let petNote = plant.petNote, report.subject.isAnimal {
                        Text(petNote)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.rust)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.rust.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rust.opacity(0.5), lineWidth: 1))
            } else {
                // The escalation path. Unknown never reassures.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Not identified")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.parchment)
                    Text("FloraFang could not match this to a plant it knows. That is not the same as safe. Most toxic plants are not on its list. Call poison control and describe the plant, or bring a cutting.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.parchment.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.ochre.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.ochre.opacity(0.5), lineWidth: 1))
            }
        }
    }

    // MARK: - Intake

    private var intakeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("THEY WILL ASK")

            field("Weight and age", text: $report.subjectDetail,
                  placeholder: report.subject.isAnimal ? "60 lb lab, 4 years" : "45 lbs, 5 years old")

            VStack(alignment: .leading, spacing: 5) {
                smallLabel("What part")
                Picker("Part", selection: $report.partEaten) {
                    ForEach(ExposureReport.PlantPart.allCases) { part in
                        Text(part.label).tag(part)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.ochre)
            }

            field("How much", text: $report.amount, placeholder: "a few leaves, one seed, unknown")

            VStack(alignment: .leading, spacing: 5) {
                smallLabel("When")
                DatePicker("", selection: $report.timeOfExposure,
                           in: ...Date.now, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .tint(Palette.ochre)
            }

            VStack(alignment: .leading, spacing: 5) {
                smallLabel("Any signs yet")
                ForEach(ExposureReport.Symptom.allCases) { symptom in
                    Button {
                        if report.symptoms.contains(symptom) {
                            report.symptoms.remove(symptom)
                        } else {
                            report.symptoms.insert(symptom)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: report.symptoms.contains(symptom)
                                  ? "checkmark.square.fill" : "square")
                                .foregroundStyle(report.symptoms.contains(symptom)
                                                 ? Palette.ochre : Palette.lichen)
                            Text(symptom.label)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.parchment)
                            Spacer()
                        }
                    }
                }
            }

            field("Anything else", text: $report.otherNotes, placeholder: "optional")
        }
    }

    // MARK: - Relay

    private var relaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("READ THIS TO THEM")

            Text(report.relaySummary())
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))

            Button {
                UIPasteboard.general.string = report.relaySummary()
                showCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showCopied = false
                }
            } label: {
                Label(showCopied ? "Copied" : "Copy summary", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Palette.parchment)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Palette.lichen)
    }

    private func smallLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.lichen)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            smallLabel(label)
            TextField(placeholder, text: text)
                .font(.system(size: 13))
                .foregroundStyle(Palette.parchment)
                .padding(9)
                .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    // MARK: - Classification

    private func classify(_ image: UIImage) {
        isClassifying = true
        classifierFailed = false
        Task {
            defer { isClassifying = false }
            do {
                if let prediction = try await classifier.classify(image) {
                    report.suspectedPlant = prediction.plantClass
                    report.rawLabel = prediction.rawLabel
                    report.confidence = prediction.confidence
                } else {
                    report.suspectedPlant = nil
                    classifierFailed = true
                }
            } catch {
                report.suspectedPlant = nil
                classifierFailed = true
            }
        }
    }
}

/// Minimal capture wrapper so the emergency flow does not depend on the main
/// camera screen's cascade, zoom, or capture frame framing. Fewer moving parts in
/// the path that matters most.
struct EmergencyCaptureSheet: View {
    let onCapture: (UIImage) -> Void

    @State private var camera = CameraService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if case .ready = camera.state {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                        .padding()
                    Spacer()
                }
                Spacer()
                Button {
                    Task {
                        if let image = try? await camera.capturePhoto() {
                            onCapture(image)
                        }
                    }
                } label: {
                    Circle()
                        .fill(Palette.ochre)
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76))
                }
                .padding(.bottom, 34)
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }
}
