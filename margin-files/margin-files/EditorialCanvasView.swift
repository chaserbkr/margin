import SwiftUI
import AppKit

// MARK: - Pile Navigation Action
/// Enum for pile navigation actions - at file level so SwiftUI views can use it
enum PileNavigationAction {
    case previous
    case next
    case goToIndex(Int)
}

struct EditorialCanvasView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var canvas: Canvas
    @State private var showFloatingToolbar = true
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isStrikethrough = false
    @State private var isLink = false
    @State private var isBulletList = false
    @State private var isNumberedList = false
    @FocusState private var isTitleFocused: Bool
    @State private var bodyEditorRef: EditorialNSTextView?

    // Use global typeSystem from settings (applies to all documents like Notion)
    private var typeSystem: TypeSystem {
        appState.settings.defaultTypeSystem
    }

    private var layoutMode: LayoutMode {
        canvas.layoutMode
    }

    private var maxWidth: CGFloat {
        layoutMode.maxWidth
    }
    
    var body: some View {
        ZStack {
            // Background - different for Scratch mode
            if layoutMode.allowsFreeformCanvas {
                // Scratch mode: infinite canvas background
                ScratchCanvasBackground()
            } else {
                // Essay/Brief: clean paper background
            MarginColors.paper
            }

            // Margin guides removed for cleaner look

            // Main content area - differs by mode
            if layoutMode.allowsFreeformCanvas {
                // SCRATCH MODE: Document as locked page + freeform canvas
                ScratchModeCanvas(
                    canvas: $canvas,
                    typeSystem: typeSystem,
                    maxWidth: maxWidth,
                    baseFontSize: appState.settings.baseFontSize,
                    lineHeightMultiple: appState.settings.lineHeightMultiple,
                    isTitleFocused: $isTitleFocused,
                    bodyEditorRef: $bodyEditorRef
                )
            } else {
                // ESSAY & BRIEF MODES: Standard document flow
                DocumentFlowCanvas(
                    canvas: $canvas,
                    typeSystem: typeSystem,
                    layoutMode: layoutMode,
                    maxWidth: maxWidth,
                    baseFontSize: appState.settings.baseFontSize,
                    lineHeightMultiple: appState.settings.lineHeightMultiple,
                    isTitleFocused: $isTitleFocused,
                    bodyEditorRef: $bodyEditorRef
                )
            }

            // Floating toolbar on left side (all modes)
            if showFloatingToolbar {
                HStack {
                    FloatingToolbar(
                        typeSystem: $appState.settings.defaultTypeSystem,
                        isBold: $isBold,
                        isItalic: $isItalic,
                        isStrikethrough: $isStrikethrough,
                        isLink: $isLink,
                        isBulletList: $isBulletList,
                        isNumberedList: $isNumberedList
                    )
                    .padding(.leading, 24)
                    Spacer()
                }
                .padding(.top, 200) // Position toolbar partway down the left side
            }
        }
    }
}


// MARK: - Document Flow Canvas (Essay & Brief)

struct DocumentFlowCanvas: View {
    @Binding var canvas: Canvas
    let typeSystem: TypeSystem
    let layoutMode: LayoutMode
    let maxWidth: CGFloat
    let baseFontSize: CGFloat
    let lineHeightMultiple: CGFloat
    @FocusState.Binding var isTitleFocused: Bool
    @Binding var bodyEditorRef: EditorialNSTextView?

    // State for tracking scroll and editor position for overlay
    @State private var titleAreaHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var floatingImageRenderVersion: Int = 0  // Incremented to trigger re-renders during drag

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Main content - VStack with title area at top and scrolling editor below
                VStack(alignment: .center, spacing: 0) {
                    // Title area - constrained to maxWidth (fixed at top, doesn't scroll)
                VStack(alignment: .leading, spacing: 0) {
                    TitleEditorView(
                        title: $canvas.title,
                            typeSystem: typeSystem,
                        onSubmit: {
                            isTitleFocused = false
                            DispatchQueue.main.async {
                                bodyEditorRef?.window?.makeFirstResponder(bodyEditorRef)
                            }
                        }
                    )
                    .focused($isTitleFocused)
                        .padding(.top, layoutMode.topPadding)

                    // Editorial metadata bar
                    EditorialMetadataBar(canvas: canvas)
                        .padding(.vertical, 32)
                    }
                    .frame(maxWidth: maxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .background(MarginColors.paper) // Ensure title area has solid background
                    .overlay(
                        GeometryReader { titleGeo in
                            Color.clear
                                .onAppear {
                                    titleAreaHeight = titleGeo.size.height
                                }
                                .onChange(of: titleGeo.size.height) { _, newHeight in
                                    titleAreaHeight = newHeight
                                }
                        }
                    )
                    .zIndex(1) // Title stays above scrolling content

                    // Main text editor with its own NSScrollView
                    // Takes remaining vertical space
                    EditorialTextEditor(
                        content: $canvas.content,
                        inlineMediaBlocks: $canvas.inlineMediaBlocks,
                        floatingImagesData: $canvas.floatingImages,
                        canvasId: canvas.id,
                        typeSystem: typeSystem,
                        layoutMode: layoutMode,
                        baseFontSize: baseFontSize,
                        lineHeightMultiple: lineHeightMultiple,
                        textViewRef: $bodyEditorRef,
                        pageMaxWidth: maxWidth,
                        viewWidth: geometry.size.width,
                        onScrollOffsetChange: { offset in
                            scrollOffset = offset
                        },
                        onFloatingImagePositionChange: {
                            // Increment to trigger SwiftUI re-render (cheap, no disk I/O)
                            floatingImageRenderVersion += 1
                        }
                    )
                    .frame(maxHeight: .infinity) // Take all remaining vertical space
                }

                // Floating images layer - renders ALL floating images
                // This layer sits OUTSIDE the scroll view but clips at the title area
                // so images hide under the header when scrolling
                // Only show when:
                // 1. There are floating images to render
                // 2. titleAreaHeight has been measured (> 0) - prevents images from rendering at wrong position
                if !canvas.floatingImages.isEmpty && titleAreaHeight > 0 {
                    FloatingImagesLayer(
                        textViewRef: bodyEditorRef,
                        floatingImagesData: canvas.floatingImages,
                        viewWidth: geometry.size.width,
                        pageMaxWidth: maxWidth,
                        titleAreaHeight: titleAreaHeight,
                        scrollOffset: scrollOffset,
                        renderVersion: floatingImageRenderVersion  // Triggers re-render during drag
                    )
                    .allowsHitTesting(false) // Let clicks pass through to the text view
                    // Clip images so they hide under the title/header when scrolling
                    .mask(
                        VStack(spacing: 0) {
                            // Invisible area above title (images hidden here)
                            Color.clear
                                .frame(height: titleAreaHeight)
                            // Visible area below title (images shown here)
                            Rectangle()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Floating Images Layer
// Renders ALL floating images in a SwiftUI layer that sits outside the NSScrollView
// This ensures images can extend beyond the text area without being clipped

struct FloatingImagesLayer: View {
    let textViewRef: EditorialNSTextView?
    let floatingImagesData: [FloatingImageData]  // For ForEach identity (add/remove tracking)
    let viewWidth: CGFloat
    let pageMaxWidth: CGFloat
    let titleAreaHeight: CGFloat
    let scrollOffset: CGFloat
    let renderVersion: Int  // Changes trigger re-render during drag (cheap, no disk I/O)

    var body: some View {
        GeometryReader { geometry in
            // Get floating images from the text view
            if let textView = textViewRef {
                // Use floatingImagesData for ForEach identity (tracks add/remove)
                // Read position/size from textView.floatingImages (runtime data, updated during drag)
                // renderVersion changing triggers re-render without expensive disk I/O
                let _ = renderVersion  // Force dependency on renderVersion

                ForEach(floatingImagesData) { imageData in
                    // Get position/size from runtime data (updated during drag)
                    if let floatingImage = textView.floatingImages.first(where: { $0.id == imageData.id }) {
                        // Check selection/hover state from text view
                        let isSelected = textView.selectedFloatingImageId == floatingImage.id
                        let isHovered = textView.hoveredFloatingImageId == floatingImage.id
                        
                        // Render single image or pile with selection overlay
                        FloatingImageView(
                            floatingImage: floatingImage,
                            titleAreaHeight: titleAreaHeight,
                            scrollOffset: scrollOffset,
                            viewportHeight: geometry.size.height,
                            isSelected: isSelected,
                            isHovered: isHovered,
                            onNavigate: { imageId, action in
                                textView.handlePileNavigationFromSwiftUI(imageId: imageId, action: action)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Single Floating Image or Pile View
struct FloatingImageView: View {
    let floatingImage: FloatingReflowImage
    let titleAreaHeight: CGFloat
    let scrollOffset: CGFloat
    let viewportHeight: CGFloat
    let isSelected: Bool
    let isHovered: Bool
    let onNavigate: (UUID, PileNavigationAction) -> Void

    var body: some View {
        // Use the center point of the floating image - this is the canonical anchor
        let yOffset = titleAreaHeight - scrollOffset

        // Use floatingImage.center which is the logical center point
        let center = floatingImage.center
        let centerX = center.x
        let centerY = yOffset + center.y

        // For visibility check, use the pileBoundingBox which encompasses all content
        let bbox = floatingImage.pileBoundingBox
        let yPos = yOffset + bbox.origin.y
        
        // Calculate selection overlay position using image's actual frame
        // (not paddedFrame which has asymmetric padding and wouldn't center correctly)
        let imgFrame = floatingImage.frame
        let selectionCenterX = imgFrame.midX
        let selectionCenterY = yOffset + imgFrame.midY

        // Use generous visibility bounds - viewportHeight might be 0 during initial layout
        let effectiveViewportHeight = max(viewportHeight, 2000)
        if yPos + bbox.height > -500 && yPos < effectiveViewportHeight + 500 {
            ZStack {
                // Render image content
                if floatingImage.isPile {
                    FloatingPileView(
                        floatingImage: floatingImage,
                        centerX: centerX,
                        centerY: centerY,
                        baseWidth: floatingImage.displayWidth,
                        baseHeight: floatingImage.size.height,
                        isHovered: isHovered || isSelected,
                        onNavigate: { action in
                            onNavigate(floatingImage.id, action)
                        }
                    )
                } else {
                    if let nsImage = floatingImage.currentImage {
                        let imgFrame = floatingImage.frame
                        let imgWidth = imgFrame.width > 0 ? imgFrame.width : floatingImage.size.width
                        let imgHeight = imgFrame.height > 0 ? imgFrame.height : floatingImage.size.height
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imgWidth, height: imgHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 4)
                            .position(x: centerX, y: centerY)
                    }
                }
                
                // Render selection overlay when selected
                if isSelected {
                    SelectionOverlayView(
                        frame: imgFrame,
                        centerX: selectionCenterX,
                        centerY: selectionCenterY
                    )
                }
            }
        }
    }
}

// MARK: - Selection Overlay View
struct SelectionOverlayView: View {
    let frame: CGRect
    let centerX: CGFloat
    let centerY: CGFloat
    
    var body: some View {
        ZStack {
            // Selection border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: centerX, y: centerY)
            
            // Resize handles at corners and edges
            ForEach(handlePositions, id: \.0) { position in
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                    .position(
                        x: centerX + position.1 * frame.width / 2,
                        y: centerY + position.2 * frame.height / 2
                    )
            }
        }
    }
    
    // Handle positions: (id, xMultiplier, yMultiplier)
    // Multipliers: -1 = left/top, 0 = center, 1 = right/bottom
    private var handlePositions: [(Int, CGFloat, CGFloat)] {
        [
            (0, -1, -1),  // Top left
            (1,  0, -1),  // Top center
            (2,  1, -1),  // Top right
            (3,  1,  0),  // Right center
            (4,  1,  1),  // Bottom right
            (5,  0,  1),  // Bottom center
            (6, -1,  1),  // Bottom left
            (7, -1,  0),  // Left center
        ]
    }
}

// MARK: - Floating Pile View (multiple stacked images)
struct FloatingPileView: View {
    let floatingImage: FloatingReflowImage
    let centerX: CGFloat
    let centerY: CGFloat
    let baseWidth: CGFloat
    let baseHeight: CGFloat
    let isHovered: Bool
    let onNavigate: (PileNavigationAction) -> Void

    var body: some View {
        let imageCount = floatingImage.images.count
        let visibleCards = min(imageCount, 4)  // Show max 4 background cards
        
        // Use the stable bounding box for sizing, but position relative to centerX/centerY
        // which already have scroll offset applied
        let bbox = floatingImage.pileBoundingBox
        let bboxHalfWidth = bbox.width / 2
        let bboxHalfHeight = bbox.height / 2

        ZStack {
            // Draw background cards from back to front (skip the current one)
            ForEach((0..<visibleCards).reversed(), id: \.self) { i in
                let actualIndex = (floatingImage.currentIndex + i + 1) % imageCount
                if actualIndex != floatingImage.currentIndex {
                    PileCardView(
                        floatingImage: floatingImage,
                        imageIndex: actualIndex,
                        depthIndex: i,
                        centerX: centerX,
                        centerY: centerY
                    )
                }
            }

            // Draw front image (current image)
            if let nsImage = floatingImage.currentImage {
                let rotation = floatingImage.rotationForImage(at: floatingImage.currentIndex)
                let offset = floatingImage.offsetForImage(at: floatingImage.currentIndex)

                // Use frameForImage to get EXACT same dimensions as AppKit bounding box
                let imgFrame = floatingImage.frameForImage(at: floatingImage.currentIndex)
                
                // Ensure valid dimensions (fallback to stored size if frame calc fails)
                let imgWidth = imgFrame.width > 0 ? imgFrame.width : floatingImage.size.width
                let imgHeight = imgFrame.height > 0 ? imgFrame.height : floatingImage.size.height

                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imgWidth, height: imgHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                    .rotationEffect(.degrees(Double(rotation)))
                    .position(
                        x: centerX + offset.x,
                        y: centerY + offset.y
                    )
            }
            
            // Navigation overlay - covers the entire bounding box area
            // Position relative to centerX/centerY which have scroll offset applied
            if imageCount > 1 {
                // Invisible click zones for navigation (Instagram Stories pattern)
                HStack(spacing: 0) {
                    // Left half - go to previous
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onNavigate(.previous)
                        }
                    
                    // Right half - go to next
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onNavigate(.next)
                        }
                }
                .frame(width: bbox.width, height: bbox.height)
                .position(x: centerX, y: centerY)  // Use scroll-adjusted center
                
                // Navigation arrows - aligned with caption section at bottom
                if isHovered {
                    // Left arrow
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                        )
                        .position(
                            x: centerX - bboxHalfWidth + 28,      // Inside left edge
                            y: centerY + bboxHalfHeight + 16      // Aligned with caption below
                        )
                        .onTapGesture {
                            onNavigate(.previous)
                        }
                    
                    // Right arrow
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                        )
                        .position(
                            x: centerX + bboxHalfWidth - 28,      // Inside right edge
                            y: centerY + bboxHalfHeight + 16      // Aligned with caption below
                        )
                        .onTapGesture {
                            onNavigate(.next)
                        }
                }
                
                // Page indicator dots at bottom of bounding box
                if isHovered {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(0..<imageCount, id: \.self) { index in
                                Circle()
                                    .fill(index == floatingImage.currentIndex 
                                          ? Color.white 
                                          : Color.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                        )
                    }
                    .frame(width: bbox.width, height: bbox.height)
                    .position(x: centerX, y: centerY)  // Use scroll-adjusted center
                }
            }
        }
    }
}

// MARK: - Individual Pile Card (background card in pile)
struct PileCardView: View {
    let floatingImage: FloatingReflowImage
    let imageIndex: Int
    let depthIndex: Int
    let centerX: CGFloat
    let centerY: CGFloat

    var body: some View {
        let cardImage = floatingImage.images[imageIndex]
        let rotation = floatingImage.rotationForImage(at: imageIndex)
        let offset = floatingImage.offsetForImage(at: imageIndex)

        // Scale based on depth (cards further back are slightly smaller)
        let depthScale: CGFloat = 0.95 - CGFloat(depthIndex) * 0.02

        // Use frameForImage to get EXACT same dimensions as AppKit bounding box
        let cardFrame = floatingImage.frameForImage(at: imageIndex)
        
        // Ensure valid dimensions (fallback if frame calc fails)
        let baseWidth = cardFrame.width > 0 ? cardFrame.width : floatingImage.size.width
        let baseHeight = cardFrame.height > 0 ? cardFrame.height : floatingImage.size.height
        let cardWidth = baseWidth * depthScale
        let cardHeight = baseHeight * depthScale

        Image(nsImage: cardImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .rotationEffect(.degrees(Double(rotation)))
            .position(
                x: centerX + offset.x,
                y: centerY + offset.y
            )
    }
}

// MARK: - Scratch Mode Canvas

struct ScratchModeCanvas: View {
    @Binding var canvas: Canvas
    let typeSystem: TypeSystem
    let maxWidth: CGFloat
    let baseFontSize: CGFloat
    let lineHeightMultiple: CGFloat
    @FocusState.Binding var isTitleFocused: Bool
    @Binding var bodyEditorRef: EditorialNSTextView?
    
    // Freeform canvas state
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Freeform canvas objects layer (behind document)
            FreeformCanvasLayer(
                objects: $canvas.canvasObjects,
                offset: canvasOffset,
                scale: canvasScale
            )
            
            // Locked document page (centered, fixed-width rectangle)
            LockedDocumentPage(
                canvas: $canvas,
                typeSystem: typeSystem,
                maxWidth: maxWidth,
                baseFontSize: baseFontSize,
                lineHeightMultiple: lineHeightMultiple,
                isTitleFocused: $isTitleFocused,
                bodyEditorRef: $bodyEditorRef
            )
        }
    }
}

// MARK: - Locked Document Page (Scratch Mode)

struct LockedDocumentPage: View {
    @Binding var canvas: Canvas
    let typeSystem: TypeSystem
    let maxWidth: CGFloat
    let baseFontSize: CGFloat
    let lineHeightMultiple: CGFloat
    @FocusState.Binding var isTitleFocused: Bool
    @Binding var bodyEditorRef: EditorialNSTextView?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title area (still editable)
                TitleEditorView(
                    title: $canvas.title,
                    typeSystem: typeSystem,
                    onSubmit: {
                        isTitleFocused = false
                        DispatchQueue.main.async {
                            bodyEditorRef?.window?.makeFirstResponder(bodyEditorRef)
                        }
                    }
                )
                .focused($isTitleFocused)
                .padding(.top, 60)

                // Metadata
                EditorialMetadataBar(canvas: canvas)
                    .padding(.vertical, 24)

                // Main text editor (still editable inside page)
                // Note: Image drops disabled in Scratch mode (layoutMode doesn't allowInlineMedia)
                EditorialTextEditor(
                    content: $canvas.content,
                    inlineMediaBlocks: $canvas.inlineMediaBlocks,
                    floatingImagesData: $canvas.floatingImages,
                    canvasId: canvas.id,
                    typeSystem: typeSystem,
                    layoutMode: .plan,
                    baseFontSize: baseFontSize,
                    lineHeightMultiple: lineHeightMultiple,
                        textViewRef: $bodyEditorRef
                    )
                    .frame(minHeight: 300)

                    Spacer()
                    .frame(height: 80)
            }
            .padding(.horizontal, 48)
                }
                .frame(maxWidth: maxWidth)
        .background(MarginColors.paper)
        .cornerRadius(8)
        // Page shadow
        .shadow(color: Color(hex: "1C1C1E").opacity(0.06), radius: 0, x: 0, y: 0)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.04), radius: 8, x: 0, y: 4)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.08), radius: 24, x: 0, y: 12)
        // Subtle page border
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MarginColors.stone200.opacity(0.5), lineWidth: 1)
        )
        .padding(40)
    }
            }
            
// MARK: - Scratch Canvas Background

struct ScratchCanvasBackground: View {
    var body: some View {
        // Subtle dot grid pattern for freeform canvas
        MarginColors.stone50
            .overlay(
                // Use SwiftUI.Canvas to disambiguate from our Canvas model
                SwiftUI.Canvas { context, size in
                    let dotSpacing: CGFloat = 24
                    let dotRadius: CGFloat = 1
                    
                    for x in stride(from: dotSpacing, to: size.width, by: dotSpacing) {
                        for y in stride(from: dotSpacing, to: size.height, by: dotSpacing) {
                            let rect = CGRect(
                                x: x - dotRadius,
                                y: y - dotRadius,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(MarginColors.stone200.opacity(0.6))
                            )
                        }
                    }
                }
            )
    }
}

// MARK: - Freeform Canvas Layer

struct FreeformCanvasLayer: View {
    @Binding var objects: [FreeformCanvasObject]
    let offset: CGSize
    let scale: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(objects.sorted(by: { $0.zIndex < $1.zIndex })) { object in
                FreeformObjectView(object: binding(for: object))
                    .position(
                        x: object.position.x + offset.width,
                        y: object.position.y + offset.height
                    )
            }
        }
        .scaleEffect(scale)
    }
    
    private func binding(for object: FreeformCanvasObject) -> Binding<FreeformCanvasObject> {
        guard let index = objects.firstIndex(where: { $0.id == object.id }) else {
            return .constant(object)
        }
        return $objects[index]
    }
}

// MARK: - Freeform Object View

struct FreeformObjectView: View {
    @Binding var object: FreeformCanvasObject
    @State private var isDragging = false
    
    var body: some View {
        Group {
            switch object.objectType {
            case .stickyNote:
                StickyNoteView(content: $object.content, size: object.size)
            case .textBox:
                FreeformTextBoxView(content: $object.content, size: object.size)
            case .image:
                if let filename = object.imageFilename {
                    FreeformImageView(filename: filename, size: object.size)
                }
            }
        }
        .frame(width: object.size.width, height: object.size.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    object.position = CGPoint(
                        x: object.position.x + value.translation.width,
                        y: object.position.y + value.translation.height
                    )
                }
                .onEnded { _ in
                    isDragging = false
                    object.updatedAt = Date()
                }
        )
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Sticky Note View

struct StickyNoteView: View {
    @Binding var content: String
    let size: CGSize
    
    var body: some View {
        TextEditor(text: $content)
            .font(MarginTypography.ui(size: 13))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(hex: "FEF9C3")) // Yellow sticky
            .cornerRadius(4)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Freeform Text Box View

struct FreeformTextBoxView: View {
    @Binding var content: String
    let size: CGSize
    
    var body: some View {
        TextEditor(text: $content)
            .font(MarginTypography.body(size: 14))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(MarginColors.paper)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(MarginColors.stone200, lineWidth: 1)
            )
            }
        }

// MARK: - Freeform Image View

struct FreeformImageView: View {
    let filename: String
    let size: CGSize
    
    var body: some View {
        // Placeholder for image loading
        RoundedRectangle(cornerRadius: 4)
            .fill(MarginColors.stone100)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(MarginColors.stone300)
            )
    }
}

// Note: InlineMediaBlocksView removed - images are now inserted directly as NSTextAttachments


// MARK: - Title Editor

struct TitleEditorView: View {
    @Binding var title: String
    let typeSystem: TypeSystem
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        TextField("Untitled", text: $title)
            .textFieldStyle(.plain)
            .font(typeSystem.swiftUITitleFont(size: 48))
            .foregroundColor(MarginColors.ink)
            .onSubmit {
                onSubmit?()
            }
    }
}

// MARK: - Editorial Metadata Bar

struct EditorialMetadataBar: View {
    let canvas: Canvas
    
    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(canvas.updatedAt, style: .date)
            }
            
            Spacer()
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

// MARK: - Non-Clipping Clip View
// Custom NSClipView that allows content to be drawn outside its bounds
// This enables floating images to extend beyond the text area

class NonClippingClipView: NSClipView {
    // Note: We now render floating images in a SwiftUI overlay layer,
    // so the NSScrollView can use normal clipping. This prevents text
    // from bleeding into the title area above.
    // The floating images layer (FloatingImagesLayer) sits outside the
    // scroll view and handles image rendering without clipping.

    override var wantsDefaultClipping: Bool {
        return true  // Use normal clipping - floating images are in SwiftUI overlay
    }
}

struct EditorialTextEditor: NSViewRepresentable {
    @Binding var content: AttributedContent
    @Binding var inlineMediaBlocks: [InlineMediaBlock]
    @Binding var floatingImagesData: [FloatingImageData]
    let canvasId: UUID
    let typeSystem: TypeSystem
    let layoutMode: LayoutMode
    let baseFontSize: CGFloat
    let lineHeightMultiple: CGFloat
    @Binding var textViewRef: EditorialNSTextView?
    var pageMaxWidth: CGFloat = 680  // Max width for text content
    var viewWidth: CGFloat = 0       // Full view width (for floating images)
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil  // Callback for scroll position changes
    var onFloatingImagePositionChange: (() -> Void)? = nil  // Callback for floating image position changes (cheap re-render trigger)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true // Hide scrollbar when not needed
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Use custom clip view (now with normal clipping since floating images
        // are rendered in a SwiftUI overlay layer outside the scroll view)
        let customClipView = NonClippingClipView()
        customClipView.drawsBackground = false
        scrollView.contentView = customClipView

        // Standard clipping - floating images rendered in SwiftUI overlay
        scrollView.contentView.wantsLayer = true
        scrollView.wantsLayer = true

        let textView = EditorialNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        // IMPORTANT: horizontallyResizable must be true for the text view to use full scroll view width
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]

        // Calculate horizontal inset to center text content within pageMaxWidth
        // while allowing floating images to use full view width
        let horizontalInset = max(0, (viewWidth - pageMaxWidth) / 2)
        textView.textContainerInset = NSSize(width: horizontalInset, height: 16)

        // Store the page width for floating image positioning reference
        textView.pageMaxWidth = pageMaxWidth
        textView.pageHorizontalInset = horizontalInset

        // Configure for full width spanning so floating images can extend beyond text area
        // The minSize.width ensures the text view fills the scroll view width
        let effectiveWidth = viewWidth > 0 ? viewWidth : pageMaxWidth
        textView.minSize = NSSize(width: effectiveWidth, height: 0)
        textView.maxSize = NSSize(width: effectiveWidth, height: CGFloat.greatestFiniteMagnitude)

        // Configure text container for fixed width (pageMaxWidth) for text content
        // This keeps text within bounds while the view itself is wider for floating images
        // IMPORTANT: widthTracksTextView must be false so text container stays at pageMaxWidth
        // while the text view itself can be wider
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: pageMaxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Set the text view frame to full width (this is what allows floating images beyond text area)
        if viewWidth > 0 {
            textView.frame = NSRect(x: 0, y: 0, width: viewWidth, height: max(textView.frame.height, 100))
        }

        // Set default typing attributes
        textView.typingAttributes = defaultAttributes

        // Set initial content
        let attributedString = content.toAttributedString(typeSystem: typeSystem)
        textView.textStorage?.setAttributedString(attributedString)

        textView.currentTypeSystem = typeSystem
        textView.currentLayoutMode = layoutMode
        textView.currentBaseFontSize = baseFontSize
        textView.currentLineHeightMultiple = lineHeightMultiple
        
        // Apply global typography settings to ensure consistency
        DispatchQueue.main.async {
            self.applyGlobalTypographySettings(to: textView, typeSystem: self.typeSystem, baseFontSize: self.baseFontSize, lineHeightMultiple: self.lineHeightMultiple)
        }
        
        // Set up drag and drop for images
        textView.setupDragAndDrop()
        let coordinator = context.coordinator
        
        // Set up floating images changed handler
        textView.floatingImagesChangedHandler = { [weak coordinator] floatingImages in
            coordinator?.syncFloatingImages(floatingImages)
        }
        
        // Set canvas ID for image saving
        textView.canvasId = canvasId

        context.coordinator.textView = textView
        context.coordinator.lastKnownContent = content.plainText
        
        // Load existing floating images
        context.coordinator.loadFloatingImages(into: textView)

        // Store reference for external access
        DispatchQueue.main.async {
            self.textViewRef = textView
        }

        scrollView.documentView = textView

        // Set up scroll observation for the floating image overlay layer
        coordinator.onScrollOffsetChange = onScrollOffsetChange
        coordinator.onFloatingImagePositionChange = onFloatingImagePositionChange

        // Set up floating image position change handler for live updates during drag
        textView.floatingImagePositionChangedHandler = { [weak coordinator] in
            coordinator?.onFloatingImagePositionChange?()
        }

        // Observe scroll position changes from the clip view
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak coordinator] notification in
            guard let clipView = notification.object as? NSClipView else { return }
            let scrollOffset = clipView.bounds.origin.y
            coordinator?.onScrollOffsetChange?(scrollOffset)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorialNSTextView else { return }

        textView.currentTypeSystem = typeSystem
        textView.currentLayoutMode = layoutMode
        textView.currentBaseFontSize = baseFontSize
        textView.currentLineHeightMultiple = lineHeightMultiple
        textView.typingAttributes = defaultAttributes

        // Update page layout constraints for floating images
        let horizontalInset = max(0, (viewWidth - pageMaxWidth) / 2)
        let effectiveWidth = viewWidth > 0 ? viewWidth : pageMaxWidth
        if textView.pageMaxWidth != pageMaxWidth || textView.pageHorizontalInset != horizontalInset || textView.frame.width != effectiveWidth {
            textView.pageMaxWidth = pageMaxWidth
            textView.pageHorizontalInset = horizontalInset
            textView.textContainerInset = NSSize(width: horizontalInset, height: 16)
            textView.textContainer?.containerSize = NSSize(width: pageMaxWidth, height: CGFloat.greatestFiniteMagnitude)

            // Update text view frame to span full width for floating images
            if viewWidth > 0 {
                textView.minSize = NSSize(width: viewWidth, height: 0)
                textView.maxSize = NSSize(width: viewWidth, height: CGFloat.greatestFiniteMagnitude)
                var frame = textView.frame
                frame.size.width = viewWidth
                textView.frame = frame
            }

            textView.needsLayout = true
            textView.needsDisplay = true
        }

        // Check if type system, font size, or line height changed - reapply styling to existing text
        // Use tolerance for floating point comparison
        let fontSizeChanged = abs(context.coordinator.lastBaseFontSize - baseFontSize) > 0.1
        let lineHeightChanged = abs(context.coordinator.lastLineHeightMultiple - lineHeightMultiple) > 0.01
        let settingsChanged = context.coordinator.lastTypeSystem != typeSystem || fontSizeChanged || lineHeightChanged
        
        if settingsChanged {
            
            context.coordinator.lastTypeSystem = typeSystem
            context.coordinator.baseFontSize = baseFontSize
            context.coordinator.lastBaseFontSize = baseFontSize
            context.coordinator.lineHeightMultiple = lineHeightMultiple
            context.coordinator.lastLineHeightMultiple = lineHeightMultiple
            
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                // Reapply body text styling with new font size and line height
                let fullRange = NSRange(location: 0, length: textStorage.length)
                
                // Heading sizes are fixed and much larger than body text range (14-28px)
                let h1Size: CGFloat = 36  // H1 size - always 36
                
                textStorage.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                    guard let font = value as? NSFont else { return }
                    
                    // Check paragraph style to determine if this is a heading
                    // Headings have lineHeightMultiple < 1.4, body text has >= 1.4
                    var isHeading = false
                    if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle {
                        isHeading = paragraphStyle.lineHeightMultiple < 1.4
                    }
                    
                    // Also check for very large fonts that are definitely headings
                    if font.pointSize >= h1Size - 1 {
                        isHeading = true
                    }
                    
                    if !isHeading {
                        // Apply new body font size
                        let newFont = typeSystem.bodyFont(size: baseFontSize)
                        let preservedFont = preserveFontTraits(from: font, to: newFont)
                        textStorage.addAttribute(.font, value: preservedFont, range: range)
                    }
                }
                
                // Apply new line height to body paragraphs
                textStorage.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
                    if let paragraphStyle = value as? NSParagraphStyle {
                        let mutableStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                        // Only update body text line height (headings have lower line height multiplier)
                        if mutableStyle.lineHeightMultiple >= 1.4 {
                            mutableStyle.lineHeightMultiple = lineHeightMultiple
                            textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
                        }
                    }
                }
                
                // Force redraw
                textView.needsDisplay = true
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
            
            // Apply global typography settings to the loaded document
            applyGlobalTypographySettings(to: textView, typeSystem: typeSystem, baseFontSize: baseFontSize, lineHeightMultiple: lineHeightMultiple)
            
            // Also reload floating images for the new document
            context.coordinator.loadFloatingImages(into: textView)
        }
        
        // Check if canvas ID changed (document switch) - update bindings and reload floating images
        if canvasId != context.coordinator.lastCanvasId {
            // Update coordinator bindings to point to new canvas data
            context.coordinator.updateBindings(
                content: $content,
                inlineMediaBlocks: $inlineMediaBlocks,
                floatingImagesData: $floatingImagesData,
                canvasId: canvasId
            )
            context.coordinator.lastCanvasId = canvasId
            context.coordinator.loadFloatingImages(into: textView)
            
            // Apply global typography settings when switching documents
            applyGlobalTypographySettings(to: textView, typeSystem: typeSystem, baseFontSize: baseFontSize, lineHeightMultiple: lineHeightMultiple)
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
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        paragraphStyle.paragraphSpacing = 20

        return [
            .font: typeSystem.bodyFont(size: baseFontSize),
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: paragraphStyle
        ]
    }
    
    /// Preserves bold/italic traits from source font when changing to new font
    private func preserveFontTraits(from sourceFont: NSFont, to targetFont: NSFont) -> NSFont {
        var result = targetFont
        let sourceTraits = sourceFont.fontDescriptor.symbolicTraits
        
        if sourceTraits.contains(.bold) {
            result = NSFontManager.shared.convert(result, toHaveTrait: .boldFontMask)
        }
        if sourceTraits.contains(.italic) {
            result = NSFontManager.shared.convert(result, toHaveTrait: .italicFontMask)
        }
        return result
    }
    
    /// Applies global typography settings (font size, line height) to all body text in the document
    private func applyGlobalTypographySettings(to textView: EditorialNSTextView, typeSystem: TypeSystem, baseFontSize: CGFloat, lineHeightMultiple: CGFloat) {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }
        
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Apply font size to body text (not headings)
        textStorage.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            
            // Check paragraph style to determine if this is a heading
            var isHeading = false
            if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle {
                isHeading = paragraphStyle.lineHeightMultiple < 1.4
            }
            
            // Also check for very large fonts that are definitely headings
            if font.pointSize >= 35 {
                isHeading = true
            }
            
            if !isHeading {
                let newFont = typeSystem.bodyFont(size: baseFontSize)
                let preservedFont = preserveFontTraits(from: font, to: newFont)
                textStorage.addAttribute(.font, value: preservedFont, range: range)
            }
        }
        
        // Apply line height to body paragraphs
        textStorage.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            if let paragraphStyle = value as? NSParagraphStyle {
                let mutableStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                if mutableStyle.lineHeightMultiple >= 1.4 {
                    mutableStyle.lineHeightMultiple = lineHeightMultiple
                    textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
                }
            }
        }
        
        // Update typing attributes for new text
        textView.typingAttributes = [
            .font: typeSystem.bodyFont(size: baseFontSize),
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: typeSystem.bodyParagraphStyle(lineHeight: lineHeightMultiple)
        ]
        
        textView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            content: $content, 
            inlineMediaBlocks: $inlineMediaBlocks,
            floatingImagesData: $floatingImagesData,
            canvasId: canvasId,
            typeSystem: typeSystem,
            baseFontSize: baseFontSize,
            lineHeightMultiple: lineHeightMultiple
        )
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var contentBinding: Binding<AttributedContent>
        var inlineMediaBlocksBinding: Binding<[InlineMediaBlock]>
        var floatingImagesDataBinding: Binding<[FloatingImageData]>
        var currentCanvasId: UUID
        var lastCanvasId: UUID
        var typeSystem: TypeSystem
        var lastTypeSystem: TypeSystem
        var baseFontSize: CGFloat
        var lastBaseFontSize: CGFloat
        var lineHeightMultiple: CGFloat
        var lastLineHeightMultiple: CGFloat
        weak var textView: EditorialNSTextView?
        var lastKnownContent: String = ""
        var onScrollOffsetChange: ((CGFloat) -> Void)?
        var onFloatingImagePositionChange: (() -> Void)?
        var scrollObserver: NSObjectProtocol?
        
        // Computed properties to access binding values
        var content: AttributedContent {
            get { contentBinding.wrappedValue }
            set { contentBinding.wrappedValue = newValue }
        }
        
        var inlineMediaBlocks: [InlineMediaBlock] {
            get { inlineMediaBlocksBinding.wrappedValue }
            set { inlineMediaBlocksBinding.wrappedValue = newValue }
        }
        
        var floatingImagesData: [FloatingImageData] {
            get { floatingImagesDataBinding.wrappedValue }
            set { floatingImagesDataBinding.wrappedValue = newValue }
        }

        init(content: Binding<AttributedContent>, inlineMediaBlocks: Binding<[InlineMediaBlock]>, floatingImagesData: Binding<[FloatingImageData]>, canvasId: UUID, typeSystem: TypeSystem, baseFontSize: CGFloat, lineHeightMultiple: CGFloat) {
            self.contentBinding = content
            self.inlineMediaBlocksBinding = inlineMediaBlocks
            self.floatingImagesDataBinding = floatingImagesData
            self.currentCanvasId = canvasId
            self.lastCanvasId = canvasId
            self.typeSystem = typeSystem
            self.lastTypeSystem = typeSystem
            self.baseFontSize = baseFontSize
            self.lastBaseFontSize = baseFontSize
            self.lineHeightMultiple = lineHeightMultiple
            self.lastLineHeightMultiple = lineHeightMultiple
        }

        deinit {
            // Clean up scroll observer
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// Update bindings when canvas changes
        func updateBindings(content: Binding<AttributedContent>, inlineMediaBlocks: Binding<[InlineMediaBlock]>, floatingImagesData: Binding<[FloatingImageData]>, canvasId: UUID) {
            self.contentBinding = content
            self.inlineMediaBlocksBinding = inlineMediaBlocks
            self.floatingImagesDataBinding = floatingImagesData
            self.currentCanvasId = canvasId
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }

            let newContent = AttributedContent(from: textStorage)
            content = newContent
            lastKnownContent = newContent.plainText
            
            // Scroll to keep the caret visible as the user types
            textView.scrollRangeToVisible(textView.selectedRange())
            
            // Ensure text view is tall enough for continued typing
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let usedRect = layoutManager.usedRect(for: textContainer)
                
                // Add generous bottom padding so user can keep typing
                let bottomPadding: CGFloat = 400
                let neededHeight = usedRect.height + textView.textContainerInset.height * 2 + bottomPadding
                
                if neededHeight > textView.frame.height {
                    textView.setFrameSize(NSSize(width: textView.frame.width, height: neededHeight))
                }
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? EditorialNSTextView,
                  let textStorage = textView.textStorage else { return }
            
            // When the cursor is at an insertion point (not a selection range),
            // check if we're in an empty paragraph or after a newline - use body style
            let selectedRange = textView.selectedRange()
            if selectedRange.length == 0 && selectedRange.location <= textStorage.length {
                let location = selectedRange.location
                
                // Check if we're at start of document, after a newline, or in empty area
                var shouldUseBodyStyle = false
                
                if location == 0 {
                    // Start of document
                    shouldUseBodyStyle = true
                } else if location == textStorage.length {
                    // End of document - check previous character
                    let prevChar = (textStorage.string as NSString).character(at: location - 1)
                    if prevChar == 0x0A { // newline
                        shouldUseBodyStyle = true
                    }
                } else {
                    // Middle of document - check if we're at start of a new paragraph
                    let prevChar = (textStorage.string as NSString).character(at: location - 1)
                    if prevChar == 0x0A { // after newline = new paragraph
                        shouldUseBodyStyle = true
                    }
                    
                    // Also check if we're next to an attachment (image)
                    let currentChar = (textStorage.string as NSString).character(at: location)
                    if currentChar == 0xFFFC { // NSAttachmentCharacter
                        shouldUseBodyStyle = true
                    }
                }
                
                if shouldUseBodyStyle {
                    let bodyFont = typeSystem.bodyFont(size: baseFontSize)
                    let paragraphStyle = typeSystem.bodyParagraphStyle(lineHeight: lineHeightMultiple)
                    
                    textView.typingAttributes = [
                        .font: bodyFont,
                        .foregroundColor: MarginColors.inkNS,
                        .paragraphStyle: paragraphStyle
                    ]
                }
            }
        }
        
        // MARK: - Image Storage
        
        private func saveImageToStorage(image: NSImage) -> String {
            let filename = UUID().uuidString + ".png"

            // Get the app support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let marginDir = appSupport.appendingPathComponent("Margin/Images", isDirectory: true)

            // Create directory if needed
            try? FileManager.default.createDirectory(at: marginDir, withIntermediateDirectories: true)

            // Save the image as PNG
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let fileURL = marginDir.appendingPathComponent(filename)
                try? pngData.write(to: fileURL)
            }

            return filename
        }

        // MARK: - Floating Images Persistence

        /// Cache of already-saved filenames by image ID to avoid re-saving
        private var savedImageFilenames: [UUID: [String]] = [:]

        /// Sync floating images from the text view to the Canvas binding
        /// Optimized to only save new images to disk (expensive) and reuse existing filenames
        func syncFloatingImages(_ floatingImages: [FloatingReflowImage]) {
            var newData: [FloatingImageData] = []

            for floating in floatingImages {
                // Check if we already have saved filenames for this image
                if let existingFilenames = savedImageFilenames[floating.id],
                   existingFilenames.count == floating.images.count {
                    // Reuse existing filenames - just update position/size (cheap)
                    var items: [FloatingImageItem] = []
                    for (index, filename) in existingFilenames.enumerated() {
                        let image = floating.images[index]
                        items.append(FloatingImageItem(
                            id: UUID(),
                            filename: filename,
                            naturalWidth: image.size.width,
                            naturalHeight: image.size.height
                        ))
                    }

                    let data = FloatingImageData(
                        id: floating.id,
                        images: items,
                        currentIndex: floating.currentIndex,
                        position: floating.position,
                        size: floating.size,
                        originalSize: floating.originalSize,
                        caption: floating.caption
                    )
                    newData.append(data)
                } else {
                    // New image or pile changed - save to storage (expensive, but only once)
                    var items: [FloatingImageItem] = []
                    var filenames: [String] = []
                    for image in floating.images {
                        let filename = saveImageToStorage(image: image)
                        filenames.append(filename)
                        items.append(FloatingImageItem(
                            id: UUID(),
                            filename: filename,
                            naturalWidth: image.size.width,
                            naturalHeight: image.size.height
                        ))
                    }

                    // Cache the filenames for next time
                    savedImageFilenames[floating.id] = filenames

                    let data = FloatingImageData(
                        id: floating.id,
                        images: items,
                        currentIndex: floating.currentIndex,
                        position: floating.position,
                        size: floating.size,
                        originalSize: floating.originalSize,
                        caption: floating.caption
                    )
                    newData.append(data)
                }
            }

            // Clean up cache for deleted images
            let currentIds = Set(floatingImages.map { $0.id })
            savedImageFilenames = savedImageFilenames.filter { currentIds.contains($0.key) }

            floatingImagesData = newData
        }
        
        /// Load floating images from Canvas binding into the text view
        func loadFloatingImages(into textView: EditorialNSTextView) {
            var loadedImages: [FloatingReflowImage] = []

            for data in floatingImagesData {
                // Load NSImages from storage
                var images: [NSImage] = []
                var filenames: [String] = []
                for item in data.images {
                    if let image = loadImageFromStorage(filename: item.filename) {
                        images.append(image)
                        filenames.append(item.filename)
                    }
                }

                guard !images.isEmpty else { continue }

                // Pre-populate the cache so we don't re-save these images
                savedImageFilenames[data.id] = filenames
                
                let floating = FloatingReflowImage(
                    id: data.id,
                    images: images,
                    position: data.position,
                    size: data.size,
                    originalSize: data.originalSize,
                    isSelected: false,
                    caption: data.caption
                )
                loadedImages.append(floating)
            }
            
            textView.floatingImages = loadedImages
            
            // Immediately update exclusion paths
            textView.updateExclusionPaths()
            textView.needsDisplay = true
            
            // Also schedule a delayed update to ensure layout is fully computed
            // This handles cases where the text layout isn't ready yet on app launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak textView] in
                textView?.updateExclusionPaths()
                textView?.needsDisplay = true
            }
        }
        
        /// Load an image from storage by filename
        private func loadImageFromStorage(filename: String) -> NSImage? {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let fileURL = appSupport.appendingPathComponent("Margin/Images/\(filename)")
            return NSImage(contentsOf: fileURL)
        }
    }
}

// MARK: - Custom NSTextView

// MARK: - Floating Reflow Image Model
// This is the primary image component - supports both single images and piles
// Text reflows around it based on horizontal position (left = text flows right, right = text flows left)

struct FloatingReflowImage: Identifiable {
    let id: UUID
    var images: [NSImage]          // Array of images (1 for single, 2+ for pile)
    var currentIndex: Int = 0       // Current visible image in pile
    var position: CGPoint           // Position in text view coordinates
    var size: CGSize                // Current display size
    var originalSize: CGSize        // Original size of first image
    var isSelected: Bool = false
    var caption: String?            // Optional caption text beneath the image
    var isEditingCaption: Bool = false  // Whether caption is being edited
    
    /// Height for caption area (if caption exists or is being edited)
    var captionHeight: CGFloat {
        guard caption != nil || isEditingCaption else { return 0 }
        return 24  // Height for caption text
    }
    
    /// Single image initializer
    init(id: UUID = UUID(), image: NSImage, position: CGPoint) {
        self.id = id
        self.images = [image]
        self.position = position
        self.originalSize = image.size
        // Default to 33% of a typical width, maintaining aspect ratio
        let defaultWidth: CGFloat = 260
        let aspectRatio = image.size.width / image.size.height
        self.size = CGSize(width: defaultWidth, height: defaultWidth / aspectRatio)
    }
    
    /// Pile initializer (multiple images)
    init(id: UUID = UUID(), images: [NSImage], position: CGPoint, size: CGSize) {
        self.id = id
        self.images = images
        self.position = position
        self.size = size
        self.originalSize = images.first?.size ?? CGSize(width: 260, height: 195)
    }
    
    /// Full initializer for restoration (undo/redo)
    init(id: UUID, images: [NSImage], position: CGPoint, size: CGSize, originalSize: CGSize, isSelected: Bool, caption: String? = nil) {
        self.id = id
        self.images = images
        self.position = position
        self.size = size
        self.originalSize = originalSize
        self.isSelected = isSelected
        self.caption = caption
    }
    
    /// Whether this is a pile (2+ images)
    var isPile: Bool {
        images.count > 1
    }
    
    /// The currently visible image
    var currentImage: NSImage? {
        guard currentIndex >= 0 && currentIndex < images.count else { return images.first }
        return images[currentIndex]
    }
    
    /// The base display width for the pile (all images scaled relative to this)
    var displayWidth: CGFloat {
        size.width
    }
    
    /// The center point of the pile (stays fixed for navigation stability)
    var center: CGPoint {
        CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
    }
    
    /// Calculate frame for a specific image based on its own aspect ratio
    /// Uses adaptive sizing to make landscape and portrait images visually similar in area
    func frameForImage(at index: Int) -> CGRect {
        guard index >= 0 && index < images.count else { 
            return CGRect(origin: position, size: size)
        }
        let img = images[index]
        let imgAspect = img.size.width / img.size.height
        
        // Scale landscape images larger so they have comparable visual area to portrait images
        // Target: roughly equal visual "area" regardless of aspect ratio
        // For portrait (aspect < 1): use base width
        // For landscape (aspect > 1): scale up width to compensate for shorter height
        let baseWidth = displayWidth
        let aspectScale: CGFloat
        
        if imgAspect > 1.0 {
            // Landscape image - scale up width based on how much wider it is
            // Use sqrt to balance: a 2:1 landscape would get ~40% wider instead of 100%
            aspectScale = 1.0 + (sqrt(imgAspect) - 1.0) * 0.6
        } else {
            // Portrait or square - use base width
            aspectScale = 1.0
        }
        
        let width = baseWidth * aspectScale
        let height = width / imgAspect
        
        // Center this frame on the pile's center point
        let x = center.x - width / 2
        let y = center.y - height / 2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// The frame for the current image (based on its own aspect ratio)
    var frame: CGRect {
        frameForImage(at: currentIndex)
    }
    
    /// Get the pseudo-random rotation for an image at a given index
    func rotationForImage(at index: Int) -> CGFloat {
        let seed = Double(index * 7 + 13)
        return CGFloat(sin(seed * 0.9) * 4 + cos(seed * 0.5) * 3)  // -7 to +7 degrees
    }
    
    /// Get the pseudo-random offset for an image at a given index
    func offsetForImage(at index: Int) -> CGPoint {
        let seed = Double(index * 7 + 13)
        let offsetX = CGFloat(sin(seed) * 6 + cos(seed * 1.3) * 4)  // -10 to +10
        let offsetY = CGFloat(cos(seed * 0.7) * 4 + sin(seed * 1.1) * 3)  // -7 to +7
        return CGPoint(x: offsetX, y: offsetY)
    }
    
    /// Horizontal padding around the image for text reflow and selection
    static let imageHorizontalPadding: CGFloat = 8
    /// Top padding (more space above to separate from text)
    static let imageTopPadding: CGFloat = 16
    /// Bottom padding (minimal space below)
    static let imageBottomPadding: CGFloat = 0
    
    /// Calculate the bounding box that contains ALL images in the pile
    /// This is STABLE - it doesn't change based on which image is currently in front
    /// Simplified: just use the actual extents of the images with small padding for offsets/rotation
    var pileBoundingBox: CGRect {
        guard !images.isEmpty else { return frame }

        // For single images, just return the frame
        if images.count == 1 {
            return frame
        }

        // For piles, calculate actual bounds of all image frames + their offsets
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for i in 0..<images.count {
            let imageFrame = frameForImage(at: i)
            let offset = offsetForImage(at: i)

            // Small buffer for rotation (max ~7 degrees = very small expansion)
            let buffer: CGFloat = 15

            // Calculate bounds including offset
            let leftX = imageFrame.minX + offset.x - buffer
            let rightX = imageFrame.maxX + offset.x + buffer
            let topY = imageFrame.minY + offset.y - buffer
            let bottomY = imageFrame.maxY + offset.y + buffer

            minX = min(minX, leftX)
            minY = min(minY, topY)
            maxX = max(maxX, rightX)
            maxY = max(maxY, bottomY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// The padded frame (used for text exclusion and selection outline)
    /// For piles, this encompasses ALL images plus caption area
    var paddedFrame: CGRect {
        let pile = pileBoundingBox
        // Apply asymmetric padding: more on top, less on bottom
        var box = CGRect(
            x: pile.minX - Self.imageHorizontalPadding,
            y: pile.minY - Self.imageTopPadding,
            width: pile.width + Self.imageHorizontalPadding * 2,
            height: pile.height + Self.imageTopPadding + Self.imageBottomPadding
        )
        // Extend downward for caption if present
        if captionHeight > 0 {
            box.size.height += captionHeight
        }
        return box
    }
    
    /// The rect for the caption area at the bottom of the component
    var captionRect: CGRect {
        guard captionHeight > 0 else { return .zero }
        // Use pileBoundingBox to avoid circular dependency with paddedFrame
        let pile = pileBoundingBox
        let baseBounds = CGRect(
            x: pile.minX - Self.imageHorizontalPadding,
            y: pile.minY - Self.imageTopPadding,
            width: pile.width + Self.imageHorizontalPadding * 2,
            height: pile.height + Self.imageTopPadding + Self.imageBottomPadding
        )
        return CGRect(
            x: baseBounds.minX,
            y: baseBounds.maxY,  // Below the base bounds, at the bottom
            width: baseBounds.width,
            height: captionHeight
        )
    }
    
    /// Returns which side the image floats to based on its center position
    func floatSide(in containerWidth: CGFloat) -> FloatSide {
        let centerX = position.x + size.width / 2
        return centerX < containerWidth / 2 ? .left : .right
    }
    
    /// Navigate to next image in pile
    mutating func nextImage() {
        guard isPile else { return }
        currentIndex = (currentIndex + 1) % images.count
    }
    
    /// Navigate to previous image in pile
    mutating func previousImage() {
        guard isPile else { return }
        currentIndex = (currentIndex - 1 + images.count) % images.count
    }
    
    /// Navigate to specific image
    mutating func goToImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        currentIndex = index
    }
    
    /// Add an image to create/extend a pile
    mutating func addImage(_ image: NSImage) {
        images.append(image)
    }
    
    /// Combine with another floating image to create a pile
    mutating func combineWith(_ other: FloatingReflowImage) {
        images.append(contentsOf: other.images)
    }
    
    enum FloatSide {
        case left, right
    }
}

class EditorialNSTextView: NSTextView, NSTextFieldDelegate {
    var currentTypeSystem: TypeSystem = .editorialSerif
    var currentLayoutMode: LayoutMode = .write
    var currentBaseFontSize: CGFloat = 18.0
    var currentLineHeightMultiple: CGFloat = 1.65
    var slashCommandHandler: ((CGPoint) -> Void)?
    var floatingImagesChangedHandler: (([FloatingReflowImage]) -> Void)?  // Handler for floating image changes (persists to disk)
    var floatingImagePositionChangedHandler: (() -> Void)?  // Handler for position changes during drag (lightweight, no disk I/O)
    var canvasId: UUID?  // Canvas ID for saving images
    private var placeholderString = "Start writing..."

    // Page layout constraints - allows floating images beyond text bounds
    var pageMaxWidth: CGFloat = 680      // Max width for text content
    var pageHorizontalInset: CGFloat = 0 // Horizontal inset to center text
    
    // Image selection and resize state
    let imageSelectionManager = ImageSelectionManager()
    private var isResizingImage = false
    private var resizeStartPoint: NSPoint = .zero
    private var resizeStartPercent: CGFloat = 0
    private var activeResizeHandle: ResizableImageAttachmentCell.ResizeHandlePosition = .none

    // MARK: - Floating Reflow Images (Text flows around these)
    
    /// Floating images that text reflows around
    var floatingImages: [FloatingReflowImage] = []
    
    /// Currently selected floating image for drag/resize
    var selectedFloatingImageId: UUID?
    
    /// Currently hovered floating image (for showing navigation controls)
    var hoveredFloatingImageId: UUID?
    
    /// Hover animation progress for each image (0.0 = not hovered, 1.0 = fully hovered)
    private var hoverAnimationProgress: [UUID: CGFloat] = [:]
    private var hoverAnimationTimer: Timer?

    /// Hover animation transform values
    private struct HoverTransform {
        var offset: CGPoint = .zero
        var scale: CGFloat = 1.0
        var additionalRotation: CGFloat = 0.0
    }
    
    /// Drag state for floating images
    private var isDraggingFloatingImage = false
    private var floatingDragOffset: CGPoint = .zero
    private var floatingDragStartPosition: CGPoint = .zero  // For undo
    
    /// Resize state for floating images
    private var isResizingFloatingImage = false
    private var floatingResizeHandle: ResizeHandle = .none
    private var floatingResizeStartFrame: CGRect = .zero
    private var floatingResizeStartMouse: CGPoint = .zero
    private var floatingResizeOriginalFrame: CGRect = .zero  // For undo (saved before any resize)
    
    /// Pile creation state (when dragging one floating image onto another)
    private var floatingPileTargetId: UUID?
    private var floatingPileDropTargetLayer: CALayer?
    
    /// Gap between image and text
    private let reflowGap: CGFloat = 14
    
    enum ResizeHandle {
        case none, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
        
        var cursor: NSCursor {
            switch self {
            case .none: return .arrow
            // Diagonal cursors - match Figma behavior
            case .topLeft, .bottomRight: 
                // NW-SE diagonal (↖↘) - arrow points top-left to bottom-right
                return NSCursor(image: Self.diagonalResizeCursorImage(nwse: true), hotSpot: NSPoint(x: 8, y: 8))
            case .topRight, .bottomLeft: 
                // NE-SW diagonal (↗↙) - arrow points top-right to bottom-left
                return NSCursor(image: Self.diagonalResizeCursorImage(nwse: false), hotSpot: NSPoint(x: 8, y: 8))
            // Edge cursors - horizontal for sides, vertical for top/bottom
            case .top, .bottom: return .resizeUpDown
            case .left, .right: return .resizeLeftRight
            }
        }
        
        /// Generate a diagonal resize cursor image
        private static func diagonalResizeCursorImage(nwse: Bool) -> NSImage {
            let size = NSSize(width: 16, height: 16)
            let image = NSImage(size: size, flipped: true) { rect in
                let path = NSBezierPath()
                
                if nwse {
                    // NW-SE diagonal (↖↘) - for topLeft/bottomRight
                    // Line from top-left to bottom-right
                    path.move(to: NSPoint(x: 2, y: 2))
                    path.line(to: NSPoint(x: 14, y: 14))
                    // Top-left arrow head
                    path.move(to: NSPoint(x: 2, y: 6))
                    path.line(to: NSPoint(x: 2, y: 2))
                    path.line(to: NSPoint(x: 6, y: 2))
                    // Bottom-right arrow head
                    path.move(to: NSPoint(x: 14, y: 10))
                    path.line(to: NSPoint(x: 14, y: 14))
                    path.line(to: NSPoint(x: 10, y: 14))
                } else {
                    // NE-SW diagonal (↗↙) - for topRight/bottomLeft
                    // Line from top-right to bottom-left
                    path.move(to: NSPoint(x: 14, y: 2))
                    path.line(to: NSPoint(x: 2, y: 14))
                    // Top-right arrow head
                    path.move(to: NSPoint(x: 10, y: 2))
                    path.line(to: NSPoint(x: 14, y: 2))
                    path.line(to: NSPoint(x: 14, y: 6))
                    // Bottom-left arrow head
                    path.move(to: NSPoint(x: 2, y: 10))
                    path.line(to: NSPoint(x: 2, y: 14))
                    path.line(to: NSPoint(x: 6, y: 14))
                }
                
                // Draw white outline for visibility
                NSColor.white.setStroke()
                path.lineWidth = 3.5
                path.lineCapStyle = .round
                path.stroke()
                
                // Draw black line on top
                NSColor.black.setStroke()
                path.lineWidth = 1.5
                path.stroke()
                
                return true
            }
            return image
        }
    }

    // MARK: - Smooth Resize Optimization

    /// Throttle interval for resize updates (16ms = 60fps)
    private let resizeThrottleInterval: TimeInterval = 1.0 / 60.0
    private var lastResizeTime: TimeInterval = 0

    /// Pending resize percentage to apply after drag ends
    private var pendingResizePercent: CGFloat?

    /// Size tooltip window for live feedback
    private var sizeTooltipWindow: NSWindow?
    private var sizeTooltipLabel: NSTextField?

    /// Snap points for intelligent resizing (percentages)
    private let snapPoints: [CGFloat] = [0.25, 0.33, 0.50, 0.75, 1.0]
    private let snapThreshold: CGFloat = 0.03 // 3% threshold for snapping

    /// Drop preview layer for drag feedback
    private var dropPreviewLayer: CALayer?

    // MARK: - Block Drag-and-Drop State

    /// Reference to current media blocks (set by coordinator)
    var currentMediaBlocks: [MediaBlock] = []

    /// Currently hovered block for drag handle display
    private var hoveredBlockId: UUID?
    private var hoveredBlockFrame: NSRect?

    /// Drag handle layer (grip icon that appears on hover)
    private var dragHandleLayer: CALayer?
    private var dragHandleDots: [CALayer] = []

    /// Block drag state
    private var isDraggingBlock = false
    private var draggedBlockId: UUID?
    private var draggedBlockType: DocumentBlockType?
    private var dragStartLocation: CGPoint = .zero
    private var blockDragPreviewLayer: CALayer?
    private var blockDropIndicatorLayer: CALayer?

    /// Tracks if mouse is over the drag handle
    private var isMouseOverDragHandle = false

    // MARK: - Inline Image Drag State (for pile creation)

    /// Whether we're dragging an inline image (for pile creation)
    private var isDraggingInlineImage = false
    private var draggedInlineImageRange: NSRange?
    private var draggedInlineImageAttachment: ResizableImageAttachmentCell?
    private var inlineImageDragStartPoint: CGPoint = .zero
    private var inlineImageDragPreviewLayer: CALayer?
    private var inlineImageDropTargetLayer: CALayer?
    private var potentialPileTargetRange: NSRange?


    // MARK: - Image Toolbar State

    /// Floating toolbar window for image layout controls
    private var imageToolbarWindow: NSWindow?

    /// Timer for auto-hiding the toolbar after 3 seconds
    private var toolbarAutoHideTimer: Timer?

    /// Currently tracked image attachment (for toolbar positioning) - legacy inline images
    private var toolbarTargetAttachment: ResizableImageAttachmentCell?
    private var toolbarTargetRange: NSRange?
    
    /// Currently tracked floating image (for toolbar positioning)
    private var toolbarTargetFloatingImageId: UUID?

    /// Whether the toolbar is being hovered (prevents auto-hide)
    private var isToolbarHovered: Bool = false

    /// Handler for layout preset changes (set by coordinator)
    var imageLayoutPresetChangedHandler: ((_ attachmentId: UUID, _ preset: ImageLayoutPreset) -> Void)?

    /// Handler for caption button clicks (set by coordinator)
    var imageCaptionRequestedHandler: ((_ attachmentId: UUID, _ range: NSRange) -> Void)?

    // MARK: - Image Hover Indicator State

    /// Small indicator button that appears on image hover after toolbar fades
    private var hoverIndicatorLayer: CALayer?

    /// Currently hovered inline image (for showing indicator)
    private var hoveredInlineImageRange: NSRange?
    private var hoveredInlineImageAttachment: ResizableImageAttachmentCell?

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Document Block Types

    /// Represents a block type in the document (for drag-drop)
    enum DocumentBlockType {
        case paragraph(range: NSRange, text: String)
        case media(MediaBlock)
    }
    
    // MARK: - Text Reflow with Exclusion Paths
    
    /// Updates exclusion paths for all floating images so text reflows around them
    /// Real-time text reflow: As the image moves, text dynamically wraps around it on one side
    /// based on the image's horizontal position (left side = text flows right, right side = text flows left)
    ///
    /// COORDINATE SYSTEM NOTE:
    /// - Floating images are positioned in VIEW coordinates (which include textContainerInset)
    /// - Exclusion paths must be in TEXT CONTAINER coordinates (starting at textContainerOrigin)
    /// - We convert image positions by subtracting textContainerOrigin
    /// - Images beyond the text container bounds still create exclusion at the container edges
    func updateExclusionPaths() {
        guard let textContainer = textContainer else { return }

        var paths: [NSBezierPath] = []
        let containerWidth = textContainer.size.width
        let origin = textContainerOrigin

        for floatingImage in floatingImages {
            // Convert padded frame from view coordinates to text container coordinates
            let paddedFrame = floatingImage.paddedFrame
            let containerFrame = NSRect(
                x: paddedFrame.minX - origin.x,
                y: paddedFrame.minY - origin.y,
                width: paddedFrame.width,
                height: paddedFrame.height
            )

            // Skip if the image doesn't vertically overlap with text area
            // (images completely above or below visible content don't need exclusions)

            // Determine float side based on image position relative to text container
            // Images to the left of center push text right, images to the right push text left
            let imageCenterInContainer = containerFrame.midX
            let floatSide: FloatingReflowImage.FloatSide = imageCenterInContainer < containerWidth / 2 ? .left : .right

            // Create exclusion path based on which side the image is on
            // This forces text to flow on the opposite side
            var exclusionRect: NSRect

            if floatSide == .left {
                // Image is on left half → text should flow on the RIGHT side
                // Create exclusion from left edge of container to right edge of image
                // Clamp to container bounds (images beyond left edge still exclude from 0)
                let rightEdge = max(0, min(containerFrame.maxX, containerWidth))
                exclusionRect = NSRect(
                    x: 0,
                    y: containerFrame.minY,
                    width: rightEdge,
                    height: containerFrame.height
                )
            } else {
                // Image is on right half → text should flow on the LEFT side
                // Create exclusion from left edge of image to right edge of container
                // Clamp to container bounds (images beyond right edge still exclude to containerWidth)
                let leftEdge = max(0, min(containerFrame.minX, containerWidth))
                exclusionRect = NSRect(
                    x: leftEdge,
                    y: containerFrame.minY,
                    width: containerWidth - leftEdge,
                    height: containerFrame.height
                )
            }

            // Only add exclusion if it has positive dimensions
            if exclusionRect.width > 0 && exclusionRect.height > 0 {
                let path = NSBezierPath(rect: exclusionRect)
                paths.append(path)
            }
        }

        textContainer.exclusionPaths = paths

        // Force layout recalculation
        layoutManager?.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage?.length ?? 0), actualCharacterRange: nil)
        layoutManager?.ensureLayout(for: textContainer)
        needsDisplay = true
    }
    
    /// Adds a new floating image at the specified position
    func addFloatingImage(_ image: NSImage, at position: CGPoint) {
        print("[FloatingImage] Adding floating image at position: \(position), size: \(image.size)")
        let floatingImage = FloatingReflowImage(image: image, position: position)
        floatingImages.append(floatingImage)
        selectedFloatingImageId = floatingImage.id
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        
        // Register undo for adding the image
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeFloatingImageWithoutUndo(id: floatingImage.id)
        }
        undoManager?.setActionName("Add Image")
    }
    
    /// Notify that floating images have changed (for persistence)
    private func notifyFloatingImagesChanged() {
        floatingImagesChangedHandler?(floatingImages)
    }
    
    /// Removes a floating image by ID
    func removeFloatingImage(id: UUID) {
        // Store the image before removing for undo
        guard let imageToRemove = floatingImages.first(where: { $0.id == id }) else { return }
        let storedImages = imageToRemove.images
        let storedPosition = imageToRemove.position
        let storedSize = imageToRemove.size
        let storedOriginalSize = imageToRemove.originalSize
        let storedId = imageToRemove.id
        
        floatingImages.removeAll { $0.id == id }
        if selectedFloatingImageId == id {
            selectedFloatingImageId = nil
        }
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        
        // Register undo for removing the image
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreFloatingImage(id: storedId, images: storedImages, position: storedPosition, size: storedSize, originalSize: storedOriginalSize)
        }
        undoManager?.setActionName("Delete Image")
    }
    
    /// Internal remove without undo registration (used for undo of add)
    private func removeFloatingImageWithoutUndo(id: UUID) {
        floatingImages.removeAll { $0.id == id }
        if selectedFloatingImageId == id {
            selectedFloatingImageId = nil
        }
        updateExclusionPaths()
        notifyFloatingImagesChanged()
    }
    
    /// Restores a floating image (used for undo of remove)
    private func restoreFloatingImage(id: UUID, images: [NSImage], position: CGPoint, size: CGSize, originalSize: CGSize) {
        var restoredImage = FloatingReflowImage(id: id, images: images, position: position, size: size)
        restoredImage.originalSize = originalSize
        floatingImages.append(restoredImage)
        selectedFloatingImageId = id
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        
        // Register redo (which is undo of undo - removes the image again)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeFloatingImage(id: id)
        }
    }
    
    /// Registers undo for moving a floating image
    func registerMoveUndo(for imageId: UUID, from oldPosition: CGPoint) {
        guard floatingImages.first(where: { $0.id == imageId }) != nil else { return }
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.moveFloatingImage(id: imageId, to: oldPosition, registerUndo: true)
        }
        undoManager?.setActionName("Move Image")
    }
    
    /// Moves a floating image to a specific position
    private func moveFloatingImage(id: UUID, to position: CGPoint, registerUndo: Bool) {
        guard let index = floatingImages.firstIndex(where: { $0.id == id }) else { return }
        let oldPosition = floatingImages[index].position
        floatingImages[index].position = position
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        
        if registerUndo {
            undoManager?.registerUndo(withTarget: self) { target in
                target.moveFloatingImage(id: id, to: oldPosition, registerUndo: true)
            }
        }
    }
    
    /// Registers undo for resizing a floating image
    func registerResizeUndo(for imageId: UUID, from oldFrame: CGRect) {
        guard floatingImages.first(where: { $0.id == imageId }) != nil else { return }
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.resizeFloatingImage(id: imageId, to: oldFrame, registerUndo: true)
        }
        undoManager?.setActionName("Resize Image")
    }
    
    /// Resizes a floating image to a specific frame
    private func resizeFloatingImage(id: UUID, to frame: CGRect, registerUndo: Bool) {
        guard let index = floatingImages.firstIndex(where: { $0.id == id }) else { return }
        let oldFrame = floatingImages[index].frame
        floatingImages[index].position = frame.origin
        floatingImages[index].size = frame.size
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        
        if registerUndo {
            undoManager?.registerUndo(withTarget: self) { target in
                target.resizeFloatingImage(id: id, to: oldFrame, registerUndo: true)
            }
        }
    }
    
    // MARK: - Floating Image Hit Testing
    
    /// Returns the floating image at the given point, if any
    /// - Parameters:
    ///   - point: The point to test
    ///   - excluding: Optional ID of an image to exclude from hit testing (e.g., when dragging)
    private func floatingImage(at point: CGPoint, excluding: UUID? = nil) -> FloatingReflowImage? {
        // Check in reverse order so topmost images are selected first
        for image in floatingImages.reversed() {
            // Skip the excluded image (e.g., the one being dragged)
            if let excludeId = excluding, image.id == excludeId {
                continue
            }
            // Use padded frame for hit testing (matches the selection outline)
            if image.paddedFrame.contains(point) {
                return image
            }
        }
        return nil
    }
    
    /// Returns the resize handle at the given point for a floating image
    private func resizeHandle(at point: CGPoint, for image: FloatingReflowImage) -> ResizeHandle {
        // Use padded frame for handle positions (matches the selection outline)
        let frame = image.paddedFrame
        let handleSize: CGFloat = 20  // Larger hit target for easier grabbing
        
        // In flipped coordinates (NSTextView):
        // - minY is the TOP of the frame
        // - maxY is the BOTTOM of the frame
        
        // Corner handles (check corners first - they have priority)
        // Top-left corner (minX, minY in flipped coords)
        if NSRect(x: frame.minX - handleSize/2, y: frame.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .topLeft
        }
        // Top-right corner (maxX, minY in flipped coords)
        if NSRect(x: frame.maxX - handleSize/2, y: frame.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .topRight
        }
        // Bottom-left corner (minX, maxY in flipped coords)
        if NSRect(x: frame.minX - handleSize/2, y: frame.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottomLeft
        }
        // Bottom-right corner (maxX, maxY in flipped coords)
        if NSRect(x: frame.maxX - handleSize/2, y: frame.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottomRight
        }
        
        // Edge handles
        // Top edge (minY in flipped coords)
        if NSRect(x: frame.midX - handleSize/2, y: frame.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .top
        }
        // Bottom edge (maxY in flipped coords)
        if NSRect(x: frame.midX - handleSize/2, y: frame.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottom
        }
        // Left edge
        if NSRect(x: frame.minX - handleSize/2, y: frame.midY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .left
        }
        // Right edge
        if NSRect(x: frame.maxX - handleSize/2, y: frame.midY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .right
        }
        
        return .none
    }
    
    // MARK: - Setup
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        imageSelectionManager.textView = self
    }
    
    // MARK: - Drag and Drop Registration
    
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes(Self.supportedDragTypes)
    }
    
    func setupDragAndDrop() {
        registerForDraggedTypes(Self.supportedDragTypes)
        imageSelectionManager.textView = self

        // Enable Core Animation layer for smoother resize animations
        wantsLayer = true
        layer?.masksToBounds = false  // Allow floating images to extend beyond view bounds
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    private static var supportedDragTypes: [NSPasteboard.PasteboardType] {
        return [
            .png, .tiff, .fileURL,
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.png")
        ]
    }

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
                .font: currentTypeSystem.bodyFont(size: currentBaseFontSize),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let inset = textContainerInset
            let rect = NSRect(x: inset.width + 5, y: inset.height, width: bounds.width - inset.width * 2, height: bounds.height)
            placeholderString.draw(in: rect, withAttributes: attributes)
        }
        
        // Draw floating reflow images
        drawFloatingImages(in: dirtyRect)
    }
    
    /// Draws all floating images with selection handles
    /// NOTE: Image rendering is now handled by SwiftUI FloatingImagesLayer to avoid clipping
    /// This method only draws selection UI (resize handles, etc.)
    private func drawFloatingImages(in dirtyRect: NSRect) {
        for floatingImage in floatingImages {
            let frame = floatingImage.frame

            // For piles, we need a larger dirty rect check due to scattered cards
            let expandedFrame = frame.insetBy(dx: -30, dy: -30)
            guard expandedFrame.intersects(dirtyRect) else { continue }

            // NOTE: Skip drawing the actual image - it's rendered by SwiftUI FloatingImagesLayer
            // This prevents clipping issues since NSScrollView clips its content
            // We only draw selection UI, captions, and navigation controls here

            // DISABLED: Pile stack effect and main image drawing - handled by SwiftUI
            // if floatingImage.isPile { drawPileStackEffect(for: floatingImage) }
            // Image drawing code removed - see FloatingImagesLayer
            
            // Draw caption if present (and not currently being edited via text field)
            if let caption = floatingImage.caption, !caption.isEmpty, !floatingImage.isEditingCaption {
                drawFloatingImageCaption(caption, for: floatingImage)
            }
            
            // Draw "Add caption" hint when hovered or selected and no caption
            let isHoveredOrSelected = floatingImage.id == selectedFloatingImageId || floatingImage.id == hoveredFloatingImageId
            if isHoveredOrSelected && floatingImage.caption == nil && !floatingImage.isEditingCaption {
                drawCaptionHint(for: floatingImage)
            }
            
            // DISABLED: Pile navigation is now rendered in SwiftUI (FloatingPileView)
            // if floatingImage.isPile && (floatingImage.id == hoveredFloatingImageId || floatingImage.id == selectedFloatingImageId) {
            //     drawPileNavigation(for: floatingImage)
            // }
            
            // Selection UI is now rendered in SwiftUI overlay (SelectionOverlayView)
            // to prevent clipping by the scroll view
        }
    }
    
    /// Calculates a rect that fills the target while maintaining aspect ratio (aspect fill)
    private func aspectFillRect(for imageSize: NSSize, in targetRect: NSRect) -> NSRect {
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = targetRect.width / targetRect.height
        
        var drawRect: NSRect
        
        if imageAspect > targetAspect {
            // Image is wider than target - match heights, center horizontally
            let drawHeight = targetRect.height
            let drawWidth = drawHeight * imageAspect
            let drawX = targetRect.minX - (drawWidth - targetRect.width) / 2
            drawRect = NSRect(x: drawX, y: targetRect.minY, width: drawWidth, height: drawHeight)
        } else {
            // Image is taller than target - match widths, center vertically
            let drawWidth = targetRect.width
            let drawHeight = drawWidth / imageAspect
            let drawY = targetRect.minY - (drawHeight - targetRect.height) / 2
            drawRect = NSRect(x: targetRect.minX, y: drawY, width: drawWidth, height: drawHeight)
        }
        
        return drawRect
    }
    
    /// Draws the scattered stack effect for image piles (cards behind the main image)
    private func drawPileStackEffect(for image: FloatingReflowImage) {
        let pileCenter = image.center
        let imageCount = image.images.count
        let visibleCards = min(imageCount, 4) // Show max 4 background cards
        
        // Get the front image's aspect ratio to compare
        let frontAspect = image.currentImage.map { $0.size.width / $0.size.height } ?? 1.0
        
        // Draw background cards from back to front (skip the current one which is drawn separately)
        for i in (0..<visibleCards).reversed() {
            // Skip the current image (it's drawn as the main image)
            let actualIndex = (image.currentIndex + i + 1) % imageCount
            guard actualIndex != image.currentIndex else { continue }
            
            let cardImage = image.images[actualIndex]
            
            // Get unique rotation and offset for this image (uses same values when it comes to front)
            let randomRotation = image.rotationForImage(at: actualIndex)
            let randomOffset = image.offsetForImage(at: actualIndex)

            // Get hover animation transform for this card (includes offset and scale)
            let hoverXform = hoverTransform(for: image, at: actualIndex)

            // Scale based on depth (cards further back are slightly smaller)
            let depthScale: CGFloat = 0.95 - CGFloat(i) * 0.02  // 95%, 93%, 91%... (less aggressive scaling)

            // Apply hover scale on top of depth scale
            let totalScale = depthScale * hoverXform.scale

            // Calculate card size based on THIS image's aspect ratio
            // Apply same landscape scaling as frameForImage for consistent sizing
            let cardAspect = cardImage.size.width / cardImage.size.height
            let landscapeScale: CGFloat = cardAspect > 1.0 ? (1.0 + (sqrt(cardAspect) - 1.0) * 0.6) : 1.0
            let cardWidth = image.displayWidth * totalScale * landscapeScale
            let cardHeight = cardWidth / cardAspect

            // Calculate how much this card should stick out to the sides
            // If this card is wider (more landscape) than the front card, it should stick out more
            let aspectDifference = cardAspect - frontAspect  // Positive = this card is more landscape
            let baseStickOut: CGFloat = 15 + CGFloat(i) * 8  // Base horizontal offset that increases with depth

            // Alternate left/right based on index, with extra offset for landscape cards behind portrait
            let direction: CGFloat = (actualIndex % 2 == 0) ? -1.0 : 1.0
            let landscapeBonus: CGFloat = max(0, aspectDifference * 20)  // Extra offset if card is more landscape
            let horizontalStickOut = direction * (baseStickOut + landscapeBonus)

            // Vertical offset - balanced around center with slight variation
            let verticalOffset: CGFloat = direction * CGFloat(i) * 3

            // Center the card on pile center, apply offsets (including hover offset for fanning out)
            let cardX = pileCenter.x - cardWidth / 2 + randomOffset.x + horizontalStickOut + hoverXform.offset.x
            let cardY = pileCenter.y - cardHeight / 2 + randomOffset.y + verticalOffset + hoverXform.offset.y
            let cardFrame = NSRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            
            NSGraphicsContext.saveGraphicsState()
            
            // Apply rotation around the center of the card
            let centerX = cardFrame.midX
            let centerY = cardFrame.midY
            let transform = NSAffineTransform()
            transform.translateX(by: centerX, yBy: centerY)
            transform.rotate(byDegrees: randomRotation)
            transform.translateX(by: -centerX, yBy: -centerY)
            transform.concat()
            
            // Draw card shadow
            let shadowPath = NSBezierPath(roundedRect: cardFrame, xRadius: 12, yRadius: 12)
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
            shadow.shadowBlurRadius = 10
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            shadow.set()
            NSColor.black.setFill()
            shadowPath.fill()
            
            // Reset shadow
            NSShadow().set()
            
            // Clip to rounded rect and draw the actual image preview
            let clipPath = NSBezierPath(roundedRect: cardFrame, xRadius: 12, yRadius: 12)
            clipPath.addClip()
            
            // Draw the image - frame already matches this image's aspect ratio
            cardImage.draw(in: cardFrame)
            
            // Add a slight darkening overlay to show depth
            let overlayOpacity: CGFloat = 0.12 + CGFloat(i) * 0.06  // Subtle darkening for cards further back
            NSColor.black.withAlphaComponent(overlayOpacity).setFill()
            NSBezierPath(rect: cardFrame).fill()
            
            NSGraphicsContext.restoreGraphicsState()
            
            // Draw border outside the clip (need new graphics state)
            NSGraphicsContext.saveGraphicsState()
            let borderTransform = NSAffineTransform()
            borderTransform.translateX(by: centerX, yBy: centerY)
            borderTransform.rotate(byDegrees: randomRotation)
            borderTransform.translateX(by: -centerX, yBy: -centerY)
            borderTransform.concat()
            
            NSColor.white.withAlphaComponent(0.15).setStroke()
            let borderPath = NSBezierPath(roundedRect: cardFrame, xRadius: 12, yRadius: 12)
            borderPath.lineWidth = 1
            borderPath.stroke()
            
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    
    /// Draws navigation controls for image piles
    private func drawPileNavigation(for image: FloatingReflowImage) {
        let paddedFrame = image.paddedFrame
        
        // Navigation arrows - spread to either side, vertically centered
        let arrowSize: CGFloat = 28
        let sidePadding: CGFloat = 8  // Distance from sides of bounding box
        
        // Vertically center arrows
        let arrowY = paddedFrame.midY - arrowSize / 2
        
        // Left arrow (previous) - on the left side
        let leftArrowRect = NSRect(x: paddedFrame.minX + sidePadding, y: arrowY, width: arrowSize, height: arrowSize)
        NSColor.black.withAlphaComponent(0.5).setFill()
        let leftArrowBg = NSBezierPath(ovalIn: leftArrowRect)
        leftArrowBg.fill()
        
        let arrowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let leftArrow = "‹"
        let leftArrowTextSize = (leftArrow as NSString).size(withAttributes: arrowAttrs)
        let leftArrowPoint = NSPoint(
            x: leftArrowRect.midX - leftArrowTextSize.width / 2,
            y: leftArrowRect.midY - leftArrowTextSize.height / 2
        )
        (leftArrow as NSString).draw(at: leftArrowPoint, withAttributes: arrowAttrs)
        
        // Right arrow (next) - on the right side
        let rightArrowRect = NSRect(x: paddedFrame.maxX - arrowSize - sidePadding, y: arrowY, width: arrowSize, height: arrowSize)
        NSColor.black.withAlphaComponent(0.5).setFill()
        let rightArrowBg = NSBezierPath(ovalIn: rightArrowRect)
        rightArrowBg.fill()
        
        let rightArrow = "›"
        let rightArrowTextSize = (rightArrow as NSString).size(withAttributes: arrowAttrs)
        let rightArrowPoint = NSPoint(
            x: rightArrowRect.midX - rightArrowTextSize.width / 2,
            y: rightArrowRect.midY - rightArrowTextSize.height / 2
        )
        (rightArrow as NSString).draw(at: rightArrowPoint, withAttributes: arrowAttrs)
    }
    
    /// Draws the caption text beneath a floating image
    private func drawFloatingImageCaption(_ caption: String, for image: FloatingReflowImage) {
        let captionRect = image.captionRect
        guard !captionRect.isEmpty else { return }
        
        // Check if this image is hovered for enhanced visibility
        let isHovered = image.id == hoveredFloatingImageId || image.id == selectedFloatingImageId
        
        // Caption styling - italic font
        let captionFont: NSFont
        if let newsreader = NSFont(name: "Newsreader-Italic", size: 13) {
            captionFont = newsreader
        } else {
            let baseFont = NSFont.systemFont(ofSize: 13)
            captionFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        
        // Use more legible color when hovered
        let textColor: NSColor = isHovered 
            ? NSColor(MarginColors.stone600)  // Darker, more legible on hover
            : NSColor(MarginColors.stone400)  // Subtle when not hovered
        
        // Draw background pill when hovered for better legibility
        if isHovered {
            let captionSize = (caption as NSString).size(withAttributes: [.font: captionFont])
            let bgPadding: CGFloat = 8
            let bgRect = NSRect(
                x: captionRect.midX - captionSize.width / 2 - bgPadding,
                y: captionRect.midY - captionSize.height / 2 - 4,
                width: captionSize.width + bgPadding * 2,
                height: captionSize.height + 8
            )
            
            // Draw semi-transparent background
            NSColor(MarginColors.paper).withAlphaComponent(0.85).setFill()
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
            bgPath.fill()
        }
        
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Draw the caption text centered
        let captionSize = (caption as NSString).size(withAttributes: captionAttrs)
        let textY = captionRect.midY - captionSize.height / 2
        let textRect = NSRect(x: captionRect.minX, y: textY, width: captionRect.width, height: captionSize.height)
        (caption as NSString).draw(in: textRect, withAttributes: captionAttrs)
    }
    
    /// Draws a hint to add caption when image is selected
    private func drawCaptionHint(for image: FloatingReflowImage) {
        let paddedFrame = image.paddedFrame
        
        // Position hint BELOW the paddedFrame (outside all images)
        let hintHeight: CGFloat = 20
        let hintRect = NSRect(
            x: paddedFrame.minX,
            y: paddedFrame.maxY + 4,  // Below the component, not inside it
            width: paddedFrame.width,
            height: hintHeight
        )
        
        let hintFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        // Draw a subtle background pill for better visibility
        let hintText = "Double-click to add caption"
        let textSize = (hintText as NSString).size(withAttributes: [.font: hintFont])
        let bgPadding: CGFloat = 8
        let bgRect = NSRect(
            x: paddedFrame.midX - textSize.width / 2 - bgPadding,
            y: hintRect.minY,
            width: textSize.width + bgPadding * 2,
            height: hintHeight
        )
        
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 10, yRadius: 10)
        NSColor(MarginColors.stone100).withAlphaComponent(0.9).setFill()
        bgPath.fill()
        
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: hintFont,
            .foregroundColor: NSColor(MarginColors.stone500),
            .paragraphStyle: paragraphStyle
        ]
        
        (hintText as NSString).draw(in: hintRect, withAttributes: hintAttrs)
    }
    
    /// Draws selection border and handles for a floating image
    private func drawFloatingImageSelection(for image: FloatingReflowImage) {
        let paddedFrame = image.paddedFrame
        
        // Selection border - uses system accent color for theme adaptability
        // Draw around the padded frame to show the full interactive area
        let borderColor = MarginColors.selectionNS
        borderColor.setStroke()
        let borderPath = NSBezierPath(roundedRect: paddedFrame, xRadius: 8, yRadius: 8)
        borderPath.lineWidth = 2
        borderPath.stroke()
        
        // Resize handles - positioned on the padded frame edges
        // In flipped coordinates: minY = top, maxY = bottom
        let handleSize: CGFloat = 10
        let handleColor = NSColor.white
        let handleBorderColor = MarginColors.selectionNS
        
        let handlePositions: [(CGFloat, CGFloat)] = [
            (paddedFrame.minX, paddedFrame.minY),  // Top left (minX, minY in flipped)
            (paddedFrame.midX, paddedFrame.minY),  // Top center
            (paddedFrame.maxX, paddedFrame.minY),  // Top right (maxX, minY in flipped)
            (paddedFrame.maxX, paddedFrame.midY),  // Right center
            (paddedFrame.maxX, paddedFrame.maxY),  // Bottom right (maxX, maxY in flipped)
            (paddedFrame.midX, paddedFrame.maxY),  // Bottom center
            (paddedFrame.minX, paddedFrame.maxY),  // Bottom left (minX, maxY in flipped)
            (paddedFrame.minX, paddedFrame.midY),  // Left center
        ]
        
        for (x, y) in handlePositions {
            let handleRect = NSRect(
                x: x - handleSize/2,
                y: y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            
            handleColor.setFill()
            handleBorderColor.setStroke()
            
            let handlePath = NSBezierPath(ovalIn: handleRect)
            handlePath.fill()
            handlePath.lineWidth = 1.5
            handlePath.stroke()
        }
        
        // Float side indicator
        let floatSide = image.floatSide(in: bounds.width)
        let labelText = floatSide == .left ? "← Left" : "Right →"
        let labelFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let labelColor = isDraggingFloatingImage ? NSColor.white : MarginColors.selectionNS
        let labelBgColor = isDraggingFloatingImage ? MarginColors.selectionNS : NSColor.white
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: labelColor
        ]
        let labelSize = (labelText as NSString).size(withAttributes: labelAttrs)
        let labelRect = NSRect(
            x: paddedFrame.midX - labelSize.width/2 - 8,
            y: paddedFrame.minY - labelSize.height - 16,  // Position below the padded frame
            width: labelSize.width + 16,
            height: labelSize.height + 8
        )
        
        // Draw label background
        labelBgColor.setFill()
        let labelPath = NSBezierPath(roundedRect: labelRect, xRadius: labelRect.height/2, yRadius: labelRect.height/2)
        labelPath.fill()
        
        if !isDraggingFloatingImage {
            MarginColors.selectionLight.setStroke()
            labelPath.lineWidth = 1
            labelPath.stroke()
        }
        
        // Draw label text
        let textPoint = NSPoint(x: labelRect.minX + 8, y: labelRect.minY + 4)
        (labelText as NSString).draw(at: textPoint, withAttributes: labelAttrs)
    }

    override func mouseDown(with event: NSEvent) {
        let windowPoint = event.locationInWindow
        let viewPoint = convert(windowPoint, from: nil)

        // Adjust for text container origin
        let textContainerOrigin = self.textContainerOrigin
        let containerPoint = NSPoint(
            x: viewPoint.x - textContainerOrigin.x,
            y: viewPoint.y - textContainerOrigin.y
        )

        // ZERO: Check if clicking on hover indicator to show toolbar
        if let indicatorLayer = hoverIndicatorLayer,
           !indicatorLayer.isHidden,
           indicatorLayer.frame.contains(viewPoint),
           let attachment = hoveredInlineImageAttachment,
           let range = hoveredInlineImageRange {
            // Get the image rect
            if let layoutManager = layoutManager,
               let textContainer = textContainer {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let imageRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                hideHoverIndicator()
                showImageToolbar(for: attachment, at: range, imageRect: imageRect)
            }
            return
        }

        // FIRST: Check if clicking on the drag handle to start block drag
        if isPointOverDragHandle(viewPoint),
           let blockId = hoveredBlockId,
           hoveredBlockFrame != nil,
           currentLayoutMode.allowsBlockDragDrop {

            // Determine block type
            if let blockInfo = blockAtPoint(viewPoint) {
                isDraggingBlock = true
                draggedBlockId = blockId
                draggedBlockType = blockInfo.type
                dragStartLocation = viewPoint
                NSCursor.closedHand.set()

                // Hide the drag handle during drag
                hideDragHandle(animated: false)

                window?.makeFirstResponder(self)
                return
            }
        }

        // SECOND: Check if clicking on a floating reflow image
        if let clickedImage = floatingImage(at: viewPoint) {
            // Handle double-click to start caption editing
            if event.clickCount == 2 {
                startCaptionEditing(for: clickedImage.id)
                return
            }
            
            // Check if clicking on pile navigation controls (for piles - works on hover)
            if clickedImage.isPile {
                if let navAction = pileNavigationHitTest(at: viewPoint, for: clickedImage) {
                    handlePileNavigation(action: navAction, for: clickedImage.id)
                    needsDisplay = true
                    return
                }
            }
            
            // Check if clicking on a resize handle of already-selected image
            if clickedImage.id == selectedFloatingImageId {
                let handle = resizeHandle(at: viewPoint, for: clickedImage)
                if handle != .none {
                    // Start resize
                    isResizingFloatingImage = true
                    floatingResizeHandle = handle
                    floatingResizeStartFrame = clickedImage.frame
                    floatingResizeOriginalFrame = clickedImage.frame  // Save for undo
                    floatingResizeStartMouse = viewPoint
                    window?.makeFirstResponder(self)
                    return
                }
            }
            
            // Select this floating image and prepare for drag
            selectedFloatingImageId = clickedImage.id
            isDraggingFloatingImage = true
            floatingDragOffset = CGPoint(
                x: viewPoint.x - clickedImage.position.x,
                y: viewPoint.y - clickedImage.position.y
            )
            floatingDragStartPosition = clickedImage.position  // Save for undo
            
            // Deselect any inline images
            imageSelectionManager.deselectAll()
            
            window?.makeFirstResponder(self)
            needsDisplay = true
            return
        } else {
            // Clicked outside floating images - deselect
            if selectedFloatingImageId != nil {
                selectedFloatingImageId = nil
                needsDisplay = true
            }
        }

        // Check if click is on an image attachment
        // Image selection and pile drag work in all modes, resize only in Brief mode
        if let (attachment, range, cellFrame) = findImageAttachment(at: containerPoint) {

            // Check if clicking on a resize handle (only works on selected images in Brief mode)
            if attachment.isSelected {
                // Resize handles only available in Brief mode
                if currentLayoutMode.allowsInlineMedia {
                    let handlePosition = attachment.hitTestHandle(at: containerPoint, in: cellFrame)
                    if handlePosition != .none {
                        // Start resize from corner handle
                        isResizingImage = true
                        activeResizeHandle = handlePosition
                        resizeStartPoint = viewPoint
                        resizeStartPercent = attachment.displayWidthPercent
                        window?.makeFirstResponder(self)
                        return
                    }
                }

                // Clicked on selected image body (not on handle) - prepare for potential drag
                // This enables dragging one image onto another to create a pile
                // Works in any mode that supports image piles
                if currentLayoutMode.allowsImagePiles {
                    isDraggingInlineImage = false // Will become true in mouseDragged after threshold
                    draggedInlineImageRange = range
                    draggedInlineImageAttachment = attachment
                    inlineImageDragStartPoint = viewPoint
                    window?.makeFirstResponder(self)
                    return
                }
            }

            // First click on unselected image - select it (don't start resize)
            imageSelectionManager.selectImage(attachment, at: range)
            activeResizeHandle = .none
            isResizingImage = false

            window?.makeFirstResponder(self)
            needsDisplay = true
            return
        } else {
            // Clicked outside any image - deselect
            if imageSelectionManager.selectedAttachment != nil {
                imageSelectionManager.deselectAll()
                needsDisplay = true
            }
        }

        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(
            x: viewPoint.x - textContainerOrigin.x,
            y: viewPoint.y - textContainerOrigin.y
        )

        // Handle inline image drag (for pile creation)
        if draggedInlineImageRange != nil && draggedInlineImageAttachment != nil {
            let distance = hypot(viewPoint.x - inlineImageDragStartPoint.x,
                                viewPoint.y - inlineImageDragStartPoint.y)

            // Start dragging after threshold
            if !isDraggingInlineImage && distance > 5 {
                isDraggingInlineImage = true
                NSCursor.closedHand.set()
            }

            if isDraggingInlineImage {
                // Show drag preview
                showInlineImageDragPreview(at: viewPoint)

                // Check if hovering over another image (potential pile target)
                if let (_, targetRange, targetFrame) = findImageAttachment(at: containerPoint) {
                    // Don't target ourselves
                    if targetRange != draggedInlineImageRange {
                        potentialPileTargetRange = targetRange
                        showPileDropTarget(frame: targetFrame.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y))
                    } else {
                        potentialPileTargetRange = nil
                        hidePileDropTarget()
                    }
                } else {
                    potentialPileTargetRange = nil
                    hidePileDropTarget()
                }

                return
            }
        }

        // Handle block drag
        if isDraggingBlock, let blockType = draggedBlockType {
            // Get original block frame for preview
            var blockFrame: NSRect = .zero
            switch blockType {
            case .paragraph(let range, _):
                if let frame = frameForParagraphRange(range) {
                    blockFrame = frame.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                }
            case .media(let mediaBlock):
                if let frame = frameForMediaBlock(mediaBlock) {
                    blockFrame = frame.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                }
            }

            // Show drag preview at cursor
            showBlockDragPreview(frame: blockFrame, at: viewPoint)

            // Show drop indicator
            showBlockDropIndicator(at: viewPoint)

            return
        }

        // Handle floating image drag
        if isDraggingFloatingImage, let imageId = selectedFloatingImageId,
           let index = floatingImages.firstIndex(where: { $0.id == imageId }) {

            var newX = viewPoint.x - floatingDragOffset.x
            var newY = viewPoint.y - floatingDragOffset.y

            // Constrain to bounds
            let padding: CGFloat = 16
            newX = max(padding, min(newX, bounds.width - floatingImages[index].size.width - padding))
            newY = max(padding, min(newY, bounds.height - floatingImages[index].size.height - padding))

            floatingImages[index].position = CGPoint(x: newX, y: newY)

            // Check if hovering over another floating image (potential pile target)
            // Use the center of the dragged image for more intuitive targeting
            let draggedCenter = CGPoint(
                x: floatingImages[index].position.x + floatingImages[index].size.width / 2,
                y: floatingImages[index].position.y + floatingImages[index].size.height / 2
            )
            if let targetImage = floatingImage(at: draggedCenter, excluding: imageId) {
                floatingPileTargetId = targetImage.id
                showFloatingPileDropTarget(frame: targetImage.frame)
            } else {
                floatingPileTargetId = nil
                hideFloatingPileDropTarget()
            }

            updateExclusionPaths()
            needsDisplay = true

            // Notify SwiftUI layer for live preview (cheap, no disk I/O)
            floatingImagePositionChangedHandler?()

            return
        }

        // Handle floating image resize
        if isResizingFloatingImage, let imageId = selectedFloatingImageId,
           let index = floatingImages.firstIndex(where: { $0.id == imageId }) {
            
            let deltaX = viewPoint.x - floatingResizeStartMouse.x
            let deltaY = viewPoint.y - floatingResizeStartMouse.y
            
            var newFrame = floatingResizeStartFrame
            let aspectRatio = floatingImages[index].originalSize.width / floatingImages[index].originalSize.height
            
            // Apply resize based on handle
            // Note: In NSTextView (flipped), Y increases downward, so:
            // - minY is the TOP of the frame
            // - maxY is the BOTTOM of the frame
            let minWidth: CGFloat = 100
            let minHeight: CGFloat = minWidth / aspectRatio
            
            switch floatingResizeHandle {
            case .right:
                // Drag right edge → width changes, origin stays
                newFrame.size.width = max(minWidth, floatingResizeStartFrame.width + deltaX)
                newFrame.size.height = newFrame.size.width / aspectRatio
                
            case .left:
                // Drag left edge → width changes, origin.x moves
                let newWidth = max(minWidth, floatingResizeStartFrame.width - deltaX)
                let widthChange = floatingResizeStartFrame.width - newWidth
                newFrame.size.width = newWidth
                newFrame.origin.x = floatingResizeStartFrame.origin.x + widthChange
                newFrame.size.height = newFrame.size.width / aspectRatio
                
            case .bottom:
                // Drag bottom edge → height changes, origin stays (in flipped coords)
                newFrame.size.height = max(minHeight, floatingResizeStartFrame.height + deltaY)
                newFrame.size.width = newFrame.size.height * aspectRatio
                
            case .top:
                // Drag top edge → height changes, origin.y moves (in flipped coords)
                let newHeight = max(minHeight, floatingResizeStartFrame.height - deltaY)
                let heightChange = floatingResizeStartFrame.height - newHeight
                newFrame.size.height = newHeight
                newFrame.origin.y = floatingResizeStartFrame.origin.y + heightChange
                newFrame.size.width = newFrame.size.height * aspectRatio
                
            case .bottomRight:
                // Drag bottom-right corner → grow/shrink from top-left anchor
                newFrame.size.width = max(minWidth, floatingResizeStartFrame.width + deltaX)
                newFrame.size.height = newFrame.size.width / aspectRatio
                // Origin stays the same (top-left is anchor)
                
            case .bottomLeft:
                // Drag bottom-left corner → grow/shrink from top-right anchor
                let newWidth = max(minWidth, floatingResizeStartFrame.width - deltaX)
                let widthChange = floatingResizeStartFrame.width - newWidth
                newFrame.size.width = newWidth
                newFrame.origin.x = floatingResizeStartFrame.origin.x + widthChange
                newFrame.size.height = newFrame.size.width / aspectRatio
                // Origin.y stays the same (top is anchor)
                
            case .topRight:
                // Drag top-right corner → grow/shrink from bottom-left anchor
                // In flipped coords: origin.y is TOP, so bottom = origin.y + height
                // Bottom-left anchor means: origin.x stays fixed, bottom edge stays fixed
                newFrame.size.width = max(minWidth, floatingResizeStartFrame.width + deltaX)
                let newHeight = newFrame.size.width / aspectRatio
                // Keep bottom edge fixed: new origin.y = old bottom - new height
                let oldBottom = floatingResizeStartFrame.origin.y + floatingResizeStartFrame.height
                newFrame.size.height = newHeight
                newFrame.origin.y = oldBottom - newHeight
                // Origin.x stays the same (left edge is anchor)
                
            case .topLeft:
                // Drag top-left corner → grow/shrink from bottom-right anchor
                // In flipped coords: origin.y is TOP, so bottom = origin.y + height
                // Bottom-right anchor means: right edge stays fixed, bottom edge stays fixed
                let newWidth = max(minWidth, floatingResizeStartFrame.width - deltaX)
                let newHeight = newWidth / aspectRatio
                // Keep right edge fixed: new origin.x = old right - new width
                let oldRight = floatingResizeStartFrame.origin.x + floatingResizeStartFrame.width
                let oldBottom = floatingResizeStartFrame.origin.y + floatingResizeStartFrame.height
                newFrame.size.width = newWidth
                newFrame.size.height = newHeight
                newFrame.origin.x = oldRight - newWidth
                newFrame.origin.y = oldBottom - newHeight
                
            case .none:
                break
            }

            floatingImages[index].position = newFrame.origin
            floatingImages[index].size = newFrame.size
            updateExclusionPaths()
            needsDisplay = true

            // Notify SwiftUI layer for live preview (cheap, no disk I/O)
            floatingImagePositionChangedHandler?()

            return
        }

        // Handle inline image resize drag
        if isResizingImage, let attachment = imageSelectionManager.selectedAttachment {
            // Enable fast resize mode on attachment
            attachment.isDraggingResize = true

            let deltaX = viewPoint.x - resizeStartPoint.x

            // Calculate new width percentage based on drag delta
            let rawPercent = (attachment.containerWidth * resizeStartPercent + deltaX) / attachment.containerWidth
            var newPercent = max(0.15, min(1.0, rawPercent))

            // Apply snap-to-grid (hold Shift to disable snapping)
            if !event.modifierFlags.contains(.shift) {
                newPercent = snapToNearestPoint(newPercent)
            }

            // Throttle updates for smooth 60fps performance
            let currentTime = CACurrentMediaTime()
            let shouldUpdate = (currentTime - lastResizeTime) >= resizeThrottleInterval

            if shouldUpdate {
                lastResizeTime = currentTime

                // Update attachment with optimized redraw
                attachment.displayWidthPercent = newPercent

                // Lightweight layout invalidation - only invalidate the attachment range
                if let range = imageSelectionManager.selectedRange,
                   let layoutManager = layoutManager,
                   let textContainer = textContainer {

                    // Invalidate only the affected range, not the entire document
                    layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                    layoutManager.ensureLayout(for: textContainer)
                }

                // Update size tooltip
                updateSizeTooltip(for: attachment, at: event.locationInWindow)

                needsDisplay = true
            } else {
                // Store pending value for smooth interpolation
                pendingResizePercent = newPercent
            }

            return
        }

        super.mouseDragged(with: event)
    }

    /// Snap percentage to nearest grid point if within threshold
    private func snapToNearestPoint(_ percent: CGFloat) -> CGFloat {
        for snapPoint in snapPoints {
            if abs(percent - snapPoint) < snapThreshold {
                return snapPoint
            }
        }
        return percent
    }

    /// Show/update the size tooltip during resize
    private func updateSizeTooltip(for attachment: ResizableImageAttachmentCell, at windowPoint: NSPoint) {
        let size = attachment.cellSize()
        let percentText = String(format: "%.0f%%", attachment.displayWidthPercent * 100)
        let sizeText = String(format: "%.0f × %.0f px • %@", size.width, size.height, percentText)

        // Check if snapped
        let isSnapped = snapPoints.contains(where: { abs(attachment.displayWidthPercent - $0) < 0.001 })
        let displayText = isSnapped ? "⊡ \(sizeText)" : sizeText

        if sizeTooltipWindow == nil {
            createSizeTooltipWindow()
        }

        sizeTooltipLabel?.stringValue = displayText
        sizeTooltipLabel?.sizeToFit()

        // Position tooltip near cursor
        if let window = self.window {
            let screenPoint = window.convertToScreen(NSRect(origin: windowPoint, size: .zero)).origin
            sizeTooltipWindow?.setFrameOrigin(NSPoint(x: screenPoint.x + 16, y: screenPoint.y + 16))
            sizeTooltipWindow?.orderFront(nil)
        }
    }

    private func createSizeTooltipWindow() {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        contentView.layer?.cornerRadius = 4
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        let tooltipWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 24),
                                      styleMask: .borderless,
                                      backing: .buffered,
                                      defer: false)
        tooltipWindow.isOpaque = false
        tooltipWindow.backgroundColor = .clear
        tooltipWindow.level = .floating
        tooltipWindow.contentView = contentView
        tooltipWindow.ignoresMouseEvents = true

        sizeTooltipWindow = tooltipWindow
        sizeTooltipLabel = label
    }

    private func hideSizeTooltip() {
        sizeTooltipWindow?.orderOut(nil)
    }

    // MARK: - Image Layout Toolbar

    /// Shows the image layout toolbar beneath the specified image attachment
    func showImageToolbar(for attachment: ResizableImageAttachmentCell, at range: NSRange, imageRect: NSRect) {
        print("[ImageToolbar] showImageToolbar called - range: \(range), imageRect: \(imageRect)")

        toolbarTargetAttachment = attachment
        toolbarTargetRange = range

        if imageToolbarWindow == nil {
            print("[ImageToolbar] Creating toolbar window")
            createImageToolbarWindow()
        }

        // Get orientation from aspect ratio
        let orientation = ImageOrientation.detect(
            width: attachment.aspectRatio > 1 ? 100 : 100 / attachment.aspectRatio,
            height: attachment.aspectRatio > 1 ? 100 / attachment.aspectRatio : 100
        )
        let currentPreset = ImageLayoutPreset.detect(
            widthPercent: attachment.displayWidthPercent * 100,
            orientation: orientation
        )

        updateToolbarButtons(currentPreset: currentPreset, orientation: orientation)
        positionImageToolbar(beneath: imageRect)

        // Start auto-hide timer
        startToolbarAutoHideTimer()
    }

    /// Positions the toolbar window beneath the image
    private func positionImageToolbar(beneath imageRect: NSRect) {
        guard let window = self.window,
              let toolbarWindow = imageToolbarWindow else {
            print("[ImageToolbar] No window or toolbarWindow")
            return
        }

        // The imageRect is in text container coordinates, need to add text container origin
        let origin = textContainerOrigin
        let adjustedRect = NSRect(
            x: imageRect.origin.x + origin.x,
            y: imageRect.origin.y + origin.y,
            width: imageRect.width,
            height: imageRect.height
        )

        // Convert to window coordinates then screen coordinates
        let viewRect = convert(adjustedRect, to: nil)
        let screenRect = window.convertToScreen(viewRect)

        // Position toolbar centered beneath the image
        let toolbarWidth = toolbarWindow.frame.width
        let toolbarX = screenRect.midX - toolbarWidth / 2
        let toolbarY = screenRect.minY - 8 - toolbarWindow.frame.height

        print("[ImageToolbar] Positioning at screen: \(toolbarX), \(toolbarY)")

        toolbarWindow.setFrameOrigin(NSPoint(x: toolbarX, y: toolbarY))
        toolbarWindow.orderFront(nil)
    }

    /// Creates the image toolbar window with layout preset buttons
    private func createImageToolbarWindow() {
        let toolbarHeight: CGFloat = 36
        let toolbarWidth: CGFloat = 220

        // Container view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: toolbarWidth, height: toolbarHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(MarginColors.paper).cgColor
        contentView.layer?.cornerRadius = 8
        contentView.layer?.borderColor = NSColor(MarginColors.stone200).cgColor
        contentView.layer?.borderWidth = 1

        // Add shadow
        contentView.layer?.shadowColor = NSColor.black.cgColor
        contentView.layer?.shadowOpacity = 0.12
        contentView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        contentView.layer?.shadowRadius = 8

        // Create size preset buttons
        let buttonWidth: CGFloat = 36
        let buttonSpacing: CGFloat = 4
        let buttonY: CGFloat = (toolbarHeight - 28) / 2

        var xOffset: CGFloat = 8

        // Compact button
        let compactButton = createToolbarButton(
            frame: NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: 28),
            iconName: "rectangle.center.inset.filled",
            tag: 0,
            action: #selector(toolbarPresetButtonClicked(_:))
        )
        contentView.addSubview(compactButton)
        xOffset += buttonWidth + buttonSpacing

        // Medium button
        let mediumButton = createToolbarButton(
            frame: NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: 28),
            iconName: "rectangle.inset.filled",
            tag: 1,
            action: #selector(toolbarPresetButtonClicked(_:))
        )
        contentView.addSubview(mediumButton)
        xOffset += buttonWidth + buttonSpacing

        // Full button
        let fullButton = createToolbarButton(
            frame: NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: 28),
            iconName: "rectangle.ratio.16.to.9.fill",
            tag: 2,
            action: #selector(toolbarPresetButtonClicked(_:))
        )
        contentView.addSubview(fullButton)

        // Create the window
        let toolbarWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: toolbarWidth, height: toolbarHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        toolbarWindow.isOpaque = false
        toolbarWindow.backgroundColor = .clear
        toolbarWindow.level = .floating
        toolbarWindow.contentView = contentView
        toolbarWindow.ignoresMouseEvents = false

        // Track mouse enter/exit for hover detection
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: ["isToolbar": true]
        )
        contentView.addTrackingArea(trackingArea)

        imageToolbarWindow = toolbarWindow
    }

    /// Creates a toolbar button with an SF Symbol icon
    private func createToolbarButton(frame: NSRect, iconName: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(frame: frame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.tag = tag
        button.target = self
        button.action = action

        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor(MarginColors.stone500)

        // Add hover tracking
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: button,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)

        return button
    }

    /// Creates a toolbar button with text
    private func createToolbarButton(frame: NSRect, title: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(frame: frame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.tag = tag
        button.target = self
        button.action = action
        button.title = title
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = NSColor(MarginColors.stone600)

        return button
    }

    /// Updates the toolbar button states to reflect the current preset
    private func updateToolbarButtons(currentPreset: ImageLayoutPreset, orientation: ImageOrientation) {
        guard let contentView = imageToolbarWindow?.contentView else { return }

        for subview in contentView.subviews {
            guard let button = subview as? NSButton, button.tag < 10 else { continue }

            let isSelected: Bool
            switch button.tag {
            case 0: isSelected = (currentPreset == .compact)
            case 1: isSelected = (currentPreset == .medium)
            case 2: isSelected = (currentPreset == .full)
            default: isSelected = false
            }

            button.layer?.backgroundColor = isSelected
                ? NSColor(MarginColors.stone100).cgColor
                : NSColor.clear.cgColor
            button.contentTintColor = isSelected
                ? NSColor(MarginColors.ink)
                : NSColor(MarginColors.stone500)
        }
    }

    /// Handles preset button clicks
    @objc private func toolbarPresetButtonClicked(_ sender: NSButton) {
        guard let attachment = toolbarTargetAttachment else { return }

        let preset: ImageLayoutPreset
        switch sender.tag {
        case 0: preset = .compact
        case 1: preset = .medium
        case 2: preset = .full
        default: return
        }

        // Get orientation and calculate new width
        let orientation = ImageOrientation.detect(
            width: attachment.aspectRatio > 1 ? 100 : 100 / attachment.aspectRatio,
            height: attachment.aspectRatio > 1 ? 100 / attachment.aspectRatio : 100
        )
        let newWidthPercent = preset.widthPercent(for: orientation) / 100.0

        // Update the attachment
        attachment.displayWidthPercent = newWidthPercent
        attachment.finalizeResize()

        // Update button states
        updateToolbarButtons(currentPreset: preset, orientation: orientation)

        // Trigger layout update
        layoutManager?.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage?.length ?? 0), actualCharacterRange: nil)
        needsDisplay = true

        // Notify handler
        imageLayoutPresetChangedHandler?(attachment.attachmentId, preset)

        // Reposition toolbar after size change
        if let range = toolbarTargetRange,
           let (_, _, rect) = findImageAttachment(at: range) {
            positionImageToolbar(beneath: rect)
        }

        // Restart auto-hide timer
        startToolbarAutoHideTimer()
    }

    // Caption button for inline images removed - floating images handle captions directly

    /// Find image attachment at a specific range
    private func findImageAttachment(at range: NSRange) -> (ResizableImageAttachmentCell, NSRange, NSRect)? {
        guard let textStorage = textStorage,
              range.location < textStorage.length,
              let attachment = textStorage.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment,
              let cell = attachment.attachmentCell as? ResizableImageAttachmentCell,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        return (cell, range, rect)
    }

    /// Starts the 3-second auto-hide timer
    private func startToolbarAutoHideTimer() {
        toolbarAutoHideTimer?.invalidate()
        toolbarAutoHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self, !self.isToolbarHovered else { return }
            self.hideImageToolbar()
        }
    }

    /// Hides the image toolbar
    func hideImageToolbar() {
        toolbarAutoHideTimer?.invalidate()
        toolbarAutoHideTimer = nil
        imageToolbarWindow?.orderOut(nil)
        toolbarTargetAttachment = nil
        toolbarTargetRange = nil
        toolbarTargetFloatingImageId = nil
    }
    
    // MARK: - Floating Image Caption
    
    /// Text field for editing floating image captions
    private var floatingCaptionTextField: NSTextField?
    private var floatingCaptionEditingId: UUID?
    
    /// Starts caption editing for a floating image
    func startCaptionEditing(for imageId: UUID) {
        guard let index = floatingImages.firstIndex(where: { $0.id == imageId }) else { return }
        
        // End any existing caption editing
        endCaptionEditing()
        
        // Mark the image as editing caption
        floatingImages[index].isEditingCaption = true
        floatingCaptionEditingId = imageId
        
        // Get the caption rect at the bottom of the component
        let image = floatingImages[index]
        let paddedFrame = image.paddedFrame
        
        // Create the text field at the bottom of the component
        let textFieldHeight: CGFloat = 24
        let textFieldRect = NSRect(
            x: paddedFrame.minX + 8,
            y: paddedFrame.maxY - textFieldHeight - 4,
            width: paddedFrame.width - 16,
            height: textFieldHeight
        )
        
        let textField = NSTextField(frame: textFieldRect)
        textField.stringValue = image.caption ?? ""
        textField.placeholderString = "Add a caption..."
        textField.isBordered = false
        textField.backgroundColor = NSColor.clear
        textField.focusRingType = .none
        textField.alignment = .center
        
        // Style the text field
        if let newsreader = NSFont(name: "Newsreader-Italic", size: 13) {
            textField.font = newsreader
        } else {
            let baseFont = NSFont.systemFont(ofSize: 13)
            textField.font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        }
        textField.textColor = NSColor(MarginColors.stone600)
        
        // Set delegate to handle Enter/Escape
        textField.delegate = self
        textField.target = self
        textField.action = #selector(captionTextFieldAction(_:))
        
        // Add to view
        addSubview(textField)
        floatingCaptionTextField = textField
        
        // Focus the text field
        window?.makeFirstResponder(textField)
        
        // Select all text if there's existing caption
        if image.caption != nil {
            textField.selectText(nil)
        }
        
        needsDisplay = true
        updateExclusionPaths()  // Update because paddedFrame changes
    }
    
    /// Ends caption editing and saves the caption
    func endCaptionEditing() {
        guard let textField = floatingCaptionTextField,
              let editingId = floatingCaptionEditingId,
              let index = floatingImages.firstIndex(where: { $0.id == editingId }) else { return }
        
        // Get the new caption
        let newCaption = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldCaption = floatingImages[index].caption
        
        // Update the floating image
        floatingImages[index].caption = newCaption.isEmpty ? nil : newCaption
        floatingImages[index].isEditingCaption = false
        
        // Remove the text field
        textField.removeFromSuperview()
        floatingCaptionTextField = nil
        floatingCaptionEditingId = nil
        
        // Make the text view first responder again
        window?.makeFirstResponder(self)
        
        needsDisplay = true
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        
        // Register undo if caption changed
        if oldCaption != floatingImages[index].caption {
            let capturedId = editingId
            let capturedOldCaption = oldCaption
            undoManager?.registerUndo(withTarget: self) { target in
                if let idx = target.floatingImages.firstIndex(where: { $0.id == capturedId }) {
                    target.floatingImages[idx].caption = capturedOldCaption
                    target.updateExclusionPaths()
                    target.needsDisplay = true
                    target.notifyFloatingImagesChanged()
                }
            }
            undoManager?.setActionName(newCaption.isEmpty ? "Remove Caption" : "Add Caption")
        }
    }
    
    /// Cancels caption editing without saving
    func cancelCaptionEditing() {
        guard let textField = floatingCaptionTextField,
              let editingId = floatingCaptionEditingId,
              let index = floatingImages.firstIndex(where: { $0.id == editingId }) else { return }
        
        // Reset editing state
        floatingImages[index].isEditingCaption = false
        
        // Remove the text field
        textField.removeFromSuperview()
        floatingCaptionTextField = nil
        floatingCaptionEditingId = nil
        
        // Make the text view first responder again
        window?.makeFirstResponder(self)
        
        needsDisplay = true
        updateExclusionPaths()
    }
    
    @objc private func captionTextFieldAction(_ sender: NSTextField) {
        // Enter pressed - save caption
        endCaptionEditing()
    }
    
    // MARK: - NSTextFieldDelegate
    
    func controlTextDidEndEditing(_ obj: Notification) {
        // Commit caption when text field loses focus
        if floatingCaptionEditingId != nil {
            endCaptionEditing()
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            // Escape pressed - cancel caption editing
            cancelCaptionEditing()
            return true
        }
        return false
    }

    override func mouseUp(with event: NSEvent) {
        // Handle block drag end
        if isDraggingBlock {
            // Clean up preview layers
            hideBlockDragPreview()
            hideBlockDropIndicator()

            // Perform the block move if we have valid data
            if let blockType = draggedBlockType {
                // TODO: Implement actual block reordering
                // For now, just log the operation
                switch blockType {
                case .paragraph(let range, let text):
                    print("[BlockDrag] Would move paragraph at \(range.location): \(text.prefix(30))...")
                case .media(let mediaBlock):
                    print("[BlockDrag] Would move media block \(mediaBlock.id)")
                }
            }

            // Reset drag state
            isDraggingBlock = false
            draggedBlockId = nil
            draggedBlockType = nil
            NSCursor.arrow.set()
            needsDisplay = true
            return
        }

        // Handle floating image drag end
        if isDraggingFloatingImage {
            hideFloatingPileDropTarget()

            // Check if we're dropping onto another floating image to create/extend a pile
            if let sourceId = selectedFloatingImageId, let targetId = floatingPileTargetId {
                combineFloatingImages(sourceId: sourceId, targetId: targetId)
                floatingPileTargetId = nil
            } else {
                // Just a move, register undo
                if let imageId = selectedFloatingImageId {
                    registerMoveUndo(for: imageId, from: floatingDragStartPosition)
                }
            }

            // Sync to SwiftUI layer for rendering
            notifyFloatingImagesChanged()

            isDraggingFloatingImage = false
            floatingPileTargetId = nil
            needsDisplay = true
            return
        }

        // Handle floating image resize end
        if isResizingFloatingImage {
            // Register undo for the resize operation
            if let imageId = selectedFloatingImageId {
                registerResizeUndo(for: imageId, from: floatingResizeOriginalFrame)
            }

            // Sync to SwiftUI layer for rendering
            notifyFloatingImagesChanged()

            isResizingFloatingImage = false
            floatingResizeHandle = .none
            needsDisplay = true
            return
        }
        
        // Handle inline image resize end
        if isResizingImage {
            // Hide size tooltip
            hideSizeTooltip()

            if let attachment = imageSelectionManager.selectedAttachment {
                // Apply any pending resize that was throttled
                if let pending = pendingResizePercent {
                    attachment.isDraggingResize = true // Keep fast mode for this update
                    attachment.displayWidthPercent = pending
                    pendingResizePercent = nil
                }

                // Finalize the attachment with high-quality image
                attachment.finalizeResize()

                // Final full layout invalidation for clean state
                if let layoutManager = layoutManager,
                   let textStorage = textStorage,
                   let textContainer = textContainer {
                    let fullRange = NSRange(location: 0, length: textStorage.length)
                    layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
                    layoutManager.ensureLayout(for: textContainer)

                    // Adjust frame height if needed
                    let usedRect = layoutManager.usedRect(for: textContainer)
                    let newHeight = max(usedRect.height + textContainerInset.height * 2 + 100, frame.height)
                    if abs(newHeight - frame.height) > 1 {
                        var newFrame = frame
                        newFrame.size.height = newHeight
                        frame = newFrame
                    }
                }

                // Note: Undo for image resize is complex because the attachment reference
                // and text storage state may change. For now, we skip undo registration
                // for resize operations to prevent crashes.
                // TODO: Implement proper undo by storing image state in a separate data structure
            }

            isResizingImage = false
            activeResizeHandle = .none
            needsDisplay = true
            window?.invalidateCursorRects(for: self) // Only invalidate cursor rects once at the end
            return
        }

        super.mouseUp(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        // Add resize cursors only for corner handles of selected image
        if let _ = imageSelectionManager.selectedAttachment,
           let range = imageSelectionManager.selectedRange,
           let layoutManager = layoutManager,
           let textContainer = textContainer {

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var cellFrame = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // Offset for text container origin
            let origin = textContainerOrigin
            cellFrame = cellFrame.offsetBy(dx: origin.x, dy: origin.y)

            // Handle size for cursor rects (slightly larger for easier targeting)
            let handleSize: CGFloat = 14

            // Corner handle rects
            let topLeft = NSRect(x: cellFrame.minX - handleSize/2, y: cellFrame.maxY - handleSize/2, width: handleSize, height: handleSize)
            let topRight = NSRect(x: cellFrame.maxX - handleSize/2, y: cellFrame.maxY - handleSize/2, width: handleSize, height: handleSize)
            let bottomLeft = NSRect(x: cellFrame.minX - handleSize/2, y: cellFrame.minY - handleSize/2, width: handleSize, height: handleSize)
            let bottomRight = NSRect(x: cellFrame.maxX - handleSize/2, y: cellFrame.minY - handleSize/2, width: handleSize, height: handleSize)

            // Use diagonal resize cursors (nwse for top-left/bottom-right, nesw for top-right/bottom-left)
            // Note: macOS doesn't have built-in diagonal cursors, so we create them
            let nwseCursor = NSCursor(image: createDiagonalResizeCursorImage(nwse: true), hotSpot: NSPoint(x: 8, y: 8))
            let neswCursor = NSCursor(image: createDiagonalResizeCursorImage(nwse: false), hotSpot: NSPoint(x: 8, y: 8))

            addCursorRect(topLeft, cursor: nwseCursor)
            addCursorRect(bottomRight, cursor: nwseCursor)
            addCursorRect(topRight, cursor: neswCursor)
            addCursorRect(bottomLeft, cursor: neswCursor)
        }
    }

    /// Creates a diagonal resize cursor image
    private func createDiagonalResizeCursorImage(nwse: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()

        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round

        if nwse {
            // NW-SE diagonal (top-left to bottom-right)
            // Arrow line
            path.move(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 13, y: 3))
            // Top-right arrowhead
            path.move(to: NSPoint(x: 13, y: 3))
            path.line(to: NSPoint(x: 8, y: 3))
            path.move(to: NSPoint(x: 13, y: 3))
            path.line(to: NSPoint(x: 13, y: 8))
            // Bottom-left arrowhead
            path.move(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 8, y: 13))
            path.move(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 3, y: 8))
        } else {
            // NE-SW diagonal (top-right to bottom-left)
            // Arrow line
            path.move(to: NSPoint(x: 13, y: 13))
            path.line(to: NSPoint(x: 3, y: 3))
            // Top-left arrowhead
            path.move(to: NSPoint(x: 3, y: 3))
            path.line(to: NSPoint(x: 8, y: 3))
            path.move(to: NSPoint(x: 3, y: 3))
            path.line(to: NSPoint(x: 3, y: 8))
            // Bottom-right arrowhead
            path.move(to: NSPoint(x: 13, y: 13))
            path.line(to: NSPoint(x: 8, y: 13))
            path.move(to: NSPoint(x: 13, y: 13))
            path.line(to: NSPoint(x: 13, y: 8))
        }

        NSColor.black.setStroke()
        path.stroke()

        image.unlockFocus()
        return image
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        
        // Add tracking area for mouse movement (to detect hover on images)
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let viewPoint = convert(event.locationInWindow, from: nil)
        let origin = textContainerOrigin
        let containerPoint = NSPoint(x: viewPoint.x - origin.x, y: viewPoint.y - origin.y)

        // FIRST: Check if hovering over the drag handle
        if isPointOverDragHandle(viewPoint) {
            isMouseOverDragHandle = true
            NSCursor.openHand.set()
            return
        } else if isMouseOverDragHandle {
            isMouseOverDragHandle = false
            NSCursor.arrow.set()
        }

        // DISABLED: Block drag handle feature removed
        // The 6-dot grip icon is no longer shown on block hover
        if hoveredBlockId != nil {
            hideDragHandle()
            hoveredBlockId = nil
        }
        
        // THIRD: Check for floating image hover (for pile navigation and cursor)
        let previousHoveredId = hoveredFloatingImageId
        if let hoveredImage = floatingImage(at: viewPoint) {
            hoveredFloatingImageId = hoveredImage.id
            
            // Check if over a resize handle (for selected images)
            if hoveredImage.id == selectedFloatingImageId {
                let handle = resizeHandle(at: viewPoint, for: hoveredImage)
                switch handle {
                case .topLeft, .bottomRight:
                    let cursor = NSCursor(image: createDiagonalResizeCursorImage(nwse: true), hotSpot: NSPoint(x: 8, y: 8))
                    cursor.set()
                case .topRight, .bottomLeft:
                    let cursor = NSCursor(image: createDiagonalResizeCursorImage(nwse: false), hotSpot: NSPoint(x: 8, y: 8))
                    cursor.set()
                case .left, .right:
                    NSCursor.resizeLeftRight.set()
                case .top, .bottom:
                    NSCursor.resizeUpDown.set()
                case .none:
                    // Over the image but not a handle - use move cursor
                    NSCursor.openHand.set()
                }
            } else {
                // Hovering over a non-selected image - use pointer/hand cursor
                NSCursor.pointingHand.set()
            }
        } else {
            hoveredFloatingImageId = nil
            // Reset to arrow if we were over a floating image before
            if previousHoveredId != nil && !isMouseOverDragHandle {
                NSCursor.arrow.set()
            }
        }
        // Redraw if hover state changed (to show/hide navigation controls)
        if previousHoveredId != hoveredFloatingImageId {
            startHoverAnimation()
            needsDisplay = true
        }

        // FOURTH: Handle image resize cursor (Brief mode - inline images)
        guard currentLayoutMode.allowsInlineMedia,
              let attachment = imageSelectionManager.selectedAttachment,
              let range = imageSelectionManager.selectedRange,
              let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return
        }

        // Get the image cell frame
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let cellFrame = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Check if mouse is over a corner handle
        let handlePosition = attachment.hitTestHandle(at: containerPoint, in: cellFrame)

        switch handlePosition {
        case .topLeft, .bottomRight:
            // NW-SE diagonal cursor
            let cursor = NSCursor(image: createDiagonalResizeCursorImage(nwse: true), hotSpot: NSPoint(x: 8, y: 8))
            cursor.set()
        case .topRight, .bottomLeft:
            // NE-SW diagonal cursor
            let cursor = NSCursor(image: createDiagonalResizeCursorImage(nwse: false), hotSpot: NSPoint(x: 8, y: 8))
            cursor.set()
        case .none:
            // Not over a handle - use arrow cursor (unless over drag handle)
            if !isMouseOverDragHandle {
                NSCursor.arrow.set()
            }
        }

        // FIFTH: Check for inline image hover to show indicator (when toolbar is hidden)
        updateInlineImageHoverIndicator(at: viewPoint)
    }

    /// Updates the hover indicator for inline images
    private func updateInlineImageHoverIndicator(at point: NSPoint) {
        // Only show indicator when toolbar is not visible
        guard imageToolbarWindow == nil || imageToolbarWindow?.isVisible == false else {
            hideHoverIndicator()
            return
        }

        // Find image at point
        if let (attachment, range, rect) = findImageAttachment(at: point) {
            // Check if this is a new hover target
            if hoveredInlineImageRange?.location != range.location {
                hoveredInlineImageAttachment = attachment
                hoveredInlineImageRange = range
                showHoverIndicator(at: rect)
            }
        } else {
            // No longer hovering over an image
            if hoveredInlineImageRange != nil {
                hideHoverIndicator()
                hoveredInlineImageAttachment = nil
                hoveredInlineImageRange = nil
            }
        }
    }

    /// Shows the hover indicator at the top-right of the image
    private func showHoverIndicator(at imageRect: NSRect) {
        if hoverIndicatorLayer == nil {
            createHoverIndicatorLayer()
        }

        guard let layer = hoverIndicatorLayer else { return }

        // Position at top-right of image with small offset
        let indicatorSize: CGFloat = 28
        let padding: CGFloat = 8
        layer.frame = NSRect(
            x: imageRect.maxX - indicatorSize - padding,
            y: imageRect.maxY - indicatorSize - padding,
            width: indicatorSize,
            height: indicatorSize
        )

        layer.isHidden = false
        needsDisplay = true
    }

    /// Creates the hover indicator layer (ellipsis button)
    private func createHoverIndicatorLayer() {
        let layer = CALayer()
        layer.backgroundColor = NSColor(MarginColors.paper).withAlphaComponent(0.95).cgColor
        layer.cornerRadius = 6
        layer.borderColor = NSColor(MarginColors.stone200).cgColor
        layer.borderWidth = 1

        // Add shadow
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 3

        // Add ellipsis icon using a text layer
        let textLayer = CATextLayer()
        textLayer.string = "⋯"
        textLayer.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textLayer.fontSize = 14
        textLayer.foregroundColor = NSColor(MarginColors.stone500).cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.frame = CGRect(x: 0, y: 6, width: 28, height: 20)
        layer.addSublayer(textLayer)

        self.layer?.addSublayer(layer)
        hoverIndicatorLayer = layer
    }

    /// Hides the hover indicator
    private func hideHoverIndicator() {
        hoverIndicatorLayer?.isHidden = true
    }

    // MARK: - Keyboard Handling for Images
    
    override func keyDown(with event: NSEvent) {
        // Handle Escape during caption editing
        if floatingCaptionEditingId != nil {
            if event.keyCode == 53 { // Escape
                cancelCaptionEditing()
                return
            }
            // Let other keys pass through to the text field
            super.keyDown(with: event)
            return
        }
        
        // Handle keyboard input for selected floating images
        if let selectedId = selectedFloatingImageId {
            switch event.keyCode {
            case 51, 117: // Delete or Forward Delete - remove floating image
                removeFloatingImage(id: selectedId)
                return
                
            case 53: // Escape - deselect floating image
                selectedFloatingImageId = nil
                needsDisplay = true
                return
                
            default:
                break
            }
        }
        
        // Handle keyboard input for selected inline images
        if let attachment = imageSelectionManager.selectedAttachment {
            switch event.keyCode {
            case 123: // Left arrow - shrink image
                let newPercent = max(0.15, attachment.displayWidthPercent - 0.05)
                resizeSelectedImage(to: newPercent)
                return
                
            case 124: // Right arrow - grow image
                let newPercent = min(1.0, attachment.displayWidthPercent + 0.05)
                resizeSelectedImage(to: newPercent)
                return
                
            case 51, 117: // Delete or Forward Delete - remove image
                if let range = imageSelectionManager.selectedRange {
                    deleteImageAtRange(range)
                }
                return
                
            case 53: // Escape - deselect
                imageSelectionManager.deselectAll()
                return
                
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }

    // MARK: - Pull Quote Placeholder Handling

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // Check if we're typing into a pull quote placeholder
        if handlePullQuotePlaceholderReplacement(insertingText: string, replacementRange: replacementRange) {
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    override func deleteBackward(_ sender: Any?) {
        // Check if we're deleting a pull quote placeholder - remove the entire block
        if handlePullQuotePlaceholderDeletion() {
            return
        }
        super.deleteBackward(sender)
    }

    /// Handles deleting the entire pull quote block if user hits backspace on a placeholder
    private func handlePullQuotePlaceholderDeletion() -> Bool {
        guard let textStorage = textStorage else { return false }

        let range = selectedRange()
        guard range.location > 0 && range.location <= textStorage.length else { return false }

        // Check position before cursor (what backspace would delete)
        let checkLocation = range.length > 0 ? range.location : range.location - 1
        guard checkLocation >= 0 && checkLocation < textStorage.length else { return false }

        // Check if we're in a pull quote placeholder
        var effectiveRange = NSRange()
        let isPlaceholder = textStorage.attribute(.pullQuotePlaceholder, at: checkLocation, effectiveRange: &effectiveRange) as? Bool ?? false

        guard isPlaceholder else { return false }

        // Find the entire pull quote block (from the quote mark to the trailing newline)
        // Look backwards for the quote mark
        var blockStart = effectiveRange.location
        while blockStart > 0 {
            let char = (textStorage.string as NSString).substring(with: NSRange(location: blockStart - 1, length: 1))
            if char == "\n" {
                break
            }
            blockStart -= 1
        }

        // Look forwards for the trailing newline after the placeholder
        var blockEnd = effectiveRange.location + effectiveRange.length
        while blockEnd < textStorage.length {
            let char = (textStorage.string as NSString).substring(with: NSRange(location: blockEnd, length: 1))
            blockEnd += 1
            if char == "\n" {
                break
            }
        }

        // Delete the entire pull quote block
        let blockRange = NSRange(location: blockStart, length: blockEnd - blockStart)

        textStorage.beginEditing()
        textStorage.deleteCharacters(in: blockRange)
        textStorage.endEditing()

        setSelectedRange(NSRange(location: blockStart, length: 0))
        didChangeText()

        return true
    }

    /// Handles replacing placeholder text when user starts typing in a pull quote block
    private func handlePullQuotePlaceholderReplacement(insertingText: Any, replacementRange: NSRange) -> Bool {
        guard let textStorage = textStorage else { return false }
        guard let insertString = insertingText as? String else { return false }

        let range = replacementRange.location != NSNotFound ? replacementRange : selectedRange()

        // Check if the current selection/cursor is within a placeholder
        guard range.location < textStorage.length else { return false }

        // Check if we're in a pull quote placeholder
        var effectiveRange = NSRange()
        let isPlaceholder = textStorage.attribute(.pullQuotePlaceholder, at: range.location, effectiveRange: &effectiveRange) as? Bool ?? false

        guard isPlaceholder else { return false }

        // We're typing into a placeholder - replace the entire placeholder with the typed character
        // and apply proper pull quote styling

        textStorage.beginEditing()

        // Create the pull quote paragraph style
        let quoteParaStyle = NSMutableParagraphStyle()
        quoteParaStyle.paragraphSpacingBefore = 24
        quoteParaStyle.paragraphSpacing = 8
        quoteParaStyle.firstLineHeadIndent = 56
        quoteParaStyle.headIndent = 56
        quoteParaStyle.lineSpacing = 6

        // Quote font
        let quoteFont = NSFont(name: "InstrumentSerif-Regular", size: 24)
            ?? NSFont(name: "Georgia-Italic", size: 24)
            ?? NSFont.systemFont(ofSize: 24, weight: .regular)

        // Attributes for the actual quote text (no placeholder marker)
        let quoteAttributes: [NSAttributedString.Key: Any] = [
            .font: quoteFont,
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: quoteParaStyle,
            .pullQuoteMarker: true
        ]

        // Replace the placeholder with the typed text
        let attributedInsert = NSAttributedString(string: insertString, attributes: quoteAttributes)
        textStorage.replaceCharacters(in: effectiveRange, with: attributedInsert)

        textStorage.endEditing()

        // Position cursor after the inserted text
        let newCursorPosition = effectiveRange.location + insertString.count
        setSelectedRange(NSRange(location: newCursorPosition, length: 0))

        // Update typing attributes to continue with quote styling
        typingAttributes = quoteAttributes

        // Notify of changes
        didChangeText()

        return true
    }

    // MARK: - List Continuation & Indentation

    override func insertNewline(_ sender: Any?) {
        // Check if we're in a list and should continue it
        if handleListContinuation() {
            return
        }
        super.insertNewline(sender)
    }
    
    override func insertTab(_ sender: Any?) {
        // Check if we should indent the current list item
        if handleListIndent() {
            return
        }
        super.insertTab(sender)
    }
    
    override func insertBacktab(_ sender: Any?) {
        // Check if we should outdent the current list item
        if handleListOutdent() {
            return
        }
        super.insertBacktab(sender)
    }
    
    /// Handles Return key in lists - continues the list or exits if empty
    private func handleListContinuation() -> Bool {
        guard let textStorage = textStorage else { return false }
        
        let cursorLocation = selectedRange().location
        guard cursorLocation > 0 else { return false }
        
        // Get the current paragraph
        let fullText = string as NSString
        let paragraphRange = fullText.paragraphRange(for: NSRange(location: cursorLocation, length: 0))
        let paragraphText = fullText.substring(with: paragraphRange)
        
        // Detect list type and indentation
        let listInfo = detectListInfo(in: paragraphText)
        
        guard let info = listInfo else { return false }
        
        // Check if the line is empty (only contains the list prefix)
        let contentAfterPrefix = String(paragraphText.dropFirst(info.prefixLength)).trimmingCharacters(in: .whitespaces)
        let isEmptyListItem = contentAfterPrefix.isEmpty || contentAfterPrefix == "\n"
        
        if isEmptyListItem {
            // Exit the list - remove the prefix from current line
            let prefixRange = NSRange(location: paragraphRange.location, length: info.prefixLength)
            if shouldChangeText(in: prefixRange, replacementString: "") {
                textStorage.deleteCharacters(in: prefixRange)
                didChangeText()
            }
            return true
        }
        
        // Continue the list
        var newPrefix: String
        if info.isBullet {
            newPrefix = info.indent + "• "
        } else {
            // Increment the number for numbered lists
            let nextNumber = info.number + 1
            newPrefix = info.indent + "\(nextNumber). "
        }
        
        // Insert newline and new list prefix
        let insertText = "\n" + newPrefix
        if shouldChangeText(in: selectedRange(), replacementString: insertText) {
            textStorage.replaceCharacters(in: selectedRange(), with: NSAttributedString(string: insertText, attributes: typingAttributes))
            setSelectedRange(NSRange(location: selectedRange().location + insertText.count, length: 0))
            didChangeText()
        }
        
        return true
    }
    
    /// Handles Tab key - indents list item
    private func handleListIndent() -> Bool {
        guard let textStorage = textStorage else { return false }
        
        let cursorLocation = selectedRange().location
        let fullText = string as NSString
        let paragraphRange = fullText.paragraphRange(for: NSRange(location: cursorLocation, length: 0))
        let paragraphText = fullText.substring(with: paragraphRange)
        
        guard detectListInfo(in: paragraphText) != nil else { return false }
        
        // Add indentation (tab or spaces) at the start of the paragraph
        let indentString = "\t"
        let insertLocation = paragraphRange.location
        
        if shouldChangeText(in: NSRange(location: insertLocation, length: 0), replacementString: indentString) {
            textStorage.insert(NSAttributedString(string: indentString, attributes: typingAttributes), at: insertLocation)
            // Move cursor to account for inserted indent
            setSelectedRange(NSRange(location: selectedRange().location + indentString.count, length: 0))
            didChangeText()
        }
        
        return true
    }
    
    /// Handles Shift+Tab - outdents list item
    private func handleListOutdent() -> Bool {
        guard let textStorage = textStorage else { return false }
        
        let cursorLocation = selectedRange().location
        let fullText = string as NSString
        let paragraphRange = fullText.paragraphRange(for: NSRange(location: cursorLocation, length: 0))
        let paragraphText = fullText.substring(with: paragraphRange)
        
        guard detectListInfo(in: paragraphText) != nil else { return false }
        
        // Check if line starts with tab or spaces that we can remove
        var removeLength = 0
        if paragraphText.hasPrefix("\t") {
            removeLength = 1
        } else if paragraphText.hasPrefix("    ") {
            removeLength = 4 // 4 spaces = 1 level
        } else if paragraphText.hasPrefix("  ") {
            removeLength = 2
        } else {
            return false // Nothing to outdent
        }
        
        let removeRange = NSRange(location: paragraphRange.location, length: removeLength)
        if shouldChangeText(in: removeRange, replacementString: "") {
            textStorage.deleteCharacters(in: removeRange)
            // Move cursor to account for removed indent
            let newCursorPos = max(paragraphRange.location, selectedRange().location - removeLength)
            setSelectedRange(NSRange(location: newCursorPos, length: 0))
            didChangeText()
        }
        
        return true
    }
    
    /// Detects if a paragraph is a list item and returns info about it
    private func detectListInfo(in text: String) -> (isBullet: Bool, number: Int, indent: String, prefixLength: Int)? {
        // Match bullet: optional whitespace + "• " 
        // Match number: optional whitespace + digit(s) + ". "
        
        var indent = ""
        var remaining = text
        
        // Extract leading whitespace
        while remaining.hasPrefix("\t") || remaining.hasPrefix(" ") {
            indent.append(remaining.removeFirst())
        }
        
        // Check for bullet
        if remaining.hasPrefix("• ") {
            return (isBullet: true, number: 0, indent: indent, prefixLength: indent.count + 2)
        }
        
        // Check for number (e.g., "1. ", "12. ")
        if let match = remaining.range(of: "^(\\d+)\\.\\s", options: .regularExpression) {
            let numberStr = String(remaining[match]).dropLast(2) // Remove ". "
            if let number = Int(numberStr) {
                let prefixInRemaining = remaining.distance(from: remaining.startIndex, to: match.upperBound)
                return (isBullet: false, number: number, indent: indent, prefixLength: indent.count + prefixInRemaining)
            }
        }
        
        return nil
    }
    
    private func resizeSelectedImage(to percent: CGFloat) {
        guard let attachment = imageSelectionManager.selectedAttachment,
              let range = imageSelectionManager.selectedRange else { return }
        
        // Apply resize directly without undo registration
        // (Undo for image resize is complex due to attachment lifecycle)
        attachment.displayWidthPercent = percent
        layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        needsDisplay = true
    }
    
    private func deleteImageAtRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        undoManager?.beginUndoGrouping()
        
        if shouldChangeText(in: range, replacementString: "") {
            textStorage.deleteCharacters(in: range)
            didChangeText()
            imageSelectionManager.deselectAll()
        }
        
        undoManager?.endUndoGrouping()
    }
    
    // MARK: - Image Attachment Detection
    
    private func findImageAttachment(at point: NSPoint) -> (ResizableImageAttachmentCell, NSRange, NSRect)? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage else { return nil }
        
        // Get character index at point
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        guard charIndex < textStorage.length else { return nil }
        
        // Check if there's an attachment at this position
        var effectiveRange = NSRange()
        if let attachment = textStorage.attribute(.attachment, at: charIndex, effectiveRange: &effectiveRange) as? NSTextAttachment,
           let cell = attachment.attachmentCell as? ResizableImageAttachmentCell {
            
            // Get the cell's frame
            let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
            let cellFrame = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Check if point is within the cell frame (with some padding for handles)
            let expandedFrame = cellFrame.insetBy(dx: -10, dy: -10)
            if expandedFrame.contains(point) {
                return (cell, effectiveRange, cellFrame)
            }
        }
        
        return nil
    }

    // MARK: - Block Detection & Drag Handles

    /// Returns the document block at the given point (in view coordinates)
    func blockAtPoint(_ point: CGPoint) -> (id: UUID, type: DocumentBlockType, frame: NSRect)? {
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )

        // Check media blocks first (they have visual priority)
        for mediaBlock in currentMediaBlocks {
            if let frame = frameForMediaBlock(mediaBlock) {
                let viewFrame = frame.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                if viewFrame.contains(point) {
                    return (mediaBlock.id, .media(mediaBlock), viewFrame)
                }
            }
        }

        // Check floating images - they don't participate in block drag (they use their own drag system)
        // Note: floatingImage(at:) expects view coordinates, not container coordinates
        if floatingImage(at: point) != nil {
            return nil
        }

        // Fall back to text paragraph detection
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage,
              textStorage.length > 0 else { return nil }

        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        guard charIndex < textStorage.length else { return nil }

        // Get paragraph range
        let paragraphRange = (string as NSString).paragraphRange(for: NSRange(location: charIndex, length: 0))
        let paragraphText = (string as NSString).substring(with: paragraphRange)

        // Get visual frame for paragraph
        if let frame = frameForParagraphRange(paragraphRange) {
            let viewFrame = frame.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            // Generate stable ID from paragraph content hash + position
            let blockId = UUID(uuidString: String(format: "%08X-0000-0000-0000-%012X",
                                                   paragraphText.hashValue & 0xFFFFFFFF,
                                                   paragraphRange.location)) ?? UUID()
            return (blockId, .paragraph(range: paragraphRange, text: paragraphText), viewFrame)
        }

        return nil
    }

    /// Returns the visual frame for a media block
    private func frameForMediaBlock(_ mediaBlock: MediaBlock) -> NSRect? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage else { return nil }

        let insertionIndex = mediaBlock.insertionIndex
        guard insertionIndex <= textStorage.length else { return nil }

        // Find the attachment at or near this insertion index
        // For now, calculate based on insertion point in document flow
        let charIndex = min(insertionIndex, max(0, textStorage.length - 1))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: charIndex, length: 1), actualCharacterRange: nil)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

        // Calculate media block size
        let containerWidth = textContainer.size.width
        let displayWidth = mediaBlock.displayWidth(forContainerWidth: containerWidth)
        let displayHeight = mediaBlock.displayHeight(forContainerWidth: containerWidth)

        // Position after the line (simplified - real implementation would use attachment positions)
        let frame = NSRect(
            x: (containerWidth - displayWidth) / 2, // Center the block
            y: lineRect.maxY + 8, // Below the line
            width: displayWidth,
            height: displayHeight
        )

        return frame
    }

    /// Returns the visual frame for a paragraph range
    private func frameForParagraphRange(_ range: NSRange) -> NSRect? {
        guard let layoutManager = layoutManager,
              textContainer != nil else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else { return nil }

        var unionRect = NSRect.zero
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, _, _ in
            if unionRect == .zero {
                unionRect = rect
            } else {
                unionRect = unionRect.union(rect)
            }
        }

        return unionRect
    }

    // MARK: - Inline Image Drag for Pile Creation

    /// Shows a preview of the image being dragged
    private func showInlineImageDragPreview(at point: CGPoint) {
        if inlineImageDragPreviewLayer == nil {
            wantsLayer = true
            let preview = CALayer()
            preview.backgroundColor = MarginColors.selectionLight.cgColor
            preview.borderColor = MarginColors.selectionNS.cgColor
            preview.borderWidth = 2
            preview.cornerRadius = 8
            preview.shadowColor = NSColor.black.cgColor
            preview.shadowOpacity = 0.3
            preview.shadowOffset = CGSize(width: 0, height: -4)
            preview.shadowRadius = 8
            layer?.addSublayer(preview)
            inlineImageDragPreviewLayer = preview
        }

        // Size based on the dragged attachment
        let previewSize: CGFloat = 60

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        inlineImageDragPreviewLayer?.frame = NSRect(
            x: point.x - previewSize / 2,
            y: point.y - previewSize / 2,
            width: previewSize,
            height: previewSize
        )
        inlineImageDragPreviewLayer?.opacity = 1.0
        CATransaction.commit()
    }

    /// Hides the inline image drag preview
    private func hideInlineImageDragPreview() {
        inlineImageDragPreviewLayer?.removeFromSuperlayer()
        inlineImageDragPreviewLayer = nil
    }

    /// Shows a highlight around the potential pile target
    private func showPileDropTarget(frame: NSRect) {
        if inlineImageDropTargetLayer == nil {
            wantsLayer = true
            let target = CALayer()
            target.backgroundColor = MarginColors.selectionLight.cgColor
            target.borderColor = MarginColors.selectionNS.cgColor
            target.borderWidth = 3
            target.cornerRadius = 8
            layer?.addSublayer(target)
            inlineImageDropTargetLayer = target
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        inlineImageDropTargetLayer?.frame = frame.insetBy(dx: -4, dy: -4)
        inlineImageDropTargetLayer?.opacity = 1.0
        CATransaction.commit()
    }

    /// Hides the pile drop target highlight
    private func hidePileDropTarget() {
        inlineImageDropTargetLayer?.removeFromSuperlayer()
        inlineImageDropTargetLayer = nil
    }
    
    // MARK: - Floating Image Pile Drop Target
    
    /// Shows a highlight around a floating image that's a potential pile target
    private func showFloatingPileDropTarget(frame: NSRect) {
        if floatingPileDropTargetLayer == nil {
            wantsLayer = true
            let target = CALayer()
            target.backgroundColor = MarginColors.selectionLight.cgColor
            target.borderColor = MarginColors.selectionNS.cgColor
            target.borderWidth = 3
            target.cornerRadius = 12
            layer?.addSublayer(target)
            floatingPileDropTargetLayer = target
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        floatingPileDropTargetLayer?.frame = frame.insetBy(dx: -6, dy: -6)
        floatingPileDropTargetLayer?.opacity = 1.0
        CATransaction.commit()
    }
    
    /// Hides the floating pile drop target highlight
    private func hideFloatingPileDropTarget() {
        floatingPileDropTargetLayer?.removeFromSuperlayer()
        floatingPileDropTargetLayer = nil
    }
    
    /// Combines two floating images into a pile
    private func combineFloatingImages(sourceId: UUID, targetId: UUID) {
        guard let sourceIndex = floatingImages.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = floatingImages.firstIndex(where: { $0.id == targetId }) else {
            return
        }
        
        // Store state for undo
        let sourceImage = floatingImages[sourceIndex]
        let sourceImages = sourceImage.images
        let sourcePosition = sourceImage.position
        let sourceSize = sourceImage.size
        let sourceOriginalSize = sourceImage.originalSize
        let targetOriginalImages = floatingImages[targetIndex].images
        let targetOriginalCurrentIndex = floatingImages[targetIndex].currentIndex
        
        // Add all images from source to target
        floatingImages[targetIndex].combineWith(sourceImage)
        
        // Remove the source image
        floatingImages.remove(at: sourceIndex)
        
        // Select the combined pile
        let newTargetIndex = floatingImages.firstIndex(where: { $0.id == targetId })
        if newTargetIndex != nil {
            selectedFloatingImageId = targetId
        }
        
        // Register undo
        undoManager?.registerUndo(withTarget: self) { target in
            target.uncombineFloatingImages(
                sourceId: sourceId,
                sourceImages: sourceImages,
                sourcePosition: sourcePosition,
                sourceSize: sourceSize,
                sourceOriginalSize: sourceOriginalSize,
                targetId: targetId,
                targetOriginalImages: targetOriginalImages,
                targetOriginalCurrentIndex: targetOriginalCurrentIndex
            )
        }
        undoManager?.setActionName("Create Pile")
        
        // Update exclusion paths
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        needsDisplay = true
        
        print("[FloatingPile] Combined images into pile with \(floatingImages.first(where: { $0.id == targetId })?.images.count ?? 0) images")
    }
    
    /// Undo operation for combining floating images
    private func uncombineFloatingImages(
        sourceId: UUID,
        sourceImages: [NSImage],
        sourcePosition: CGPoint,
        sourceSize: CGSize,
        sourceOriginalSize: CGSize,
        targetId: UUID,
        targetOriginalImages: [NSImage],
        targetOriginalCurrentIndex: Int
    ) {
        // Restore the target to its original state
        if let targetIndex = floatingImages.firstIndex(where: { $0.id == targetId }) {
            floatingImages[targetIndex].images = targetOriginalImages
            floatingImages[targetIndex].currentIndex = min(targetOriginalCurrentIndex, targetOriginalImages.count - 1)
        }
        
        // Restore the source as a separate floating image
        let restoredSource = FloatingReflowImage(
            id: sourceId,
            images: sourceImages,
            position: sourcePosition,
            size: sourceSize,
            originalSize: sourceOriginalSize,
            isSelected: false
        )
        floatingImages.append(restoredSource)
        
        // Register redo (which combines them again)
        undoManager?.registerUndo(withTarget: self) { target in
            target.combineFloatingImages(sourceId: sourceId, targetId: targetId)
        }
        undoManager?.setActionName("Create Pile")
        
        // Update exclusion paths and redraw
        updateExclusionPaths()
        notifyFloatingImagesChanged()
        needsDisplay = true
        
        print("[FloatingPile] Undo: Separated pile back into individual images")
    }
    
    // MARK: - Hover Animation
    
    /// Starts the hover animation timer for smooth transitions
    private func startHoverAnimation() {
        // Stop existing timer
        hoverAnimationTimer?.invalidate()
        
        // Start new animation timer (60fps)
        hoverAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            var needsUpdate = false
            let animationSpeed: CGFloat = 0.12  // Smooth, gentle transition
            
            // Animate towards target values
            for floatingImage in self.floatingImages {
                let targetProgress: CGFloat = (floatingImage.id == self.hoveredFloatingImageId) ? 1.0 : 0.0
                let currentProgress = self.hoverAnimationProgress[floatingImage.id] ?? 0.0
                
                if abs(currentProgress - targetProgress) > 0.001 {
                    // Ease out animation
                    let newProgress = currentProgress + (targetProgress - currentProgress) * animationSpeed
                    self.hoverAnimationProgress[floatingImage.id] = newProgress
                    needsUpdate = true
                } else if currentProgress != targetProgress {
                    // Snap to final value
                    self.hoverAnimationProgress[floatingImage.id] = targetProgress
                    needsUpdate = true
                }
            }
            
            if needsUpdate {
                self.needsDisplay = true
            } else {
                // Animation complete, stop timer
                timer.invalidate()
                self.hoverAnimationTimer = nil
            }
        }
    }
    
    /// Calculate hover transform for an image at a given index
    /// For single images: Enlarge and rotate slightly
    /// For piles: Enlarge and fan outward from center
    private func hoverTransform(for image: FloatingReflowImage, at index: Int) -> HoverTransform {
        let progress = hoverAnimationProgress[image.id] ?? 0.0
        guard progress > 0.001 else { return HoverTransform() }

        let isFrontCard = (index == image.currentIndex)
        let isPile = image.isPile

        // SINGLE IMAGE: Enlarge and rotate slightly
        if !isPile {
            let scale = 1.0 + (0.05 * progress)  // 5% scale increase
            let rotation = 2.0 * progress         // 2 degree rotation
            return HoverTransform(offset: .zero, scale: scale, additionalRotation: rotation)
        }

        // IMAGE PILE: Different behavior for front card vs background cards

        // Get the card's random offset (where it's positioned in the scatter)
        let cardOffset = image.offsetForImage(at: index)

        // Each card fans out based on depth - front card moves most, back cards less
        let depthFromFront = (index - image.currentIndex + image.images.count) % image.images.count
        let depthFactor = max(0.3, 1.0 - CGFloat(depthFromFront) * 0.15)

        // Front card in pile: Enlarge more significantly
        if isFrontCard {
            let scale = 1.0 + (0.08 * progress)  // 8% scale increase for front card
            return HoverTransform(offset: .zero, scale: scale, additionalRotation: 0)
        }

        // Background cards in pile: Fan outward from center
        // Direction is based on which side of center the card is positioned
        let horizontalDirection = cardOffset.x  // Positive = right, negative = left
        let verticalDirection = cardOffset.y    // Positive = down, negative = up

        // Spread multipliers - how much to amplify the existing offset direction
        let horizontalSpreadMultiplier: CGFloat = 3.5  // Spread outward horizontally (increased)
        let verticalSpreadMultiplier: CGFloat = 2.0    // Spread outward vertically
        let upwardLift: CGFloat = 10.0                 // Base upward lift for all cards (increased)

        // Calculate the outward spread based on current position
        // Cards already positioned to the right will move further right
        let outwardX = horizontalDirection * horizontalSpreadMultiplier * progress * depthFactor

        // Vertical: cards spread in their natural direction + slight upward lift for all
        let outwardY = (verticalDirection * verticalSpreadMultiplier - upwardLift) * progress * depthFactor

        // Background cards also scale up slightly
        let scale = 1.0 + (0.04 * progress * depthFactor)  // 4% max scale for back cards

        return HoverTransform(offset: CGPoint(x: outwardX, y: outwardY), scale: scale, additionalRotation: 0)
    }

    /// Legacy wrapper for backward compatibility
    private func hoverOffset(for image: FloatingReflowImage, at index: Int) -> CGPoint {
        return hoverTransform(for: image, at: index).offset
    }
    
    // MARK: - Pile Navigation
    
    /// Hit test for pile navigation controls
    private func pileNavigationHitTest(at point: CGPoint, for image: FloatingReflowImage) -> PileNavigationAction? {
        let paddedFrame = image.paddedFrame
        
        // Navigation arrows - spread to either side, vertically centered
        let arrowSize: CGFloat = 28
        let sidePadding: CGFloat = 8
        
        // Vertically center arrows
        let arrowY = paddedFrame.midY - arrowSize / 2
        
        // Left arrow (previous) - on the left side
        let leftArrowRect = NSRect(x: paddedFrame.minX + sidePadding, y: arrowY, width: arrowSize, height: arrowSize)
        if leftArrowRect.contains(point) {
            return .previous
        }
        
        // Right arrow (next) - on the right side
        let rightArrowRect = NSRect(x: paddedFrame.maxX - arrowSize - sidePadding, y: arrowY, width: arrowSize, height: arrowSize)
        if rightArrowRect.contains(point) {
            return .next
        }
        
        return nil
    }
    
    /// Handle pile navigation action
    private func handlePileNavigation(action: PileNavigationAction, for imageId: UUID) {
        guard let index = floatingImages.firstIndex(where: { $0.id == imageId }) else { return }
        
        switch action {
        case .previous:
            floatingImages[index].previousImage()
        case .next:
            floatingImages[index].nextImage()
        case .goToIndex(let i):
            floatingImages[index].goToImage(at: i)
        }
        
        // Update exclusion paths since frame size changes with aspect ratio
        updateExclusionPaths()
        needsDisplay = true
    }
    
    /// Public method for SwiftUI to call for pile navigation
    func handlePileNavigationFromSwiftUI(imageId: UUID, action: PileNavigationAction) {
        handlePileNavigation(action: action, for: imageId)
        
        // Trigger SwiftUI re-render
        NotificationCenter.default.post(
            name: NSNotification.Name("FloatingImagesChanged"),
            object: nil
        )
    }

    // MARK: - Drag Handle UI

    /// Shows the drag handle for a block
    private func showDragHandle(for blockFrame: NSRect, blockId: UUID) {
        guard currentLayoutMode.allowsBlockDragDrop else { return }

        hoveredBlockId = blockId
        hoveredBlockFrame = blockFrame

        // Create drag handle layer if needed
        if dragHandleLayer == nil {
            wantsLayer = true
            let handleLayer = CALayer()
            handleLayer.backgroundColor = NSColor.clear.cgColor
            handleLayer.cornerRadius = 4
            layer?.addSublayer(handleLayer)
            dragHandleLayer = handleLayer

            // Create 6 dots (2x3 grid) for grip icon
            for _ in 0..<6 {
                let dot = CALayer()
                dot.backgroundColor = NSColor(MarginColors.stone400).cgColor
                dot.cornerRadius = 2
                handleLayer.addSublayer(dot)
                dragHandleDots.append(dot)
            }
        }

        // Position handle to the left of the block
        let handleWidth: CGFloat = 20
        let handleHeight: CGFloat = 24
        let handleX = blockFrame.minX - handleWidth - 8
        let handleY = blockFrame.midY - handleHeight / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        dragHandleLayer?.frame = NSRect(x: handleX, y: handleY, width: handleWidth, height: handleHeight)
        dragHandleLayer?.opacity = 1.0

        // Position dots in 2x3 grid
        let dotSize: CGFloat = 4
        let dotSpacingX: CGFloat = 6
        let dotSpacingY: CGFloat = 5
        let gridWidth = 2 * dotSize + dotSpacingX
        let gridHeight = 3 * dotSize + 2 * dotSpacingY
        let startX = (handleWidth - gridWidth) / 2
        let startY = (handleHeight - gridHeight) / 2

        for i in 0..<6 {
            let col = i % 2
            let row = i / 2
            let x = startX + CGFloat(col) * (dotSize + dotSpacingX)
            let y = startY + CGFloat(row) * (dotSize + dotSpacingY)
            dragHandleDots[i].frame = NSRect(x: x, y: y, width: dotSize, height: dotSize)
        }

        CATransaction.commit()
    }

    /// Hides the drag handle
    private func hideDragHandle(animated: Bool = true) {
        hoveredBlockId = nil
        hoveredBlockFrame = nil

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            dragHandleLayer?.opacity = 0
            CATransaction.commit()
        } else {
            dragHandleLayer?.opacity = 0
        }
    }

    /// Checks if a point is over the drag handle
    private func isPointOverDragHandle(_ point: CGPoint) -> Bool {
        guard let handleFrame = dragHandleLayer?.frame,
              dragHandleLayer?.opacity ?? 0 > 0.5 else { return false }
        return handleFrame.contains(point)
    }

    // MARK: - Block Drag Preview

    /// Shows a ghost preview of the dragged block
    private func showBlockDragPreview(frame: NSRect, at point: CGPoint) {
        if blockDragPreviewLayer == nil {
            wantsLayer = true
            let preview = CALayer()
            preview.backgroundColor = NSColor(MarginColors.stone200).withAlphaComponent(0.5).cgColor
            preview.borderColor = NSColor(MarginColors.stone400).cgColor
            preview.borderWidth = 1
            preview.cornerRadius = 4
            layer?.addSublayer(preview)
            blockDragPreviewLayer = preview
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blockDragPreviewLayer?.frame = NSRect(
            x: point.x - frame.width / 2,
            y: point.y - 20,
            width: frame.width,
            height: min(frame.height, 60) // Cap preview height
        )
        blockDragPreviewLayer?.opacity = 0.8
        CATransaction.commit()
    }

    /// Hides the block drag preview
    private func hideBlockDragPreview() {
        blockDragPreviewLayer?.removeFromSuperlayer()
        blockDragPreviewLayer = nil
    }

    /// Shows drop indicator line between blocks
    private func showBlockDropIndicator(at point: CGPoint) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )

        // Find nearest paragraph boundary
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let paragraphRange = (string as NSString).paragraphRange(for: NSRange(location: charIndex, length: 0))

        // Get paragraph rect
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
        let paragraphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Determine if inserting above or below
        let insertAbove = containerPoint.y < paragraphRect.midY
        let indicatorY = insertAbove ? paragraphRect.minY : paragraphRect.maxY

        if blockDropIndicatorLayer == nil {
            wantsLayer = true
            let indicator = CALayer()
            indicator.backgroundColor = NSColor(MarginColors.stone500).cgColor
            indicator.cornerRadius = 2
            layer?.addSublayer(indicator)
            blockDropIndicatorLayer = indicator
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blockDropIndicatorLayer?.frame = NSRect(
            x: paragraphRect.minX + textContainerOrigin.x,
            y: indicatorY + textContainerOrigin.y - 2,
            width: paragraphRect.width,
            height: 4
        )
        blockDropIndicatorLayer?.opacity = 1.0
        CATransaction.commit()
    }

    /// Hides the block drop indicator
    private func hideBlockDropIndicator() {
        blockDropIndicatorLayer?.removeFromSuperlayer()
        blockDropIndicatorLayer = nil
    }

    // MARK: - Drag and Drop Handling

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Only accept image drops in Brief mode
        guard currentLayoutMode.allowsInlineMedia else {
            return super.draggingEntered(sender)
        }

        let pasteboard = sender.draggingPasteboard
        if containsImage(pasteboard: pasteboard) {
            // Show drop preview indicator
            showDropPreview(at: sender.draggingLocation)
            return .copy
        }
        return super.draggingEntered(sender)
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard currentLayoutMode.allowsInlineMedia else {
            hideDropPreview()
            return super.draggingUpdated(sender)
        }

        let pasteboard = sender.draggingPasteboard
        if containsImage(pasteboard: pasteboard) {
            // Update drop preview position
            updateDropPreview(at: sender.draggingLocation)
            return .copy
        }
        hideDropPreview()
        return super.draggingUpdated(sender)
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Accept the drag if it contains an image and we're in Brief mode
        guard currentLayoutMode.allowsInlineMedia else {
            return super.prepareForDragOperation(sender)
        }
        
        let pasteboard = sender.draggingPasteboard
        if containsImage(pasteboard: pasteboard) {
            return true
        }
        return super.prepareForDragOperation(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        // Check if this is an image
        if containsImage(pasteboard: pasteboard) {
            if let image = extractImage(from: pasteboard) {
                let dropLocation = convert(sender.draggingLocation, from: nil)
                
                // Always use floating reflow images - text flows around them dynamically
                // The floating image position determines which side text flows to:
                // - Image on left half → text flows on right
                // - Image on right half → text flows on left
                addFloatingImage(image, at: dropLocation)
                return true
            }
        }
        
        // Not an image we can handle, let NSTextView handle it
        return super.performDragOperation(sender)
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // Clean up drop preview
        hideDropPreview()
        super.concludeDragOperation(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hideDropPreview()
        super.draggingExited(sender)
    }

    // MARK: - Drop Preview Visual Feedback

    private func showDropPreview(at windowPoint: NSPoint) {
        let viewPoint = convert(windowPoint, from: nil)

        if dropPreviewLayer == nil {
            wantsLayer = true
            let preview = CALayer()
            preview.backgroundColor = NSColor(MarginColors.stone300).withAlphaComponent(0.4).cgColor
            preview.cornerRadius = 2
            layer?.addSublayer(preview)
            dropPreviewLayer = preview
        }

        // Calculate insertion line position at paragraph boundary
        let containerPoint = NSPoint(x: viewPoint.x - textContainerOrigin.x,
                                      y: viewPoint.y - textContainerOrigin.y)

        if let layoutManager = layoutManager,
           let textContainer = textContainer {
            let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            // Find paragraph boundary
            let paragraphRange = (textStorage?.string as NSString?)?.paragraphRange(for: NSRange(location: charIndex, length: 0)) ?? NSRange(location: charIndex, length: 0)

            // Get line rect at paragraph start
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: paragraphRange.location, length: 0), actualCharacterRange: nil)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: max(0, glyphRange.location), effectiveRange: nil)

            // Position preview as a horizontal insertion indicator
            lineRect = lineRect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dropPreviewLayer?.frame = NSRect(x: lineRect.minX, y: lineRect.minY - 2, width: lineRect.width, height: 4)
            CATransaction.commit()
        }
    }

    private func updateDropPreview(at windowPoint: NSPoint) {
        showDropPreview(at: windowPoint)
    }

    private func hideDropPreview() {
        dropPreviewLayer?.removeFromSuperlayer()
        dropPreviewLayer = nil
    }
    
    // MARK: - Paste Handling
    
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        
        // Check for image paste - always use floating reflow images
        if let image = extractImage(from: pasteboard) {
            // Position near the center of visible area
            let visibleRect = visibleRect
            let position = CGPoint(
                x: visibleRect.midX - 130,  // Offset for default 260 width
                y: visibleRect.midY - 97    // Offset for typical height
            )
            addFloatingImage(image, at: position)
            return
        }
        
        // For text paste: strip formatting and apply app's styling
        // This prevents issues with fonts that don't exist or encoding problems
        if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
            pasteAsPlainText(plainText)
            return
        }
        
        // Try to get text from RTF and convert to plain
        if let rtfData = pasteboard.data(forType: .rtf),
           let attrString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            pasteAsPlainText(attrString.string)
            return
        }
        
        // Fallback: standard paste (may have issues, but better than nothing)
        super.paste(sender)
    }
    
    /// Paste text with the app's styling applied
    private func pasteAsPlainText(_ text: String) {
        guard let textStorage = textStorage else { return }
        
        let selectedRange = self.selectedRange()
        
        // Create attributed string with app's body font styling
        let attributes: [NSAttributedString.Key: Any] = [
            .font: currentTypeSystem.bodyFont(size: currentBaseFontSize),
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: currentTypeSystem.bodyParagraphStyle(lineHeight: currentLineHeightMultiple)
        ]
        
        let styledText = NSAttributedString(string: text, attributes: attributes)
        
        // Group the operation for undo
        undoManager?.beginUndoGrouping()
        
        // Replace selected text (or insert at cursor)
        if textStorage.length >= selectedRange.location + selectedRange.length {
            textStorage.replaceCharacters(in: selectedRange, with: styledText)
        } else {
            textStorage.append(styledText)
        }
        
        undoManager?.endUndoGrouping()
        undoManager?.setActionName("Paste")
        
        // Move cursor to end of pasted text
        let newCursorPosition = selectedRange.location + text.count
        setSelectedRange(NSRange(location: newCursorPosition, length: 0))
        
        // Scroll to show the pasted text
        scrollRangeToVisible(NSRange(location: newCursorPosition, length: 0))
        
        // Notify delegate of change
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }
    
    private func containsImage(pasteboard: NSPasteboard) -> Bool {
        let types = pasteboard.types ?? []
        
        // Check for direct image data
        if types.contains(.png) || types.contains(.tiff) {
            return true
        }
        
        // Use readObjects to check for image file URLs (most reliable)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "bmp"].contains(ext) {
                    return true
                }
            }
        }
        
        // Fallback: check file URL types
        if types.contains(.fileURL) {
            if let urlString = pasteboard.string(forType: .fileURL),
               let url = URL(string: urlString) {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "bmp"].contains(ext) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func extractImage(from pasteboard: NSPasteboard) -> NSImage? {
        // FIRST: Try readObjects - this is the most reliable method for drag from Finder
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "bmp"].contains(ext) {
                    if let image = NSImage(contentsOf: url) {
                        return image
                    }
                }
            }
        }
        
        // Try PNG data (direct image paste/screenshot)
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            return image
        }
        
        // Try TIFF data
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            return image
        }
        
        // Try file URL string - need to properly decode percent-encoding
        if let urlString = pasteboard.string(forType: .fileURL) {
            if let url = URL(string: urlString) {
                // Convert to file path and back to handle encoding properly
                let path = url.path
                let fileURL = URL(fileURLWithPath: path)
                let ext = fileURL.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "bmp"].contains(ext) {
                    if let image = NSImage(contentsOf: fileURL) {
                        return image
                    }
                }
            }
        }
        
        // Try pasteboardItems for file URLs
        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let urlString = item.string(forType: .fileURL),
                   let url = URL(string: urlString) {
                    let path = url.path
                    let fileURL = URL(fileURLWithPath: path)
                    let ext = fileURL.pathExtension.lowercased()
                    if ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "bmp"].contains(ext) {
                        if let image = NSImage(contentsOf: fileURL) {
                            return image
                        }
                    }
                }
            }
        }
        
        // Try general image pasteboard type
        if let image = NSImage(pasteboard: pasteboard) {
            return image
        }
        
        return nil
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
        toggleFontTrait(.boldFontMask)
    }
    
    @objc func toggleItalic(_ sender: Any?) {
        toggleFontTrait(.italicFontMask)
    }
    
    @objc func toggleStrikethrough(_ sender: Any?) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
        if range.length > 0 {
            // Check if strikethrough is already applied
            let hasStrikethrough = textStorage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            
            if hasStrikethrough != 0 {
                textStorage.removeAttribute(.strikethroughStyle, range: range)
        } else {
                textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        } else {
            // Apply to typing attributes for future input
            var attrs = typingAttributes
            let hasStrikethrough = attrs[.strikethroughStyle] as? Int ?? 0
            if hasStrikethrough != 0 {
                attrs.removeValue(forKey: .strikethroughStyle)
            } else {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
                typingAttributes = attrs
        }
    }
    
    @objc func toggleUnderline(_ sender: Any?) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
        if range.length > 0 {
            // Check if underline is already applied
            let hasUnderline = textStorage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            
            if hasUnderline != 0 {
                textStorage.removeAttribute(.underlineStyle, range: range)
            } else {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        } else {
            // Apply to typing attributes for future input
            var attrs = typingAttributes
            let hasUnderline = attrs[.underlineStyle] as? Int ?? 0
            if hasUnderline != 0 {
                attrs.removeValue(forKey: .underlineStyle)
            } else {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            typingAttributes = attrs
        }
    }
    
    @objc func insertLink(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else {
            // No text selected - show alert
            let alert = NSAlert()
            alert.messageText = "Select Text First"
            alert.informativeText = "Please select the text you want to turn into a link."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Get selected text
        let selectedText = (string as NSString).substring(with: range)
        
        // Show link input dialog
        let alert = NSAlert()
        alert.messageText = "Add Link"
        alert.informativeText = "Enter the URL for \"\(selectedText)\":"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add Link")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "https://example.com"
        inputField.stringValue = ""
        alert.accessoryView = inputField
        
        // Make the text field the first responder
        alert.window.initialFirstResponder = inputField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            var urlString = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Add https:// if no scheme is present
            if !urlString.isEmpty && !urlString.contains("://") {
                urlString = "https://" + urlString
            }
            
            if let url = URL(string: urlString) {
                textStorage?.addAttribute(.link, value: url, range: range)
                // Style the link
                textStorage?.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
                textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
    }
    
    @objc func removeLink(_ sender: Any?) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
        guard range.length > 0 else { return }
        
        textStorage.removeAttribute(.link, range: range)
        textStorage.removeAttribute(.underlineStyle, range: range)
        textStorage.addAttribute(.foregroundColor, value: MarginColors.inkNS, range: range)
    }
    
    // MARK: - List Formatting
    
    @objc func toggleBulletList(_ sender: Any?) {
        toggleListStyle(bullet: true)
    }
    
    @objc func toggleNumberedList(_ sender: Any?) {
        toggleListStyle(bullet: false)
    }
    
    private func toggleListStyle(bullet: Bool) {
        guard let textStorage = textStorage else { return }
        
        let selectedRange = self.selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selectedRange)
        let paragraphText = (string as NSString).substring(with: paragraphRange)
        
        // Check if current paragraph is already a list item
        let bulletPrefix = "• "
        let numberPattern = "^\\d+\\.\\s"
        
        let isBulletList = paragraphText.hasPrefix(bulletPrefix)
        let isNumberedList = paragraphText.range(of: numberPattern, options: .regularExpression) != nil
        
        textStorage.beginEditing()
        
        if bullet {
            // Toggle bullet list
            if isBulletList {
                // Remove bullet - find all paragraphs in selection and remove bullets
                removeBulletsFromRange(paragraphRange)
            } else if isNumberedList {
                // Convert numbered to bullet
                convertNumberedToBulletInRange(paragraphRange)
            } else {
                // Add bullet to each paragraph
                addBulletsToRange(paragraphRange)
            }
        } else {
            // Toggle numbered list
            if isNumberedList {
                // Remove numbers
                removeNumbersFromRange(paragraphRange)
            } else if isBulletList {
                // Convert bullet to numbered
                convertBulletToNumberedInRange(paragraphRange)
            } else {
                // Add numbers to each paragraph
                addNumbersToRange(paragraphRange)
            }
        }
        
        textStorage.endEditing()
        
        // Notify of changes
        didChangeText()
    }
    
    private func addBulletsToRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        let text = string as NSString
        var offset = 0
        
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
            let insertLocation = paragraphRange.location + offset
            let bulletString = NSAttributedString(string: "• ", attributes: self.typingAttributes)
            textStorage.insert(bulletString, at: insertLocation)
            offset += 2 // "• " is 2 characters
        }
    }
    
    private func removeBulletsFromRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        let text = textStorage.string as NSString
        var ranges: [NSRange] = []
        
        // Collect all bullet ranges first (to avoid index shifting during removal)
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
            let paragraphText = text.substring(with: paragraphRange)
            if paragraphText.hasPrefix("• ") {
                ranges.append(NSRange(location: paragraphRange.location, length: 2))
            }
        }
        
        // Remove in reverse order to maintain correct indices
        for bulletRange in ranges.reversed() {
            textStorage.deleteCharacters(in: bulletRange)
        }
    }
    
    private func addNumbersToRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        let text = string as NSString
        var offset = 0
        var number = 1
        
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
            let insertLocation = paragraphRange.location + offset
            let numberString = NSAttributedString(string: "\(number). ", attributes: self.typingAttributes)
            textStorage.insert(numberString, at: insertLocation)
            offset += numberString.length
            number += 1
        }
    }
    
    private func removeNumbersFromRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        let text = textStorage.string as NSString
        var ranges: [NSRange] = []
        
        // Collect all number prefix ranges first
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
            let paragraphText = text.substring(with: paragraphRange)
            if let match = paragraphText.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                let prefixLength = paragraphText.distance(from: paragraphText.startIndex, to: match.upperBound)
                ranges.append(NSRange(location: paragraphRange.location, length: prefixLength))
            }
        }
        
        // Remove in reverse order
        for numberRange in ranges.reversed() {
            textStorage.deleteCharacters(in: numberRange)
        }
    }
    
    private func convertBulletToNumberedInRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        let text = textStorage.string as NSString
        var replacements: [(range: NSRange, replacement: String)] = []
        var number = 1
        
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
            let paragraphText = text.substring(with: paragraphRange)
            if paragraphText.hasPrefix("• ") {
                replacements.append((NSRange(location: paragraphRange.location, length: 2), "\(number). "))
                number += 1
            }
        }
        
        // Replace in reverse order
        for replacement in replacements.reversed() {
            textStorage.replaceCharacters(in: replacement.range, with: replacement.replacement)
        }
    }
    
    private func convertNumberedToBulletInRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        let text = textStorage.string as NSString
        var replacements: [(range: NSRange, replacement: String)] = []
        
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
            let paragraphText = text.substring(with: paragraphRange)
            if let match = paragraphText.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                let prefixLength = paragraphText.distance(from: paragraphText.startIndex, to: match.upperBound)
                replacements.append((NSRange(location: paragraphRange.location, length: prefixLength), "• "))
            }
        }
        
        // Replace in reverse order
        for replacement in replacements.reversed() {
            textStorage.replaceCharacters(in: replacement.range, with: replacement.replacement)
        }
    }
    
    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textStorage = textStorage else { return }
        
        let range = selectedRange()
            let fontManager = NSFontManager.shared
        
        if range.length > 0 {
            // Check if trait is already applied at the start of selection
            let currentFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? currentTypeSystem.bodyFont(size: currentBaseFontSize)
            let hasTrait = fontManager.traits(of: currentFont).contains(trait)
            
            // Apply or remove trait from entire selection
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
                if let font = value as? NSFont {
                    let newFont: NSFont
                    if hasTrait {
                        newFont = fontManager.convert(font, toNotHaveTrait: trait)
        } else {
                        newFont = fontManager.convert(font, toHaveTrait: trait)
                    }
                    textStorage.addAttribute(.font, value: newFont, range: attrRange)
                }
            }
        } else {
            // Apply to typing attributes for future input
            var attrs = typingAttributes
            if let currentFont = attrs[.font] as? NSFont {
                let hasTrait = fontManager.traits(of: currentFont).contains(trait)
                let newFont: NSFont
                if hasTrait {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: trait)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: trait)
                }
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
            font = currentTypeSystem.bodyFont(size: currentBaseFontSize)
            paragraphStyle.lineHeightMultiple = currentLineHeightMultiple
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

    // MARK: - Pull Quote Insertion

    @objc func insertPullQuote(_ sender: Any?) {
        // Insert an empty pull quote block inline - user types directly into it (Notion-style)
        insertEmptyPullQuoteBlock()
    }

    private func insertEmptyPullQuoteBlock() {
        guard let textStorage = textStorage else { return }

        let insertionPoint = selectedRange().location
        var currentPosition = insertionPoint

        textStorage.beginEditing()

        // If not at start of document, ensure we have a newline before
        if insertionPoint > 0 {
            let text = string as NSString
            let charBefore = text.substring(with: NSRange(location: insertionPoint - 1, length: 1))
            if charBefore != "\n" {
                textStorage.insert(NSAttributedString(string: "\n", attributes: typingAttributes), at: insertionPoint)
                currentPosition += 1
            }
        }

        // Build the empty pull quote block
        let result = NSMutableAttributedString()

        // Pull quote paragraph style - indented with vertical bar effect via left indent
        let quoteParaStyle = NSMutableParagraphStyle()
        quoteParaStyle.paragraphSpacingBefore = 24
        quoteParaStyle.paragraphSpacing = 8
        quoteParaStyle.firstLineHeadIndent = 56
        quoteParaStyle.headIndent = 56
        quoteParaStyle.lineSpacing = 6

        // Quote font - Instrument Serif or Georgia Italic at 24pt
        let quoteFont = NSFont(name: "InstrumentSerif-Regular", size: 24)
            ?? NSFont(name: "Georgia-Italic", size: 24)
            ?? NSFont.systemFont(ofSize: 24, weight: .regular)

        // Add opening quote mark (❝) as visual indicator
        let openQuoteMark = NSAttributedString(
            string: "❝ ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 20, weight: .light),
                .foregroundColor: MarginColors.stone300NS,
                .paragraphStyle: quoteParaStyle,
                .pullQuoteMarker: true
            ]
        )
        result.append(openQuoteMark)

        // Placeholder text that user will replace by typing
        let placeholderText = NSAttributedString(
            string: "Type your quote...",
            attributes: [
                .font: quoteFont,
                .foregroundColor: MarginColors.stone300NS,
                .paragraphStyle: quoteParaStyle,
                .pullQuoteMarker: true,
                .pullQuotePlaceholder: true
            ]
        )
        result.append(placeholderText)

        // Trailing newline to separate from following content
        let trailingParaStyle = NSMutableParagraphStyle()
        trailingParaStyle.paragraphSpacing = 24

        result.append(NSAttributedString(
            string: "\n",
            attributes: [
                .font: currentTypeSystem.bodyFont(size: currentBaseFontSize),
                .paragraphStyle: trailingParaStyle
            ]
        ))

        // Insert the pull quote block
        textStorage.insert(result, at: currentPosition)
        textStorage.endEditing()

        // Position cursor at the placeholder text (after the quote mark)
        // Select the placeholder so user can immediately start typing to replace it
        let placeholderStart = currentPosition + 2  // After "❝ "
        let placeholderLength = 17  // "Type your quote..."
        setSelectedRange(NSRange(location: placeholderStart, length: placeholderLength))

        // Notify of changes
        didChangeText()
    }

    /// Apply pull quote styling to the current paragraph (for when user types in the quote area)
    func applyPullQuoteStyle() {
        guard let textStorage = textStorage else { return }

        let selectedRange = self.selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selectedRange)

        // Pull quote paragraph style
        let quoteParaStyle = NSMutableParagraphStyle()
        quoteParaStyle.paragraphSpacingBefore = 24
        quoteParaStyle.paragraphSpacing = 8
        quoteParaStyle.firstLineHeadIndent = 56
        quoteParaStyle.headIndent = 56
        quoteParaStyle.lineSpacing = 6

        // Quote font
        let quoteFont = NSFont(name: "InstrumentSerif-Regular", size: 24)
            ?? NSFont(name: "Georgia-Italic", size: 24)
            ?? NSFont.systemFont(ofSize: 24, weight: .regular)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: quoteFont,
            .foregroundColor: MarginColors.inkNS,
            .paragraphStyle: quoteParaStyle,
            .pullQuoteMarker: true
        ]

        textStorage.addAttributes(attributes, range: paragraphRange)
        typingAttributes = attributes
    }

    /// Callback when a pull quote is inserted
    var onPullQuoteInserted: ((PullQuote) -> Void)?
}

// MARK: - Custom Attributed String Key for Pull Quotes

extension NSAttributedString.Key {
    static let pullQuoteMarker = NSAttributedString.Key("com.margin.pullQuoteMarker")
    static let pullQuotePlaceholder = NSAttributedString.Key("com.margin.pullQuotePlaceholder")
}

// MARK: - Floating Toolbar

struct FloatingToolbar: View {
    @Binding var typeSystem: TypeSystem
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isStrikethrough: Bool
    @Binding var isLink: Bool
    @Binding var isBulletList: Bool
    @Binding var isNumberedList: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Type system selector
            VStack(spacing: 2) {
                // Serif option
                ToolbarButton(
                    isActive: typeSystem == .editorialSerif,
                    action: { typeSystem = .editorialSerif }
                ) {
                    Text("Aa")
                        .font(.custom("Georgia-Italic", size: 15))
                }
                .help("Editorial Serif")
                
                // Sans option
                ToolbarButton(
                    isActive: typeSystem == .modernSans,
                    action: { typeSystem = .modernSans }
                ) {
                    Text("Aa")
                        .font(.system(size: 13, weight: .medium))
                }
                .help("Modern Sans")
            }
            .padding(.bottom, 6)
            
            // Subtle divider
            ToolbarDividerHorizontal()
            
            // Formatting tools
            VStack(spacing: 2) {
                ToolbarButton(
                    isActive: isBold,
                    action: { NSApp.sendAction(#selector(EditorialNSTextView.toggleBold(_:)), to: nil, from: nil) }
                ) {
                    Text("B")
                        .font(.system(size: 14, weight: .bold))
                }
                .help("Bold (⌘B)")
                
                ToolbarButton(
                    isActive: isItalic,
                    action: { NSApp.sendAction(#selector(EditorialNSTextView.toggleItalic(_:)), to: nil, from: nil) }
                ) {
                    Text("I")
                        .font(.system(size: 14, weight: .medium).italic())
                }
                .help("Italic (⌘I)")
                
                ToolbarButton(
                    isActive: isStrikethrough,
                    action: { NSApp.sendAction(#selector(EditorialNSTextView.toggleStrikethrough(_:)), to: nil, from: nil) }
                ) {
                    Image(systemName: "strikethrough")
                        .font(.system(size: 13, weight: .medium))
                }
                .help("Strikethrough (⌘⇧X)")
                
                ToolbarButton(
                    isActive: isLink,
                    action: { NSApp.sendAction(#selector(EditorialNSTextView.insertLink(_:)), to: nil, from: nil) }
                ) {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .medium))
                }
                .help("Link (⌘K)")
            }
            .padding(.vertical, 6)
            
            // Subtle divider
            ToolbarDividerHorizontal()
            
            // List formatting
            VStack(spacing: 2) {
                ToolbarButton(
                    isActive: isBulletList,
                    action: { NSApp.sendAction(#selector(EditorialNSTextView.toggleBulletList(_:)), to: nil, from: nil) }
                ) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .medium))
                }
                .help("Bullet List (⌘⇧8)")

                ToolbarButton(
                    isActive: isNumberedList,
                    action: { NSApp.sendAction(#selector(EditorialNSTextView.toggleNumberedList(_:)), to: nil, from: nil) }
                ) {
                    Image(systemName: "list.number")
                        .font(.system(size: 13, weight: .medium))
                }
                .help("Numbered List (⌘⇧7)")
            }
            .padding(.vertical, 6)

            // Subtle divider
            ToolbarDividerHorizontal()

            // Pull Quote
            ToolbarButton(
                isActive: false,
                action: { NSApp.sendAction(#selector(EditorialNSTextView.insertPullQuote(_:)), to: nil, from: nil) }
            ) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.vertical, 6)
            .help("Insert Pull Quote")

            // Subtle divider
            ToolbarDividerHorizontal()
            
            // AI assist
            ToolbarButton(
                isActive: false,
                action: { /* AI assist */ },
                accentColor: MarginColors.purple500
            ) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.top, 6)
            .help("AI Assist")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(Color(hex: "FAF9F7")) // Warm off-white
        )
        // Multi-layer shadow system
        .shadow(color: Color(hex: "1C1C1E").opacity(0.05), radius: 0, x: 0, y: 0)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.04), radius: 6, x: 0, y: 4)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

// MARK: - Horizontal Toolbar Divider

struct ToolbarDividerHorizontal: View {
    var body: some View {
        Rectangle()
            .fill(MarginColors.stone200.opacity(0.6))
            .frame(width: 24, height: 1)
    }
}

// MARK: - Toolbar Button

struct ToolbarButton<Content: View>: View {
    let isActive: Bool
    let action: () -> Void
    var accentColor: Color? = nil
    @ViewBuilder let content: Content
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    private var foregroundColor: Color {
        if let accent = accentColor, !isActive {
            return accent.opacity(0.7)
        }
        return isActive ? MarginColors.ink : MarginColors.stone400
    }
    
    private var backgroundColor: Color {
        if isPressed {
            return MarginColors.stone200.opacity(0.8)
        } else if isActive {
            return MarginColors.stone100
        } else if isHovered {
            return MarginColors.stone100.opacity(0.5)
        }
        return .clear
    }
    
    var body: some View {
        Button(action: action) {
            content
                .foregroundColor(foregroundColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Toolbar Divider

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(MarginColors.stone200.opacity(0.6))
            .frame(width: 1, height: 16)
    }
}

// MARK: - Resizable Image Attachment Cell

/// Custom NSTextAttachmentCell that supports resizing and alignment controls
class ResizableImageAttachmentCell: NSTextAttachmentCell {

    // MARK: - Properties

    /// The original full-size image
    var originalImage: NSImage?

    /// Cached scaled images at various sizes for smooth resize
    private var imageCache: [Int: NSImage] = [:]
    private let cacheSteps = 20 // Number of cached size steps

    /// Whether we're currently in a drag resize operation (defers heavy image recreation)
    var isDraggingResize: Bool = false

    /// Display width as percentage of container (0.15 to 1.0)
    var displayWidthPercent: CGFloat = 0.33 {
        didSet {
            displayWidthPercent = max(0.15, min(1.0, displayWidthPercent))
            if !isDraggingResize {
                updateDisplaySize()
            } else {
                // During drag, use cached image for smooth performance
                updateDisplaySizeFast()
            }
        }
    }

    /// Aspect ratio (width / height) - locked during resize
    var aspectRatio: CGFloat = 1.0

    /// Text wrap alignment
    var wrapAlignment: ImageWrapStyle = .block
    
    /// Whether this image is currently selected
    var isSelected: Bool = false
    
    /// Container width for calculating display size
    var containerWidth: CGFloat = 700
    
    /// Unique identifier for this attachment
    let attachmentId: UUID = UUID()

    // MARK: - Pile Placeholder State

    /// Whether this cell is a placeholder for a pile overlay
    var isPilePlaceholder: Bool = false

    /// The pile ID if this is a placeholder
    var pileId: UUID?

    /// Number of images in the pile (for badge display)
    var pileImageCount: Int = 0

    // MARK: - Caption State

    /// Caption text for this image
    var caption: String?

    /// Whether the caption is currently being edited
    var isEditingCaption: Bool = false

    /// Caption font
    private var captionFont: NSFont {
        if let newsreader = NSFont(name: "Newsreader-Italic", size: 14) {
            return newsreader
        }
        return NSFont.systemFont(ofSize: 14, weight: .regular).italic
    }

    /// Caption text color
    private var captionColor: NSColor {
        NSColor(MarginColors.stone500)
    }

    /// Height reserved for caption (including padding)
    private var captionHeight: CGFloat {
        guard caption != nil || isEditingCaption else { return 0 }
        return 28 // 8px top padding + ~14px text + 6px bottom
    }

    // MARK: - Resize State
    
    private var isResizing = false
    private var resizeStartWidth: CGFloat = 0
    private var resizeHandle: ResizeHandlePosition = .none
    
    enum ResizeHandlePosition {
        case none
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    init(image: NSImage, aspectRatio: CGFloat, containerWidth: CGFloat = 700) {
        super.init()
        self.originalImage = image
        self.aspectRatio = aspectRatio
        self.containerWidth = containerWidth
        self.image = image
        updateDisplaySize()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Size Calculation

    /// Full quality image update - called when drag ends
    private func updateDisplaySize() {
        guard let originalImage = originalImage else { return }

        let displayWidth = containerWidth * displayWidthPercent
        let displayHeight = displayWidth / aspectRatio
        let displaySize = NSSize(width: displayWidth, height: displayHeight)

        // Create a properly scaled image
        let resizedImage = NSImage(size: displaySize)
        resizedImage.lockFocus()

        // Set high-quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high

        // Draw the original image scaled to fit
        originalImage.draw(
            in: NSRect(origin: .zero, size: displaySize),
            from: NSRect(origin: .zero, size: originalImage.size),
            operation: .sourceOver,
            fraction: 1.0
        )

        resizedImage.unlockFocus()
        self.image = resizedImage
    }

    /// Fast update during drag - uses cached images or lower quality for smooth performance
    private func updateDisplaySizeFast() {
        guard let originalImage = originalImage else { return }

        let displayWidth = containerWidth * displayWidthPercent
        let displayHeight = displayWidth / aspectRatio
        let displaySize = NSSize(width: displayWidth, height: displayHeight)

        // Find nearest cached size step
        let stepSize = 1.0 / CGFloat(cacheSteps)
        let nearestStep = Int(round(displayWidthPercent / stepSize))
        let cacheKey = nearestStep

        if let cachedImage = imageCache[cacheKey] {
            // Use cached image, scaled to exact display size
            let scaledImage = NSImage(size: displaySize)
            scaledImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .default
            cachedImage.draw(
                in: NSRect(origin: .zero, size: displaySize),
                from: NSRect(origin: .zero, size: cachedImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            scaledImage.unlockFocus()
            self.image = scaledImage
        } else {
            // Create and cache a lower-quality version for this step
            let stepPercent = CGFloat(nearestStep) * stepSize
            let cacheWidth = containerWidth * max(0.15, min(1.0, stepPercent))
            let cacheHeight = cacheWidth / aspectRatio
            let cacheSize = NSSize(width: cacheWidth, height: cacheHeight)

            let cachedImage = NSImage(size: cacheSize)
            cachedImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .default // Faster interpolation
            originalImage.draw(
                in: NSRect(origin: .zero, size: cacheSize),
                from: NSRect(origin: .zero, size: originalImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            cachedImage.unlockFocus()
            imageCache[cacheKey] = cachedImage

            // Scale cached image to exact display size
            let scaledImage = NSImage(size: displaySize)
            scaledImage.lockFocus()
            cachedImage.draw(
                in: NSRect(origin: .zero, size: displaySize),
                from: NSRect(origin: .zero, size: cachedImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            scaledImage.unlockFocus()
            self.image = scaledImage
        }
    }

    /// Finalize resize - regenerate high-quality image and clear cache
    func finalizeResize() {
        isDraggingResize = false
        imageCache.removeAll()
        updateDisplaySize()
    }
    
    override func cellSize() -> NSSize {
        let width = containerWidth * displayWidthPercent
        let imageHeight = width / aspectRatio
        let totalHeight = imageHeight + captionHeight
        return NSSize(width: width, height: totalHeight)
    }

    /// Returns just the image portion of the cell (excludes caption)
    func imageRect(in cellFrame: NSRect) -> NSRect {
        let imageHeight = cellFrame.height - captionHeight
        return NSRect(x: cellFrame.minX, y: cellFrame.minY + captionHeight, width: cellFrame.width, height: imageHeight)
    }

    /// Returns the caption area rect
    func captionRect(in cellFrame: NSRect) -> NSRect {
        guard captionHeight > 0 else { return .zero }
        return NSRect(x: cellFrame.minX, y: cellFrame.minY, width: cellFrame.width, height: captionHeight)
    }
    
    override func cellFrame(for textContainer: NSTextContainer,
                           proposedLineFragment lineFrag: NSRect,
                           glyphPosition position: NSPoint,
                           characterIndex charIndex: Int) -> NSRect {
        let size = cellSize()
        return NSRect(origin: .zero, size: size)
    }
    
    // MARK: - Drawing

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        // Calculate rects for image and caption
        let imgRect = imageRect(in: cellFrame)
        let capRect = captionRect(in: cellFrame)

        // Draw the image in its portion of the cell
        if let img = image {
            img.draw(
                in: imgRect,
                from: NSRect(origin: .zero, size: img.size),
                operation: .sourceOver,
                fraction: 1.0
            )
        }

        // Draw caption if present
        if let captionText = caption, !captionText.isEmpty {
            drawCaption(captionText, in: capRect)
        } else if isEditingCaption {
            // Draw placeholder when editing but empty
            drawCaptionPlaceholder(in: capRect)
        }

        // Draw selection handles if selected (around image only)
        if isSelected {
            drawSelectionHandles(in: imgRect, controlView: controlView)
        }
    }

    /// Draws the caption text centered beneath the image
    private func drawCaption(_ text: String, in rect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: captionColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Calculate vertical centering within caption rect
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: rect.minX,
            y: rect.minY + (rect.height - textSize.height) / 2,
            width: rect.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
    }

    /// Draws placeholder text for empty caption during editing
    private func drawCaptionPlaceholder(in rect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: NSColor(MarginColors.stone400),
            .paragraphStyle: paragraphStyle
        ]

        let placeholder = NSAttributedString(string: "Add a description...", attributes: attributes)

        let textSize = placeholder.size()
        let textRect = NSRect(
            x: rect.minX,
            y: rect.minY + (rect.height - textSize.height) / 2,
            width: rect.width,
            height: textSize.height
        )

        placeholder.draw(in: textRect)
    }

    private func drawSelectionHandles(in cellFrame: NSRect, controlView: NSView?) {
        // Selection border
        let borderPath = NSBezierPath(rect: cellFrame.insetBy(dx: -1, dy: -1))
        NSColor(MarginColors.stone300).setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()

        // Handle size
        let handleSize: CGFloat = 8
        let handleColor = NSColor(MarginColors.stone400)

        // Draw corner handles
        let handles = [
            NSRect(x: cellFrame.minX - handleSize/2, y: cellFrame.minY - handleSize/2, width: handleSize, height: handleSize),
            NSRect(x: cellFrame.maxX - handleSize/2, y: cellFrame.minY - handleSize/2, width: handleSize, height: handleSize),
            NSRect(x: cellFrame.minX - handleSize/2, y: cellFrame.maxY - handleSize/2, width: handleSize, height: handleSize),
            NSRect(x: cellFrame.maxX - handleSize/2, y: cellFrame.maxY - handleSize/2, width: handleSize, height: handleSize)
        ]

        for handle in handles {
            let path = NSBezierPath(roundedRect: handle, xRadius: 2, yRadius: 2)
            handleColor.setFill()
            path.fill()
        }
    }
    
    // MARK: - Hit Testing
    
    func hitTestHandle(at point: NSPoint, in cellFrame: NSRect) -> ResizeHandlePosition {
        let handleSize: CGFloat = 12 // Slightly larger hit area than visual
        
        let topLeft = NSRect(x: cellFrame.minX - handleSize/2, y: cellFrame.maxY - handleSize/2, width: handleSize, height: handleSize)
        let topRight = NSRect(x: cellFrame.maxX - handleSize/2, y: cellFrame.maxY - handleSize/2, width: handleSize, height: handleSize)
        let bottomLeft = NSRect(x: cellFrame.minX - handleSize/2, y: cellFrame.minY - handleSize/2, width: handleSize, height: handleSize)
        let bottomRight = NSRect(x: cellFrame.maxX - handleSize/2, y: cellFrame.minY - handleSize/2, width: handleSize, height: handleSize)
        
        if topLeft.contains(point) { return .topLeft }
        if topRight.contains(point) { return .topRight }
        if bottomLeft.contains(point) { return .bottomLeft }
        if bottomRight.contains(point) { return .bottomRight }
        
        return .none
    }
    
    // MARK: - Resize Handling
    
    func beginResize(at point: NSPoint, in cellFrame: NSRect) {
        resizeHandle = hitTestHandle(at: point, in: cellFrame)
        if resizeHandle != .none {
            isResizing = true
            resizeStartWidth = containerWidth * displayWidthPercent
        }
    }
    
    func continueResize(delta: CGFloat) {
        guard isResizing else { return }
        
        // Calculate new width based on horizontal delta
        let newWidth = resizeStartWidth + delta
        let newPercent = newWidth / containerWidth
        displayWidthPercent = newPercent
    }
    
    func endResize() {
        isResizing = false
        resizeHandle = .none
    }
    
    // MARK: - Alignment
    
    func cycleAlignment() {
        switch wrapAlignment {
        case .block:
            wrapAlignment = .wrapLeft
        case .wrapLeft:
            wrapAlignment = .wrapRight
        case .wrapRight:
            wrapAlignment = .block
        }
    }
}

// MARK: - Image Selection Manager

/// Manages image selection state for the text view
class ImageSelectionManager {
    weak var textView: EditorialNSTextView?
    
    var selectedAttachment: ResizableImageAttachmentCell?
    var selectedRange: NSRange?
    
    func selectImage(_ attachment: ResizableImageAttachmentCell, at range: NSRange) {
        // Deselect previous
        selectedAttachment?.isSelected = false
        
        // Select new
        selectedAttachment = attachment
        selectedRange = range
        attachment.isSelected = true
        
        textView?.needsDisplay = true
        
        // Invalidate cursor rects so resize cursor appears
        textView?.window?.invalidateCursorRects(for: textView!)
    }
    
    func deselectAll() {
        selectedAttachment?.isSelected = false
        selectedAttachment = nil
        selectedRange = nil
        
        // Invalidate cursor rects to restore normal cursor
        if let textView = textView {
            textView.window?.invalidateCursorRects(for: textView)
        }
        textView?.needsDisplay = true
    }
    
    func resizeSelected(delta: CGFloat) {
        guard let attachment = selectedAttachment else { return }
        
        // Group resize into single undo action
        textView?.undoManager?.beginUndoGrouping()
        
        let oldPercent = attachment.displayWidthPercent
        let newWidth = attachment.containerWidth * oldPercent + delta
        let newPercent = max(0.15, min(1.0, newWidth / attachment.containerWidth))
        
        // Apply resize directly (undo for image resize is complex)
        attachment.displayWidthPercent = newPercent
        
        // Invalidate layout
        if let range = selectedRange {
            textView?.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
        textView?.needsDisplay = true
        
        textView?.undoManager?.endUndoGrouping()
    }
    
    func changeAlignment(to alignment: ImageWrapStyle) {
        guard let attachment = selectedAttachment else { return }
        
        // Apply alignment directly (undo for image changes is complex)
        attachment.wrapAlignment = alignment
        textView?.needsDisplay = true
    }
}

// MARK: - Image Alignment Control View

struct ImageAlignmentControl: View {
    let currentAlignment: ImageWrapStyle
    let onAlignmentChange: (ImageWrapStyle) -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            // Block alignment
            AlignmentButton(
                icon: "text.aligncenter",
                isSelected: currentAlignment == .block,
                action: { onAlignmentChange(.block) }
            )
            .help("Block (full width)")
            
            // Wrap left
            AlignmentButton(
                icon: "text.alignleft",
                isSelected: currentAlignment == .wrapLeft,
                action: { onAlignmentChange(.wrapLeft) }
            )
            .help("Wrap text right")
            
            // Wrap right
            AlignmentButton(
                icon: "text.alignright",
                isSelected: currentAlignment == .wrapRight,
                action: { onAlignmentChange(.wrapRight) }
            )
            .help("Wrap text left")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "FAF9F7"))
        )
        .shadow(color: Color(hex: "1C1C1E").opacity(0.05), radius: 0, x: 0, y: 0)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.04), radius: 6, x: 0, y: 4)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

struct AlignmentButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? MarginColors.ink : MarginColors.stone400)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? MarginColors.stone100 : (isHovered ? MarginColors.stone100.opacity(0.5) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    EditorialCanvasView(canvas: .constant(Canvas(
        title: "The Architecture of Thought",
        layoutMode: .write,
        typeSystem: .editorialSerif
    )))
}
