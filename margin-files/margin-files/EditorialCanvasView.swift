import SwiftUI
import AppKit

struct EditorialCanvasView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var canvas: Canvas
    @State private var showFloatingToolbar = true
    @State private var isBold = false
    @State private var isItalic = false
    @FocusState private var isTitleFocused: Bool
    @State private var bodyEditorRef: EditorialNSTextView?

    private var typeSystem: TypeSystem {
        canvas.typeSystem
    }

    private var maxWidth: CGFloat {
        switch canvas.layoutMode {
        case .essay: return 700
        case .brief: return 800
        case .scratch: return 900
        }
    }

    var body: some View {
        ZStack {
            // Background
            MarginColors.paper

            // Subtle margin guides (like the HTML design)
            GeometryReader { _ in
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(MarginColors.ink.opacity(0.02))
                        .frame(width: 1)
                    Spacer()
                        .frame(width: maxWidth - 2)
                    Rectangle()
                        .fill(MarginColors.ink.opacity(0.02))
                        .frame(width: 1)
                    Spacer()
                }
            }

            // Main scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title area
                    TitleEditorView(
                        title: $canvas.title,
                        typeSystem: typeSystem,
                        onSubmit: {
                            // Move focus to body editor when Enter is pressed
                            isTitleFocused = false
                            DispatchQueue.main.async {
                                bodyEditorRef?.window?.makeFirstResponder(bodyEditorRef)
                            }
                        }
                    )
                    .focused($isTitleFocused)
                    .padding(.top, 80)

                    // Editorial metadata bar
                    EditorialMetadataBar(canvas: canvas)
                        .padding(.vertical, 32)

                    // Main text editor
                    EditorialTextEditor(
                        content: $canvas.content,
                        typeSystem: typeSystem,
                        layoutMode: canvas.layoutMode,
                        textViewRef: $bodyEditorRef
                    )
                    .frame(minHeight: 300)

                    // Bottom spacing
                    Spacer()
                        .frame(height: 160)
                }
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }

            // Floating toolbar at bottom
            if showFloatingToolbar {
                VStack {
                    Spacer()
                    FloatingToolbar(
                        typeSystem: $canvas.typeSystem,
                        isBold: $isBold,
                        isItalic: $isItalic
                    )
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Title Editor

struct TitleEditorView: View {
    @Binding var title: String
    let typeSystem: TypeSystem
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        TextField("Untitled", text: $title)
            .textFieldStyle(.plain)
            .font(MarginTypography.display(size: 48))
            .foregroundColor(MarginColors.ink)
            .onSubmit {
                onSubmit?()
            }
    }
}

// MARK: - Editorial Metadata Bar

struct EditorialMetadataBar: View {
    let canvas: Canvas
    
    private var wordCount: Int {
        canvas.content.plainText.split(separator: " ").count
    }
    
    private var readingTime: Int {
        max(1, wordCount / 200)
    }
    
    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text("\(readingTime) min read")
            }
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(canvas.updatedAt, style: .date)
            }
            
            Spacer()

            Text("DRAFT 03")
                .font(MarginTypography.ui(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(MarginColors.stone300)
        }
        .font(MarginTypography.ui(size: 12, weight: .medium))
        .tracking(1)
        .foregroundColor(MarginColors.stone400)
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            MarginDivider()
        }
        .overlay(alignment: .bottom) {
            MarginDivider()
        }
    }
}

// MARK: - Editorial Text Editor

struct EditorialTextEditor: NSViewRepresentable {
    @Binding var content: AttributedContent
    let typeSystem: TypeSystem
    let layoutMode: LayoutMode
    @Binding var textViewRef: EditorialNSTextView?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = EditorialNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 8)

        // Configure text container
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Set default typing attributes
        textView.typingAttributes = defaultAttributes

        // Set initial content
        let attributedString = content.toAttributedString(typeSystem: typeSystem)
        textView.textStorage?.setAttributedString(attributedString)

        textView.currentTypeSystem = typeSystem
        context.coordinator.textView = textView
        context.coordinator.lastKnownContent = content.plainText

        // Store reference for external access
        DispatchQueue.main.async {
            self.textViewRef = textView
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorialNSTextView else { return }

        textView.currentTypeSystem = typeSystem
        textView.typingAttributes = defaultAttributes

        // Check if type system changed - reapply styling to existing text
        if context.coordinator.lastTypeSystem != typeSystem {
            context.coordinator.lastTypeSystem = typeSystem
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttributes(defaultAttributes, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        // Check if the content changed externally (document switch)
        let currentTextViewContent = textView.string
        let bindingContent = content.plainText

        // If the binding content differs from both what's in the text view AND what we last knew,
        // it means the document was switched externally
        if bindingContent != currentTextViewContent && bindingContent != context.coordinator.lastKnownContent {
            let attributedString = content.toAttributedString(typeSystem: typeSystem)
            textView.textStorage?.setAttributedString(attributedString)
            context.coordinator.lastKnownContent = bindingContent
        }

        // Update reference if needed
        if textViewRef !== textView {
            DispatchQueue.main.async {
                self.textViewRef = textView
            }
        }
    }

    private var defaultAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.65
        paragraphStyle.paragraphSpacing = 20

        return [
            .font: typeSystem.bodyFont,
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: paragraphStyle
        ]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, typeSystem: typeSystem)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var content: AttributedContent
        var typeSystem: TypeSystem
        var lastTypeSystem: TypeSystem
        weak var textView: EditorialNSTextView?
        var lastKnownContent: String = ""

        init(content: Binding<AttributedContent>, typeSystem: TypeSystem) {
            _content = content
            self.typeSystem = typeSystem
            self.lastTypeSystem = typeSystem
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }

            let newContent = AttributedContent(from: textStorage)
            content = newContent
            lastKnownContent = newContent.plainText
        }
    }
}

// MARK: - Custom NSTextView

class EditorialNSTextView: NSTextView {
    var currentTypeSystem: TypeSystem = .editorialSerif
    var slashCommandHandler: ((CGPoint) -> Void)?
    private var placeholderString = "Start writing..."

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw placeholder text when empty
        if string.isEmpty && self.window?.firstResponder != self {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: currentTypeSystem.bodyFont,
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let inset = textContainerInset
            let rect = NSRect(x: inset.width + 5, y: inset.height, width: bounds.width - inset.width * 2, height: bounds.height)
            placeholderString.draw(in: rect, withAttributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Ensure we become first responder on click
        window?.makeFirstResponder(self)
    }
    
    // MARK: - Heading Commands
    
    @objc func applyHeading1(_ sender: Any?) {
        applyHeadingStyle(.heading1)
    }
    
    @objc func applyHeading2(_ sender: Any?) {
        applyHeadingStyle(.heading2)
    }
    
    @objc func applyHeading3(_ sender: Any?) {
        applyHeadingStyle(.heading3)
    }
    
    @objc func applyBodyStyle(_ sender: Any?) {
        applyHeadingStyle(.body)
    }
    
    @objc func toggleBold(_ sender: Any?) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
        if range.length > 0 {
            let currentFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? currentTypeSystem.bodyFont
            let fontManager = NSFontManager.shared
            let newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: newFont, range: range)
        } else {
            var attrs = typingAttributes
            if let currentFont = attrs[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                attrs[.font] = newFont
                typingAttributes = attrs
            }
        }
    }
    
    @objc func toggleItalic(_ sender: Any?) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
        if range.length > 0 {
            let currentFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? currentTypeSystem.bodyFont
            let fontManager = NSFontManager.shared
            let newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: newFont, range: range)
        } else {
            var attrs = typingAttributes
            if let currentFont = attrs[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                attrs[.font] = newFont
                typingAttributes = attrs
            }
        }
    }
    
    private enum TextStyle {
        case heading1
        case heading2
        case heading3
        case body
    }
    
    private func applyHeadingStyle(_ style: TextStyle) {
        guard let textStorage = textStorage else { return }
        
        let selectedRange = self.selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selectedRange)
        
        let font: NSFont
        let paragraphStyle = NSMutableParagraphStyle()
        
        switch style {
        case .heading1:
            font = NSFont(name: "Georgia-Italic", size: 40) ?? NSFont.boldSystemFont(ofSize: 40)
            paragraphStyle.lineHeightMultiple = 1.1
            paragraphStyle.paragraphSpacingBefore = 32
            paragraphStyle.paragraphSpacing = 16
        case .heading2:
            font = NSFont(name: "Georgia-Bold", size: 28) ?? NSFont.boldSystemFont(ofSize: 28)
            paragraphStyle.lineHeightMultiple = 1.2
            paragraphStyle.paragraphSpacingBefore = 24
            paragraphStyle.paragraphSpacing = 12
        case .heading3:
            font = NSFont(name: "Georgia-Bold", size: 20) ?? NSFont.boldSystemFont(ofSize: 20)
            paragraphStyle.lineHeightMultiple = 1.3
            paragraphStyle.paragraphSpacingBefore = 20
            paragraphStyle.paragraphSpacing = 10
        case .body:
            font = currentTypeSystem.bodyFont
            paragraphStyle.lineHeightMultiple = 1.65
            paragraphStyle.paragraphSpacing = 20
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor(MarginColors.ink)
        ]
        
        textStorage.addAttributes(attributes, range: paragraphRange)
        typingAttributes = attributes
    }
}

// MARK: - Floating Toolbar

struct FloatingToolbar: View {
    @Binding var typeSystem: TypeSystem
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            // Type system selector
            HStack(spacing: 4) {
                // Serif option
                Button {
                    typeSystem = .editorialSerif
                } label: {
                    Text("Aa")
                        .font(.custom("Georgia-Italic", size: 16))
                }
                .buttonStyle(MarginIconButtonStyle(isActive: typeSystem == .editorialSerif))
                .help("Editorial Serif")
                
                // Sans option
                Button {
                    typeSystem = .modernSans
                } label: {
                    Text("Aa")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(MarginIconButtonStyle(isActive: typeSystem == .modernSans))
                .help("Modern Sans")
            }
            .padding(.trailing, 8)
            
            MarginDivider(vertical: true)
                .frame(height: 20)
            
            // Formatting tools
            HStack(spacing: 4) {
                Button {
                    NSApp.sendAction(#selector(EditorialNSTextView.toggleBold(_:)), to: nil, from: nil)
                } label: {
                    Image(systemName: "bold")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(MarginIconButtonStyle(isActive: isBold))
                
                Button {
                    NSApp.sendAction(#selector(EditorialNSTextView.toggleItalic(_:)), to: nil, from: nil)
                } label: {
                    Image(systemName: "italic")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(MarginIconButtonStyle(isActive: isItalic))
                
                Button {
                    // Strikethrough
                } label: {
                    Image(systemName: "strikethrough")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(MarginIconButtonStyle())
                
                Button {
                    // Link
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(MarginIconButtonStyle())
            }
            .padding(.horizontal, 8)
            
            MarginDivider(vertical: true)
                .frame(height: 20)
            
            // AI assist
            Button {
                // AI assist
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MarginColors.purple700.opacity(0.7))
            }
            .buttonStyle(MarginIconButtonStyle())
            .padding(.leading, 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .background(
                    Capsule()
                        .fill(MarginColors.paper.opacity(0.9))
                )
        )
        .overlay(
            Capsule()
                .stroke(MarginColors.stone200.opacity(0.5), lineWidth: 1)
        )
        .floatShadow()
    }
}

#Preview {
    EditorialCanvasView(canvas: .constant(Canvas(
        title: "The Architecture of Thought",
        layoutMode: .essay,
        typeSystem: .editorialSerif
    )))
}
