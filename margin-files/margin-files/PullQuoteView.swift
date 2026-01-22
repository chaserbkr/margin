import SwiftUI

// MARK: - Pull Quote View

/// A typographically-focused pull quote component for editorial content.
/// Integrates with the Margin design system and supports scroll-triggered animations.
///
/// Usage:
/// ```swift
/// PullQuoteView(
///     quote: "The emptiness is not absence but presence.",
///     attribution: "On minimalism",
///     sourceURL: URL(string: "https://example.com")
/// )
/// ```
struct PullQuoteView: View {

    // MARK: - Properties

    let quote: String
    var attribution: String? = nil
    var sourceURL: URL? = nil

    /// Optional type system override. If nil, uses editorial serif styling.
    var typeSystem: TypeSystem? = nil

    // MARK: - State

    @State private var isVisible: Bool = false
    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Design Tokens

    private enum Design {
        // Colors - using Margin design system
        static let textColor = MarginColors.ink
        static let mutedTextColor = MarginColors.stone500
        static let accentColor = MarginColors.stone300
        static let accentColorHover = MarginColors.stone500

        // Typography - scale up from body (18pt base → ~24pt quote)
        static let quoteSize: CGFloat = 24
        static let attributionSize: CGFloat = 13

        // Layout
        static let leadingIndent: CGFloat = 48
        static let accentRuleWidth: CGFloat = 2
        static let accentRuleSpacing: CGFloat = 20
        static let maxWidth: CGFloat = 520
        static let verticalPadding: CGFloat = 32

        // Animation
        static let animationDuration: Double = 0.35
        static let verticalOffset: CGFloat = 12
    }

    // MARK: - Computed Properties

    private var quoteFont: Font {
        if let ts = typeSystem {
            return ts.swiftUITitleFont(size: Design.quoteSize)
        }
        // Default: Instrument Serif for editorial feel
        return .custom("InstrumentSerif-Regular", size: Design.quoteSize)
    }

    private var attributionFont: Font {
        MarginTypography.ui(size: Design.attributionSize, weight: .regular)
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: Design.accentRuleSpacing) {
            // Vertical accent rule
            accentRule

            // Quote content
            VStack(alignment: .leading, spacing: 12) {
                quoteText

                if let attribution = attribution {
                    attributionView(attribution)
                }
            }
        }
        .padding(.leading, Design.leadingIndent)
        .padding(.vertical, Design.verticalPadding)
        .frame(maxWidth: Design.maxWidth, alignment: .leading)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : (reduceMotion ? 0 : Design.verticalOffset))
        .onHover { hovering in
            guard sourceURL != nil else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .background(visibilityTracker)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var accentRule: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(isHovered && sourceURL != nil ? Design.accentColorHover : Design.accentColor)
            .frame(width: Design.accentRuleWidth)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var quoteText: some View {
        Text(quote)
            .font(quoteFont)
            .foregroundColor(Design.textColor)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func attributionView(_ text: String) -> some View {
        if let url = sourceURL {
            // Linked attribution
            Link(destination: url) {
                HStack(spacing: 4) {
                    Text("—")
                    Text(text)
                        .underline(isHovered, color: Design.mutedTextColor)
                }
                .font(attributionFont)
                .foregroundColor(Design.mutedTextColor)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        } else {
            // Plain attribution
            HStack(spacing: 4) {
                Text("—")
                Text(text)
            }
            .font(attributionFont)
            .foregroundColor(Design.mutedTextColor)
        }
    }

    private var visibilityTracker: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    triggerAppearAnimation()
                }
                .preference(
                    key: PullQuoteVisibilityKey.self,
                    value: geometry.frame(in: .global).minY
                )
        }
        .onPreferenceChange(PullQuoteVisibilityKey.self) { minY in
            // Trigger animation when view enters viewport
            if minY < (NSScreen.main?.frame.height ?? 800) && !isVisible {
                triggerAppearAnimation()
            }
        }
    }

    // MARK: - Helpers

    private func triggerAppearAnimation() {
        guard !isVisible else { return }

        if reduceMotion {
            isVisible = true
        } else {
            withAnimation(.easeOut(duration: Design.animationDuration)) {
                isVisible = true
            }
        }
    }

    private var accessibilityLabel: String {
        var label = "Pull quote: \(quote)"
        if let attribution = attribution {
            label += ". Attribution: \(attribution)"
        }
        if sourceURL != nil {
            label += ". Link available."
        }
        return label
    }
}

// MARK: - Preference Key

private struct PullQuoteVisibilityKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - Previews

#Preview("Short Quote") {
    ScrollView {
        VStack(spacing: 40) {
            Text("Body text above the quote. This represents the editorial content that would precede a pull quote in a typical article layout.")
                .font(MarginTypography.body(size: 18))
                .foregroundColor(MarginColors.ink)
                .frame(maxWidth: 600, alignment: .leading)

            PullQuoteView(
                quote: "The emptiness is not absence but presence."
            )

            Text("Body text below the quote. The pull quote creates a natural pause in the reading experience, drawing attention to a key insight.")
                .font(MarginTypography.body(size: 18))
                .foregroundColor(MarginColors.ink)
                .frame(maxWidth: 600, alignment: .leading)
        }
        .padding(60)
    }
    .background(MarginColors.paper)
    .frame(width: 800, height: 600)
}

#Preview("With Attribution") {
    PullQuoteView(
        quote: "The details are not the details. They make the design.",
        attribution: "Charles Eames"
    )
    .padding(60)
    .background(MarginColors.paper)
    .frame(width: 700, height: 300)
}

#Preview("Long Quote with Link") {
    PullQuoteView(
        quote: "To communicate more, you must often say less. A single well-chosen word can resonate longer than a paragraph of explanation. A single gesture, placed with precision, can anchor an entire composition.",
        attribution: "The Discipline of Simplicity, Design Observer",
        sourceURL: URL(string: "https://designobserver.com")
    )
    .padding(60)
    .background(MarginColors.paper)
    .frame(width: 700, height: 400)
}

#Preview("Multiple Quotes in Context") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(0..<3) { i in
                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.")
                    .font(MarginTypography.body(size: 18))
                    .foregroundColor(MarginColors.ink)
                    .lineSpacing(8)
                    .frame(maxWidth: 600, alignment: .leading)
            }

            PullQuoteView(
                quote: "Design is not self-expression but communication.",
                attribution: "First principles",
                sourceURL: URL(string: "https://example.com")
            )

            ForEach(0..<3) { i in
                Text("Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident.")
                    .font(MarginTypography.body(size: 18))
                    .foregroundColor(MarginColors.ink)
                    .lineSpacing(8)
                    .frame(maxWidth: 600, alignment: .leading)
            }
        }
        .padding(60)
    }
    .background(MarginColors.paper)
    .frame(width: 800, height: 700)
}
