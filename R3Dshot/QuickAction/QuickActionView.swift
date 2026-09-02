import AppKit
import SwiftUI

struct QuickActionView: View {
    let capture: PendingCapture
    let suggestedFileName: String
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onCopy: () -> Void
    let onOpenEditor: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSImage(cgImage: capture.image, size: .zero))
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 158)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.quaternary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestedFileName)
                    .lineLimit(1)
                    .font(.headline)
                Text(capture.pixelSizeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Sichern", action: onSave)
                    .buttonStyle(.borderedProminent)
                Button("Sichern unter …", action: onSaveAs)
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button("Kopieren", action: onCopy)
                Button("Im Editor öffnen", action: onOpenEditor)
                Spacer()
                Button(role: .destructive, action: onDiscard) {
                    Image(systemName: "trash")
                }
                .help("Verwerfen")
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 308)
    }
}
