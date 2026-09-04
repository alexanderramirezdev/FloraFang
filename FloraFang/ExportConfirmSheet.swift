//
//  ExportConfirmSheet.swift
//  FloraFang
//
//  Stands between the export button and the share sheet.
//
//  WHY: the export is the one moment in this app where everything sensitive
//  is aggregated into a single portable file. Photos capture whatever was in
//  frame, not just the subject, and with location enabled a photo taken in
//  someone's garage is their home address attached to a picture of the
//  inside of their home. Nothing else in the app collects across scans like
//  this, and nothing else leaves the device at all.
//
//  The warning is specific rather than generic on purpose. "This contains
//  personal data" gets dismissed without reading. "12 photos and 4 locations"
//  does not.
//

import SwiftUI

struct ExportConfirmSheet: View {
    let summary: ExportSummary
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        contents
                        warning
                        if summary.locationCount > 0 { locationWarning }
                        Spacer(minLength: 8)
                        buttons
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Export field log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.lichen)
                }
            }
        }
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS FILE WILL CONTAIN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Palette.lichen)

            line("\(summary.photoCount) photo\(summary.photoCount == 1 ? "" : "s")",
                 symbol: "photo")
            line("\(summary.entryCount) entr\(summary.entryCount == 1 ? "y" : "ies") with what the app said about each",
                 symbol: "list.bullet")
            if summary.hasNotes {
                line("Any notes you wrote", symbol: "text.alignleft")
            }
            if summary.locationCount > 0 {
                line("\(summary.locationCount) location\(summary.locationCount == 1 ? "" : "s")",
                     symbol: "location", tint: Palette.rust)
            }
            if let earliest = summary.earliest, let latest = summary.latest {
                line("\(earliest.formatted(date: .abbreviated, time: .omitted)) to \(latest.formatted(date: .abbreviated, time: .omitted))",
                     symbol: "calendar")
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.moss.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Palette.ochre)
            Text("Photos capture whatever was in frame, not just the subject. That can include your home, your screen, documents, or other people. Have a look at the file before sending it if you are not sure what is in it.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.parchment.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Palette.ochre.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.ochre.opacity(0.5), lineWidth: 1))
    }

    private var locationWarning: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "location.slash")
                .foregroundStyle(Palette.rust)
            VStack(alignment: .leading, spacing: 3) {
                Text("This includes roughly where you were")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.rust)
                Text("Roughly where each scan happened, as a city name and coordinates rounded to about a kilometre. This does not pinpoint an address, but it does show the general area you were in. You can turn location capture off in Settings, though it will not remove locations already saved.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.parchment.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Palette.rust.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.rust.opacity(0.6), lineWidth: 1))
    }

    private var buttons: some View {
        VStack(spacing: 9) {
            Button {
                dismiss()
                onConfirm()
            } label: {
                Text("CONTINUE")
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Palette.parchment)
            }

            Text("Nothing has left your device yet. The next screen is where you choose who to send it to.")
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.lichen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func line(_ text: String, symbol: String, tint: Color = Palette.parchment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint == Palette.parchment ? Palette.lichen : tint)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(tint == Palette.parchment ? Palette.parchment.opacity(0.9) : tint)
            Spacer()
        }
    }
}
