import AppKit
import SwiftUI

/// Drawing settings remain available before placing the first annotation.
struct ToolDefaultsInspector: View {
    @Bindable var store: EditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(heading).font(.headline)
                VStack(alignment: .leading, spacing: 18) {
                    controls
                }
                Divider()
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch store.activeTool {
        case .rectangle:
            shapeControls($store.toolDefaults.rectangle, rounded: true)
        case .ellipse:
            shapeControls($store.toolDefaults.ellipse, rounded: false)
        case .arrow:
            colorPicker("Farbe", $store.toolDefaults.arrow.strokeColor)
            InspectorNumericRow("Linienstärke", value: $store.toolDefaults.arrow.lineWidth, range: 1...40)
            InspectorNumericRow("Pfeilspitze", value: $store.toolDefaults.arrow.arrowheadLength, range: 6...80)
            Toggle("Spitze am Anfang", isOn: $store.toolDefaults.arrow.hasStartArrowhead)
            Toggle("Spitze am Ende", isOn: $store.toolDefaults.arrow.hasEndArrowhead)
            opacityRow($store.toolDefaults.arrow.opacity)
        case .redaction:
            colorPicker("Farbe", $store.toolDefaults.redaction.color)
        case .marker:
            colorPicker("Farbe", $store.toolDefaults.marker.color)
            InspectorNumericRow("Breite", value: $store.toolDefaults.marker.lineWidth, range: 4...80)
            opacityRow($store.toolDefaults.marker.opacity)
        case .text:
            textControls($store.toolDefaults.text)
        case .speechBubble:
            textControls($store.toolDefaults.speechBubble.textStyle)
            colorPicker("Rahmen", $store.toolDefaults.speechBubble.strokeColor)
            colorPicker("Füllung", $store.toolDefaults.speechBubble.fillColor)
            InspectorNumericRow("Linienstärke", value: $store.toolDefaults.speechBubble.lineWidth, range: 1...40)
            InspectorNumericRow("Eckenradius", value: $store.toolDefaults.speechBubble.cornerRadius, range: 0...80)
            InspectorNumericRow("Zeigerposition", value: $store.toolDefaults.speechBubble.tailPoint.x, range: 0...1, unit: "%", scale: 100)
            InspectorNumericRow("Zeigerlänge", value: $store.toolDefaults.speechBubble.tailPoint.y, range: 1...1.6, unit: "%", scale: 100)
        case .stepNumber:
            Stepper("Startnummer: \(store.stepNumberStart)", value: Binding(
                get: { store.stepNumberStart },
                set: { store.setStepNumberStart($0) }
            ), in: 1...9_999)
            LabeledContent("Nächster Schritt") {
                Text("\(store.nextStepNumber)").monospacedDigit()
            }
            Picker("Form", selection: $store.toolDefaults.stepNumber.shape) {
                Text("Kreis").tag(StepNumberShape.circle)
                Text("Quadrat").tag(StepNumberShape.square)
                Text("Abgerundet").tag(StepNumberShape.roundedSquare)
            }
            colorPicker("Füllung", $store.toolDefaults.stepNumber.fillColor)
            colorPicker("Zahl", $store.toolDefaults.stepNumber.textColor)
        case .pixelate:
            InspectorNumericRow("Pixelgröße", value: $store.toolDefaults.pixelate.blockSize, range: 2...80)
        case .focus:
            InspectorNumericRow("Unschärfe", value: $store.toolDefaults.focus.blurRadius, range: 1...60)
        case .select, .crop:
            EmptyView()
        }
    }

    private func shapeControls(_ style: Binding<ShapeStyle>, rounded: Bool) -> some View {
        Group {
            colorPicker("Kontur", style.strokeColor)
            InspectorNumericRow("Linienstärke", value: style.lineWidth, range: 1...40)
            Toggle("Füllung", isOn: Binding(
                get: { style.wrappedValue.fillColor.alpha > 0 },
                set: { enabled in
                    // Keep the chosen RGB color when switching fill off.
                    style.wrappedValue.fillColor.alpha = enabled ? 0.18 : 0
                }
            ))
            if style.wrappedValue.fillColor.alpha > 0 {
                colorPicker("Füllfarbe", style.fillColor)
            }
            if rounded {
                InspectorNumericRow("Eckenradius", value: style.cornerRadius, range: 0...80)
            }
            opacityRow(style.opacity)
        }
    }

    private func textControls(_ style: Binding<TextStyle>) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("Inhalt")
                TextField("Text", text: style.text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                    .accessibilityLabel("Inhalt")
            }
            colorPicker("Textfarbe", style.color)
            InspectorNumericRow("Schriftgröße", value: style.fontSize, range: 8...160)
            Picker("Ausrichtung", selection: style.alignment) {
                Text("Links").tag(AnnotationTextAlignment.leading)
                Text("Zentriert").tag(AnnotationTextAlignment.center)
                Text("Rechts").tag(AnnotationTextAlignment.trailing)
            }
            opacityRow(style.opacity)
        }
    }

    private func opacityRow(_ value: Binding<CGFloat>) -> some View {
        InspectorNumericRow("Deckkraft", value: value, range: 0.1...1, unit: "%", scale: 100)
    }

    private func colorPicker(_ title: String, _ value: Binding<RGBAColor>) -> some View {
        ColorPicker(title, selection: Binding(
            get: {
                let rgba = value.wrappedValue
                return Color(red: rgba.red, green: rgba.green, blue: rgba.blue)
            },
            set: { color in
                guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return }
                let alpha = value.wrappedValue.alpha
                value.wrappedValue = RGBAColor(
                    red: converted.redComponent, green: converted.greenComponent,
                    blue: converted.blueComponent, alpha: alpha
                )
            }
        ), supportsOpacity: false)
    }

    private var heading: String {
        switch store.activeTool {
        case .rectangle: "Für neue Rechtecke"
        case .ellipse: "Für neue Ellipsen"
        case .arrow: "Für neue Pfeile"
        case .redaction: "Für neue Schwärzungen"
        case .marker: "Für neue Markierungen"
        case .text: "Für neue Texte"
        case .speechBubble: "Für neue Sprechblasen"
        case .stepNumber: "Für neue Schritte"
        case .pixelate: "Für neue Pixelierungen"
        case .focus: "Für neue Fokusbereiche"
        case .select, .crop: "Werkzeug"
        }
    }

    private var instruction: String {
        switch store.activeTool {
        case .stepNumber:
            "Klicke auf das Bild, um den nächsten Schritt zu setzen. Die Nummerierung wird automatisch fortgesetzt."
        case .marker:
            "Ziehe über das Bild, um mit diesen Einstellungen zu markieren."
        default:
            "Ziehe auf dem Bild einen Bereich auf. Diese Einstellungen gelten für neue Elemente."
        }
    }
}

/// A full-width slider avoids compressing the control between label and unit.
private struct InspectorNumericRow: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let unit: String
    let scale: CGFloat

    init(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, unit: String = "px", scale: CGFloat = 1) {
        self.title = title
        _value = value
        self.range = range
        self.unit = unit
        self.scale = scale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                TextField(title, value: Binding(
                    get: { Double(value * scale) },
                    set: { newValue in
                        guard newValue.isFinite else { return }
                        value = min(range.upperBound, max(range.lowerBound, CGFloat(newValue) / scale))
                    }
                ), format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 54)
                    .monospacedDigit()
                    .accessibilityLabel(title)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            Slider(value: $value, in: range, step: 1 / scale)
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value * scale).rounded())) \(unit)")
        }
    }
}
