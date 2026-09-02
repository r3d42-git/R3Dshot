import AppKit
import SwiftUI

struct RectangleInspectorView: View {
    @Bindable var store: EditorStore

    var body: some View {
        Group {
            if let style = store.selectedShapeStyle {
                Form {
                    Section(store.selectedShapeTitle ?? "Form") {
                        ColorPicker(
                            "Kontur",
                            selection: colorBinding(
                                get: { style.strokeColor },
                                set: { color in
                                    update(style, actionName: "Konturfarbe ändern") {
                                        $0.strokeColor = color
                                    }
                                }
                            )
                        )

                        LabeledContent("Linienstärke") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.lineWidth },
                                        set: { value in
                                            update(style, actionName: "Linienstärke ändern") {
                                                $0.lineWidth = value
                                            }
                                        }
                                    ),
                                    in: 1...40
                                )
                                Text("\(Int(style.lineWidth)) px")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }

                        Toggle(
                            "Füllung",
                            isOn: Binding(
                                get: { style.fillColor.alpha > 0 },
                                set: { enabled in
                                    update(style, actionName: "Füllung ändern") {
                                        $0.fillColor = enabled
                                            ? RGBAColor(red: 1, green: 0.22, blue: 0.2, alpha: 0.18)
                                            : .clear
                                    }
                                }
                            )
                        )

                        if style.fillColor.alpha > 0 {
                            ColorPicker(
                                "Füllfarbe",
                                selection: colorBinding(
                                    get: { style.fillColor },
                                    set: { color in
                                        update(style, actionName: "Füllfarbe ändern") {
                                            $0.fillColor = color
                                        }
                                    }
                                )
                            )
                        }

                        if store.selectedShapeSupportsCornerRadius {
                            LabeledContent("Eckenradius") {
                                HStack {
                                    Slider(
                                        value: valueBinding(
                                            get: { style.cornerRadius },
                                            set: { value in
                                                update(style, actionName: "Eckenradius ändern") {
                                                    $0.cornerRadius = value
                                                }
                                            }
                                        ),
                                        in: 0...80
                                    )
                                    Text("\(Int(style.cornerRadius)) px")
                                        .monospacedDigit()
                                        .frame(width: 48, alignment: .trailing)
                                }
                            }
                        }

                        LabeledContent("Deckkraft") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.opacity },
                                        set: { value in
                                            update(style, actionName: "Deckkraft ändern") {
                                                $0.opacity = value
                                            }
                                        }
                                    ),
                                    in: 0.1...1
                                )
                                Text("\(Int(style.opacity * 100)) %")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                    }

                    Section("Anordnung") {
                        HStack {
                            Button("Nach vorn") {
                                store.bringSelectionForward()
                            }
                            Button("Nach hinten") {
                                store.sendSelectionBackward()
                            }
                        }
                        HStack {
                            Button("Duplizieren") {
                                store.duplicateSelection()
                            }
                            Button("Löschen", role: .destructive) {
                                store.deleteSelection()
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else if let style = store.selectedArrowStyle {
                Form {
                    Section("Pfeil") {
                        ColorPicker(
                            "Farbe",
                            selection: colorBinding(
                                get: { style.strokeColor },
                                set: { color in
                                    updateArrow(style, actionName: "Pfeilfarbe ändern") {
                                        $0.strokeColor = color
                                    }
                                }
                            )
                        )

                        LabeledContent("Linienstärke") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.lineWidth },
                                        set: { value in
                                            updateArrow(style, actionName: "Linienstärke ändern") {
                                                $0.lineWidth = value
                                            }
                                        }
                                    ),
                                    in: 1...40
                                )
                                Text("\(Int(style.lineWidth)) px")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }

                        LabeledContent("Pfeilspitze") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.arrowheadLength },
                                        set: { value in
                                            updateArrow(style, actionName: "Pfeilspitze ändern") {
                                                $0.arrowheadLength = value
                                            }
                                        }
                                    ),
                                    in: 6...80
                                )
                                Text("\(Int(style.arrowheadLength)) px")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }

                        Toggle(
                            "Spitze am Anfang",
                            isOn: Binding(
                                get: { style.hasStartArrowhead },
                                set: { enabled in
                                    updateArrow(style, actionName: "Pfeilanfang ändern") {
                                        $0.hasStartArrowhead = enabled
                                    }
                                }
                            )
                        )

                        Toggle(
                            "Spitze am Ende",
                            isOn: Binding(
                                get: { style.hasEndArrowhead },
                                set: { enabled in
                                    updateArrow(style, actionName: "Pfeilende ändern") {
                                        $0.hasEndArrowhead = enabled
                                    }
                                }
                            )
                        )

                        LabeledContent("Deckkraft") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.opacity },
                                        set: { value in
                                            updateArrow(style, actionName: "Deckkraft ändern") {
                                                $0.opacity = value
                                            }
                                        }
                                    ),
                                    in: 0.1...1
                                )
                                Text("\(Int(style.opacity * 100)) %")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                    }

                    Section("Anordnung") {
                        HStack {
                            Button("Nach vorn") {
                                store.bringSelectionForward()
                            }
                            Button("Nach hinten") {
                                store.sendSelectionBackward()
                            }
                        }
                        HStack {
                            Button("Duplizieren") {
                                store.duplicateSelection()
                            }
                            Button("Löschen", role: .destructive) {
                                store.deleteSelection()
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else if let style = store.selectedRedactionStyle {
                Form {
                    Section("Schwärzung") {
                        ColorPicker(
                            "Farbe",
                            selection: colorBinding(
                                get: { style.color },
                                set: { color in
                                    updateRedaction(style, actionName: "Farbe der Schwärzung ändern") {
                                        $0.color = color
                                    }
                                }
                            )
                        )
                    }

                    Section("Anordnung") {
                        HStack {
                            Button("Nach vorn") {
                                store.bringSelectionForward()
                            }
                            Button("Nach hinten") {
                                store.sendSelectionBackward()
                            }
                        }
                        HStack {
                            Button("Duplizieren") {
                                store.duplicateSelection()
                            }
                            Button("Löschen", role: .destructive) {
                                store.deleteSelection()
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else if let style = store.selectedMarkerStyle {
                Form {
                    Section("Marker") {
                        ColorPicker(
                            "Farbe",
                            selection: colorBinding(
                                get: { style.color },
                                set: { color in
                                    updateMarker(style, actionName: "Markerfarbe ändern") {
                                        $0.color = color
                                    }
                                }
                            )
                        )

                        LabeledContent("Breite") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.lineWidth },
                                        set: { value in
                                            updateMarker(style, actionName: "Markerbreite ändern") {
                                                $0.lineWidth = value
                                            }
                                        }
                                    ),
                                    in: 4...80
                                )
                                Text("\(Int(style.lineWidth)) px")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }

                        LabeledContent("Deckkraft") {
                            HStack {
                                Slider(
                                    value: valueBinding(
                                        get: { style.opacity },
                                        set: { value in
                                            updateMarker(style, actionName: "Markerdeckkraft ändern") {
                                                $0.opacity = value
                                            }
                                        }
                                    ),
                                    in: 0.1...1
                                )
                                Text("\(Int(style.opacity * 100)) %")
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                    }

                    Section("Anordnung") {
                        HStack {
                            Button("Nach vorn") { store.bringSelectionForward() }
                            Button("Nach hinten") { store.sendSelectionBackward() }
                        }
                        HStack {
                            Button("Duplizieren") { store.duplicateSelection() }
                            Button("Löschen", role: .destructive) { store.deleteSelection() }
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "Keine Auswahl",
                    systemImage: "cursorarrow.click",
                    description: Text("Wähle ein Element auf der Arbeitsfläche aus.")
                )
            }
        }
        .frame(minWidth: 250, idealWidth: 280)
    }

    private func update(
        _ current: ShapeStyle,
        actionName: String,
        mutation: (inout ShapeStyle) -> Void
    ) {
        var updated = current
        mutation(&updated)
        store.setSelectedShapeStyle(updated, actionName: actionName)
    }

    private func updateArrow(
        _ current: ArrowStyle,
        actionName: String,
        mutation: (inout ArrowStyle) -> Void
    ) {
        var updated = current
        mutation(&updated)
        store.setSelectedArrowStyle(updated, actionName: actionName)
    }

    private func updateRedaction(
        _ current: RedactionStyle,
        actionName: String,
        mutation: (inout RedactionStyle) -> Void
    ) {
        var updated = current
        mutation(&updated)
        store.setSelectedRedactionStyle(updated, actionName: actionName)
    }

    private func updateMarker(
        _ current: MarkerStyle,
        actionName: String,
        mutation: (inout MarkerStyle) -> Void
    ) {
        var updated = current
        mutation(&updated)
        store.setSelectedMarkerStyle(updated, actionName: actionName)
    }

    private func valueBinding(
        get: @escaping @MainActor @Sendable () -> CGFloat,
        set: @escaping @MainActor @Sendable (CGFloat) -> Void
    ) -> Binding<CGFloat> {
        Binding(get: get, set: set)
    }

    private func colorBinding(
        get: @escaping () -> RGBAColor,
        set: @escaping (RGBAColor) -> Void
    ) -> Binding<Color> {
        Binding(
            get: {
                let value = get()
                return Color(
                    red: value.red,
                    green: value.green,
                    blue: value.blue,
                    opacity: max(value.alpha, 1)
                )
            },
            set: { color in
                guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return }
                let previousAlpha = get().alpha
                set(
                    RGBAColor(
                        red: converted.redComponent,
                        green: converted.greenComponent,
                        blue: converted.blueComponent,
                        alpha: previousAlpha > 0 ? previousAlpha : 1
                    )
                )
            }
        )
    }
}
