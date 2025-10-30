import SwiftUI

struct ImageSelectionView: View {
    let image: UIImage
    let fixedAspect: CGFloat? // width/height or nil
    let onConfirm: (CGRect) -> Void // rect in image coordinates

    @State private var viewRect: CGRect = .zero
    @State private var selection: CGRect = .zero // in view coords
    @State private var showHint = true
    @State private var areaText: String = ""
    @State private var widthText: String = ""
    @State private var heightText: String = ""

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                GeometryReader { geo in
                    let fit = fitRect(imageSize: image.size, in: geo.size)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: fit.size.width, height: fit.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .flipsForRightToLeftLayoutDirection(false)
                        .accessibilityHidden(true)
                        .onAppear {
                            viewRect = CGRect(origin: CGPoint(x: (geo.size.width - fit.size.width) / 2, y: (geo.size.height - fit.size.height) / 2), size: fit.size)
                            // default selection in center
                            let w = fit.size.width * 0.5
                            let h = fit.size.height * 0.4
                            selection = CGRect(x: viewRect.midX - w / 2, y: viewRect.midY - h / 2, width: w, height: h)
                        }
                    SelectionOverlay(rect: $selection, bounds: viewRect, minSize: CGSize(width: 40, height: 40), fixedAspect: fixedAspect)
                }
                if showHint {
                    Text(L10n.Selection.instructions)
                        .font(DS.Typo.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .onTapGesture { withAnimation { showHint = false } }
                }
            }
            .frame(maxHeight: 360)

            HStack(spacing: DS.Spacing.md) {
                LabeledSize(label: L10n.Selection.widthLabel, valueText: L10n.Selection.sizeValue(selection.width))
                LabeledSize(label: L10n.Selection.heightLabel, valueText: L10n.Selection.sizeValue(selection.height))
                LabeledSize(label: L10n.Selection.areaLabel, valueText: L10n.Selection.areaValue(width: selection.width, height: selection.height))
            }

            HStack {
                Spacer()
                Button(L10n.Selection.confirmButton) {
                    let imageRect = GeometryUtils.scale(rect: selection.offsetBy(dx: -viewRect.minX, dy: -viewRect.minY), from: viewRect.size, to: image.size)
                    onConfirm(imageRect)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(L10n.Selection.overlayHint)
            }
        }
        .padding()
        .appBackground()
    }

    private func fitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        let ar = imageSize.width / imageSize.height
        var size = if container.width / container.height > ar {
            CGSize(width: container.height * ar, height: container.height)
        } else {
            CGSize(width: container.width, height: container.width / ar)
        }
        return CGRect(origin: .zero, size: size)
    }
}

private struct LabeledSize: View {
    let label: String
    let valueText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(DS.Typo.caption).foregroundColor(Theme.textSecondary)
            Text(valueText).font(DS.Typo.headline).foregroundColor(Theme.textPrimary)
        }
        .cardStyle(padding: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(valueText)")
    }
}
