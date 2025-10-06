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


