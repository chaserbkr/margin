import Foundation
import AppKit

// MARK: - Canvas Model

struct Canvas: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: AttributedContent
    var images: [CanvasImage]                          // Legacy support
    var mediaBlocks: [MediaBlock]                      // All media (single images + piles)
    var floatingImages: [FloatingImageData]            // Floating images with absolute positions
    var pullQuotes: [PullQuote]                        // Editorial pull quotes
    var canvasObjects: [FreeformCanvasObject]          // Scratch mode objects
    var layoutMode: LayoutMode
    var typeSystem: TypeSystem
    var enableTextWrapping: Bool                        // Document-level wrap toggle
    var isFavorite: Bool                               // Whether this document is favorited
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Backward Compatibility

    /// Computed property for backward compatibility - returns only single images
    var inlineMediaBlocks: [InlineMediaBlock] {
        get {
            mediaBlocks.compactMap {
                if case .single(let block) = $0 { return block }
                return nil
            }
        }
        set {
            // Replace all single blocks with new value, preserving piles
            let piles = mediaBlocks.filter { $0.isPile }
            mediaBlocks = newValue.map { .single($0) } + piles
            // Sort by insertion index
            mediaBlocks.sort { $0.insertionIndex < $1.insertionIndex }
        }
    }

    /// All image piles in the document
    var imagePiles: [ImagePile] {
        mediaBlocks.compactMap {
            if case .pile(let pile) = $0 { return pile }
            return nil
        }
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id, title, content, images, mediaBlocks, floatingImages, pullQuotes, inlineMediaBlocks, canvasObjects
        case layoutMode, typeSystem, enableTextWrapping, isFavorite, createdAt, updatedAt
    }

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        title: String = "",
        content: AttributedContent = AttributedContent(),
        images: [CanvasImage] = [],
        mediaBlocks: [MediaBlock] = [],
        floatingImages: [FloatingImageData] = [],
        pullQuotes: [PullQuote] = [],
        canvasObjects: [FreeformCanvasObject] = [],
        layoutMode: LayoutMode = .write,
        typeSystem: TypeSystem = .editorialSerif,
        enableTextWrapping: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.images = images
        self.mediaBlocks = mediaBlocks
        self.floatingImages = floatingImages
        self.pullQuotes = pullQuotes
        self.canvasObjects = canvasObjects
        self.layoutMode = layoutMode
        self.typeSystem = typeSystem
        self.enableTextWrapping = enableTextWrapping
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoder to handle backwards compatibility with older saved files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(AttributedContent.self, forKey: .content)
        layoutMode = try container.decode(LayoutMode.self, forKey: .layoutMode)
        typeSystem = try container.decode(TypeSystem.self, forKey: .typeSystem)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Optional fields with defaults for backwards compatibility
        images = try container.decodeIfPresent([CanvasImage].self, forKey: .images) ?? []
        canvasObjects = try container.decodeIfPresent([FreeformCanvasObject].self, forKey: .canvasObjects) ?? []
        enableTextWrapping = try container.decodeIfPresent(Bool.self, forKey: .enableTextWrapping) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false

        // Try to decode new mediaBlocks format first
        if let blocks = try container.decodeIfPresent([MediaBlock].self, forKey: .mediaBlocks) {
            mediaBlocks = blocks
        } else if let legacyBlocks = try container.decodeIfPresent([InlineMediaBlock].self, forKey: .inlineMediaBlocks) {
            // Migrate legacy inlineMediaBlocks to new mediaBlocks format
            mediaBlocks = legacyBlocks.map { .single($0) }
        } else {
            mediaBlocks = []
        }
        
        // Decode floating images (optional for backwards compatibility)
        floatingImages = try container.decodeIfPresent([FloatingImageData].self, forKey: .floatingImages) ?? []

        // Decode pull quotes (optional for backwards compatibility)
        pullQuotes = try container.decodeIfPresent([PullQuote].self, forKey: .pullQuotes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(layoutMode, forKey: .layoutMode)
        try container.encode(typeSystem, forKey: .typeSystem)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(images, forKey: .images)
        try container.encode(canvasObjects, forKey: .canvasObjects)
        try container.encode(enableTextWrapping, forKey: .enableTextWrapping)
        try container.encode(isFavorite, forKey: .isFavorite)

        // Encode new mediaBlocks format
        try container.encode(mediaBlocks, forKey: .mediaBlocks)
        
        // Encode floating images
        try container.encode(floatingImages, forKey: .floatingImages)

        // Encode pull quotes
        try container.encode(pullQuotes, forKey: .pullQuotes)

        // Also encode legacy format for backward compatibility with older app versions
        let legacyBlocks = inlineMediaBlocks
        try container.encode(legacyBlocks, forKey: .inlineMediaBlocks)
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

            // Capture pull quote attributes
            if let isPullQuote = attrs[NSAttributedString.Key(rawValue: "com.margin.pullQuoteMarker")] as? Bool {
                run.isPullQuote = isPullQuote
            }
            if let isPlaceholder = attrs[NSAttributedString.Key(rawValue: "com.margin.pullQuotePlaceholder")] as? Bool {
                run.isPullQuotePlaceholder = isPlaceholder
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

            // Restore pull quote attributes
            if run.isPullQuote {
                result.addAttribute(NSAttributedString.Key(rawValue: "com.margin.pullQuoteMarker"), value: true, range: run.range)

                // Restore pull quote font (Instrument Serif at 24pt)
                let quoteFont = NSFont(name: "InstrumentSerif-Regular", size: 24)
                    ?? NSFont(name: "Georgia-Italic", size: 24)
                    ?? NSFont.systemFont(ofSize: 24, weight: .regular)
                result.addAttribute(.font, value: quoteFont, range: run.range)

                // Also restore pull quote paragraph style
                let quoteParaStyle = NSMutableParagraphStyle()
                quoteParaStyle.paragraphSpacingBefore = 24
                quoteParaStyle.paragraphSpacing = 8
                quoteParaStyle.firstLineHeadIndent = 56
                quoteParaStyle.headIndent = 56
                quoteParaStyle.lineSpacing = 6
                result.addAttribute(.paragraphStyle, value: quoteParaStyle, range: run.range)
            }
            if run.isPullQuotePlaceholder {
                result.addAttribute(NSAttributedString.Key(rawValue: "com.margin.pullQuotePlaceholder"), value: true, range: run.range)
                // Placeholder text should be muted
                result.addAttribute(.foregroundColor, value: MarginColors.stone300NS, range: run.range)

                // Also set the font for placeholder
                let quoteFont = NSFont(name: "InstrumentSerif-Regular", size: 24)
                    ?? NSFont(name: "Georgia-Italic", size: 24)
                    ?? NSFont.systemFont(ofSize: 24, weight: .regular)
                result.addAttribute(.font, value: quoteFont, range: run.range)
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
    var isPullQuote: Bool = false
    var isPullQuotePlaceholder: Bool = false

    init(range: NSRange) {
        self.range = range
    }

    // Custom coding for NSRange
    enum CodingKeys: String, CodingKey {
        case location, length, fontName, fontSize, isBold, isItalic, linkURL
        case isPullQuote, isPullQuotePlaceholder
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
        self.isPullQuote = try container.decodeIfPresent(Bool.self, forKey: .isPullQuote) ?? false
        self.isPullQuotePlaceholder = try container.decodeIfPresent(Bool.self, forKey: .isPullQuotePlaceholder) ?? false
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
        try container.encode(isPullQuote, forKey: .isPullQuote)
        try container.encode(isPullQuotePlaceholder, forKey: .isPullQuotePlaceholder)
    }
}

// MARK: - Canvas Image (Legacy - being replaced by InlineMediaBlock)

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

// MARK: - Inline Media Block (IMB)
// Images that live inside document flow, participate in text layout rules

struct InlineMediaBlock: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String              // Persisted filename in storage
    var insertionIndex: Int           // Position in document flow (character index)
    var caption: String?

    // Image metadata
    var naturalWidth: CGFloat         // Original image width in pixels
    var naturalHeight: CGFloat        // Original image height in pixels
    var aspectRatio: CGFloat          // width / height for quick calculations

    // Display properties
    var displayWidthPercent: CGFloat  // Percentage of page width (default 33%)
    var wrapStyle: ImageWrapStyle     // Block, wrapLeft, wrapRight

    var createdAt: Date

    /// Computed orientation based on aspect ratio
    var orientation: ImageOrientation {
        ImageOrientation.detect(width: naturalWidth, height: naturalHeight)
    }

    /// Current layout preset based on width and orientation
    var layoutPreset: ImageLayoutPreset {
        ImageLayoutPreset.detect(widthPercent: displayWidthPercent, orientation: orientation)
    }

    /// Default width percentage for this image's orientation
    static func defaultWidthPercent(for orientation: ImageOrientation) -> CGFloat {
        // Default to "full" preset for landscape, "medium" for portrait/square
        switch orientation {
        case .landscape: return ImageLayoutPreset.full.widthPercent(for: .landscape)  // 100%
        case .portrait: return ImageLayoutPreset.medium.widthPercent(for: .portrait)  // 33%
        case .square: return ImageLayoutPreset.medium.widthPercent(for: .square)      // 50%
        }
    }

    init(
        id: UUID = UUID(),
        filename: String,
        insertionIndex: Int,
        caption: String? = nil,
        naturalWidth: CGFloat,
        naturalHeight: CGFloat,
        displayWidthPercent: CGFloat? = nil,  // nil = auto-detect based on orientation
        wrapStyle: ImageWrapStyle = .block,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.insertionIndex = insertionIndex
        self.caption = caption
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
        self.aspectRatio = naturalHeight > 0 ? naturalWidth / naturalHeight : 1.0

        // Auto-detect width based on orientation if not specified
        let orientation = ImageOrientation.detect(width: naturalWidth, height: naturalHeight)
        let resolvedWidth = displayWidthPercent ?? InlineMediaBlock.defaultWidthPercent(for: orientation)
        self.displayWidthPercent = min(100.0, max(15.0, resolvedWidth)) // Clamp 15-100%

        self.wrapStyle = wrapStyle
        self.createdAt = createdAt
    }
    
    /// Calculate display height for a given container width
    func displayHeight(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        let displayWidth = containerWidth * (displayWidthPercent / 100.0)
        return displayWidth / aspectRatio
    }
    
    /// Calculate display width for a given container width
    func displayWidth(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        return containerWidth * (displayWidthPercent / 100.0)
    }
}

// MARK: - Image Pile Item
// Individual image within a pile

struct ImagePileItem: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    var caption: String?
    var naturalWidth: CGFloat
    var naturalHeight: CGFloat

    var aspectRatio: CGFloat {
        naturalHeight > 0 ? naturalWidth / naturalHeight : 1.0
    }

    init(
        id: UUID = UUID(),
        filename: String,
        caption: String? = nil,
        naturalWidth: CGFloat,
        naturalHeight: CGFloat
    ) {
        self.id = id
        self.filename = filename
        self.caption = caption
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
    }

    /// Create from an existing InlineMediaBlock
    init(from block: InlineMediaBlock) {
        self.id = block.id
        self.filename = block.filename
        self.caption = block.caption
        self.naturalWidth = block.naturalWidth
        self.naturalHeight = block.naturalHeight
    }
}

// MARK: - Image Pile
// A pile of stacked images displayed as a carousel

struct ImagePile: Identifiable, Codable, Equatable {
    let id: UUID
    var images: [ImagePileItem]          // Ordered list of images in the pile
    var insertionIndex: Int              // Position in document flow (character index)
    var displayWidthPercent: CGFloat     // Size of the pile display (25-100%)
    var currentIndex: Int                // Currently visible image in the pile
    var createdAt: Date

    init(
        id: UUID = UUID(),
        images: [ImagePileItem],
        insertionIndex: Int,
        displayWidthPercent: CGFloat = 50.0,
        currentIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.images = images
        self.insertionIndex = insertionIndex
        self.displayWidthPercent = min(100.0, max(25.0, displayWidthPercent))
        self.currentIndex = min(max(0, currentIndex), max(0, images.count - 1))
        self.createdAt = createdAt
    }

    /// Calculate display height for a given container width (uses first image aspect ratio)
    func displayHeight(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        guard let firstImage = images.first else { return 200 }
        let displayWidth = containerWidth * (displayWidthPercent / 100.0)
        return displayWidth / firstImage.aspectRatio
    }

    /// Calculate display width for a given container width
    func displayWidth(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        return containerWidth * (displayWidthPercent / 100.0)
    }

    /// The currently displayed image
    var currentImage: ImagePileItem? {
        guard currentIndex >= 0 && currentIndex < images.count else { return images.first }
        return images[currentIndex]
    }
}

// MARK: - Floating Image Data
// Floating images with absolute positions that text flows around

struct FloatingImageData: Identifiable, Codable, Equatable {
    let id: UUID
    var images: [FloatingImageItem]    // Array of images (1 for single, 2+ for pile)
    var currentIndex: Int              // Currently visible image in pile
    var positionX: CGFloat             // X position in text view coordinates
    var positionY: CGFloat             // Y position in text view coordinates
    var width: CGFloat                 // Display width
    var height: CGFloat                // Display height
    var originalWidth: CGFloat         // Original image width
    var originalHeight: CGFloat        // Original image height
    var caption: String?               // Optional caption text
    var createdAt: Date
    
    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set { positionX = newValue.x; positionY = newValue.y }
    }
    
    var size: CGSize {
        get { CGSize(width: width, height: height) }
        set { width = newValue.width; height = newValue.height }
    }
    
    var originalSize: CGSize {
        get { CGSize(width: originalWidth, height: originalHeight) }
        set { originalWidth = newValue.width; originalHeight = newValue.height }
    }
    
    var isPile: Bool { images.count > 1 }
    
    init(
        id: UUID = UUID(),
        images: [FloatingImageItem],
        currentIndex: Int = 0,
        position: CGPoint,
        size: CGSize,
        originalSize: CGSize,
        caption: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.images = images
        self.currentIndex = currentIndex
        self.positionX = position.x
        self.positionY = position.y
        self.width = size.width
        self.height = size.height
        self.originalWidth = originalSize.width
        self.originalHeight = originalSize.height
        self.caption = caption
        self.createdAt = createdAt
    }
}

// MARK: - Floating Image Item
// Individual image within a floating image/pile

struct FloatingImageItem: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String               // Persisted filename in storage
    var naturalWidth: CGFloat          // Original image width in pixels
    var naturalHeight: CGFloat         // Original image height in pixels
    
    var aspectRatio: CGFloat {
        naturalHeight > 0 ? naturalWidth / naturalHeight : 1.0
    }
    
    init(
        id: UUID = UUID(),
        filename: String,
        naturalWidth: CGFloat,
        naturalHeight: CGFloat
    ) {
        self.id = id
        self.filename = filename
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
    }
}

// MARK: - Media Block
// A media block can be a single image or a pile of images

enum MediaBlock: Identifiable, Codable, Equatable {
    case single(InlineMediaBlock)
    case pile(ImagePile)

    var id: UUID {
        switch self {
        case .single(let block): return block.id
        case .pile(let pile): return pile.id
        }
    }

    var insertionIndex: Int {
        get {
            switch self {
            case .single(let block): return block.insertionIndex
            case .pile(let pile): return pile.insertionIndex
            }
        }
        set {
            switch self {
            case .single(var block):
                block.insertionIndex = newValue
                self = .single(block)
            case .pile(var pile):
                pile.insertionIndex = newValue
                self = .pile(pile)
            }
        }
    }

    var displayWidthPercent: CGFloat {
        get {
            switch self {
            case .single(let block): return block.displayWidthPercent
            case .pile(let pile): return pile.displayWidthPercent
            }
        }
        set {
            switch self {
            case .single(var block):
                block.displayWidthPercent = newValue
                self = .single(block)
            case .pile(var pile):
                pile.displayWidthPercent = newValue
                self = .pile(pile)
            }
        }
    }

    /// Calculate display height for a given container width
    func displayHeight(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        switch self {
        case .single(let block): return block.displayHeight(forContainerWidth: containerWidth)
        case .pile(let pile): return pile.displayHeight(forContainerWidth: containerWidth)
        }
    }

    /// Calculate display width for a given container width
    func displayWidth(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        switch self {
        case .single(let block): return block.displayWidth(forContainerWidth: containerWidth)
        case .pile(let pile): return pile.displayWidth(forContainerWidth: containerWidth)
        }
    }

    /// Whether this is a pile (contains multiple images)
    var isPile: Bool {
        if case .pile(_) = self { return true }
        return false
    }

    /// Number of images in this media block
    var imageCount: Int {
        switch self {
        case .single(_): return 1
        case .pile(let pile): return pile.images.count
        }
    }
}

// MARK: - Freeform Canvas Object (FCO)
// Absolutely positioned objects that exist only in Scratch mode

struct FreeformCanvasObject: Identifiable, Codable {
    let id: UUID
    var objectType: CanvasObjectType
    var position: CGPoint            // Absolute position on canvas
    var size: CGSize                 // Object dimensions
    var content: String              // Text content (for notes/textboxes)
    var imageFilename: String?       // For image objects
    var zIndex: Int                  // Stacking order
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        objectType: CanvasObjectType,
        position: CGPoint,
        size: CGSize,
        content: String = "",
        imageFilename: String? = nil,
        zIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.objectType = objectType
        self.position = position
        self.size = size
        self.content = content
        self.imageFilename = imageFilename
        self.zIndex = zIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum CanvasObjectType: String, Codable {
    case stickyNote
    case textBox
    case image
}

// MARK: - Pull Quote
// Editorial pull quotes that appear inline in the document

struct PullQuote: Identifiable, Codable, Equatable {
    let id: UUID
    var quote: String                    // The pull quote text
    var attribution: String?             // Optional author/source attribution
    var sourceURL: URL?                  // Optional link for the attribution
    var insertionIndex: Int              // Position in document flow (character index)
    var createdAt: Date

    init(
        id: UUID = UUID(),
        quote: String,
        attribution: String? = nil,
        sourceURL: URL? = nil,
        insertionIndex: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.quote = quote
        self.attribution = attribution
        self.sourceURL = sourceURL
        self.insertionIndex = insertionIndex
        self.createdAt = createdAt
    }
}

// Note: CGPoint and CGSize are already Codable in modern Swift
