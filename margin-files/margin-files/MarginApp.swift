import SwiftUI

@main
struct MarginApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Draft") {
                    appState.createNewCanvas()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Canvas") {
                Menu("Layout") {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Button(mode.displayName) {
                            appState.currentCanvas?.layoutMode = mode
                        }
                    }
                }
                
                Menu("Typography") {
                    ForEach(TypeSystem.allCases, id: \.self) { system in
                        Button(system.displayName) {
                            appState.currentCanvas?.typeSystem = system
                        }
                    }
                }
            }
            
            CommandMenu("Format") {
                Section("Headings") {
                    Button("Heading 1") {
                        NSApp.sendAction(#selector(EditorialNSTextView.applyHeading1(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                    
                    Button("Heading 2") {
                        NSApp.sendAction(#selector(EditorialNSTextView.applyHeading2(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                    
                    Button("Heading 3") {
                        NSApp.sendAction(#selector(EditorialNSTextView.applyHeading3(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                    
                    Button("Body Text") {
                        NSApp.sendAction(#selector(EditorialNSTextView.applyBodyStyle(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut("0", modifiers: [.command, .option])
                }
                
                Divider()
                
                Section("Style") {
                    Button("Bold") {
                        NSApp.sendAction(#selector(EditorialNSTextView.toggleBold(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut("b", modifiers: .command)
                    
                    Button("Italic") {
                        NSApp.sendAction(#selector(EditorialNSTextView.toggleItalic(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut("i", modifiers: .command)
                }
            }
            
            CommandGroup(replacing: .sidebar) {
                Button("Toggle Library") {
                    NotificationCenter.default.post(name: .toggleLibrary, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                
                Button("Toggle AI Assistant") {
                    NotificationCenter.default.post(name: .toggleAIPanel, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleLibrary = Notification.Name("toggleLibrary")
    static let toggleAIPanel = Notification.Name("toggleAIPanel")
}
