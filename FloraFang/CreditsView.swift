import SwiftUI

/// Photo attributions required by the CC BY 4.0 license on the reference photos.
struct CreditsView: View {
    @AppStorage("app_season_setting") private var seasonSetting = "auto"

    var body: some View {
        let theme = SeasonTheme.theme(for: seasonSetting)

        ZStack {
            theme.bark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REFERENCE PHOTOS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(theme.lichen)

                        Text("The reference photos shown in FloraFang come from iNaturalist observers who shared them under open licenses. Photos listed below are used under CC BY 4.0. Photos released to the public domain (CC0) need no credit. No changes were made beyond cropping and resizing.")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.parchment.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)

                        if let licenseURL = PhotoCredits.licenseURL {
                            Link(destination: licenseURL) {
                                HStack(spacing: 6) {
                                    Text("View the CC BY 4.0 license")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(theme.ochre)
                            }
                            .padding(.top, 2)
                        }
                    }

                    Divider().overlay(theme.moss.opacity(0.4))

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(PhotoCredits.all) { credit in
                            row(credit, theme: theme)
                            if credit.id != PhotoCredits.all.last?.id {
                                Divider().overlay(theme.moss.opacity(0.25))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Photo Credits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.bark, for: .navigationBar)
    }

    @ViewBuilder
    private func row(_ credit: PhotoCredit, theme: SeasonTheme) -> some View {
        let content = HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(credit.subject)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.parchment)
                Text("Photo by \(credit.photographer) on iNaturalist")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.lichen)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundStyle(theme.lichen)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())

        if let url = credit.observationURL {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}
