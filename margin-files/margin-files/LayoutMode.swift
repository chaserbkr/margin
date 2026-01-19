import Foundation
import SwiftUI

enum LayoutMode: String, CaseIterable, Codable {
    case essay
    case brief
    case scratch
    
    var displayName: String {
        switch self {
        case .essay: return "Essay"
        case .brief: return "Brief"
        case .scratch: return "Scratch"
        }
    }
    
    var description: String {
        switch self {
        case .essay: return "Long-form writing with generous margins"
        case .brief: return "Structured notes with tighter spacing"
        case .scratch: return "Quick capture with minimal formatting"
        }
    }
    
    // Maximum content width
    var maxWidth: CGFloat {
        switch self {
        case .essay: return 680
        case .brief: return 720
        case .scratch: return 800
        }
    }
    
    // Horizontal padding
    var horizontalPadding: CGFloat {
        switch self {
        case .essay: return 80
        case .brief: return 60
        case .scratch: return 40
        }
    }
    
    // Vertical padding (top)
    var topPadding: CGFloat {
        switch self {
        case .essay: return 80
        case .brief: return 60
        case .scratch: return 40
        }
    }
    
    // Paragraph spacing multiplier
    var paragraphSpacing: CGFloat {
        switch self {
        case .essay: return 1.5
        case .brief: return 1.2
        case .scratch: return 1.0
        }
    }
    
    // Line height multiplier
    var lineHeightMultiple: CGFloat {
        switch self {
        case .essay: return 1.6
        case .brief: return 1.5
        case .scratch: return 1.4
        }
    }
    
    // Image margins
    var imageMargin: CGFloat {
        switch self {
        case .essay: return 32
        case .brief: return 24
        case .scratch: return 16
        }
    }
}
