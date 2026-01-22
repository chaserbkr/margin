import SwiftUI
import WebKit

// MARK: - Image Model

struct PileImage: Codable, Identifiable, Equatable {
    let id: String
    let src: String
    var alt: String?

    init(id: String = UUID().uuidString, src: String, alt: String? = nil) {
        self.id = id
        self.src = src
        self.alt = alt
    }

    /// Create from a local file URL
    static func fromFileURL(_ url: URL, id: String? = nil) -> PileImage {
        PileImage(
            id: id ?? UUID().uuidString,
            src: url.absoluteString,
            alt: url.lastPathComponent
        )
    }

    /// Create from base64 encoded data
    static func fromData(_ data: Data, mimeType: String = "image/jpeg", id: String? = nil) -> PileImage {
        let base64 = data.base64EncodedString()
        return PileImage(
            id: id ?? UUID().uuidString,
            src: "data:\(mimeType);base64,\(base64)"
        )
    }

    /// Create from NSImage
    static func fromNSImage(_ image: NSImage, id: String? = nil) -> PileImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return fromData(jpegData, mimeType: "image/jpeg", id: id)
    }
}

// MARK: - Component State

struct ImagePileState: Codable {
    let images: [PileImage]
    let currentIndex: Int
    let count: Int
}

// MARK: - Event Types

enum ImagePileEvent {
    case ready(version: String)
    case imagesChanged(images: [PileImage], count: Int, currentIndex: Int)
    case imageSelected(index: Int, image: PileImage)
    case emptyStateClicked
    case error(message: String)
}

// MARK: - Theme Configuration

struct ImagePileTheme: Codable {
    var cardRadius: String?
    var arrowBg: String?
    var arrowColor: String?
    var dotColor: String?
    var dotActive: String?

    static let `default` = ImagePileTheme()

    static let dark = ImagePileTheme(
        arrowBg: "rgba(255, 255, 255, 0.1)",
        arrowColor: "rgba(255, 255, 255, 0.6)",
        dotColor: "rgba(255, 255, 255, 0.3)",
        dotActive: "rgba(255, 255, 255, 0.9)"
    )

    static let light = ImagePileTheme(
        arrowBg: "rgba(0, 0, 0, 0.1)",
        arrowColor: "rgba(0, 0, 0, 0.5)",
        dotColor: "rgba(0, 0, 0, 0.2)",
        dotActive: "rgba(0, 0, 0, 0.7)"
    )
}

// MARK: - SwiftUI View

struct ImagePileView: NSViewRepresentable {
    @Binding var images: [PileImage]
    var theme: ImagePileTheme = .default
    var onEvent: ((ImagePileEvent) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // Register message handlers
        let handlers = ["componentReady", "imagesChanged", "imageSelected", "emptyStateClicked", "error"]
        for handler in handlers {
            contentController.add(context.coordinator, name: handler)
        }

        config.userContentController = contentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background

        // Load the HTML component
        if let htmlPath = Bundle.main.path(forResource: "ImagePileComponent", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            // Fallback: Load from embedded HTML string
            loadEmbeddedHTML(webView)
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update images when binding changes
        context.coordinator.setImages(images)
        context.coordinator.setTheme(theme)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func loadEmbeddedHTML(_ webView: WKWebView) {
        // If HTML file isn't in bundle, you can embed it as a string
        // For now, log an error
        print("[ImagePileView] Warning: ImagePileComponent.html not found in bundle")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: ImagePileView
        weak var webView: WKWebView?
        private var isReady = false
        private var pendingImages: [PileImage]?
        private var pendingTheme: ImagePileTheme?

        init(_ parent: ImagePileView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }

            switch message.name {
            case "componentReady":
                isReady = true
                let version = body["version"] as? String ?? "unknown"
                parent.onEvent?(.ready(version: version))

                // Apply pending updates
                if let images = pendingImages {
                    setImages(images)
                    pendingImages = nil
                }
                if let theme = pendingTheme {
                    setTheme(theme)
                    pendingTheme = nil
                }

            case "imagesChanged":
                if let imagesData = body["images"] as? [[String: Any]],
                   let count = body["count"] as? Int,
                   let currentIndex = body["currentIndex"] as? Int {
                    let images = imagesData.compactMap { dict -> PileImage? in
                        guard let id = dict["id"] as? String,
                              let src = dict["src"] as? String else { return nil }
                        return PileImage(id: id, src: src, alt: dict["alt"] as? String)
                    }
                    parent.onEvent?(.imagesChanged(images: images, count: count, currentIndex: currentIndex))
                }

            case "imageSelected":
                if let index = body["index"] as? Int,
                   let imageDict = body["image"] as? [String: Any],
                   let id = imageDict["id"] as? String,
                   let src = imageDict["src"] as? String {
                    let image = PileImage(id: id, src: src, alt: imageDict["alt"] as? String)
                    parent.onEvent?(.imageSelected(index: index, image: image))
                }

            case "emptyStateClicked":
                parent.onEvent?(.emptyStateClicked)

            case "error":
                let message = body["message"] as? String ?? "Unknown error"
                parent.onEvent?(.error(message: message))

            default:
                break
            }
        }

        // MARK: - API Methods

        func setImages(_ images: [PileImage]) {
            guard isReady else {
                pendingImages = images
                return
            }

            guard let jsonData = try? JSONEncoder().encode(images),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let escaped = jsonString.replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript("ImagePileAPI.setImages('\(escaped)')")
        }

        func setTheme(_ theme: ImagePileTheme) {
            guard isReady else {
                pendingTheme = theme
                return
            }

            guard let jsonData = try? JSONEncoder().encode(theme),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let escaped = jsonString.replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript("ImagePileAPI.setTheme('\(escaped)')")
        }

        func addImage(_ image: PileImage) {
            guard isReady else { return }
            guard let jsonData = try? JSONEncoder().encode(image),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let escaped = jsonString.replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript("ImagePileAPI.addImage('\(escaped)')")
        }

        func removeImage(at index: Int) {
            guard isReady else { return }
            webView?.evaluateJavaScript("ImagePileAPI.removeImage(\(index))")
        }

        func removeCurrentImage() {
            guard isReady else { return }
            webView?.evaluateJavaScript("ImagePileAPI.removeCurrentImage()")
        }

        func goToIndex(_ index: Int) {
            guard isReady else { return }
            webView?.evaluateJavaScript("ImagePileAPI.goToIndex(\(index))")
        }

        func setEditMode(_ enabled: Bool) {
            guard isReady else { return }
            webView?.evaluateJavaScript("ImagePileAPI.setEditMode(\(enabled))")
        }

        func clear() {
            guard isReady else { return }
            webView?.evaluateJavaScript("ImagePileAPI.clear()")
        }

        func getState(completion: @escaping (ImagePileState?) -> Void) {
            guard isReady else {
                completion(nil)
                return
            }

            webView?.evaluateJavaScript("ImagePileAPI.getState()") { result, error in
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let state = try? JSONDecoder().decode(ImagePileState.self, from: data) else {
                    completion(nil)
                    return
                }
                completion(state)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ImagePileView(
        images: .constant([
            PileImage(src: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=450&fit=crop"),
            PileImage(src: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&h=450&fit=crop"),
            PileImage(src: "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600&h=450&fit=crop")
        ]),
        theme: .dark
    ) { event in
        switch event {
        case .ready(let version):
            print("Component ready: \(version)")
        case .imageSelected(let index, let image):
            print("Selected image \(index): \(image.id)")
        case .emptyStateClicked:
            print("Empty state clicked - show file picker")
        default:
            break
        }
    }
    .frame(width: 500, height: 400)
}
