import Foundation
import SwiftUI

// MARK: - Layout Mode

enum LayoutMode: String, CaseIterable, Codable {
    case write
    case plan

    // Legacy case mappings for backward compatibility with saved files
    // These are decoded but immediately mapped to the new cases

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .write: return "Write"
        case .plan: return "Plan"
        }
    }

    var tagline: String {
        switch self {
        case .write: return "Focused Writing"
        case .plan: return "Spatial Thinking"
        }
    }

    var description: String {
        switch self {
        case .write: return "Full-featured writing with images, text wrapping, and rich formatting."
        case .plan: return "Freeform spatial canvas for exploration and arrangement."
        }
    }

    // MARK: - Mode Capabilities

    /// Whether inline media blocks are allowed
    var allowsInlineMedia: Bool {
        switch self {
        case .write: return true    // Full inline media support
        case .plan: return false    // Document is locked
        }
    }

    /// Whether freeform canvas objects are allowed
    var allowsFreeformCanvas: Bool {
        switch self {
        case .write: return false
        case .plan: return true     // Only mode with canvas layer
        }
    }

    /// Whether text wrapping around images is allowed
    var allowsTextWrapping: Bool {
        switch self {
        case .write: return true
        case .plan: return false
        }
    }

    /// Whether images can be resized inline
    var allowsImageResize: Bool {
        switch self {
        case .write: return true    // Resizable within page bounds
        case .plan: return false    // Document locked
        }
    }

    /// Whether image piles are allowed (stacked images with carousel navigation)
    var allowsImagePiles: Bool {
        switch self {
        case .write: return true
        case .plan: return true
        }
    }

    /// Whether block-level drag-and-drop reordering is enabled
    var allowsBlockDragDrop: Bool {
        switch self {
        case .write: return true
        case .plan: return false    // Document is locked in Plan mode
        }
    }

    /// Whether the document is rendered as a locked page object
    var documentIsLockedPage: Bool {
        switch self {
        case .write: return false
        case .plan: return true     // Document becomes fixed-width rectangle
        }
    }

    // MARK: - Layout Properties

    /// Maximum content width for document
    var maxWidth: CGFloat {
        switch self {
        case .write: return 680     // Comfortable reading measure
        case .plan: return 680      // Fixed page width in Plan
        }
    }

    /// Horizontal padding
    var horizontalPadding: CGFloat {
        switch self {
        case .write: return 80
        case .plan: return 40
        }
    }

    /// Vertical padding (top)
    var topPadding: CGFloat {
        switch self {
        case .write: return 80
        case .plan: return 40
        }
    }

    /// Paragraph spacing multiplier
    var paragraphSpacing: CGFloat {
        switch self {
        case .write: return 1.5
        case .plan: return 1.4
        }
    }

    /// Line height multiplier
    var lineHeightMultiple: CGFloat {
        switch self {
        case .write: return 1.6     // Best for reading
        case .plan: return 1.5
        }
    }

    /// Image margins
    var imageMargin: CGFloat {
        switch self {
        case .write: return 32
        case .plan: return 24
        }
    }

    // MARK: - Codable (with legacy support)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Map legacy values to new cases
        switch rawValue {
        case "essay", "brief", "write":
            self = .write
        case "scratch", "plan":
            self = .plan
        default:
            self = .write // Default fallback
        }
    }
}

// MARK: - Image Wrap Style

enum ImageWrapStyle: String, CaseIterable, Codable {
    case block      // Full width, no text wrap (default)
    case wrapLeft   // Image on left, text wraps right
    case wrapRight  // Image on right, text wraps left

    var displayName: String {
        switch self {
        case .block: return "Block"
        case .wrapLeft: return "Wrap Left"
        case .wrapRight: return "Wrap Right"
        }
    }
}

// MARK: - Image Orientation

enum ImageOrientation: String, Codable {
    case landscape  // width > height
    case portrait   // height > width
    case square     // width ≈ height (within 10%)

    static func detect(width: CGFloat, height: CGFloat) -> ImageOrientation {
        let ratio = width / height
        if ratio > 1.1 {
            return .landscape
        } else if ratio < 0.9 {
            return .portrait
        } else {
            return .square
        }
    }
}

// MARK: - Image Layout Preset

enum ImageLayoutPreset: String, CaseIterable, Codable {
    case compact    // Smallest size
    case medium     // Middle size
    case full       // Largest size

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .medium: return "Medium"
        case .full: return "Full"
        }
    }

    var iconName: String {
        switch self {
        case .compact: return "rectangle.center.inset.filled"
        case .medium: return "rectangle.inset.filled"
        case .full: return "rectangle.ratio.16.to.9.fill"
        }
    }

    /// Get width percentage based on image orientation
    func widthPercent(for orientation: ImageOrientation) -> CGFloat {
        switch (self, orientation) {
        // Landscape images (width > height)
        case (.compact, .landscape): return 50
        case (.medium, .landscape): return 75
        case (.full, .landscape): return 100

        // Portrait images (height > width)
        case (.compact, .portrait): return 25
        case (.medium, .portrait): return 33
        case (.full, .portrait): return 50

        // Square images
        case (.compact, .square): return 33
        case (.medium, .square): return 50
        case (.full, .square): return 66
        }
    }

    /// Detect current preset from width percentage and orientation
    static func detect(widthPercent: CGFloat, orientation: ImageOrientation) -> ImageLayoutPreset {
        let thresholds: [(preset: ImageLayoutPreset, maxPercent: CGFloat)]

        switch orientation {
        case .landscape:
            thresholds = [(.compact, 62.5), (.medium, 87.5), (.full, 100)]
        case .portrait:
            thresholds = [(.compact, 29), (.medium, 41.5), (.full, 100)]
        case .square:
            thresholds = [(.compact, 41.5), (.medium, 58), (.full, 100)]
        }

        for (preset, maxPercent) in thresholds {
            if widthPercent <= maxPercent {
                return preset
            }
        }
        return .full
    }
}
