import Foundation
import AppKit

// MARK: - Canvas Model

struct Canvas: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: AttributedContent
    var images: [CanvasImage]
    var layoutMode: LayoutMode
    var typeSystem: TypeSystem
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String = "",
        content: AttributedContent = AttributedContent(),
        images: [CanvasImage] = [],
        layoutMode: LayoutMode = .essay,
        typeSystem: TypeSystem = .editorialSerif,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.images = images
        self.layoutMode = layoutMode
        self.typeSystem = typeSystem
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Attributed Content

struct AttributedContent: Codable, Equatable {
    var plainText: String
    private var attributeRuns: [AttributeRun]
    
    init(plainText: String = "", attributeRuns: [AttributeRun] = []) {
        self.plainText = plainText
        self.attributeRuns = attributeRuns
    }
    
    init(from textStorage: NSTextStorage) {
        self.init(attributedString: textStorage as NSAttributedString)
    }
    
    init(attributedString: NSAttributedString) {
        self.plainText = attributedString.string
        
        var runs: [AttributeRun] = []
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attrs, range, _ in
            var run = AttributeRun(range: range)
            
            if let font = attrs[.font] as? NSFont {
                run.fontName = font.fontName
                run.fontSize = font.pointSize
                
                let traits = NSFontManager.shared.traits(of: font)
                run.isBold = traits.contains(.boldFontMask)
                run.isItalic = traits.contains(.italicFontMask)
            }
            
            if let link = attrs[.link] as? URL {
                run.linkURL = link.absoluteString
            }
            
            runs.append(run)
        }
        
        self.attributeRuns = runs
    }
    
    var attributedString: NSAttributedString {
        toAttributedString(typeSystem: .editorialSerif)
    }
    
    func toAttributedString(typeSystem: TypeSystem) -> NSAttributedString {
        let result = NSMutableAttributedString(string: plainText)
        
        // Apply base styling
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: typeSystem.bodyFont,
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: typeSystem.bodyParagraphStyle
        ]
        
        if result.length > 0 {
            result.addAttributes(baseAttributes, range: NSRange(location: 0, length: result.length))
        }
        
        // Apply attribute runs
        for run in attributeRuns {
            guard run.range.location + run.range.length <= result.length else { continue }
            
            var font = typeSystem.bodyFont
            
            if let fontName = run.fontName, let fontSize = run.fontSize {
                font = NSFont(name: fontName, size: fontSize) ?? font
            }
            
            if run.isBold {
                font = font.bold
            }
            if run.isItalic {
                font = font.italic
            }
            
            result.addAttribute(.font, value: font, range: run.range)
            
            if let linkString = run.linkURL, let url = URL(string: linkString) {
                result.addAttribute(.link, value: url, range: run.range)
            }
        }
        
        return result
    }
    
    static func == (lhs: AttributedContent, rhs: AttributedContent) -> Bool {
        lhs.plainText == rhs.plainText
    }
}

// MARK: - Attribute Run

struct AttributeRun: Codable {
    var range: NSRange
    var fontName: String?
    var fontSize: CGFloat?
    var isBold: Bool = false
    var isItalic: Bool = false
    var linkURL: String?
    
    init(range: NSRange) {
        self.range = range
    }
    
    // Custom coding for NSRange
    enum CodingKeys: String, CodingKey {
        case location, length, fontName, fontSize, isBold, isItalic, linkURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let location = try container.decode(Int.self, forKey: .location)
        let length = try container.decode(Int.self, forKey: .length)
        self.range = NSRange(location: location, length: length)
        self.fontName = try container.decodeIfPresent(String.self, forKey: .fontName)
        self.fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize)
        self.isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
        self.isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
        self.linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range.location, forKey: .location)
        try container.encode(range.length, forKey: .length)
        try container.encodeIfPresent(fontName, forKey: .fontName)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(isItalic, forKey: .isItalic)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
    }
}

// MARK: - Canvas Image

struct CanvasImage: Identifiable, Codable {
    let id: UUID
    let filename: String
    var insertionIndex: Int
    var caption: String?
    
    init(id: UUID = UUID(), filename: String, insertionIndex: Int, caption: String? = nil) {
        self.id = id
        self.filename = filename
        self.insertionIndex = insertionIndex
        self.caption = caption
    }
}
