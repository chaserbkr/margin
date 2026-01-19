import Foundation
import AppKit
import SwiftUI

enum TypeSystem: String, CaseIterable, Codable {
    case editorialSerif
    case modernSans
    case technicalMono
    case humanistSans
    
    var displayName: String {
        switch self {
        case .editorialSerif: return "Editorial Serif"
        case .modernSans: return "Modern Sans"
        case .technicalMono: return "Technical Mono"
        case .humanistSans: return "Humanist Sans"
        }
    }
    
    var description: String {
        switch self {
        case .editorialSerif: return "Classic, refined typography for long-form writing"
        case .modernSans: return "Clean, contemporary feel for modern documents"
        case .technicalMono: return "Precise, structured for technical content"
        case .humanistSans: return "Warm, approachable for creative work"
        }
    }
    
    // MARK: - Fonts
    
    var bodyFont: NSFont {
        let size: CGFloat = 19
        switch self {
        case .editorialSerif:
            return NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
        case .modernSans:
            return NSFont.systemFont(ofSize: size, weight: .regular)
        case .technicalMono:
            return NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        case .humanistSans:
            return NSFont(name: "Avenir Next", size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }
    
    var headingFont: NSFont {
        let size: CGFloat = 28
        switch self {
        case .editorialSerif:
            return NSFont(name: "Georgia-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
        case .modernSans:
            return NSFont.systemFont(ofSize: size, weight: .semibold)
        case .technicalMono:
            return NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        case .humanistSans:
            return NSFont(name: "Avenir Next Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
        }
    }
    
    var subheadingFont: NSFont {
        let size: CGFloat = 20
        switch self {
        case .editorialSerif:
            return NSFont(name: "Georgia-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
        case .modernSans:
            return NSFont.systemFont(ofSize: size, weight: .medium)
        case .technicalMono:
            return NSFont.monospacedSystemFont(ofSize: 18, weight: .semibold)
        case .humanistSans:
            return NSFont(name: "Avenir Next Demi Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        }
    }
    
    var captionFont: NSFont {
        let size: CGFloat = 13
        switch self {
        case .editorialSerif:
            return NSFont(name: "Georgia-Italic", size: size) ?? NSFont.systemFont(ofSize: size)
        case .modernSans:
            return NSFont.systemFont(ofSize: size, weight: .light)
        case .technicalMono:
            return NSFont.monospacedSystemFont(ofSize: 12, weight: .light)
        case .humanistSans:
            return NSFont(name: "Avenir Next", size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }
    
    // MARK: - SwiftUI Fonts
    
    var swiftUIBodyFont: Font {
        switch self {
        case .editorialSerif:
            return .custom("Georgia", size: 19)
        case .modernSans:
            return .system(size: 19, weight: .regular)
        case .technicalMono:
            return .system(size: 14, weight: .regular, design: .monospaced)
        case .humanistSans:
            return .custom("Avenir Next", size: 16)
        }
    }
    
    var swiftUIHeadingFont: Font {
        switch self {
        case .editorialSerif:
            return .custom("Georgia-Bold", size: 28)
        case .modernSans:
            return .system(size: 28, weight: .semibold)
        case .technicalMono:
            return .system(size: 24, weight: .bold, design: .monospaced)
        case .humanistSans:
            return .custom("Avenir Next Bold", size: 28)
        }
    }
    
    // MARK: - Paragraph Styles
    
    var bodyParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.5
        style.paragraphSpacing = 12
        return style
    }
    
    func bodyParagraphStyle(for layout: LayoutMode) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = layout.lineHeightMultiple
        style.paragraphSpacing = 12 * layout.paragraphSpacing
        return style
    }
    
    var headingParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.2
        style.paragraphSpacingBefore = 24
        style.paragraphSpacing = 8
        return style
    }
    
    // MARK: - Text Colors

    var textColor: NSColor {
        return MarginColors.inkNS
    }

    var secondaryTextColor: NSColor {
        return NSColor(red: 0x73/255.0, green: 0x73/255.0, blue: 0x6D/255.0, alpha: 1.0) // stone500
    }
}

// MARK: - Font Extensions

extension NSFont {
    func withTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
    
    var bold: NSFont {
        return withTraits(.bold)
    }
    
    var italic: NSFont {
        return withTraits(.italic)
    }
}
