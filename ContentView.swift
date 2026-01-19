import SwiftUI
import AppKit

// MARK: - Window Traffic Light Configurator

struct WindowTrafficLightConfigurator: NSViewRepresentable {
    let headerHeight: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureTrafficLights(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureTrafficLights(from: nsView)
        }
    }

    private func configureTrafficLights(from view: NSView) {
        guard let window = view.window,
              let closeButton = window.standardWindowButton(.closeButton),
              let containerView = closeButton.superview else { return }

        // Move the entire button container to center traffic lights in our custom header
        // Traffic light buttons are 12pt tall, our header is 44pt
        // We want the center of buttons at 22pt from top (half of 44)
        // So top of buttons should be at 22 - 6 = 16pt from top of header
        var containerFrame = containerView.frame
        let buttonHeight: CGFloat = 12
        let verticalPadding = (headerHeight - buttonHeight) / 2  // 16pt
        containerFrame.origin.y = verticalPadding - 14  // Offset to move buttons down
        containerView.setFrameOrigin(containerFrame.origin)
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLibrary = true
    @State private var showAIPanel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HeaderBar(
                showLibrary: $showLibrary,
                showAIPanel: $showAIPanel
            )
            
            // Main content area
            HStack(spacing: 0) {
                // Library sidebar (conditional)
                if showLibrary {
                    DocumentLibraryView()
                        .frame(width: 320)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    MarginDivider(vertical: true)
                }
                
                // Canvas area with floating picker
                ZStack(alignment: .top) {
                    if let canvas = Binding($appState.currentCanvas) {
                        EditorialCanvasView(canvas: canvas)
                            .onChange(of: canvas.wrappedValue.content) { _, _ in
                                appState.saveCurrentCanvas()
                            }
                            .onChange(of: canvas.wrappedValue.title) { _, _ in
                                appState.saveCurrentCanvas()
                            }
                        
                        // Floating layout mode picker
                        LayoutModePicker(mode: canvas.layoutMode)
                            .padding(.top, 20)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    } else {
                        EmptyCanvasView()
                    }
                }
                
                // AI Panel (conditional)
                if showAIPanel {
                    MarginDivider(vertical: true)
                    
                    AIAssistPanelView()
                        .frame(width: 360)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(
            WindowTrafficLightConfigurator(headerHeight: 44)
                .frame(width: 0, height: 0)
        )
        .background(MarginColors.paper)
        .ignoresSafeArea(.all, edges: .top)
        .animation(.easeInOut(duration: 0.3), value: showLibrary)
        .animation(.easeInOut(duration: 0.3), value: showAIPanel)
        .onReceive(NotificationCenter.default.publisher(for: .toggleLibrary)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showLibrary.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAIPanel)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showAIPanel.toggle()
            }
        }
    }
}

// MARK: - Header Bar

struct HeaderBar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showLibrary: Bool
    @Binding var showAIPanel: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left section: Logo
            HStack(alignment: .center, spacing: 0) {
                Rectangle()
                    .fill(MarginColors.stone200)
                    .frame(width: 1, height: 16)
                    .padding(.trailing, 12)
                
                Text("Margin")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundColor(MarginColors.ink)
            }
            .padding(.leading, 78)
            
            Spacer()
            
            // Right section: Status & Actions
            HStack(alignment: .center, spacing: 14) {
                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(MarginColors.stone300)
                        .frame(width: 5, height: 5)
                    Text("Saved locally")
                        .font(MarginTypography.ui(size: 11, weight: .medium))
                        .foregroundColor(MarginColors.stone400)
                }
                
                Button {
                    showLibrary.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(showLibrary ? MarginColors.ink : MarginColors.stone400)
                }
                .buttonStyle(.plain)
                .help("Document Library")
                
                Button {
                    showAIPanel.toggle()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(showAIPanel ? MarginColors.purple600 : MarginColors.stone400)
                }
                .buttonStyle(.plain)
                .help("AI Assist")
            }
            .padding(.trailing, 24)
        }
        .frame(height: 44)
        .background(MarginColors.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MarginColors.stone200)
                .frame(height: 1)
        }
    }
}

// MARK: - Empty Canvas View

struct EmptyCanvasView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(MarginColors.stone300)
            
            VStack(spacing: 8) {
                Text("No document selected")
                    .font(MarginTypography.ui(size: 16, weight: .medium))
                    .foregroundColor(MarginColors.stone500)
                
                Text("Create a new draft to begin writing")
                    .font(MarginTypography.ui(size: 14))
                    .foregroundColor(MarginColors.stone400)
            }
            
            Button {
                appState.createNewCanvas()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Draft")
                }
            }
            .buttonStyle(MarginPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MarginColors.paper)
    }
}

// MARK: - Document Library View

struct DocumentLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    
    var filteredCanvases: [Canvas] {
        let sorted = appState.canvases.sorted { $0.updatedAt > $1.updatedAt }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { 
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.plainText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Library header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Documents")
                            .font(.custom("Georgia-Italic", size: 28))
                            .foregroundColor(MarginColors.ink)
                        Text("Everything starts as a fragment.")
                            .font(MarginTypography.ui(size: 13))
                            .foregroundColor(MarginColors.stone400)
                    }
                    
                    Spacer()
                    
                    Button {
                        appState.createNewCanvas()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("New Draft")
                        }
                    }
                    .buttonStyle(MarginPrimaryButtonStyle())
                }
                
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(MarginColors.stone300)
                    
                    TextField("Filter your thoughts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(MarginTypography.ui(size: 13))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    MarginDivider()
                }
            }
            .padding(24)
            
            // Document list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCanvases) { canvas in
                        DocumentRowView(
                            canvas: canvas,
                            isSelected: appState.currentCanvas?.id == canvas.id
                        ) {
                            appState.selectCanvas(canvas)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(MarginColors.stone50.opacity(0.3))
    }
}

struct DocumentRowView: View {
    let canvas: Canvas
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var displayTitle: String {
        canvas.title.isEmpty ? "Untitled" : canvas.title
    }
    
    private var wordCount: Int {
        canvas.content.plainText.split(separator: " ").count
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered || isSelected ? MarginColors.ink : MarginColors.stone100)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundColor(isHovered || isSelected ? MarginColors.paper : MarginColors.stone400)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.custom("Georgia", size: 17))
                        .foregroundColor(MarginColors.ink)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(canvas.layoutMode.displayName.uppercased())
                            .font(MarginTypography.mono(size: 10))
                        Circle()
                            .fill(MarginColors.stone200)
                            .frame(width: 3, height: 3)
                        Text("\(wordCount) WORDS")
                            .font(MarginTypography.mono(size: 10))
                    }
                    .foregroundColor(MarginColors.stone400)
                }
                
                Spacer()
                
                // Date
                VStack(alignment: .trailing, spacing: 4) {
                    Text(canvas.updatedAt, style: .date)
                        .font(MarginTypography.ui(size: 11))
                        .foregroundColor(MarginColors.stone400)
                    
                    Text("Draft")
                        .font(MarginTypography.mono(size: 9))
                        .foregroundColor(MarginColors.stone300)
                        .textCase(.uppercase)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MarginColors.stone300)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? MarginColors.stone100 : (isHovered ? MarginColors.ink.opacity(0.02) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                // Delete action
            }
        }
    }
}

// MARK: - AI Assist Panel

struct AIAssistPanelView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(MarginColors.purple500)
                    Text("ASSISTANT EDITOR")
                        .font(MarginTypography.ui(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(MarginColors.stone400)
                }
                
                Spacer()
                
                Button {
                    // Settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(MarginColors.stone400)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .overlay(alignment: .bottom) {
                MarginDivider()
                    .opacity(0.5)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Model selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CONTEXT & DEPTH")
                            .font(MarginTypography.ui(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(MarginColors.stone400)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Model Selection")
                                    .font(MarginTypography.ui(size: 13, weight: .medium))
                                Spacer()
                                Text("Claude 3.5")
                                    .font(MarginTypography.ui(size: 12, weight: .medium))
                                    .foregroundColor(MarginColors.stone500)
                            }
                            .padding(12)
                            .background(MarginColors.paper)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MarginColors.stone100, lineWidth: 1)
                            )
                            
                            HStack {
                                Text("Style Preset")
                                    .font(MarginTypography.ui(size: 13, weight: .medium))
                                Spacer()
                                Text("Editorial")
                                    .font(MarginTypography.ui(size: 12, weight: .medium))
                                    .foregroundColor(MarginColors.purple600)
                            }
                            .padding(12)
                            .background(MarginColors.paper)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MarginColors.stone100, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Privacy notice
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 16))
                            .foregroundColor(MarginColors.stone300)
                        
                        Text("Assistant operates only on selected text. Your thoughts remain local unless you explicitly invite analysis.")
                            .font(MarginTypography.ui(size: 11))
                            .foregroundColor(MarginColors.stone400)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(MarginColors.stone200)
                    )
                }
                .padding(24)
            }
            
            Spacer()
        }
        .background(MarginColors.stone50.opacity(0.5))
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences")
                        .font(.custom("Georgia-Italic", size: 40))
                        .foregroundColor(MarginColors.ink)
                    Text("Configure your environment for intentional writing.")
                        .font(.custom("Georgia-Italic", size: 17))
                        .foregroundColor(MarginColors.stone500)
                }
                
                // Typography section
                SettingsSection(title: "Typography System") {
                    VStack(spacing: 12) {
                        ForEach(TypeSystem.allCases, id: \.self) { system in
                            TypeSystemRow(
                                system: system,
                                isSelected: appState.settings.defaultTypeSystem == system
                            ) {
                                appState.settings.defaultTypeSystem = system
                            }
                        }
                    }
                }
                
                // Layout section
                SettingsSection(title: "Canvas Layout") {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default Layout")
                                    .font(MarginTypography.ui(size: 14, weight: .medium))
                                Text("Starting mode for new documents")
                                    .font(MarginTypography.ui(size: 12))
                                    .foregroundColor(MarginColors.stone400)
                            }
                            Spacer()
                            Picker("", selection: $appState.settings.defaultLayoutMode) {
                                ForEach(LayoutMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                    }
                }
                
                // AI section
                SettingsSection(title: "AI Assistance") {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable AI Assistant")
                                    .font(MarginTypography.ui(size: 14, weight: .medium))
                                Text("On-demand editorial help")
                                    .font(MarginTypography.ui(size: 12))
                                    .foregroundColor(MarginColors.stone400)
                            }
                            Spacer()
                            Toggle("", isOn: $appState.settings.aiEnabled)
                                .labelsHidden()
                        }
                        
                        if appState.settings.aiEnabled {
                            MarginDivider()
                            
                            VStack(spacing: 12) {
                                SecureField("OpenAI API Key", text: $openAIKey)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(MarginColors.paper)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(MarginColors.stone200, lineWidth: 1)
                                    )
                                
                                SecureField("Anthropic API Key", text: $anthropicKey)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(MarginColors.paper)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(MarginColors.stone200, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(20)
                    .background(MarginColors.stone50.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MarginColors.stone100, lineWidth: 1)
                    )
                }
            }
            .padding(48)
        }
        .frame(width: 600, height: 500)
        .background(MarginColors.paper)
        .onAppear {
            openAIKey = appState.settings.getAPIKey(for: .openAI) ?? ""
            anthropicKey = appState.settings.getAPIKey(for: .anthropic) ?? ""
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(title.uppercased())
                    .font(MarginTypography.ui(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(MarginColors.stone400)
                
                MarginDivider()
            }
            
            content
        }
    }
}

struct TypeSystemRow: View {
    let system: TypeSystem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(system.displayName)
                        .font(system == .editorialSerif ? 
                            .custom("Georgia-Italic", size: 20) : 
                            MarginTypography.ui(size: 18, weight: .medium))
                        .foregroundColor(MarginColors.ink)
                    
                    Text(system.description)
                        .font(MarginTypography.ui(size: 11))
                        .foregroundColor(MarginColors.stone400)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MarginColors.ink)
                }
            }
            .padding(20)
            .background(isSelected ? MarginColors.paper : MarginColors.stone50.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? MarginColors.ink.opacity(0.1) : MarginColors.stone100, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
