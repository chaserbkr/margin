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
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Main app content
            VStack(spacing: 0) {
                // Header bar
                HeaderBar(
                    showLibrary: $showLibrary,
                    showAIPanel: $showAIPanel,
                    showSettings: $showSettings
                )
                
                // Main content area
                HStack(spacing: 0) {
                    // Library sidebar (conditional)
                    if showLibrary {
                        DocumentLibraryView(showSettings: $showSettings)
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
            .blur(radius: showSettings ? 2 : 0)
            
            // Settings Modal Overlay
            if showSettings {
                SettingsModalOverlay(isPresented: $showSettings)
                    .transition(.opacity)
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
        .animation(.easeOut(duration: 0.15), value: showSettings)
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettings)) { _ in
            withAnimation(.easeOut(duration: 0.15)) {
                showSettings.toggle()
            }
        }
    }
}

// MARK: - Header Bar

struct HeaderBar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showLibrary: Bool
    @Binding var showAIPanel: Bool
    @Binding var showSettings: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left section: Logo
            HStack(alignment: .center, spacing: 0) {
                Rectangle()
                    .fill(MarginColors.stone200)
                    .frame(width: 1, height: 16)
                    .padding(.trailing, 12)
                
                Text("Margin.")
                    .font(.custom("PlayfairDisplay-Bold", size: 18))
                    .tracking(-0.5)
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLibrary.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(showLibrary ? MarginColors.ink : MarginColors.stone400)
                }
                .buttonStyle(.plain)
                .help("Document Library")
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAIPanel.toggle()
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(showAIPanel ? MarginColors.purple600 : MarginColors.stone400)
                }
                .buttonStyle(.plain)
                .help("AI Assist")
                
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showSettings.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(MarginColors.stone400)
                }
                .buttonStyle(.plain)
                .help("Settings")
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
    @Binding var showSettings: Bool
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
                LazyVStack(spacing: 4) {
                    ForEach(filteredCanvases) { canvas in
                        DocumentRowView(
                            canvas: canvas,
                            isSelected: appState.currentCanvas?.id == canvas.id,
                            action: {
                                appState.selectCanvas(canvas)
                            },
                            onDuplicate: {
                                appState.duplicateCanvas(canvas)
                            },
                            onDelete: {
                                appState.deleteCanvas(canvas)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            
            Spacer()
            
            // Settings footer
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    showSettings = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                    Text("SETTINGS")
                        .font(MarginTypography.ui(size: 11, weight: .medium))
                        .tracking(1)
                }
                .foregroundColor(MarginColors.stone400)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                MarginDivider()
            }
        }
        .background(MarginColors.stone50.opacity(0.3))
    }
}

struct DocumentRowView: View {
    let canvas: Canvas
    let isSelected: Bool
    let action: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var displayTitle: String {
        canvas.title.isEmpty ? "Untitled" : canvas.title
    }

    private var wordCount: Int {
        let text = canvas.content.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return 0 }
        return text.split(separator: " ").count
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(canvas.updatedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(canvas.updatedAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: canvas.updatedAt)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? MarginColors.ink : MarginColors.stone100)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? MarginColors.paper : MarginColors.stone400)
                    )

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.custom("Georgia", size: 15))
                        .foregroundColor(MarginColors.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(formattedDate)
                        Text("·")
                        Text("\(wordCount) words")
                    }
                    .font(MarginTypography.ui(size: 11))
                    .foregroundColor(MarginColors.stone400)
                }

                Spacer()

                // Menu button
                Menu {
                    Button {
                        onDuplicate()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MarginColors.ink.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .opacity(isHovered || isSelected ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? MarginColors.stone100 : (isHovered ? MarginColors.ink.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
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

// MARK: - Settings Modal Overlay

struct SettingsModalOverlay: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    
    // Staged settings values (local copy for editing)
    @State private var stagedTypography: TypeSystem = .editorialSerif
    @State private var stagedInterfaceTheme: InterfaceTheme = .light
    @State private var stagedFontSize: Double = 18
    @State private var stagedLineHeight: Double = 1.6
    @State private var stagedLocalStorageOnly: Bool = true
    @State private var stagedAutoSave: Bool = true
    
    // Animation state
    @State private var modalScale: CGFloat = 0.95
    @State private var modalOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dimmed background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissModal()
                }
            
            // Modal container
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.custom("Georgia-Italic", size: 32))
                        .foregroundColor(MarginColors.ink)
                    
                    Spacer()
                    
                    Button {
                        dismissModal()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MarginColors.stone400)
                            .frame(width: 32, height: 32)
                            .background(MarginColors.stone100.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // EDITOR APPEARANCE Section
                        SettingsModalSection(title: "EDITOR APPEARANCE") {
                            VStack(spacing: 24) {
                                // Typography & Theme row
                                HStack(alignment: .top, spacing: 48) {
                                    // Typography
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Typography")
                                            .font(MarginTypography.ui(size: 14, weight: .medium))
                                            .foregroundColor(MarginColors.ink)
                                        
                                        SettingsSegmentedPicker(
                                            options: ["Serif", "Sans", "Mono"],
                                            selected: typographyBinding
                                        )
                                    }
                                    
                                    // Interface Theme
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Interface Theme")
                                            .font(MarginTypography.ui(size: 14, weight: .medium))
                                            .foregroundColor(MarginColors.ink)
                                        
                                        HStack(spacing: 8) {
                                            ForEach(InterfaceTheme.allCases, id: \.self) { theme in
                                                Button {
                                                    stagedInterfaceTheme = theme
                                                } label: {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(theme.previewColor)
                                                        .frame(width: 48, height: 32)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 6)
                                                                .stroke(stagedInterfaceTheme == theme ? MarginColors.ink : MarginColors.stone200, lineWidth: stagedInterfaceTheme == theme ? 2 : 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                
                                // Font Size & Line Height row
                                HStack(alignment: .top, spacing: 48) {
                                    // Font Size
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Font Size")
                                            .font(MarginTypography.ui(size: 14, weight: .medium))
                                            .foregroundColor(MarginColors.ink)
                                        
                                        HStack(spacing: 16) {
                                            Slider(value: $stagedFontSize, in: 12...24, step: 1)
                                                .frame(width: 160)
                                            Text("\(Int(stagedFontSize))px")
                                                .font(MarginTypography.ui(size: 13))
                                                .foregroundColor(MarginColors.stone500)
                                                .frame(width: 40, alignment: .trailing)
                                        }
                                    }
                                    
                                    // Line Height
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Line Height")
                                            .font(MarginTypography.ui(size: 14, weight: .medium))
                                            .foregroundColor(MarginColors.ink)
                                        
                                        HStack(spacing: 16) {
                                            Slider(value: $stagedLineHeight, in: 1.2...2.0, step: 0.1)
                                                .frame(width: 160)
                                            Text(String(format: "%.1f", stagedLineHeight))
                                                .font(MarginTypography.ui(size: 13))
                                                .foregroundColor(MarginColors.stone500)
                                                .frame(width: 40, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // PRIVACY & LOCAL FIRST Section
                        SettingsModalSection(title: "PRIVACY & LOCAL FIRST") {
                            VStack(spacing: 20) {
                                // Local Storage Only
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Local Storage Only")
                                            .font(MarginTypography.ui(size: 14, weight: .medium))
                                            .foregroundColor(MarginColors.ink)
                                        Text("Your documents are encrypted and stored locally on this Mac. No cloud syncing enabled.")
                                            .font(MarginTypography.ui(size: 12))
                                            .foregroundColor(MarginColors.stone400)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $stagedLocalStorageOnly)
                                        .labelsHidden()
                                        .toggleStyle(SwitchToggleStyle(tint: MarginColors.ink))
                                }
                                
                                MarginDivider()
                                
                                // Auto-save Interval
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Auto-save Interval")
                                            .font(MarginTypography.ui(size: 14, weight: .medium))
                                            .foregroundColor(MarginColors.ink)
                                        Text("Save every 30 seconds of inactivity.")
                                            .font(MarginTypography.ui(size: 12))
                                            .foregroundColor(MarginColors.stone400)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $stagedAutoSave)
                                        .labelsHidden()
                                        .toggleStyle(SwitchToggleStyle(tint: MarginColors.ink))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
                
                // Footer buttons
                HStack {
                    Button {
                        resetToDefaults()
                    } label: {
                        Text("RESET DEFAULTS")
                            .font(MarginTypography.ui(size: 11, weight: .medium))
                            .tracking(1)
                            .foregroundColor(MarginColors.stone400)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button {
                            dismissModal()
                        } label: {
                            Text("CANCEL")
                                .font(MarginTypography.ui(size: 12, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(MarginColors.stone500)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            saveChanges()
                        } label: {
                            Text("SAVE CHANGES")
                                .font(MarginTypography.ui(size: 12, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(MarginColors.paper)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(MarginColors.ink)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .overlay(alignment: .top) {
                    MarginDivider()
                }
            }
            .frame(width: 580, height: 520)
            .background(MarginColors.paper)
            .cornerRadius(16)
            .shadow(color: MarginColors.ink.opacity(0.15), radius: 40, x: 0, y: 20)
            .shadow(color: MarginColors.ink.opacity(0.1), radius: 10, x: 0, y: 5)
            .scaleEffect(modalScale)
            .opacity(modalOpacity)
        }
        .onAppear {
            loadCurrentSettings()
            withAnimation(.easeOut(duration: 0.15)) {
                modalScale = 1.0
                modalOpacity = 1.0
            }
        }
        .onExitCommand {
            dismissModal()
        }
    }
    
    private var typographyBinding: Binding<Int> {
        Binding(
            get: {
                switch stagedTypography {
                case .editorialSerif: return 0
                case .modernSans: return 1
                case .technicalMono: return 2
                case .humanistSans: return 1 // Map to Sans
                }
            },
            set: { newValue in
                switch newValue {
                case 0: stagedTypography = .editorialSerif
                case 1: stagedTypography = .modernSans
                case 2: stagedTypography = .technicalMono
                default: break
                }
            }
        )
    }
    
    private func loadCurrentSettings() {
        stagedTypography = appState.settings.defaultTypeSystem
        stagedFontSize = 18
        stagedLineHeight = 1.6
        stagedLocalStorageOnly = true
        stagedAutoSave = true
    }
    
    private func saveChanges() {
        appState.settings.defaultTypeSystem = stagedTypography
        // Apply other settings as needed
        dismissModal()
    }
    
    private func resetToDefaults() {
        stagedTypography = .editorialSerif
        stagedInterfaceTheme = .light
        stagedFontSize = 18
        stagedLineHeight = 1.6
        stagedLocalStorageOnly = true
        stagedAutoSave = true
    }
    
    private func dismissModal() {
        withAnimation(.easeIn(duration: 0.12)) {
            modalScale = 0.95
            modalOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            isPresented = false
        }
    }
}

// MARK: - Settings Modal Components

struct SettingsModalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(MarginTypography.ui(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(MarginColors.stone400)
            
            content
        }
    }
}

struct SettingsSegmentedPicker: View {
    let options: [String]
    @Binding var selected: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    selected = index
                } label: {
                    Text(options[index])
                        .font(MarginTypography.ui(size: 13, weight: .medium))
                        .foregroundColor(selected == index ? MarginColors.ink : MarginColors.stone400)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selected == index ? MarginColors.paper : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MarginColors.stone100.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Interface Theme

enum InterfaceTheme: CaseIterable {
    case light, dark, darker
    
    var previewColor: Color {
        switch self {
        case .light: return MarginColors.paper
        case .dark: return MarginColors.stone800
        case .darker: return MarginColors.stone900
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
