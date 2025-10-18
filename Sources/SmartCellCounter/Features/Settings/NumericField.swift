import SwiftUI

struct NumericField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: NumberFormatter
    let onInvalid: (String) -> Void

    @State private var text: String = ""
    @State private var lastValid: Double = 0
    @FocusState private var focused: Bool

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1.0, onInvalid: @escaping (String)->Void) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.onInvalid = onInvalid
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 3
        nf.minimumFractionDigits = 0
        nf.numberStyle = .decimal
        self.formatter = nf
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: focused) { isFocused in if !isFocused { commit() } }
            Stepper("", onIncrement: { increment() }, onDecrement: { decrement() })
                .labelsHidden()
        }
        .onAppear { lastValid = value; text = formatter.string(from: NSNumber(value: value)) ?? "\(value)" }
        .onChange(of: value) { newVal in text = formatter.string(from: NSNumber(value: newVal)) ?? "\(newVal)"; lastValid = newVal }
    }

    private func commit() {
        guard let entered = Double(text.replacingOccurrences(of: ",", with: ".")) else { revert("Invalid number") ; return }
        let clamped = min(max(entered, range.lowerBound), range.upperBound)
        if clamped != entered { onInvalid("Clamped to \(clamped)") }
        value = clamped
        lastValid = clamped
        text = formatter.string(from: NSNumber(value: clamped)) ?? "\(clamped)"
    }

    private func revert(_ msg: String) { onInvalid(msg); value = lastValid; text = formatter.string(from: NSNumber(value: lastValid)) ?? "\(lastValid)" }
    private func increment() { value = min(value + step, range.upperBound) }
    private func decrement() { value = max(value - step, range.lowerBound) }
}

