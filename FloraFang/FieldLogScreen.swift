//
//  FieldLogScreen.swift
//  FloraFang
//

import SwiftUI
import SwiftData

struct FieldLogScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FieldEntry.capturedAt, order: .reverse)
    private var entries: [FieldEntry]

    @State private var location = LocationService()
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showSettings = false
    @State private var showExportConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink {
                                EntryDetailScreen(entry: entry)
                            } label: {
                                row(entry)
                            }
                            .listRowBackground(Palette.bark)
                            .listRowSeparatorTint(Palette.moss.opacity(0.4))
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Field Log")
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showExportConfirm = true
                        } label: {
                            Label("Export field log", systemImage: "square.and.arrow.up")
                        }
                        .disabled(entries.isEmpty)

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Palette.ochre)
                    }
                }
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
                    ExportService.cleanUpPreviousExports()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(location: location)
            }
            .alert("Export failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 34))
                .foregroundStyle(Palette.moss)
            Text("Nothing logged yet")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)
            Text("Scans save here automatically.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(Palette.lichen)
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
        case .safe:    return Palette.moss
        case .caution: return Palette.ochre
        case .avoid:   return Palette.rust
        case .unknown: return Palette.lichen
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
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
}

private struct ShareItem: Identifiable {
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

// MARK: - Settings

struct SettingsSheet: View {
    @Bindable var location: LocationService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("app_season_setting") private var seasonSetting = "auto"
    @State private var locationOn = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("SEASONAL PALETTE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundStyle(Palette.lichen)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: SeasonTheme.active.season.icon)
                                    Text(SeasonTheme.active.season.moodTitle)
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.ochre)
                            }

                            Picker("Season", selection: $seasonSetting) {
                                Text("Auto (\(Season.current.rawValue))").tag("auto")
                                ForEach(Season.allCases) { season in
                                    Text(season.rawValue).tag(season.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("FloraFang automatically tunes its organic slate, moss, and foliage accents to match the natural seasons, keeping screens visible and true to life.")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.lichen)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider().overlay(Palette.moss.opacity(0.4))

                        Toggle(isOn: $locationOn) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Record location on scans")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Palette.parchment)
                                Text("Off by default. Where you are narrows down what a thing can be, since range rules a lot of species out.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.lichen)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Stored on your iPhone only and never sent anywhere. Recorded as a city name plus coordinates rounded to about a kilometre, which is enough to rule species in or out and not enough to identify an address.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.ochre.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                            }
                        }
                        .tint(Palette.moss)
                        .onChange(of: locationOn) { _, newValue in
                            location.isEnabled = newValue
                            if newValue { location.requestPermission() }
                        }

                        Divider().overlay(Palette.moss.opacity(0.4))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("ABOUT")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(Palette.lichen)
                            Text("FloraFang runs entirely on your iPhone. No account, no server, no analytics. Exporting your field log creates a file on your device that goes nowhere unless you send it yourself.")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.parchment.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.ochre)
                }
            }
            .onAppear { locationOn = location.isEnabled }
        }
    }
}
