//
//  ExposureHistoryView.swift
//  FloraFang
//
//  Displays past saved exposure incidents so users, doctors, or vets
//  can review what was reported, when it happened, and what signs were observed.
//

import SwiftUI
import SwiftData

struct ExposureHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExposureIncident.timestamp, order: .reverse) private var incidents: [ExposureIncident]

    @State private var selectedIncident: ExposureIncident?
    @State private var incidentToDelete: ExposureIncident?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                if incidents.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(incidents) { incident in
                            Button {
                                selectedIncident = incident
                            } label: {
                                incidentRow(incident)
                            }
                            .listRowBackground(Color.black.opacity(0.25))
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    incidentToDelete = incident
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Incident History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.parchment)
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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(Palette.moss)

            Text("No Past Incidents")
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.parchment)

            Text("When you save an intake report from the Exposure tab, a permanent record of the plant, symptoms, timing, and dispatch summary will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 36)
        }
        .padding()
    }

    private func incidentRow(_ incident: ExposureIncident) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Subject badge icon
            ZStack {
                Circle()
                    .fill(Palette.moss.opacity(0.25))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Palette.moss.opacity(0.6), lineWidth: 1))

                Image(systemName: subjectIcon(incident.subject))
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.parchment)
            }

            VStack(alignment: .leading, spacing: 4) {
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

    private func subjectIcon(_ subject: ExposureSubject) -> String {
        switch subject {
        case .dog:         return "pawprint.fill"
        case .cat:         return "pawprint"
        case .otherAnimal: return "hare.fill"
        case .child:       return "figure.and.child.holdinghands"
        case .adult:       return "person.fill"
        }
    }
}

// MARK: - Incident Detail Sheet

struct ExposureIncidentDetailSheet: View {
    let incident: ExposureIncident
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showCopied = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Top header card
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(incident.displaySubject.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundStyle(Palette.ochre)
                                Text(incident.displayPlant)
                                    .font(.system(size: 22, weight: .semibold, design: .serif))
                                    .foregroundStyle(Palette.parchment)
                                if !incident.scientificName.isEmpty {
                                    Text(incident.scientificName)
                                        .font(.system(size: 12))
                                        .italic()
                                        .foregroundStyle(Palette.lichen)
                                }
                            }
                            Spacer()
                            Text(incident.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.lichen)
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                        // Photo if attached
                        if let data = incident.imageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Intake details
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RECORDED INTAKE")
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Palette.lichen)

                            infoRow(label: "Who", value: incident.subjectDetail.isEmpty ? incident.displaySubject : "\(incident.displaySubject) — \(incident.subjectDetail)")
                            infoRow(label: "Part eaten", value: incident.partEaten.label)
                            if !incident.amount.isEmpty {
                                infoRow(label: "Amount", value: incident.amount)
                            }
                            infoRow(label: "Time", value: incident.timeOfExposure.formatted(date: .abbreviated, time: .shortened))
                            infoRow(label: "Signs observed", value: incident.symptomsRaw.isEmpty ? "None noted" : incident.symptomsRaw.joined(separator: ", "))
                            if !incident.otherNotes.isEmpty {
                                infoRow(label: "Notes", value: incident.otherNotes)
                            }
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))

                        // Relay summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DISPATCH RELAY SUMMARY")
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Palette.lichen)

                            Text(incident.relaySummaryText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Palette.parchment)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.moss.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))

                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = incident.relaySummaryText
                                    showCopied = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        showCopied = false
                                    }
                                } label: {
                                    Label(showCopied ? "Copied" : "Copy Summary", systemImage: "doc.on.clipboard")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                                        .foregroundStyle(Palette.parchment)
                                }

                                ShareLink(item: incident.relaySummaryText) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                                        .foregroundStyle(Palette.parchment)
                                }
                            }
                        }

                        // Delete button
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete Record", systemImage: "trash")
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(Palette.rust)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rust.opacity(0.5), lineWidth: 1))
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Incident Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.parchment)
                }
            }
            .confirmationDialog("Delete this incident record?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(incident)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Palette.lichen)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.parchment)
            Spacer()
        }
    }
}
