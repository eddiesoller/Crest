import SwiftUI

// MARK: - Types

struct BrowserSidebarTabFaviconReturnAppearance: Equatable {
    var isTarget = false
    var isLit = false
    var inset: CGFloat = 0
}

extension EnvironmentValues {
    @Entry var sidebarTabFaviconReturn = BrowserSidebarTabFaviconReturnAppearance()
}

/// Lights a saved tab's favicon while a click on it returns the tab to its saved URL.
struct BrowserSidebarTabFaviconReturnTarget: ViewModifier {
    // MARK: - Static Variables

    /// The gap before the saved-location indicator.
    private static let maximumInset: CGFloat = 3

    // MARK: - Variables

    let restore: (() -> Void)?
    let isSuppressed: Bool
    let scale: Double

    @Environment(\.tabFaviconIsReplaced) private var isReplaced
    @State private var isHovering = false

    private var target: (() -> Void)? { isReplaced ? nil : restore }
    private var inset: CGFloat { min(Self.maximumInset * scale, Self.maximumInset) }

    func body(content: Content) -> some View {
        content
            .environment(
                \.sidebarTabFaviconReturn,
                BrowserSidebarTabFaviconReturnAppearance(
                    isTarget: target != nil, isLit: target != nil && isHovering && !isSuppressed, inset: inset)
            )
            .contentShape(Rectangle().inset(by: -inset))
            .onHover { isHovering = $0 }
            .simultaneousGesture(
                TapGesture().onEnded { target?() },
                including: target == nil ? .none : .all
            )
    }
}

#if DEBUG
    #Preview("Return target") {
        let tab = BrowserSidebarTabRowPreviewFixture.tab(placement: .saved)
        let favicons = FaviconAssets()
        HStack(spacing: 24) {
            ForEach([false, true], id: \.self) { isLit in
                BrowserSidebarTabFaviconContent(
                    tab: tab, favicons: favicons, profileID: BrowserSidebarTabRowPreviewFixture.profileID,
                    metrics: .pointer, iconScale: 1
                )
                .environment(
                    \.sidebarTabFaviconReturn,
                    BrowserSidebarTabFaviconReturnAppearance(isTarget: true, isLit: isLit, inset: 3))
            }
        }
        .padding()
    }
#endif
