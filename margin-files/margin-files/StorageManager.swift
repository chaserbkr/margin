import Foundation
import AppKit

class StorageManager {
    
    // MARK: - Directories
    
    private var appSupportURL: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Margin", isDirectory: true)
    }
    
    private var canvasesURL: URL {
        appSupportURL.appendingPathComponent("Canvases", isDirectory: true)
    }
    
    private var imagesURL: URL {
        appSupportURL.appendingPathComponent("Images", isDirectory: true)
    }
    
    init() {
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        
        for url in [appSupportURL, canvasesURL, imagesURL] {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Canvas Persistence
    
    func saveCanvas(_ canvas: Canvas) {
        let fileURL = canvasesURL.appendingPathComponent("\(canvas.id.uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(canvas)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save canvas: \(error)")
        }
    }
    
    func loadCanvas(id: UUID) -> Canvas? {
        let fileURL = canvasesURL.appendingPathComponent("\(id.uuidString).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(Canvas.self, from: data)
        } catch {
            print("Failed to load canvas: \(error)")
            return nil
        }
    }
    
    func loadAllCanvases() -> [Canvas] {
        let fm = FileManager.default
        
        guard let files = try? fm.contentsOfDirectory(at: canvasesURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return files.compactMap { url -> Canvas? in
            guard url.pathExtension == "json" else { return nil }
            
            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(Canvas.self, from: data)
            } catch {
                print("Failed to load canvas at \(url): \(error)")
                return nil
            }
        }
    }
    
    func deleteCanvas(_ canvas: Canvas) {
        let fileURL = canvasesURL.appendingPathComponent("\(canvas.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        
        // Also delete associated images
        for image in canvas.images {
            deleteImage(filename: image.filename)
        }
    }
    
    // MARK: - Image Persistence
    
    func saveImage(_ image: NSImage, for canvasID: UUID) -> String? {
        let filename = "\(canvasID.uuidString)_\(UUID().uuidString).png"
        let fileURL = imagesURL.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        do {
            try pngData.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    func loadImage(filename: String) -> NSImage? {
        let fileURL = imagesURL.appendingPathComponent(filename)
        return NSImage(contentsOf: fileURL)
    }
    
    func deleteImage(filename: String) {
        let fileURL = imagesURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func imageURL(for filename: String) -> URL {
        imagesURL.appendingPathComponent(filename)
    }
}
