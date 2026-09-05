//
//  EmergencyScreen.swift
//  FloraFang
//
//  The "something ate this" flow.
//
//  DESIGN RULES:
//    - Hotline buttons render FIRST and stay pinned. Three seconds of inference
//      is three seconds not spent dialing.
//    - Urgency banner is always visible.
//    - The intake form only reveals AFTER selecting who was exposed (Person or Pet).
//    - Records of exposures are persisted to SwiftData so users can review, share,
//      or clear data without stale emergency details cluttering a new incident.
//

import SwiftUI
import SwiftData

struct EmergencyScreen: View {
    /// Set when opened from a result screen that already identified something
    /// dangerous, so the user does not rephotograph a plant the app just saw.
    var prefilledPlant: PlantClass? = nil
    var prefilledImage: UIImage? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExposureIncident.timestamp, order: .reverse) private var pastIncidents: [ExposureIncident]

    @State private var selectedSubject: ExposureSubject? = nil
    @State private var report = ExposureReport()
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var isClassifying = false
    @State private var classifierFailed = false
    @State private var showCopied = false
    @State private var didPrefill = false
    @State private var showHistory = false
    @State private var showSavedToast = false
    @State private var confirmClear = false

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
                        subjectSelector

                        if selectedSubject != nil {
                            intakeForm
                        } else {
                            unselectedPlaceholder
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 44)
                }

                if showSavedToast {
                    savedToast
                }
            }
            .navigationTitle("Exposure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .onAppear {
                guard !didPrefill else { return }
                didPrefill = true
                if let plant = prefilledPlant {
                    report.suspectedPlant = plant
                    report.rawLabel = plant.trainingLabel
                    selectedSubject = .dog // default for prefilled ingestion if unset
                }
                if let img = prefilledImage {
                    image = img
                    if selectedSubject == nil { selectedSubject = .dog }
                }
            }
            .toolbar {
                // Only provide a close/done button when opened as a modal sheet
                if prefilledPlant != nil || prefilledImage != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.parchment)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 15))
                            if !pastIncidents.isEmpty {
                                Text("\(pastIncidents.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Palette.moss, in: Capsule())
                                    .foregroundStyle(Palette.parchment)
                            }
                        }
                        .foregroundStyle(Palette.parchment)
                    }
                    .accessibilityLabel("Incident history")
                }
            }
            .sheet(isPresented: $showHistory) {
                ExposureHistoryView()
            }
            .confirmationDialog("Start a new report?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear and Start Fresh", role: .destructive) {
                    withAnimation {
                        clearForm()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear the current intake form. Any saved records in Incident History remain safe.")
            }
        }
    }

    // MARK: - Above the fold: Urgency Banner

    private var urgencyBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.rust)
                Text("CALL FIRST")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Palette.rust)
            }
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

    // MARK: - Emergency Hotlines (Always Visible)

    private var hotlines: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("EMERGENCY DISPATCH HOTLINES")

            // Human Poison Control
            Link(destination: URL(string: "tel://18002221222")!) {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("Poison Control (People)")
                                .font(.system(size: 13.5, weight: .semibold))
                            Spacer()
                            Text("Free · 24/7")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Palette.parchment.opacity(0.75))
                        }
                        Text("1-800-222-1222")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(Palette.parchment)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.rust, in: RoundedRectangle(cornerRadius: 8))
            }

            // Animal Poison Control
            Link(destination: URL(string: "tel://8884264435")!) {
                HStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 15))
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("ASPCA Animal Poison Control")
                                .font(.system(size: 13.5, weight: .semibold))
                            Spacer()
                            Text("Pet Hotline")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Palette.parchment.opacity(0.75))
                        }
                        Text("(888) 426-4435")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(Palette.parchment)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
            }

            Text("US numbers. If you are outside the US, contact your local poison center or emergency vet.")
                .font(.system(size: 10))
                .foregroundStyle(Palette.lichen)
        }
    }

    // MARK: - Subject Selector

    private var subjectSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("WHO WAS EXPOSED?")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExposureSubject.allCases) { subject in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSubject = subject
                                report.subject = subject
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: subjectIcon(subject))
                                    .font(.system(size: 13))
                                Text(subject.label)
                                    .font(.system(size: 12.5, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                selectedSubject == subject ? Palette.moss : Color.black.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedSubject == subject ? Palette.parchment : Palette.lichen.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundStyle(selectedSubject == subject ? Palette.parchment : Palette.lichen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Unselected Placeholder

    private var unselectedPlaceholder: some View {
        VStack(spacing: 8) {
            Text("Select who was exposed above to start an intake checklist.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.parchment)
                .multilineTextAlignment(.center)

            Text("Having age, timing, and symptoms ready helps the poison specialist give you fast, accurate care.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if !pastIncidents.isEmpty {
                Button {
                    showHistory = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("View Past Incident Records (\(pastIncidents.count))")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ochre)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Palette.lichen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Intake Form (Reveals upon subject selection)

    private var intakeForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            photoSection

            if report.suspectedPlant != nil || classifierFailed {
                matchSection
            }

            intakeSection
            relaySection
            incidentActionsSection
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PHOTO OF WHAT WAS EATEN")

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
                Label(image == nil ? "Take a Photo" : "Retake Photo",
                      systemImage: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Palette.parchment)
            }

            Text("If you can do it safely, keep a cutting or physical sample. The vet or doctor may want to see it.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.lichen)

            if isClassifying {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small).tint(Palette.ochre)
                    Text("checking against known toxic plants…")
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

    // MARK: - Match Section

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

    // MARK: - Intake Questions

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

            field("Anything else", text: $report.otherNotes, placeholder: "optional details")
        }
    }

    // MARK: - Relay Section

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

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = report.relaySummary()
                    showCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showCopied = false
                    }
                } label: {
                    Label(showCopied ? "Copied" : "Copy summary", systemImage: "doc.on.clipboard")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Palette.parchment)
                }

                ShareLink(item: report.relaySummary()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Palette.parchment)
                }
            }
        }
    }

    // MARK: - Incident Actions (Save / Clear)

    private var incidentActionsSection: some View {
        VStack(spacing: 10) {
            // Save to Incident Log
            Button(action: saveIncident) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save to Incident Log")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Palette.ochre, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.black)
            }

            // Start New Report / Clear
            Button {
                confirmClear = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Start New Report")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(Palette.lichen)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.lichen.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Toast Banner

    private var savedToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.moss)
                Text("Incident saved to history log")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.parchment)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.85), in: Capsule())
            .overlay(Capsule().stroke(Palette.moss.opacity(0.6), lineWidth: 1))
            .padding(.bottom, 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showSavedToast)
    }

    // MARK: - Logic & Actions

    private func saveIncident() {
        let incident = ExposureIncident(
            subjectRaw: report.subject.rawValue,
            subjectDetail: report.subjectDetail,
            plantName: report.suspectedPlant?.displayName ?? (report.rawLabel.isEmpty ? "" : report.rawLabel),
            scientificName: report.suspectedPlant?.scientificName ?? "",
            rawLabel: report.rawLabel,
            confidence: report.confidence,
            partEatenRaw: report.partEaten.rawValue,
            amount: report.amount,
            timeOfExposure: report.timeOfExposure,
            symptomsRaw: report.symptoms.map(\.label),
            otherNotes: report.otherNotes,
            relaySummaryText: report.relaySummary(),
            imageData: image?.jpegData(compressionQuality: 0.8)
        )

        modelContext.insert(incident)
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            showSavedToast = false
        }
    }

    private func clearForm() {
        selectedSubject = nil
        report = ExposureReport()
        image = nil
        classifierFailed = false
        isClassifying = false
    }

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

    private func subjectIcon(_ subject: ExposureSubject) -> String {
        switch subject {
        case .dog:         return "pawprint.fill"
        case .cat:         return "pawprint"
        case .otherAnimal: return "hare.fill"
        case .child:       return "figure.and.child.holdinghands"
        case .adult:       return "person.fill"
        }
    }

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
}

// MARK: - Capture Sheet

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
