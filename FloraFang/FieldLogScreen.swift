//
//  FieldLogScreen.swift
//  FloraFang
//

import SwiftUI
import SwiftData

enum LogFilter: String, CaseIterable, Identifiable {
    case all
    case flagged
    case unresolved
    case unmarked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:        return "All"
        case .flagged:    return "Flagged"
        case .unresolved: return "Unresolved"
        case .unmarked:   return "Not marked"
        }
    }

    var systemImage: String {
        switch self {
        case .all:        return "square.stack"
        case .flagged:    return "exclamationmark.triangle"
        case .unresolved: return "questionmark.circle"
        case .unmarked:   return "circle.dashed"
        }
    }

    func matches(_ entry: FieldEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .flagged:
            return entry.hazard == .avoid
        case .unresolved:
            return entry.wasRefusal || entry.hazard == .unknown
        case .unmarked:
            return entry.verdict == nil
        }
    }
}

enum LogSection: String, CaseIterable, Identifiable {
    case field = "Field Log"
    case exposure = "Exposure Log"

    var id: String { rawValue }
}

struct FieldLogScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FieldEntry.capturedAt, order: .reverse)
    private var entries: [FieldEntry]

    @Query(sort: \ExposureIncident.timestamp, order: .reverse)
    private var incidents: [ExposureIncident]

    @AppStorage("app_season_setting") private var seasonSetting = "auto"

    @State private var selectedSection: LogSection = .field
    @State private var location = LocationService()
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showSettings = false
    @State private var showExportConfirm = false
    @State private var selectedIncident: ExposureIncident?
    @State private var incidentToDelete: ExposureIncident?
    @State private var filter: LogFilter = .all
    @State private var isSelectingIncidents = false
    @State private var selectedIncidentIDs: Set<UUID> = []

    private var visibleEntries: [FieldEntry] {
        entries.filter { filter.matches($0) }
    }

    private func count(for filter: LogFilter) -> Int {
        entries.filter { filter.matches($0) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()
                SeasonalAtmosphereView().ignoresSafeArea()

                VStack(spacing: 0) {
                    sectionSwitcher

                    if selectedSection == .field {
                        fieldLogContent
                    } else {
                        exposureLogContent
                    }
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                if isSelectingIncidents {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            withAnimation {
                                isSelectingIncidents = false
                                selectedIncidentIDs.removeAll()
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.parchment)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if selectedSection == .field {
                            Button {
                                showExportConfirm = true
                            } label: {
                                Label("Export field log", systemImage: "square.and.arrow.up")
                            }
                            .disabled(entries.isEmpty)
                        } else {
                            if !isSelectingIncidents {
                                Button {
                                    withAnimation {
                                        isSelectingIncidents = true
                                        selectedIncidentIDs.removeAll()
                                    }
                                } label: {
                                    Label("Select reports to export", systemImage: "checklist")
                                }
                                .disabled(incidents.isEmpty)

                                Button {
                                    exportExposureReports(incidents)
                                } label: {
                                    Label("Export all exposure reports", systemImage: "square.and.arrow.up")
                                }
                                .disabled(incidents.isEmpty)
                            }
                        }

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.ochre)
                            .frame(width: 32, height: 32)
                    }
                    .transaction { $0.animation = nil }
                }
            }
            .sheet(item: $selectedIncident) { incident in
                ExposureIncidentDetailSheet(incident: incident)
            }
            .confirmationDialog("Delete this incident record?", isPresented: Binding(
                get: { incidentToDelete != nil },
                set: { if !$0 { incidentToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item = incidentToDelete {
                        modelContext.delete(item)
                        try? modelContext.save()
                        incidentToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { incidentToDelete = nil }
            }
            .sheet(isPresented: $showExportConfirm) {
                ExportConfirmSheet(summary: ExportSummary.of(entries)) {
                    exportLog()
                }
            }
            .sheet(item: Binding(
                get: { exportURL.map { ShareItem(url: $0) } },
                set: { if $0 == nil { exportURL = nil } }
            )) { item in
                ShareSheet(items: [item.url]) {
                    // Share sheet dismissed. Whether they sent it or not,
                    // the archive has no reason to stay on disk.
                    exportURL = nil
                    ExportService.cleanUpPreviousExports()
                }
            }
            .onDisappear {
                // Backstop: leaving the tab with an archive still staged
                // should not leave it sitting in temp indefinitely.
                if exportURL == nil {
                    Task(priority: .utility) {
                        ExportService.cleanUpPreviousExports()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(location: location, onDeleteAll: deleteAllData)
            }
            .alert("Export failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(LogSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                        if section == .field {
                            isSelectingIncidents = false
                            selectedIncidentIDs.removeAll()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section == .field ? "leaf.fill" : "cross.case.fill")
                            .font(.system(size: 11))
                        Text(section == .field ? "Field Log (\(entries.count))" : "Exposure Log (\(incidents.count))")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedSection == section ? Palette.surface : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedSection == section ? Palette.ochre.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(selectedSection == section ? Palette.parchment : Palette.lichen)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var fieldLogContent: some View {
        Group {
            if entries.isEmpty {
                fieldEmptyState
            } else {
                VStack(spacing: 0) {
                    fieldFilterChips

                    if visibleEntries.isEmpty {
                        filteredEmptyState
                    } else {
                        List {
                            ForEach(visibleEntries) { entry in
                                NavigationLink {
                                    EntryDetailScreen(entry: entry)
                                } label: {
                                    row(entry)
                                }
                                .listRowBackground(Palette.surface)
                                .listRowSeparatorTint(Palette.moss.opacity(0.3))
                            }
                            .onDelete(perform: deleteFieldEntries)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 90)
                        }
                    }
                }
            }
        }
    }

    private var fieldFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogFilter.allCases) { option in
                    let n = count(for: option)
                    let selected = filter == option

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { filter = option }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: option.systemImage)
                                .font(.system(size: 10))
                            Text(option.label)
                                .font(.system(size: 12))
                            if option != .all {
                                Text("\(n)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .opacity(0.75)
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            selected ? filterTint(for: option) : Palette.moss.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(selected ? Palette.parchment : Palette.lichen)
                    }
                    .disabled(n == 0 && option != .all)
                    .opacity(n == 0 && option != .all ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterTint(for option: LogFilter) -> Color {
        switch option {
        case .all:        return Palette.moss
        case .flagged:    return Palette.rust
        case .unresolved: return Palette.lichen.opacity(0.6)
        case .unmarked:   return Palette.ochre
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: filter.systemImage)
                .font(.system(size: 30))
                .foregroundStyle(Palette.moss)
            Text(emptyFilterMessage)
                .font(.system(size: 13))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var emptyFilterMessage: String {
        switch filter {
        case .all:        return "Nothing logged yet."
        case .flagged:    return "Nothing flagged. No scan has come back as do not handle."
        case .unresolved: return "Nothing unresolved. Every scan reached an answer."
        case .unmarked:   return "Everything is marked. That is the whole dataset usable for calibration."
        }
    }

    private var exposureLogContent: some View {
        Group {
            if incidents.isEmpty {
                exposureEmptyState
            } else {
                VStack(spacing: 0) {
                    List {
                        ForEach(incidents) { incident in
                            Button {
                                if isSelectingIncidents {
                                    toggleIncidentSelection(incident)
                                } else {
                                    selectedIncident = incident
                                }
                            } label: {
                                incidentRow(incident)
                            }
                            .listRowBackground(Palette.surface)
                            .listRowSeparatorTint(Palette.moss.opacity(0.3))
                            .swipeActions(edge: .leading) {
                                Button {
                                    exportExposureReports([incident])
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .tint(Palette.moss)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    incidentToDelete = incident
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)

                    if isSelectingIncidents {
                        selectionBottomBar
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: isSelectingIncidents ? 130 : 90)
                }
            }
        }
    }

    private var selectionBottomBar: some View {
        HStack {
            Button(selectedIncidentIDs.count == incidents.count ? "Deselect All" : "Select All") {
                withAnimation {
                    if selectedIncidentIDs.count == incidents.count {
                        selectedIncidentIDs.removeAll()
                    } else {
                        selectedIncidentIDs = Set(incidents.map(\.id))
                    }
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.lichen)

            Spacer()

            Button {
                let targets = incidents.filter { selectedIncidentIDs.contains($0.id) }
                exportExposureReports(targets)
            } label: {
                Label("Export Selected (\(selectedIncidentIDs.count))", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selectedIncidentIDs.isEmpty ? Palette.moss.opacity(0.3) : Palette.moss, in: Capsule())
                    .foregroundStyle(Palette.parchment)
            }
            .disabled(selectedIncidentIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Divider().overlay(Palette.moss.opacity(0.3)), alignment: .top)
    }

    private var fieldEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                CameraViewfinderMark(size: 68, bracketLength: 16, strokeWidth: 2.2)

                Image("app_mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Palette.moss)
            }

            Text("Nothing scanned yet")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
                .shadow(color: Palette.bark.opacity(0.8), radius: 4, x: 0, y: 1)

            Text("Every scan saves here automatically, with what the app said at the time. Mark whether it got things right and the app learns where it's overconfident.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.parchment.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 36)
                .shadow(color: Palette.bark.opacity(0.9), radius: 6, x: 0, y: 1)
            Spacer()
        }
        .offset(y: -30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var exposureEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(Palette.moss)
                .shadow(color: Palette.bark.opacity(0.8), radius: 4, x: 0, y: 1)

            Text("No exposure reports yet")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
                .shadow(color: Palette.bark.opacity(0.8), radius: 4, x: 0, y: 1)

            Text("When something gets eaten and you fill in the details on the Exposure tab, that report saves here. Useful for a follow up vet or doctor visit, when they ask what happened and when.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.parchment.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 36)
                .shadow(color: Palette.bark.opacity(0.9), radius: 6, x: 0, y: 1)
            Spacer()
        }
        .offset(y: -30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func incidentRow(_ incident: ExposureIncident) -> some View {
        let isSelected = selectedIncidentIDs.contains(incident.id)

        return HStack(alignment: .top, spacing: 12) {
            if isSelectingIncidents {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Palette.moss : Palette.lichen.opacity(0.6))
                    .padding(.top, 8)
            }

            ZStack {
                Circle()
                    .fill(Palette.moss.opacity(0.2))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(Palette.moss.opacity(0.5), lineWidth: 1))

                subjectIconView(incident.subject, size: 16)
                    .foregroundStyle(Palette.parchment)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(incident.displaySubject)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ochre)
                    if !incident.subjectDetail.isEmpty {
                        Text("(\(incident.subjectDetail))")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.lichen)
                    }
                    Spacer()
                    Text(incident.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.lichen.opacity(0.8))
                }

                Text(incident.displayPlant)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.parchment)

                if !incident.symptomsRaw.isEmpty {
                    Text("Signs: \(incident.symptomsRaw.joined(separator: ", "))")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.rust)
                        .lineLimit(1)
                } else {
                    Text("No immediate signs noted")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.lichen)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Palette.lichen.opacity(0.5))
                .padding(.top, 10)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func subjectIconView(_ subject: ExposureSubject, size: CGFloat = 13) -> some View {
        if subject == .otherAnimal {
            Image("raccoon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size + 2, height: size + 2)
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

    private func row(_ entry: FieldEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if let data = entry.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Palette.moss
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.parchment)
                    .lineLimit(2)
                Text(entry.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.lichen)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(Palette.lichen.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: entry.hazard.symbol)
                .font(.system(size: 13))
                .foregroundStyle(tint(for: entry.hazard))
        }
        .padding(.vertical, 3)
    }

    private func tint(for hazard: Hazard) -> Color {
        switch hazard {
        case .safe:    return Palette.safe
        case .caution: return Palette.warn
        case .avoid:   return Palette.danger
        case .unknown: return Palette.lichen
        }
    }

    private func deleteFieldEntries(at offsets: IndexSet) {
        let targets = offsets.map { visibleEntries[$0] }
        for entry in targets {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func exportLog() {
        do {
            exportURL = try ExportService.exportFieldLog(entries)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func toggleIncidentSelection(_ incident: ExposureIncident) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedIncidentIDs.contains(incident.id) {
                selectedIncidentIDs.remove(incident.id)
            } else {
                selectedIncidentIDs.insert(incident.id)
            }
        }
    }

    private func exportExposureReports(_ targets: [ExposureIncident]) {
        guard !targets.isEmpty else { return }
        do {
            exportURL = try ExportService.exportExposureIncidents(targets)
            isSelectingIncidents = false
            selectedIncidentIDs.removeAll()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteAllData() {
        for entry in entries {
            modelContext.delete(entry)
        }
        for incident in incidents {
            modelContext.delete(incident)
        }
        try? modelContext.save()
        ExportService.cleanUpPreviousExports()
    }
}

// MARK: Camera Viewfinder Reticle

private struct CameraViewfinderMark: View {
    var size: CGFloat = 68
    var bracketLength: CGFloat = 16
    var strokeWidth: CGFloat = 2.2
    var cornerRadius: CGFloat = 4

    var body: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            let pad = strokeWidth * 0.5
            let bl = bracketLength
            let r = cornerRadius
            let color = Palette.moss

            var path = Path()

            // Top left bracket
            path.move(to: CGPoint(x: pad, y: pad + bl))
            path.addLine(to: CGPoint(x: pad, y: pad + r))
            path.addQuadCurve(to: CGPoint(x: pad + r, y: pad), control: CGPoint(x: pad, y: pad))
            path.addLine(to: CGPoint(x: pad + bl, y: pad))

            // Top right bracket
            path.move(to: CGPoint(x: w - pad - bl, y: pad))
            path.addLine(to: CGPoint(x: w - pad - r, y: pad))
            path.addQuadCurve(to: CGPoint(x: w - pad, y: pad + r), control: CGPoint(x: w - pad, y: pad))
            path.addLine(to: CGPoint(x: w - pad, y: pad + bl))

            // Bottom left bracket
            path.move(to: CGPoint(x: pad, y: h - pad - bl))
            path.addLine(to: CGPoint(x: pad, y: h - pad - r))
            path.addQuadCurve(to: CGPoint(x: pad + r, y: h - pad), control: CGPoint(x: pad, y: h - pad))
            path.addLine(to: CGPoint(x: pad + bl, y: h - pad))

            // Bottom right bracket
            path.move(to: CGPoint(x: w - pad - bl, y: h - pad))
            path.addLine(to: CGPoint(x: w - pad - r, y: h - pad))
            path.addQuadCurve(to: CGPoint(x: w - pad, y: h - pad - r), control: CGPoint(x: w - pad, y: h - pad))
            path.addLine(to: CGPoint(x: w - pad, y: h - pad - bl))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Fires whether the user sent it, cancelled, or the sheet failed.
        // Without this the archive lingers until iOS decides to clear temp,
        // which can be a long time.
        controller.completionWithItemsHandler = { _, _, _, _ in
            onFinish()
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: Settings

struct SettingsSheet: View {
    @Bindable var location: LocationService
    var onDeleteAll: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @AppStorage("app_season_setting") private var seasonSetting = "auto"
    @AppStorage("autumn_visitor_setting") private var autumnVisitorSetting = "auto"
    @AppStorage("winter_holiday_setting") private var winterHolidaySetting = "auto"
    @AppStorage("spring_holiday_setting") private var springHolidaySetting = "auto"
    @State private var locationOn = false
    @State private var showDeleteConfirm = false

    private var locationPrivacyRadiusText: String {
        let system = Locale.current.measurementSystem
        if system == .us || system == .uk {
            return "about half a mile"
        } else {
            return "about a kilometer"
        }
    }

    var body: some View {
        let theme = SeasonTheme.theme(for: seasonSetting)

        NavigationStack {
            ZStack {
                theme.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("SEASONAL PALETTE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundStyle(theme.lichen)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: theme.season.icon)
                                    Text(theme.season.moodTitle)
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.season == .spring ? theme.accentAlt : theme.accent)
                            }

                            Picker("Season", selection: $seasonSetting) {
                                Text("Auto (\(Season.current.rawValue))").tag("auto")
                                ForEach(Season.allCases) { season in
                                    Text(season.rawValue).tag(season.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(theme.season.moodDescription)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(theme.parchment)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                (theme.season == .spring ? theme.accentAlt : theme.accent).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        (theme.season == .spring ? theme.accentAlt : theme.accent).opacity(0.4),
                                        lineWidth: 1
                                    )
                            )

                            Text("FloraFang automatically tunes its organic slate, moss, and foliage accents to match the natural seasons, keeping screens visible and true to life.")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.lichen)
                                .fixedSize(horizontal: false, vertical: true)

                            if theme.season == .autumn {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("AUTUMN CELEBRATION OVERLAY")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(theme.lichen)

                                    Picker("Autumn Celebration", selection: $autumnVisitorSetting) {
                                        Text("Auto (By Month)").tag("auto")
                                        Text("Halloween").tag("october")
                                        Text("Thanksgiving").tag("november")
                                        Text("Off").tag("standard")
                                    }
                                    .pickerStyle(.segmented)

                                    Text(autumnVisitorDescription)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(theme.lichen)
                                }
                                .padding(.top, 4)
                            } else if theme.season == .winter {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("WINTER CELEBRATION OVERLAY")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(theme.lichen)

                                    Picker("Winter Celebration", selection: $winterHolidaySetting) {
                                        Text("Auto (December)").tag("auto")
                                        Text("Christmas").tag("christmas")
                                        Text("Off").tag("none")
                                    }
                                    .pickerStyle(.segmented)

                                    Text(winterHolidayDescription)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(theme.lichen)
                                }
                                .padding(.top, 4)
                            } else if theme.season == .spring {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("SPRING CELEBRATION OVERLAY")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(theme.lichen)

                                    Picker("Spring Celebration", selection: $springHolidaySetting) {
                                        Text("Auto (Springtime)").tag("auto")
                                        Text("Easter").tag("easter")
                                        Text("Off").tag("none")
                                    }
                                    .pickerStyle(.segmented)

                                    Text(springHolidayDescription)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(theme.lichen)
                                }
                                .padding(.top, 4)
                            } else if theme.season == .summer {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("SUMMER SEASON")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(theme.lichen)

                                    Text("Summer is dedicated to pure sunny warmth, drifting sunbeams, and colorful fluttering butterflies.")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(theme.lichen)
                                }
                                .padding(.top, 4)
                            }
                        }

                        Divider().overlay(theme.moss.opacity(0.4))

                        Toggle(isOn: $locationOn) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Record location on scans")
                                    .font(.system(size: 14))
                                    .foregroundStyle(theme.parchment)
                                Text("Off by default. Attaches your general area to field log entries for personal notes and seasonal reference.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.lichen)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Stored only on your iPhone and never shared. Records a nearby town plus coordinates rounded to \(locationPrivacyRadiusText) to protect your privacy. Included in export archives and shared with your on device assistant.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.ochre.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                            }
                        }
                        .tint(theme.moss)
                        .onChange(of: locationOn) { _, newValue in
                            location.isEnabled = newValue
                            if newValue { location.requestPermission() }
                        }

                        Divider().overlay(theme.moss.opacity(0.4))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("ABOUT & PRIVACY")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(theme.lichen)
                            Text("FloraFang runs entirely on your iPhone. No account, no server, no analytics. All field observations and exposure incident intake reports are stored strictly in local on device database storage. Exporting records creates a file on your device that goes nowhere unless you send it yourself.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.parchment.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider().overlay(theme.moss.opacity(0.4))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MEDICAL DISCLAIMER")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(theme.rust)
                            Text("FloraFang is an educational reference tool. It does not provide medical diagnosis or replace professional identification. In an emergency, always contact Poison Control or local emergency services.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.parchment.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider().overlay(theme.moss.opacity(0.4))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("LEGAL & SUPPORT")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(theme.lichen)

                            if let privacyURL = URL(string: "https://ramirezlabs.app/florafang/privacy.html") {
                                Link(destination: privacyURL) {
                                    HStack {
                                        Text("Privacy Policy")
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(theme.parchment)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 11))
                                            .foregroundStyle(theme.lichen)
                                    }
                                }
                            }

                            if let supportURL = URL(string: "mailto:support@ramirezlabs.app") {
                                Link(destination: supportURL) {
                                    HStack {
                                        Text("Contact Support")
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(theme.parchment)
                                        Spacer()
                                        Image(systemName: "envelope")
                                            .font(.system(size: 11))
                                            .foregroundStyle(theme.lichen)
                                    }
                                }
                            }
                        }

                        Divider().overlay(theme.moss.opacity(0.4))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATA MANAGEMENT")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(theme.lichen)

                            Text("All field scans and exposure incident records live exclusively on this iPhone. You can erase all saved records at any time.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.parchment.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("Delete All Stored Data")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(theme.rust)
                                .padding(.vertical, 9)
                                .padding(.horizontal, 14)
                                .background(theme.rust.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.rust.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.ochre)
                }
            }
            .confirmationDialog("Delete all stored data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    onDeleteAll?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all field log scans and exposure incident reports from this iPhone. This action cannot be reversed.")
            }
            .onAppear { locationOn = location.isEnabled }
        }
    }

    private var autumnVisitorDescription: String {
        switch autumnVisitorSetting {
        case "october":
            return "Halloween active: flying night bat, walking skeleton stroll near tabs, and glowing jack o lantern."
        case "november":
            return "Thanksgiving active: wild harvest turkey stands proudly next to the pumpkin."
        case "standard":
            return "Peaceful autumn: resident chipmunk on the tree and colorful falling leaves only."
        default:
            return "Automatic calendar mode: bat, skeleton, and jack o lantern in October, turkey in November."
        }
    }

    private var winterHolidayDescription: String {
        switch winterHolidaySetting {
        case "christmas":
            return "Christmas active: frosted tree adorned with twinkling fairy lights, wrapped gifts, and a Santa hat on the owl."
        case "none":
            return "Peaceful winter: bare frosted tree, snowy owl, and crystalline falling snowflakes only."
        default:
            return "Automatic calendar mode: Christmas fairy lights, gifts, and festive owl hat appear in December and early January."
        }
    }

    private var springHolidayDescription: String {
        switch springHolidaySetting {
        case "easter":
            return "Easter active: sweet fluffy Easter bunny rests beneath the cherry tree alongside painted pastel Easter eggs."
        case "none":
            return "Peaceful spring: blossoming cherry tree, fresh spring shoots, and honeybee only."
        default:
            return "Automatic calendar mode: Easter bunny and decorated eggs appear during March and April."
        }
    }
}
