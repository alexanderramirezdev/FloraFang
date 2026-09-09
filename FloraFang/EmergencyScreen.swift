//
//  EmergencyScreen.swift
//  FloraFang
//
//  The "something ate this" flow.
//
//  DESIGN RULES:
//    * Hotline buttons render FIRST and stay pinned. Three seconds of inference
//      is three seconds not spent dialing.
//    * Urgency banner is always visible.
//    * The intake form only reveals AFTER selecting who was exposed (Person or Pet).
//    * Records of exposures are persisted to SwiftData so users can review, share,
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
    @State private var showSavedToast = false
    @State private var confirmClear = false

    private enum Field: Hashable {
        case subjectDetail
        case amount
        case otherNotes
    }
    @FocusState private var focusedField: Field?

    private let classifier = PlantClassifier()

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        urgencyBanner
                        hotlines
                        Divider().overlay(Palette.moss.opacity(0.3))
                        subjectSelector

                        if selectedSubject != nil {
                            intakeForm
                        } else {
                            unselectedPlaceholder
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

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
                    report.hasPhoto = true
                    if selectedSubject == nil { selectedSubject = .dog }
                }
            }
            .onChange(of: image) { _, newImg in
                report.hasPhoto = (newImg != nil)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ochre)
                }

                // Only provide a close/done button when opened as a modal sheet
                if prefilledPlant != nil || prefilledImage != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.parchment)
                    }
                }
            }
            .confirmationDialog("Start a new report?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear and Start Fresh", role: .destructive) {
                    withAnimation {
                        clearForm()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear the current intake form. Any saved records in the Log tab remain safe.")
            }
        }
    }

    // MARK: Above the fold: Urgency Banner

    private var urgencyBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text("CALL FIRST")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
            }
            Text("Do not wait on this app. Poison control can start helping while you fill in the details below.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.82, green: 0.16, blue: 0.14), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Emergency Hotlines (Subject Sensitive)

    private var hotlines: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(selectedSubject == nil ? "EMERGENCY DISPATCH HOTLINES" : "EMERGENCY DISPATCH HOTLINE")

            if let subject = selectedSubject {
                if subject.isAnimal {
                    aspcaHotline
                    petPoisonHelpline
                } else {
                    humanHotline
                }
            } else {
                aspcaHotline
                petPoisonHelpline
                humanHotline
            }

            Text("US numbers. If you are outside the US, contact your local poison center or emergency vet.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.lichen)
        }
    }

    private var humanHotline: some View {
        Link(destination: URL(string: "tel://18002221222")!) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Poison Control (Human)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Free · 24/7")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22), in: Capsule())
                    }
                    Text("(800) 222 1222")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.80, green: 0.14, blue: 0.14), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var aspcaHotline: some View {
        Link(destination: URL(string: "tel://8884264435")!) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("ASPCA Animal Poison Control")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("ASPCA · 24/7")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22), in: Capsule())
                    }
                    Text("(888) 426 4435")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.80, green: 0.14, blue: 0.14), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var petPoisonHelpline: some View {
        Link(destination: URL(string: "tel://8557647661")!) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: "cross.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Pet Poison Helpline")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Helpline · 24/7")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22), in: Capsule())
                    }
                    Text("(855) 764 7661")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.80, green: 0.14, blue: 0.14), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Subject Selector

    private var subjectSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("WHO WAS EXPOSED?")

            VStack(spacing: 8) {
                // Row 1: Animals (Dog, Cat, Other)
                HStack(spacing: 8) {
                    subjectChip(.dog)
                    subjectChip(.cat)
                    subjectChip(.otherAnimal)
                }

                // Row 2: Humans (Child, Adult)
                HStack(spacing: 8) {
                    subjectChip(.child)
                    subjectChip(.adult)
                }
            }
        }
    }

    private func subjectChip(_ subject: ExposureSubject) -> some View {
        let isSelected = (selectedSubject == subject)
        return Button {
            focusedField = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSubject = subject
                report.subject = subject
            }
        } label: {
            HStack(spacing: 6) {
                subjectIconView(subject, size: 14)
                Text(subject.label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isSelected ? Palette.ochre : Palette.surface,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Palette.ochre : Palette.moss.opacity(0.35), lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? Color.black : Palette.parchment)
        }
        .buttonStyle(.plain)
    }

    // MARK: Unselected Placeholder

    private var unselectedPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 24))
                .foregroundStyle(Palette.ochre)

            Text("Select who was exposed above to start an intake checklist.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.parchment)
                .multilineTextAlignment(.center)

            Text("Having age, timing, and symptoms ready helps the poison specialist give you fast, accurate care.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.moss.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: Intake Form (Reveals upon subject selection)

    private var intakeForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            if (selectedSubject ?? report.subject) == .cat {
                catAdvisory
            }

            photoSection

            if report.suspectedPlant != nil || classifierFailed {
                matchSection
            }

            intakeSection
            relaySection
            incidentActionsSection
        }
    }

    // MARK: Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PHOTO OF WHAT WAS EATEN")

            if let image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        self.image = nil
                        self.report.hasPhoto = false
                        if self.report.suspectedPlant != nil && self.prefilledPlant == nil {
                            self.report.suspectedPlant = nil
                            self.report.rawLabel = ""
                            self.report.confidence = 0
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.75))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo")
                }
            }

            Button {
                focusedField = nil
                showCamera = true
            } label: {
                Label(image == nil ? "Take a Photo" : "Retake Photo",
                      systemImage: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Palette.moss.opacity(0.6), lineWidth: 1.2)
                    )
                    .foregroundStyle(Palette.parchment)
            }

            Text("If you can do it safely, keep a cutting or physical sample. The vet or doctor may want to see it.")
                .font(.system(size: 12))
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
                report.hasPhoto = true
                showCamera = false
                classify(captured)
            }
        }
    }

    // MARK: Match Section

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("TELL THEM THIS")

            if let plant = report.suspectedPlant, plant != .notKnownToxic {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Possible match: \(plant.displayName)")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.parchment)
                    if !plant.scientificName.isEmpty {
                        Text(plant.scientificName)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(Palette.lichen)
                    }
                    Text("This is an unconfirmed photo match, not an identification. Say it as a possibility, not a fact.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.lichen)
                        .fixedSize(horizontal: false, vertical: true)

                    if let petNote = plant.petNote, report.subject.isAnimal {
                        Text(petNote)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.rust)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.rust.opacity(0.8), lineWidth: 1.5))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Not identified")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.parchment)
                    Text("FloraFang could not match this to a plant it knows. That is not the same as safe. Most toxic plants are not on its list. Call poison control and describe the plant, or bring a cutting.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.ochre.opacity(0.8), lineWidth: 1.5))
            }
        }
    }

    // MARK: Intake Questions

    private var intakeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("THEY WILL ASK")

            field("Weight and age", text: $report.subjectDetail,
                  placeholder: (selectedSubject ?? report.subject).placeholderDetail,
                  field: .subjectDetail)

            VStack(alignment: .leading, spacing: 6) {
                smallLabel("What part")
                Picker("Part", selection: $report.partEaten) {
                    ForEach(ExposureReport.PlantPart.allCases) { part in
                        Text(part.label).tag(part)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.ochre)
                .onChange(of: report.partEaten) { _, _ in
                    focusedField = nil
                }
            }

            field("How much", text: $report.amount, placeholder: "a few leaves, one seed, unknown",
                  field: .amount)

            VStack(alignment: .leading, spacing: 6) {
                smallLabel("When")
                DatePicker("", selection: exposureTimeBinding, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .tint(Palette.ochre)
                    .onChange(of: report.timeOfExposure) { _, _ in
                        focusedField = nil
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                smallLabel("Any signs yet")
                VStack(spacing: 6) {
                    ForEach(ExposureReport.Symptom.allCases) { symptom in
                        let isChecked = report.symptoms.contains(symptom)
                        Button {
                            focusedField = nil
                            if isChecked {
                                report.symptoms.remove(symptom)
                            } else {
                                report.symptoms.insert(symptom)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isChecked ? Palette.ochre : Palette.lichen)
                                Text(symptom.label)
                                    .font(.system(size: 13.5, weight: isChecked ? .semibold : .regular))
                                    .foregroundStyle(Palette.parchment)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                isChecked ? Palette.surface : Palette.surface.opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isChecked ? Palette.ochre.opacity(0.6) : Palette.moss.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            field("Anything else", text: $report.otherNotes, placeholder: "optional details",
                  field: .otherNotes)
        }
    }

    // MARK: Relay Section

    private var relaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("READ THIS TO THEM")

            Text(report.relaySummary())
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(3)
                .foregroundStyle(Palette.parchment)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Palette.moss.opacity(0.5), lineWidth: 1.2)
                )

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
                        .font(.system(size: 13.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Palette.parchment)
                }

                ShareLink(item: report.relaySummary()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13.5, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Palette.moss.opacity(0.5), lineWidth: 1)
                        )
                        .foregroundStyle(Palette.parchment)
                }
            }
        }
    }

    // MARK: Incident Actions (Save / Clear)

    private var incidentActionsSection: some View {
        VStack(spacing: 10) {
            // Save to Incident Log
            Button(action: saveIncident) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save to Incident Log")
                }
                .font(.system(size: 14, weight: .bold))
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
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.lichen.opacity(0.4), lineWidth: 1))
                .foregroundStyle(Palette.parchment.opacity(0.9))
            }
        }
        .padding(.top, 8)
    }

    // MARK: Toast Banner

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

    // MARK: Logic & Actions

    private var exposureTimeBinding: Binding<Date> {
        Binding(
            get: { report.timeOfExposure },
            set: { newDate in
                let calendar = Calendar.current
                let now = Date.now
                let timeComponents = calendar.dateComponents([.hour, .minute], from: newDate)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.second = 0

                if let combined = calendar.date(from: dateComponents) {
                    if combined > now {
                        report.timeOfExposure = now
                    } else {
                        report.timeOfExposure = combined
                    }
                } else {
                    report.timeOfExposure = newDate
                }
            }
        )
    }

    private func saveIncident() {
        focusedField = nil
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
        report.hasPhoto = false
        image = nil
        classifierFailed = false
        isClassifying = false
        focusedField = nil
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

    private var catAdvisory: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("CRITICAL CAT ALERT: TRUE LILIES")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(.white)
                Text("All parts of true lilies (Lilium and Hemerocallis / daylilies) are fatal to cats, causing rapid kidney failure. Even licking pollen off fur or drinking vase water requires immediate veterinary intervention.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.80, green: 0.14, blue: 0.14), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func subjectIconView(_ subject: ExposureSubject, size: CGFloat = 13) -> some View {
        if subject == .otherAnimal {
            Image("raccoon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size + 1, height: size + 1)
        } else {
            Image(systemName: subjectIcon(subject))
                .font(.system(size: size))
        }
    }

    private func subjectIcon(_ subject: ExposureSubject) -> String {
        switch subject {
        case .dog:         return "dog.fill"
        case .cat:         return "cat.fill"
        case .otherAnimal: return "pawprint"
        case .child:       return "figure.and.child.holdinghands"
        case .adult:       return "person.fill"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Palette.ochre)
    }

    private func smallLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.parchment.opacity(0.95))
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            smallLabel(label)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .font(.system(size: 14))
                .foregroundStyle(Palette.parchment)
                .padding(11)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == field ? Palette.ochre : Palette.moss.opacity(0.35), lineWidth: 1)
                )
        }
    }
}

// MARK: Capture Sheet

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
