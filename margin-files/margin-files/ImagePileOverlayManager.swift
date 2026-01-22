import AppKit
import WebKit

// MARK: - Image Pile Overlay Manager
// Manages WKWebView overlays for image piles in NSTextView

class ImagePileOverlayManager: NSObject {
    weak var textView: NSTextView?
    private var pileOverlays: [UUID: ImagePileOverlay] = [:]
    private var htmlContent: String?

    init(textView: NSTextView) {
        self.textView = textView
        super.init()
        loadHTMLContent()
        setupScrollObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        removeAllOverlays()
    }

    // MARK: - HTML Content Loading

    private func loadHTMLContent() {
        // Try to load from bundle first
        if let htmlPath = Bundle.main.path(forResource: "ImagePileComponent", ofType: "html"),
           let content = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            htmlContent = content
            return
        }

        // Fallback: embedded minimal HTML
        htmlContent = createEmbeddedHTML()
    }

    private func createEmbeddedHTML() -> String {
        // Minimal embedded version of the pile component
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: transparent; }
                .pile-container { position: relative; width: 100%; height: 100%; overflow: hidden; border-radius: 8px; }
                .pile-image { width: 100%; height: 100%; object-fit: cover; display: none; }
                .pile-image.active { display: block; }
                .pile-nav { position: absolute; bottom: 12px; left: 50%; transform: translateX(-50%); display: flex; gap: 6px; }
                .pile-dot { width: 8px; height: 8px; border-radius: 50%; background: rgba(255,255,255,0.4); cursor: pointer; transition: background 0.2s; }
                .pile-dot.active { background: rgba(255,255,255,0.9); }
                .pile-arrows { position: absolute; top: 50%; width: 100%; display: flex; justify-content: space-between; padding: 0 8px; transform: translateY(-50%); pointer-events: none; }
                .pile-arrow { width: 32px; height: 32px; border-radius: 50%; background: rgba(0,0,0,0.3); color: white; border: none; cursor: pointer; pointer-events: auto; display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity 0.2s; }
                .pile-container:hover .pile-arrow { opacity: 1; }
                .pile-count { position: absolute; top: 8px; right: 8px; background: rgba(0,0,0,0.5); color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="pile-container" id="container">
                <div class="pile-arrows">
                    <button class="pile-arrow" onclick="prev()">‹</button>
                    <button class="pile-arrow" onclick="next()">›</button>
                </div>
                <div class="pile-nav" id="nav"></div>
                <div class="pile-count" id="count"></div>
            </div>
            <script>
                let images = [];
                let currentIndex = 0;

                window.ImagePileAPI = {
                    setImages: function(jsonStr) {
                        images = JSON.parse(jsonStr);
                        render();
                    },
                    getState: function() {
                        return JSON.stringify({ images, currentIndex, count: images.length });
                    }
                };

                function render() {
                    const container = document.getElementById('container');
                    const nav = document.getElementById('nav');
                    const count = document.getElementById('count');

                    // Remove old images
                    container.querySelectorAll('.pile-image').forEach(el => el.remove());

                    // Add new images
                    images.forEach((img, i) => {
                        const imgEl = document.createElement('img');
                        imgEl.className = 'pile-image' + (i === currentIndex ? ' active' : '');
                        imgEl.src = img.src;
                        container.insertBefore(imgEl, container.firstChild);
                    });

                    // Update nav dots
                    nav.innerHTML = images.map((_, i) =>
                        `<div class="pile-dot${i === currentIndex ? ' active' : ''}" onclick="goTo(${i})"></div>`
                    ).join('');

                    // Update count
                    count.textContent = `${currentIndex + 1} / ${images.length}`;
                }

                function next() { goTo((currentIndex + 1) % images.length); }
                function prev() { goTo((currentIndex - 1 + images.length) % images.length); }
                function goTo(i) { currentIndex = i; render(); }

                // Signal ready
                window.webkit?.messageHandlers?.componentReady?.postMessage({ version: '1.0' });
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Scroll Synchronization

    private func setupScrollObserver() {
        guard let textView = textView,
              let scrollView = textView.enclosingScrollView else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        updateAllOverlayPositions()
    }

    // MARK: - Overlay Management

    /// Create a pile overlay at the specified character range
    func createPileOverlay(
        pileId: UUID,
        images: [NSImage],
        at characterRange: NSRange,
        size: NSSize
    ) -> ImagePileOverlay? {
        guard let textView = textView,
              let htmlContent = htmlContent else { return nil }

        // Create the overlay
        let overlay = ImagePileOverlay(
            pileId: pileId,
            htmlContent: htmlContent,
            size: size
        )

        // Set the images
        overlay.setImages(images)

        // Add to text view
        textView.addSubview(overlay.webView)

        // Position it
        if let frame = frameForCharacterRange(characterRange) {
            overlay.webView.frame = frame
        }

        // Store reference
        pileOverlays[pileId] = overlay
        overlay.characterRange = characterRange

        return overlay
    }

    /// Remove a pile overlay
    func removePileOverlay(pileId: UUID) {
        guard let overlay = pileOverlays[pileId] else { return }
        overlay.webView.removeFromSuperview()
        pileOverlays.removeValue(forKey: pileId)
    }

    /// Remove all overlays
    func removeAllOverlays() {
        for (_, overlay) in pileOverlays {
            overlay.webView.removeFromSuperview()
        }
        pileOverlays.removeAll()
    }

    /// Update position for a specific pile
    func updateOverlayPosition(pileId: UUID, characterRange: NSRange) {
        guard let overlay = pileOverlays[pileId],
              let frame = frameForCharacterRange(characterRange) else { return }

        overlay.webView.frame = frame
        overlay.characterRange = characterRange
    }

    /// Update all overlay positions (called on scroll/layout changes)
    func updateAllOverlayPositions() {
        for (_, overlay) in pileOverlays {
            if let range = overlay.characterRange,
               let frame = frameForCharacterRange(range) {
                overlay.webView.frame = frame
            }
        }
    }

    /// Get frame for a character range in text view coordinates
    private func frameForCharacterRange(_ range: NSRange) -> NSRect? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Offset by text container origin
        let origin = textView.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y

        return rect
    }

    /// Get overlay for a pile
    func overlay(for pileId: UUID) -> ImagePileOverlay? {
        return pileOverlays[pileId]
    }
}

// MARK: - Image Pile Overlay

class ImagePileOverlay: NSObject, WKScriptMessageHandler {
    let pileId: UUID
    let webView: WKWebView
    var characterRange: NSRange?
    private var isReady = false
    private var pendingImages: [NSImage]?

    init(pileId: UUID, htmlContent: String, size: NSSize) {
        self.pileId = pileId

        // Configure WKWebView
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        config.userContentController = contentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        super.init()

        // Register message handler
        contentController.add(self, name: "componentReady")

        // Load HTML content
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func setImages(_ images: [NSImage]) {
        guard isReady else {
            pendingImages = images
            return
        }

        // Convert NSImages to base64 data URLs
        let pileImages: [[String: Any]] = images.compactMap { image in
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
                return nil
            }
            let base64 = jpegData.base64EncodedString()
            return [
                "id": UUID().uuidString,
                "src": "data:image/jpeg;base64,\(base64)"
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: pileImages),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let escaped = jsonString.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("ImagePileAPI.setImages('\(escaped)')")
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "componentReady" {
            isReady = true
            if let images = pendingImages {
                setImages(images)
                pendingImages = nil
            }
        }
    }
}
