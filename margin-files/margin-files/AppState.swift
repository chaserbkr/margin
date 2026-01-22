import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var canvases: [Canvas] = []
    @Published var currentCanvas: Canvas?
    @Published var showFileList: Bool = true
    @Published var settings: AppSettings
    
    private let storageManager = StorageManager()
    private var settingsCancellable: AnyCancellable?
    
    /// Tracks the content hash of the current canvas when it was loaded/selected
    /// Used to detect actual content changes vs document switching
    private var loadedContentHash: Int?
    private var loadedFloatingImagesCount: Int?
    
    /// Flag to suppress onChange handlers during document switching
    /// This prevents false "change" detection when switching between documents
    var isSwitchingDocuments: Bool = false
    
    init() {
        self.settings = AppSettings()
        
        // Forward settings changes to AppState so views update
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        
        loadCanvases()
        
        // Select most recent canvas or create new one
        if let mostRecent = canvases.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            selectCanvas(mostRecent)
        } else {
            createNewCanvas()
        }
    }
    
    // MARK: - Canvas Management
    
    func createNewCanvas() {
        let canvas = Canvas(
            layoutMode: settings.defaultLayoutMode,
            typeSystem: settings.defaultTypeSystem
        )
        canvases.append(canvas)
        selectCanvas(canvas)
        saveCanvasWithTimestamp(canvas)
    }
    
    func selectCanvas(_ canvas: Canvas) {
        // Set flag to suppress onChange handlers during switch
        isSwitchingDocuments = true
        
        // Store the content hash for detecting actual changes later
        loadedContentHash = canvas.content.plainText.hashValue
        loadedFloatingImagesCount = canvas.floatingImages.count
        currentCanvas = canvas
        
        // Clear the flag after a delay to allow SwiftUI's onChange handlers to fire and be ignored
        // Using 0.1 seconds to ensure all deferred UI updates complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isSwitchingDocuments = false
        }
    }
    
    func deleteCanvas(_ canvas: Canvas) {
        canvases.removeAll { $0.id == canvas.id }
        storageManager.deleteCanvas(canvas)

        if currentCanvas?.id == canvas.id {
            currentCanvas = canvases.first
            if currentCanvas == nil {
                createNewCanvas()
            } else if let current = currentCanvas {
                selectCanvas(current)
            }
        }
    }

    func duplicateCanvas(_ canvas: Canvas) {
        var newCanvas = Canvas(
            layoutMode: canvas.layoutMode,
            typeSystem: canvas.typeSystem
        )
        newCanvas.title = canvas.title.isEmpty ? "Untitled Copy" : "\(canvas.title) Copy"
        newCanvas.content = canvas.content
        canvases.append(newCanvas)
        selectCanvas(newCanvas)
        saveCanvasWithTimestamp(newCanvas)
    }

    func toggleFavorite(_ canvas: Canvas) {
        guard let index = canvases.firstIndex(where: { $0.id == canvas.id }) else { return }
        canvases[index].isFavorite.toggle()
        storageManager.saveCanvas(canvases[index])

        // Update currentCanvas if it's the same one
        if currentCanvas?.id == canvas.id {
            currentCanvas?.isFavorite = canvases[index].isFavorite
        }
    }
    
    /// Saves a canvas WITHOUT updating the timestamp
    /// Use this when you need to persist but content hasn't meaningfully changed
    func saveCanvas(_ canvas: Canvas) {
        if let index = canvases.firstIndex(where: { $0.id == canvas.id }) {
            canvases[index] = canvas
        }
        storageManager.saveCanvas(canvas)
    }
    
    /// Saves a canvas AND updates the timestamp
    /// Use this when actual content changes have occurred
    func saveCanvasWithTimestamp(_ canvas: Canvas) {
        // Don't update timestamp during document switching
        guard !isSwitchingDocuments else {
            saveCanvas(canvas)
            return
        }
        
        var updatedCanvas = canvas
        updatedCanvas.updatedAt = Date()
        
        if let index = canvases.firstIndex(where: { $0.id == canvas.id }) {
            canvases[index] = updatedCanvas
        }
        
        // Also update currentCanvas if it's the same one
        if currentCanvas?.id == canvas.id {
            currentCanvas = updatedCanvas
        }
        
        storageManager.saveCanvas(updatedCanvas)
    }
    
    /// Saves the current canvas, only updating timestamp if content actually changed
    func saveCurrentCanvas() {
        // Ignore saves triggered during document switching
        guard !isSwitchingDocuments else { return }
        
        guard var canvas = currentCanvas else { return }
        
        // Check if content actually changed since we loaded/selected this document
        let currentContentHash = canvas.content.plainText.hashValue
        let currentFloatingCount = canvas.floatingImages.count
        
        let contentChanged = currentContentHash != loadedContentHash
        let floatingImagesChanged = currentFloatingCount != loadedFloatingImagesCount
        
        if contentChanged || floatingImagesChanged {
            // Actual content change - update timestamp
            canvas.updatedAt = Date()
            loadedContentHash = currentContentHash
            loadedFloatingImagesCount = currentFloatingCount
            
            if let index = canvases.firstIndex(where: { $0.id == canvas.id }) {
                canvases[index] = canvas
            }
            currentCanvas = canvas
            storageManager.saveCanvas(canvas)
        } else {
            // No content change - save without updating timestamp
            saveCanvas(canvas)
        }
    }
    
    // MARK: - Persistence
    
    private func loadCanvases() {
        canvases = storageManager.loadAllCanvases()
    }
}
