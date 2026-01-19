import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var canvas: Canvas
    var onSlashCommand: ((CGPoint) -> Void)?
    var onImagePaste: ((NSImage) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = MarginTextView()
        textView.delegate = context.coordinator
        textView.slashCommandHandler = onSlashCommand
        textView.imagePasteHandler = onImagePaste
        
        // Configure text view
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        
        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // Set initial content
        let attributedString = canvas.content.toAttributedString(typeSystem: canvas.typeSystem)
        textView.textStorage?.setAttributedString(attributedString)
        
        scrollView.documentView = textView
        
        // Focus on first load
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarginTextView else { return }
        
        // Update typography settings if changed
        context.coordinator.updateTypography(textView: textView, typeSystem: canvas.typeSystem, layoutMode: canvas.layoutMode)
        
        // Update content if changed externally
        let currentText = textView.string
        if currentText != canvas.content.plainText && !context.coordinator.isEditing {
            let attributedString = canvas.content.toAttributedString(typeSystem: canvas.typeSystem)
            textView.textStorage?.setAttributedString(attributedString)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false
        private var lastTypeSystem: TypeSystem?
        private var lastLayoutMode: LayoutMode?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Update the canvas content
            if let textStorage = textView.textStorage {
                parent.canvas.content = AttributedContent(attributedString: textStorage)
            }
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Handle slash command
            if let text = replacementString, text == "/" {
                let insertionPoint = textView.selectedRange().location
                
                // Check if this is a new line or start of document
                let isNewLine = insertionPoint == 0 || 
                    (insertionPoint > 0 && (textView.string as NSString).character(at: insertionPoint - 1) == 10)
                
                if isNewLine {
                    // Calculate position for AI menu
                    if let layoutManager = textView.layoutManager,
                       let textContainer = textView.textContainer {
                        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: insertionPoint, length: 0), actualCharacterRange: nil)
                        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                        rect = textView.convert(rect, to: nil)
                        
                        if let window = textView.window {
                            let screenPoint = window.convertPoint(toScreen: rect.origin)
                            
                            DispatchQueue.main.async {
                                self.parent.onSlashCommand?(CGPoint(x: screenPoint.x + 140, y: screenPoint.y - 100))
                            }
                        }
                    }
                }
            }
            
            return true
        }
        
        func updateTypography(textView: NSTextView, typeSystem: TypeSystem, layoutMode: LayoutMode) {
            // Always update the type system reference for heading commands
            if let marginTextView = textView as? MarginTextView {
                marginTextView.currentTypeSystem = typeSystem
            }
            
            guard lastTypeSystem != typeSystem || lastLayoutMode != layoutMode else { return }
            
            lastTypeSystem = typeSystem
            lastLayoutMode = layoutMode
            
            // Update default typing attributes
            let paragraphStyle = typeSystem.bodyParagraphStyle(for: layoutMode)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: typeSystem.bodyFont,
                .foregroundColor: MarginColors.inkNS,
                .paragraphStyle: paragraphStyle
            ]
            
            textView.typingAttributes = attributes
            
            // Update existing text if not currently editing
            if !isEditing, let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
            }
        }
    }
}

// MARK: - Custom Text View

class MarginTextView: NSTextView {
    var slashCommandHandler: ((CGPoint) -> Void)?
    var imagePasteHandler: ((NSImage) -> Void)?
    var currentTypeSystem: TypeSystem = .modernSans
    
    // MARK: - Heading Commands (Notion-style: ⌥⌘1, ⌥⌘2, ⌥⌘3, ⌥⌘0)
    
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
    
    private enum TextStyle {
        case heading1
        case heading2
        case heading3
        case body
    }
    
    private func applyHeadingStyle(_ style: TextStyle) {
        guard let textStorage = textStorage else { return }
        
        // Get the paragraph range for the current selection/cursor
        let selectedRange = self.selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selectedRange)
        
        // Determine font and paragraph style based on heading level
        let font: NSFont
        let paragraphStyle = NSMutableParagraphStyle()
        
        switch style {
        case .heading1:
            font = currentTypeSystem.headingFont
            paragraphStyle.lineHeightMultiple = 1.2
            paragraphStyle.paragraphSpacingBefore = 24
            paragraphStyle.paragraphSpacing = 12
        case .heading2:
            font = currentTypeSystem.subheadingFont
            paragraphStyle.lineHeightMultiple = 1.3
            paragraphStyle.paragraphSpacingBefore = 20
            paragraphStyle.paragraphSpacing = 10
        case .heading3:
            // Use a size between subheading and body
            let size: CGFloat = 17
            switch currentTypeSystem {
            case .editorialSerif:
                font = NSFont(name: "Georgia-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
            case .modernSans:
                font = NSFont.systemFont(ofSize: size, weight: .semibold)
            case .technicalMono:
                font = NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
            case .humanistSans:
                font = NSFont(name: "Avenir Next Demi Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
            }
            paragraphStyle.lineHeightMultiple = 1.4
            paragraphStyle.paragraphSpacingBefore = 16
            paragraphStyle.paragraphSpacing = 8
        case .body:
            font = currentTypeSystem.bodyFont
            paragraphStyle.lineHeightMultiple = 1.5
            paragraphStyle.paragraphSpacing = 12
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.textColor
        ]
        
        // Apply to the entire paragraph
        textStorage.addAttributes(attributes, range: paragraphRange)
        
        // Update typing attributes for continued typing
        self.typingAttributes = attributes
    }
    
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        
        // Check for images first
        if let image = NSImage(pasteboard: pasteboard) {
            imagePasteHandler?(image)
            return
        }
        
        // Check for URLs
        if let urlString = pasteboard.string(forType: .string),
           let url = URL(string: urlString),
           url.scheme != nil {
            insertLink(url)
            return
        }
        
        // Default paste behavior
        super.paste(sender)
    }
    
    private func insertLink(_ url: URL) {
        let linkChip = createLinkChip(for: url)
        
        if let textStorage = self.textStorage {
            let range = selectedRange()
            textStorage.replaceCharacters(in: range, with: linkChip)
            setSelectedRange(NSRange(location: range.location + linkChip.length, length: 0))
        }
    }
    
    private func createLinkChip(for url: URL) -> NSAttributedString {
        let displayText = url.host ?? url.absoluteString
        
        let attributes: [NSAttributedString.Key: Any] = [
            .link: url,
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: self.font ?? NSFont.systemFont(ofSize: 14)
        ]
        
        return NSAttributedString(string: " \(displayText) ", attributes: attributes)
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle escape to dismiss any menus
        if event.keyCode == 53 { // Escape key
            // Post notification that can be observed
            NotificationCenter.default.post(name: .dismissAIMenu, object: nil)
        }
        
        super.keyDown(with: event)
    }
    
    // MARK: - Formatting Commands
    
    @IBAction func toggleBold(_ sender: Any?) {
        applyFontTrait(.boldFontMask)
    }
    
    @IBAction func toggleItalic(_ sender: Any?) {
        applyFontTrait(.italicFontMask)
    }
    
    private func applyFontTrait(_ trait: NSFontTraitMask) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
        guard range.length > 0 else { return }
        
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let font = value as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont: NSFont
                
                if fontManager.traits(of: font).contains(trait) {
                    newFont = fontManager.convert(font, toNotHaveTrait: trait)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: trait)
                }
                
                textStorage.addAttribute(.font, value: newFont, range: attrRange)
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let dismissAIMenu = Notification.Name("dismissAIMenu")
}
