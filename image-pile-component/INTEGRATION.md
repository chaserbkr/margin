# Image Pile Component - macOS Integration Guide

## Files

- **`ImagePileComponent.html`** - The web component (add to your app bundle)
- **`ImagePileView.swift`** - SwiftUI wrapper with full API

## Quick Start

### 1. Add files to your Xcode project

1. Drag `ImagePileComponent.html` into your project
2. Ensure "Copy items if needed" is checked
3. Add to your app target
4. Add `ImagePileView.swift` to your Swift sources

### 2. Basic Usage

```swift
import SwiftUI

struct ContentView: View {
    @State private var images: [PileImage] = []

    var body: some View {
        ImagePileView(
            images: $images,
            theme: .dark
        ) { event in
            handleEvent(event)
        }
        .frame(width: 500, height: 400)
    }

    func handleEvent(_ event: ImagePileEvent) {
        switch event {
        case .ready(let version):
            print("Component ready v\(version)")
            loadInitialImages()

        case .emptyStateClicked:
            showFilePicker()

        case .imageSelected(let index, let image):
            print("Selected: \(image.id) at index \(index)")

        case .imagesChanged(let images, let count, _):
            print("Now have \(count) images")

        case .error(let message):
            print("Error: \(message)")
        }
    }

    func loadInitialImages() {
        images = [
            PileImage(src: "https://example.com/image1.jpg"),
            PileImage(src: "https://example.com/image2.jpg"),
        ]
    }

    func showFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            for url in panel.urls {
                images.append(PileImage.fromFileURL(url))
            }
        }
    }
}
```

## API Reference

### PileImage

```swift
// From URL
let image = PileImage(src: "https://example.com/photo.jpg", alt: "Description")

// From local file
let image = PileImage.fromFileURL(fileURL)

// From NSImage
let image = PileImage.fromNSImage(nsImage)

// From raw data (base64 encoded automatically)
let image = PileImage.fromData(jpegData, mimeType: "image/jpeg")
```

### ImagePileView

```swift
ImagePileView(
    images: $images,           // Binding<[PileImage]>
    theme: .dark,              // ImagePileTheme (optional)
    onEvent: { event in ... }  // Event callback (optional)
)
```

### Events

| Event | Description |
|-------|-------------|
| `.ready(version)` | Component loaded and ready |
| `.imagesChanged(images, count, currentIndex)` | Images were modified |
| `.imageSelected(index, image)` | User selected an image |
| `.emptyStateClicked` | User clicked empty state (show file picker) |
| `.error(message)` | An error occurred |

### Themes

```swift
// Built-in themes
.default  // Transparent, adapts to content
.dark     // White controls for dark backgrounds
.light    // Dark controls for light backgrounds

// Custom theme
let custom = ImagePileTheme(
    cardRadius: "16px",
    arrowBg: "rgba(0, 100, 255, 0.2)",
    arrowColor: "rgba(0, 100, 255, 0.8)",
    dotColor: "rgba(0, 100, 255, 0.3)",
    dotActive: "rgba(0, 100, 255, 1.0)"
)
```

## Advanced Usage

### Direct JavaScript API

For more control, access the coordinator:

```swift
struct MyView: View {
    @State private var images: [PileImage] = []

    var body: some View {
        ImagePileView(images: $images)
            .onAppear {
                // Access coordinator methods if needed
            }
    }
}
```

### JavaScript API (from WKWebView)

```javascript
// Set all images
ImagePileAPI.setImages('[{"id":"1","src":"url1"},{"id":"2","src":"url2"}]')

// Add single image
ImagePileAPI.addImage('{"src":"url","alt":"description"}')

// Remove by index
ImagePileAPI.removeImage(0)

// Remove current
ImagePileAPI.removeCurrentImage()

// Navigate
ImagePileAPI.goToIndex(2)

// Get state
const state = ImagePileAPI.getState() // Returns JSON string

// Edit mode (shows overlay on hover)
ImagePileAPI.setEditMode(true)

// Custom theme
ImagePileAPI.setTheme('{"cardRadius":"20px"}')
```

## Behavior

### Automatic Mode Switching

| Image Count | Display Mode |
|-------------|--------------|
| 0 | Empty state with "Add images" prompt |
| 1 | Single image, full display |
| 2+ | Scattered pile with all interactions |

### Interactions

- **Hover** over background cards → slides out slightly
- **Click** any card → brings to front
- **Drag/swipe** → cycles through pile
- **Arrow buttons** → appear on hover, click to navigate
- **Counter dots** → show current position

## Customization

### Transparent Background

The component has a transparent background by default. Set the parent view's background:

```swift
ImagePileView(images: $images)
    .background(Color.black) // or any color/gradient
```

### Sizing

The component is responsive. It will fill its container:

```swift
ImagePileView(images: $images)
    .frame(width: 600, height: 450) // Fixed size

ImagePileView(images: $images)
    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill parent
```

## Troubleshooting

### Images not loading

1. Check that image URLs are accessible
2. For local files, ensure the WKWebView has read access
3. For base64 images, verify the data is valid

### Component not rendering

1. Verify `ImagePileComponent.html` is in the app bundle
2. Check the console for JavaScript errors
3. Ensure the view has a non-zero frame size

### Events not firing

1. Confirm `onEvent` callback is provided
2. Check that message handlers are registered (happens automatically)
3. Verify the component reached `.ready` state
