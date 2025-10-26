import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Prefer Geo Sans Light for brand wordmark; fallback to a heavy Jost or system heavy
func geoSansFont(_ size: CGFloat) -> Font {
    #if canImport(UIKit)
    let candidates = [
        "GeosansLight",
        "GeoSansLight",
        "geosanslight"
    ]
    for name in candidates {
        if let uiFont = UIFont(name: name, size: size) {
            return Font(uiFont)
        }
    }
    #endif
    return jostFont(.heavy, size)
}

enum JostWeight {
    case heavy
    case bold
    case semi
    case medium
    case book
    case light
    case thin
    case hairline
}

// Resolve Jost by weight using common PostScript names; gracefully fall back to system weights
func jostFont(_ weight: JostWeight, _ size: CGFloat) -> Font {
    #if canImport(UIKit)
    let candidates: [String]
    switch weight {
    case .heavy:
        candidates = ["Jost-800-Heavy", "Jost-700-Bold"]
    case .bold:
        candidates = ["Jost-700-Bold", "Jost-Bold"]
    case .semi:
        candidates = ["Jost-600-Semi", "Jost-SemiBold"]
    case .medium:
        candidates = ["Jost-500-Medium", "Jost-Medium"]
    case .book:
        candidates = ["Jost-400-Book", "Jost-Book", "Jost-Regular"]
    case .light:
        candidates = ["Jost-300-Light", "Jost-Light"]
    case .thin:
        candidates = ["Jost-200-Thin", "Jost-Thin"]
    case .hairline:
        candidates = ["Jost-100-Hairline", "Jost-Hairline"]
    }
    for name in candidates {
        if let uiFont = UIFont(name: name, size: size) {
            return Font(uiFont)
        }
    }
    #endif
    let systemWeight: Font.Weight = {
        switch weight {
        case .heavy: return .heavy
        case .bold: return .bold
        case .semi: return .semibold
        case .medium: return .medium
        case .book: return .regular
        case .light: return .light
        case .thin: return .thin
        case .hairline: return .ultraLight
        }
    }()
    return .system(size: size, weight: systemWeight)
}

// Backward-compat helper
func jostHeavyFont(_ size: CGFloat) -> Font {
    jostFont(.heavy, size)
}

// MARK: - Semantic Font Styles

/// Semantic font styles with default sizes that can be customized
enum AppFont {
    /// Large title for main headings (default: 34pt, Heavy)
    case largeTitle(CGFloat? = nil)
    /// Title for section headings (default: 28pt, Bold)
    case title(CGFloat? = nil)
    /// Title 2 for subsection headings (default: 22pt, Bold)
    case title2(CGFloat? = nil)
    /// Title 3 for smaller headings (default: 20pt, Semi)
    case title3(CGFloat? = nil)
    /// Headline for emphasized text (default: 17pt, Semi)
    case headline(CGFloat? = nil)
    /// Subheadline for secondary emphasized text (default: 15pt, Medium)
    case subheadline(CGFloat? = nil)
    /// Body text for primary content (default: 17pt, Book)
    case body(CGFloat? = nil)
    /// Callout for highlighted content (default: 16pt, Book)
    case callout(CGFloat? = nil)
    /// Footnote for supplementary text (default: 13pt, Book)
    case footnote(CGFloat? = nil)
    /// Caption for labels and small text (default: 12pt, Book)
    case caption(CGFloat? = nil)
    /// Caption 2 for smallest text (default: 11pt, Book)
    case caption2(CGFloat? = nil)

    var font: Font {
        switch self {
        case .largeTitle(let size):
            return jostFont(.bold, size ?? 34)
        case .title(let size):
            return jostFont(.bold, size ?? 28)
        case .title2(let size):
            return jostFont(.bold, size ?? 22)
        case .title3(let size):
            return jostFont(.semi, size ?? 20)
        case .headline(let size):
            return jostFont(.semi, size ?? 17)
        case .subheadline(let size):
            return jostFont(.medium, size ?? 15)
        case .body(let size):
            return jostFont(.book, size ?? 17)
        case .callout(let size):
            return jostFont(.book, size ?? 16)
        case .footnote(let size):
            return jostFont(.book, size ?? 13)
        case .caption(let size):
            return jostFont(.book, size ?? 12)
        case .caption2(let size):
            return jostFont(.book, size ?? 11)
        }
    }
}

// MARK: - Geosans Font Styles

/// Semantic font styles using GeosansLight with default sizes
enum GeosansFont {
    /// Large title for main headings (default: 34pt)
    case largeTitle(CGFloat? = nil)
    /// Title for section headings (default: 28pt)
    case title(CGFloat? = nil)
    /// Title 2 for subsection headings (default: 22pt)
    case title2(CGFloat? = nil)
    /// Title 3 for smaller headings (default: 20pt)
    case title3(CGFloat? = nil)
    /// Headline for emphasized text (default: 17pt)
    case headline(CGFloat? = nil)
    /// Subheadline for secondary emphasized text (default: 15pt)
    case subheadline(CGFloat? = nil)
    /// Body text for primary content (default: 17pt)
    case body(CGFloat? = nil)
    /// Callout for highlighted content (default: 16pt)
    case callout(CGFloat? = nil)
    /// Footnote for supplementary text (default: 13pt)
    case footnote(CGFloat? = nil)
    /// Caption for labels and small text (default: 12pt)
    case caption(CGFloat? = nil)
    /// Caption 2 for smallest text (default: 11pt)
    case caption2(CGFloat? = nil)

    var font: Font {
        switch self {
        case .largeTitle(let size):
            return geoSansFont(size ?? 34)
        case .title(let size):
            return geoSansFont(size ?? 28)
        case .title2(let size):
            return geoSansFont(size ?? 22)
        case .title3(let size):
            return geoSansFont(size ?? 20)
        case .headline(let size):
            return geoSansFont(size ?? 17)
        case .subheadline(let size):
            return geoSansFont(size ?? 15)
        case .body(let size):
            return geoSansFont(size ?? 17)
        case .callout(let size):
            return geoSansFont(size ?? 16)
        case .footnote(let size):
            return geoSansFont(size ?? 13)
        case .caption(let size):
            return geoSansFont(size ?? 12)
        case .caption2(let size):
            return geoSansFont(size ?? 11)
        }
    }
}

// MARK: - Font Extension for Convenience

extension Font {
    /// Get a semantic Jost font style with optional custom size
    static func jost(_ style: AppFont) -> Font {
        style.font
    }

    /// Get a semantic GeosansLight font style with optional custom size
    static func geosans(_ style: GeosansFont) -> Font {
        style.font
    }
}


