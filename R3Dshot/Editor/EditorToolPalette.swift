import SwiftUI

/// All drawing tools stay visible beside the canvas, including in shorter windows.
struct EditorToolPalette: View {
    @Bindable var store: EditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                toolGroup("Bild", tools: [.select, .crop])
                toolGroup("Markieren", tools: [.rectangle, .ellipse, .arrow, .marker])
                toolGroup("Erklären", tools: [.text, .speechBubble, .stepNumber])
                toolGroup("Abdecken & Fokus", tools: [.redaction, .pixelate, .focus])
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .frame(width: 176)
        .background(Color(nsColor: EditorAppearance.panel))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Werkzeuge")
    }

    private func toolGroup(_ title: String, tools: [EditorTool]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 3)
            ForEach(tools) { tool in
                let isSelected = store.activeTool == tool
                Button {
                    store.selectTool(tool)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: tool.systemImage)
                            .frame(width: 18)
                        Text(tool.title)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .padding(.horizontal, 8)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tool.helpText)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
