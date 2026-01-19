import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var canvases: [Canvas] = []
    @Published var currentCanvas: Canvas?
    @Published var showFileList: Bool = true
    @Published var settings: AppSettings
    
    private let storageManager = StorageManager()
    
    init() {
        self.settings = AppSettings()
        loadCanvases()
        
        // Select most recent canvas or create new one
        if let mostRecent = canvases.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            currentCanvas = mostRecent
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
        currentCanvas = canvas
        saveCanvas(canvas)
    }
    
    func selectCanvas(_ canvas: Canvas) {
        currentCanvas = canvas
    }
    
    func deleteCanvas(_ canvas: Canvas) {
        canvases.removeAll { $0.id == canvas.id }
        storageManager.deleteCanvas(canvas)
        
        if currentCanvas?.id == canvas.id {
            currentCanvas = canvases.first
            if currentCanvas == nil {
                createNewCanvas()
            }
        }
    }
    
    func saveCanvas(_ canvas: Canvas) {
        var updatedCanvas = canvas
        updatedCanvas.updatedAt = Date()
        
        if let index = canvases.firstIndex(where: { $0.id == canvas.id }) {
            canvases[index] = updatedCanvas
        }
        
        storageManager.saveCanvas(updatedCanvas)
    }
    
    func saveCurrentCanvas() {
        guard let canvas = currentCanvas else { return }
        saveCanvas(canvas)
    }
    
    // MARK: - Persistence
    
    private func loadCanvases() {
        canvases = storageManager.loadAllCanvases()
    }
}
