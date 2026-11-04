import SwiftUI

public struct LiquidGlassSearchBar: View {
    @Binding public var text: String
    public var onCommit: (() -> Void)? = nil
    @FocusState public var isFocused: Bool

    public init(text: Binding<String>, onCommit: (() -> Void)? = nil) {
        self._text = text
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFocused ? .white : .white.opacity(0.65))
                .shadow(color: isFocused ? Color(red: 0.85, green: 0.95, blue: 1.0, opacity: 0.6) : Color.clear, radius: 5)

            TextField("Search applications...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundColor(.white)
                .focused($isFocused)
                .onSubmit {
                    onCommit?()
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13.5))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 320, height: 36)
        .appleLiquidGlass(cornerRadius: 18, isHighlighted: isFocused)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isFocused)
    }
}
