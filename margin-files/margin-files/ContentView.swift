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

        // Move the traffic light container down to vertically center in our 44pt header
        // The default position is too high, so we need to lower it
        // Negative y value moves the container down (toward the content)
        var newFrame = containerView.frame
        newFrame.origin.y = -6  // Move down 6pt to center in 44pt header
        containerView.frame = newFrame
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLibrary = true
    @State private var showAIPanel = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showMoreDocuments = false

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
                        DocumentLibraryView(
                            showSettings: $showSettings,
                            showProfile: $showProfile,
                            showMorePanel: $showMoreDocuments
                        )
                            .frame(width: showMoreDocuments ? 600 : 320)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        
                        MarginDivider(vertical: true)
                    }
                    
                    // Canvas area with floating picker
                    ZStack(alignment: .top) {
                        if let canvas = Binding($appState.currentCanvas) {
                            EditorialCanvasView(canvas: canvas)
                                .onChange(of: canvas.wrappedValue.content) { _, _ in
                                    // Ignore changes triggered by document switching
                                    guard !appState.isSwitchingDocuments else { return }
                                    appState.saveCurrentCanvas()
                                }
                                .onChange(of: canvas.wrappedValue.title) { oldTitle, newTitle in
                                    // Ignore changes triggered by document switching
                                    guard !appState.isSwitchingDocuments else { return }
                                    // Only update timestamp if title actually changed
                                    if oldTitle != newTitle {
                                        appState.saveCanvasWithTimestamp(canvas.wrappedValue)
                                    }
                                }
                                .onChange(of: canvas.wrappedValue.floatingImages.count) { _, _ in
                                    // Ignore changes triggered by document switching
                                    guard !appState.isSwitchingDocuments else { return }
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
            // Settings Modal Overlay
            if showSettings {
                SettingsModalOverlay(isPresented: $showSettings)
                    .transition(.opacity)
            }

            // Profile Modal Overlay
            if showProfile {
                ProfileModalOverlay(isPresented: $showProfile, showSettings: $showSettings)
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
        .animation(.easeOut(duration: 0.15), value: showProfile)
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
    
    /// Logo font - tries Playfair Display Bold, falls back to Georgia Bold
    private var logoFont: Font {
        // Try multiple common font name formats for Playfair Display Bold
        let fontNames = [
            "PlayfairDisplay-Bold",
            "Playfair Display Bold", 
            "Playfair Display",
            "PlayfairDisplayRoman-Bold"
        ]
        
        for fontName in fontNames {
            if let _ = NSFont(name: fontName, size: 18) {
                return Font.custom(fontName, size: 18)
            }
        }
        
        // Fallback to Georgia Bold (a serif font available on all Macs)
        return Font.custom("Georgia-Bold", size: 18)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left section: Sidebar toggle + Logo
            HStack(alignment: .center, spacing: 0) {
                Rectangle()
                    .fill(MarginColors.stone200)
                    .frame(width: 1, height: 16)
                    .padding(.trailing, 12)
                
                // Sidebar toggle button (moved from right section)
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLibrary.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(showLibrary ? MarginColors.stone500 : MarginColors.stone400)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .help("Document Library")
                .padding(.trailing, 12)
                
                Text("Margin.")
                    .font(logoFont)
                    .tracking(-0.5)
                    .foregroundColor(MarginColors.ink)
            }
            .padding(.leading, 78)
            
            Spacer()
            
            // Right section: Status & Actions
            HStack(alignment: .center, spacing: 14) {
                HStack(alignment: .center, spacing: 5) {
                    Circle()
                        .fill(Color.green.opacity(0.7))
                        .frame(width: 5, height: 5)
                    Text("Synced")
                        .font(MarginTypography.ui(size: 11, weight: .medium))
                        .foregroundColor(MarginColors.stone400)
                }
                
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
                .pointerCursor()
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
                .pointerCursor()
                .help("Settings")
            }
            .padding(.trailing, 24)
        }
        .frame(height: 44)
        .background(MarginColors.paper)
        .contentShape(Rectangle()) // Make entire header tappable
        .onTapGesture(count: 2) {
            // Double-click to zoom window (standard macOS behavior)
            if let window = NSApp.keyWindow {
                window.zoom(nil)
            }
        }
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
    @Binding var showProfile: Bool
    @Binding var showMorePanel: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let maxVisibleDocuments = 10

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

    var favoriteCanvases: [Canvas] {
        filteredCanvases.filter { $0.isFavorite }
    }

    var regularCanvases: [Canvas] {
        filteredCanvases.filter { !$0.isFavorite }
    }

    var visibleRegularCanvases: [Canvas] {
        Array(regularCanvases.prefix(maxVisibleDocuments))
    }

    var overflowCanvases: [Canvas] {
        Array(regularCanvases.dropFirst(maxVisibleDocuments))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main sidebar
            VStack(spacing: 0) {
                // Library header
                VStack(spacing: 12) {
                    // New Draft button - full width
                    Button {
                        appState.createNewCanvas()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("New Draft")
                                .font(MarginTypography.ui(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MarginColors.ink)
                        .foregroundColor(MarginColors.paper)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()

                    // Search bar - always visible, full width
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(MarginColors.stone400)

                        TextField("Search documents...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(MarginTypography.ui(size: 13))
                            .foregroundColor(MarginColors.ink)
                            .focused($isSearchFocused)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(MarginColors.stone300)
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(MarginColors.stone100.opacity(0.6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Document list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // Favorites section
                        if !favoriteCanvases.isEmpty {
                            SidebarSectionHeader(title: "FAVORITES")
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            ForEach(favoriteCanvases) { canvas in
                                DocumentRowView(
                                    canvas: canvas,
                                    isSelected: appState.currentCanvas?.id == canvas.id,
                                    action: {
                                        appState.selectCanvas(canvas)
                                    },
                                    onToggleFavorite: {
                                        appState.toggleFavorite(canvas)
                                    },
                                    onDuplicate: {
                                        appState.duplicateCanvas(canvas)
                                    },
                                    onDelete: {
                                        appState.deleteCanvas(canvas)
                                    }
                                )
                            }
                            .padding(.horizontal, 12)

                            Spacer().frame(height: 16)
                        }

                        // Documents section
                        SidebarSectionHeader(title: "DOCUMENTS")
                            .padding(.horizontal, 24)
                            .padding(.top, favoriteCanvases.isEmpty ? 8 : 0)

                        ForEach(visibleRegularCanvases) { canvas in
                            DocumentRowView(
                                canvas: canvas,
                                isSelected: appState.currentCanvas?.id == canvas.id,
                                action: {
                                    appState.selectCanvas(canvas)
                                },
                                onToggleFavorite: {
                                    appState.toggleFavorite(canvas)
                                },
                                onDuplicate: {
                                    appState.duplicateCanvas(canvas)
                                },
                                onDelete: {
                                    appState.deleteCanvas(canvas)
                                }
                            )
                        }
                        .padding(.horizontal, 12)

                        // "More" button if there are overflow documents
                        if !overflowCanvases.isEmpty {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showMorePanel.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("More")
                                        .font(MarginTypography.ui(size: 13, weight: .medium))
                                    Spacer()
                                    Text("\(overflowCanvases.count)")
                                        .font(MarginTypography.ui(size: 11))
                                        .foregroundColor(MarginColors.stone400)
                                }
                                .foregroundColor(MarginColors.stone500)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(showMorePanel ? MarginColors.stone100 : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 24)
                }

                Spacer()
                
                // Settings row
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showSettings = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MarginColors.stone500)
                        
                        Text("Settings")
                            .font(MarginTypography.ui(size: 13, weight: .medium))
                            .foregroundColor(MarginColors.stone600)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // User profile footer
                UserProfileFooter(showProfile: $showProfile)
            }
            .frame(width: 320)
            .background(MarginColors.stone50.opacity(0.3))
            .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
                // Toggle focus on the search field
                if isSearchFocused {
                    isSearchFocused = false
                    searchText = ""
                } else {
                    isSearchFocused = true
                }
            }
            .onExitCommand {
                if isSearchFocused || !searchText.isEmpty {
                    isSearchFocused = false
                    searchText = ""
                } else if showMorePanel {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showMorePanel = false
                    }
                }
            }

            // Expanded "More" panel
            if showMorePanel {
                MoreDocumentsPanel(
                    canvases: overflowCanvases,
                    selectedCanvasId: appState.currentCanvas?.id,
                    onSelect: { canvas in
                        appState.selectCanvas(canvas)
                    },
                    onToggleFavorite: { canvas in
                        appState.toggleFavorite(canvas)
                    },
                    onDuplicate: { canvas in
                        appState.duplicateCanvas(canvas)
                    },
                    onDelete: { canvas in
                        appState.deleteCanvas(canvas)
                    },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showMorePanel = false
                        }
                    }
                )
                .frame(width: 280)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Sidebar Section Header

struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MarginTypography.ui(size: 11, weight: .semibold))
            .tracking(2)
            .foregroundColor(MarginColors.stone400)
            .padding(.bottom, 8)
    }
}

// MARK: - User Profile Footer

struct UserProfileFooter: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showProfile: Bool

    private var userInitials: String {
        let name = appState.settings.userName
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "U"
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                showProfile = true
            }
        } label: {
            HStack(spacing: 12) {
                // Profile avatar
                Circle()
                    .fill(MarginColors.stone200)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(userInitials)
                            .font(MarginTypography.ui(size: 11, weight: .semibold))
                            .foregroundColor(MarginColors.stone600)
                    )

                // Name and plan
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.settings.userName)
                        .font(MarginTypography.ui(size: 13, weight: .medium))
                        .foregroundColor(MarginColors.ink)
                        .lineLimit(1)

                    Text(appState.settings.userPlan.displayName)
                        .font(MarginTypography.ui(size: 11))
                        .foregroundColor(MarginColors.stone400)
                }

                Spacer()

                // Settings chevron
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(MarginColors.stone300)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .overlay(alignment: .top) {
            MarginDivider()
        }
    }
}

// MARK: - More Documents Panel

struct MoreDocumentsPanel: View {
    let canvases: [Canvas]
    let selectedCanvasId: UUID?
    let onSelect: (Canvas) -> Void
    let onToggleFavorite: (Canvas) -> Void
    let onDuplicate: (Canvas) -> Void
    let onDelete: (Canvas) -> Void
    let onClose: () -> Void

    @State private var searchText = ""

    var filteredCanvases: [Canvas] {
        if searchText.isEmpty {
            return canvases
        }
        return canvases.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.plainText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("All Documents")
                    .font(MarginTypography.ui(size: 14, weight: .medium))
                    .foregroundColor(MarginColors.ink)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MarginColors.stone400)
                        .frame(width: 24, height: 24)
                        .background(MarginColors.stone100.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(MarginColors.stone300)

                TextField("Search for a page...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(MarginTypography.ui(size: 13))
                    .foregroundColor(MarginColors.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MarginColors.stone100.opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            MarginDivider()
                .padding(.horizontal, 16)

            // Document list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCanvases) { canvas in
                        MorePanelRowView(
                            canvas: canvas,
                            isSelected: selectedCanvasId == canvas.id,
                            onSelect: { onSelect(canvas) },
                            onToggleFavorite: { onToggleFavorite(canvas) },
                            onDuplicate: { onDuplicate(canvas) },
                            onDelete: { onDelete(canvas) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(MarginColors.paper)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MarginColors.stone200)
                .frame(width: 1)
        }
    }
}

// MARK: - More Panel Row View

struct MorePanelRowView: View {
    let canvas: Canvas
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var displayTitle: String {
        canvas.title.isEmpty ? "Untitled" : canvas.title
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(MarginColors.stone400)

                Text(displayTitle)
                    .font(MarginTypography.ui(size: 13))
                    .foregroundColor(MarginColors.ink)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? MarginColors.stone100 : (isHovered ? MarginColors.ink.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onToggleFavorite()
            } label: {
                Label(canvas.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: canvas.isFavorite ? "star.slash" : "star")
            }

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

struct DocumentRowView: View {
    let canvas: Canvas
    let isSelected: Bool
    let action: () -> Void
    let onToggleFavorite: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var menuButtonFrame: CGRect = .zero

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

                // Custom menu button
                Button {
                    showDocumentMenu()
                } label: {
                    Text("•••")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { menuButtonFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                menuButtonFrame = newFrame
                            }
                    }
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? MarginColors.stone100 : (isHovered ? MarginColors.ink.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private func showDocumentMenu() {
        DocumentRowMenuManager.shared.showMenu(
            at: menuButtonFrame,
            canvas: canvas,
            onToggleFavorite: onToggleFavorite,
            onDuplicate: onDuplicate,
            onDelete: onDelete
        )
    }
}

// MARK: - Document Row Menu Manager (NSWindow-based)

class DocumentRowMenuManager: NSObject {
    static let shared = DocumentRowMenuManager()

    private var menuWindow: NSWindow?
    private var eventMonitor: Any?
    private var currentCanvas: Canvas?
    private var onToggleFavorite: (() -> Void)?
    private var onDuplicate: (() -> Void)?
    private var onDelete: (() -> Void)?

    private override init() {
        super.init()
    }

    func showMenu(
        at buttonFrame: CGRect,
        canvas: Canvas,
        onToggleFavorite: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        // Dismiss any existing menu
        dismissMenu()

        self.currentCanvas = canvas
        self.onToggleFavorite = onToggleFavorite
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete

        // Create the menu content
        let menuView = DocumentRowMenuContent(
            isFavorite: canvas.isFavorite,
            onToggleFavorite: { [weak self] in
                self?.dismissMenu()
                onToggleFavorite()
            },
            onDuplicate: { [weak self] in
                self?.dismissMenu()
                onDuplicate()
            },
            onDelete: { [weak self] in
                self?.dismissMenu()
                onDelete()
            }
        )

        let hostingView = NSHostingView(rootView: menuView)
        hostingView.frame.size = hostingView.fittingSize

        // Make hosting view background transparent
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let menuWidth: CGFloat = hostingView.fittingSize.width
        let menuHeight: CGFloat = hostingView.fittingSize.height

        // Convert SwiftUI global coordinates to screen coordinates
        // SwiftUI uses top-left origin, AppKit uses bottom-left origin
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height

        // The content has 24pt padding for shadow, so adjust positioning
        let shadowPadding: CGFloat = 24

        // buttonFrame is in SwiftUI coordinates (top-left origin)
        // Convert to AppKit screen coordinates (bottom-left origin)
        let menuX = buttonFrame.maxX + 8 - shadowPadding
        let menuY = screenHeight - buttonFrame.midY - menuHeight / 2

        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.contentView = hostingView
        window.hasShadow = false // We draw our own shadow

        window.orderFront(nil)
        menuWindow = window

        // Add click-outside-to-dismiss monitor
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.menuWindow else { return event }

            let clickLocation = event.locationInWindow
            let windowFrame = window.frame

            // Convert click to screen coordinates
            let screenLocation: NSPoint
            if let eventWindow = event.window {
                screenLocation = eventWindow.convertPoint(toScreen: clickLocation)
            } else {
                screenLocation = clickLocation
            }

            // Check if click is outside menu
            if !windowFrame.contains(screenLocation) {
                self.dismissMenu()
            }

            return event
        }
    }

    func dismissMenu() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        menuWindow?.orderOut(nil)
        menuWindow = nil
        currentCanvas = nil
        onToggleFavorite = nil
        onDuplicate = nil
        onDelete = nil
    }
}

// MARK: - Document Row Menu Content (SwiftUI view for NSWindow)

struct DocumentRowMenuContent: View {
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var hoveredItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Favorite action
            DocumentMenuRow(
                icon: isFavorite ? "star.slash" : "star",
                title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                isHovered: hoveredItem == "favorite",
                action: onToggleFavorite
            )
            .onHover { hoveredItem = $0 ? "favorite" : nil }

            // Duplicate action
            DocumentMenuRow(
                icon: "doc.on.doc",
                title: "Duplicate",
                isHovered: hoveredItem == "duplicate",
                action: onDuplicate
            )
            .onHover { hoveredItem = $0 ? "duplicate" : nil }

            // Divider
            Rectangle()
                .fill(MarginColors.stone200.opacity(0.6))
                .frame(height: 1)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)

            // Delete action
            DocumentMenuRow(
                icon: "trash",
                title: "Delete",
                isDestructive: true,
                isHovered: hoveredItem == "delete",
                action: onDelete
            )
            .onHover { hoveredItem = $0 ? "delete" : nil }
        }
        .padding(.vertical, 8)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "FAF9F7")) // Warm off-white matching floating toolbar
        )
        // Multi-layer shadow system (matching floating toolbar & layout mode picker)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.05), radius: 0, x: 0, y: 0)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.04), radius: 6, x: 0, y: 4)
        .shadow(color: Color(hex: "1C1C1E").opacity(0.08), radius: 18, x: 0, y: 12)
        // Add padding for shadow to render outside content bounds
        .padding(24)
    }
}

// MARK: - Document Menu Row

struct DocumentMenuRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    var isHovered: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : MarginColors.stone500)
                    .frame(width: 18)
                
                Text(title)
                    .font(MarginTypography.ui(size: 13, weight: .medium))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.9) : MarginColors.ink)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? MarginColors.stone100 : Color.clear)
            )
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .pointerCursor()
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
                .pointerCursor()
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
                
                // Editor Appearance section
                SettingsSection(title: "EDITOR APPEARANCE") {
                    VStack(alignment: .leading, spacing: 24) {
                        // Typography label
                        Text("Typography")
                            .font(MarginTypography.ui(size: 15, weight: .semibold))
                            .foregroundColor(MarginColors.ink)
                        
                        // Typography cards - horizontal layout
                        HStack(spacing: 16) {
                            // Editorial Serif card
                            TypographyCard(
                                title: "Editorial Serif",
                                description: "Classic, rhythmic, Newsreader & Instrument.",
                                titleFont: .custom("Georgia-Italic", size: 24),
                                isSelected: appState.settings.defaultTypeSystem == .editorialSerif
                            ) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    appState.settings.defaultTypeSystem = .editorialSerif
                                }
                            }
                            
                            // Modern Sans card
                            TypographyCard(
                                title: "Modern Sans",
                                description: "Clean, objective, Inter UI system.",
                                titleFont: .system(size: 22, weight: .bold),
                                isSelected: appState.settings.defaultTypeSystem == .modernSans
                            ) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    appState.settings.defaultTypeSystem = .modernSans
                                }
                            }
                        }
                        
                        // Base Font Size slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Base Font Size")
                                        .font(MarginTypography.ui(size: 14, weight: .medium))
                                        .foregroundColor(MarginColors.ink)
                                    Text("Adjust readability for your display")
                                        .font(MarginTypography.ui(size: 12))
                                        .foregroundColor(MarginColors.stone400)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Slider(value: $appState.settings.baseFontSize, in: 14...28, step: 1)
                                        .frame(width: 180)
                                        .tint(MarginColors.ink)
                                    Text("\(Int(appState.settings.baseFontSize))px")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(MarginColors.stone500)
                                        .frame(width: 45, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.top, 8)
                        
                        // Line Height slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Line Height")
                                        .font(MarginTypography.ui(size: 14, weight: .medium))
                                        .foregroundColor(MarginColors.ink)
                                    Text("The vertical rhythm of your paragraphs")
                                        .font(MarginTypography.ui(size: 12))
                                        .foregroundColor(MarginColors.stone400)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Slider(value: $appState.settings.lineHeightMultiple, in: 1.2...2.2, step: 0.05)
                                        .frame(width: 180)
                                        .tint(MarginColors.ink)
                                    Text(String(format: "%.2f", appState.settings.lineHeightMultiple))
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(MarginColors.stone500)
                                        .frame(width: 45, alignment: .trailing)
                                }
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
        .pointerCursor()
    }
}

// MARK: - Typography Card (Settings)

struct TypographyCard: View {
    let title: String
    let description: String
    let titleFont: Font
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(MarginColors.ink)
                
                Text(description)
                    .font(MarginTypography.ui(size: 13))
                    .foregroundColor(MarginColors.stone400)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(MarginColors.paper)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? MarginColors.stone400 : MarginColors.stone200,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Color.black.opacity(0.04) : Color.clear, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Profile Modal Overlay

struct ProfileModalOverlay: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    @Binding var showSettings: Bool

    // Animation state
    @State private var modalScale: CGFloat = 0.95
    @State private var modalOpacity: Double = 0
    @State private var hoveredItem: String?

    private var userInitials: String {
        let name = appState.settings.userName
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "U"
    }

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
                // Header with close button
                HStack {
                    Spacer()
                    Button {
                        dismissModal()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MarginColors.stone400)
                            .frame(width: 28, height: 28)
                            .background(MarginColors.stone100.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Profile info
                VStack(spacing: 16) {
                    // Avatar
                    Circle()
                        .fill(MarginColors.stone200)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text(userInitials)
                                .font(MarginTypography.ui(size: 20, weight: .semibold))
                                .foregroundColor(MarginColors.stone600)
                        )

                    // Name and plan
                    VStack(spacing: 4) {
                        Text(appState.settings.userName)
                            .font(MarginTypography.ui(size: 17, weight: .semibold))
                            .foregroundColor(MarginColors.ink)

                        Text(appState.settings.userPlan.displayName)
                            .font(MarginTypography.ui(size: 13))
                            .foregroundColor(MarginColors.stone400)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Upgrade button (only for free plan)
                if appState.settings.userPlan == .free {
                    Button {
                        // TODO: Open upgrade flow
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                            Text("Upgrade to Pro")
                                .font(MarginTypography.ui(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(MarginColors.ink)
                        .foregroundColor(MarginColors.paper)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // Divider
                MarginDivider()
                    .padding(.horizontal, 24)

                // Menu items
                VStack(spacing: 0) {
                    // Keyboard Shortcuts
                    ProfileMenuRow(
                        icon: "command",
                        title: "Keyboard Shortcuts",
                        isHovered: hoveredItem == "shortcuts"
                    ) {
                        // TODO: Show keyboard shortcuts
                    }
                    .onHover { hoveredItem = $0 ? "shortcuts" : nil }

                    // Settings
                    ProfileMenuRow(
                        icon: "gearshape",
                        title: "Settings",
                        isHovered: hoveredItem == "settings"
                    ) {
                        dismissModal()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showSettings = true
                            }
                        }
                    }
                    .onHover { hoveredItem = $0 ? "settings" : nil }
                }
                .padding(.vertical, 8)

                // Divider
                MarginDivider()
                    .padding(.horizontal, 24)

                // Sign out
                VStack(spacing: 0) {
                    ProfileMenuRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        isHovered: hoveredItem == "signout"
                    ) {
                        // TODO: Sign out action
                    }
                    .onHover { hoveredItem = $0 ? "signout" : nil }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 12)
            }
            .frame(width: 280)
            .background(MarginColors.paper)
            .cornerRadius(16)
            .shadow(color: MarginColors.ink.opacity(0.15), radius: 40, x: 0, y: 20)
            .shadow(color: MarginColors.ink.opacity(0.1), radius: 10, x: 0, y: 5)
            .scaleEffect(modalScale)
            .opacity(modalOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                modalScale = 1.0
                modalOpacity = 1.0
            }
        }
        .onExitCommand {
            dismissModal()
        }
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

// MARK: - Profile Menu Row

struct ProfileMenuRow: View {
    let icon: String
    let title: String
    var isHovered: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(MarginColors.stone500)
                    .frame(width: 20)

                Text(title)
                    .font(MarginTypography.ui(size: 14, weight: .medium))
                    .foregroundColor(MarginColors.ink)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MarginColors.stone300)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? MarginColors.stone100 : Color.clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .pointerCursor()
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
                    .pointerCursor()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // EDITOR APPEARANCE Section
                        SettingsModalSection(title: "EDITOR APPEARANCE") {
                            VStack(alignment: .leading, spacing: 24) {
                                // Typography label
                                Text("Typography")
                                    .font(MarginTypography.ui(size: 15, weight: .semibold))
                                    .foregroundColor(MarginColors.ink)
                                
                                // Typography cards - horizontal layout (instant apply like Notion)
                                HStack(spacing: 16) {
                                    // Editorial Serif card
                                    TypographyOptionCard(
                                        title: "Editorial Serif",
                                        description: "Classic, rhythmic, Newsreader & Instrument.",
                                        titleFont: .custom("Georgia-Italic", size: 24),
                                        isSelected: appState.settings.defaultTypeSystem == .editorialSerif
                                    ) {
                                        appState.settings.defaultTypeSystem = .editorialSerif
                                    }
                                    
                                    // Modern Sans card
                                    TypographyOptionCard(
                                        title: "Modern Sans",
                                        description: "Clean, objective, Inter UI system.",
                                        titleFont: .system(size: 22, weight: .bold),
                                        isSelected: appState.settings.defaultTypeSystem == .modernSans
                                    ) {
                                        appState.settings.defaultTypeSystem = .modernSans
                                    }
                                }
                                .frame(height: 120) // Fixed height for both cards
                                
                                // Base Font Size slider (instant apply)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Base Font Size")
                                                .font(MarginTypography.ui(size: 14, weight: .medium))
                                                .foregroundColor(MarginColors.ink)
                                            Text("Adjust readability for your display")
                                                .font(MarginTypography.ui(size: 12))
                                                .foregroundColor(MarginColors.stone400)
                                        }
                                        Spacer()
                                        HStack(spacing: 12) {
                                            SettingsSlider(value: $appState.settings.baseFontSize, range: 14...28)
                                                .frame(width: 180)
                                            Text("\(Int(appState.settings.baseFontSize))px")
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                .foregroundColor(MarginColors.stone500)
                                                .frame(width: 45, alignment: .trailing)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                
                                // Line Height slider (instant apply)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Line Height")
                                                .font(MarginTypography.ui(size: 14, weight: .medium))
                                                .foregroundColor(MarginColors.ink)
                                            Text("The vertical rhythm of your paragraphs")
                                                .font(MarginTypography.ui(size: 12))
                                                .foregroundColor(MarginColors.stone400)
                                        }
                                        Spacer()
                                        HStack(spacing: 12) {
                                            SettingsSlider(value: $appState.settings.lineHeightMultiple, range: 1.2...2.2, step: 0.05)
                                                .frame(width: 180)
                                            Text(String(format: "%.2f", appState.settings.lineHeightMultiple))
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                .foregroundColor(MarginColors.stone500)
                                                .frame(width: 45, alignment: .trailing)
                                        }
                                    }
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
                    .pointerCursor()
                    
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
                        .pointerCursor()
                        
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
                        .pointerCursor()
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
        stagedFontSize = appState.settings.baseFontSize
        stagedLineHeight = appState.settings.lineHeightMultiple
    }
    
    private func saveChanges() {
        // Settings are now applied instantly via direct bindings
        // Just dismiss the modal
        dismissModal()
    }
    
    private func resetToDefaults() {
        // Reset to default values (applies instantly)
        appState.settings.defaultTypeSystem = .editorialSerif
        appState.settings.baseFontSize = 18.0
        appState.settings.lineHeightMultiple = 1.65
        stagedInterfaceTheme = .light
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

// MARK: - Typography Option Card

struct TypographyOptionCard: View {
    let title: String
    let description: String
    let titleFont: Font
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(MarginColors.ink)
                
                Text(description)
                    .font(MarginTypography.ui(size: 13))
                    .foregroundColor(MarginColors.stone400)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(24)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isPressed = false
                    }
                }
        )
    }
    
    private var backgroundColor: Color {
        if isPressed {
            return MarginColors.stone100
        } else if isHovered {
            return MarginColors.stone50.opacity(0.5)
        } else {
            return MarginColors.paper
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return MarginColors.stone500
        } else if isHovered {
            return MarginColors.stone300
        } else {
            return MarginColors.stone200
        }
    }
    
    private var shadowColor: Color {
        if isSelected {
            return Color.black.opacity(0.06)
        } else if isHovered {
            return Color.black.opacity(0.03)
        } else {
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 8 : (isHovered ? 4 : 0)
    }
    
    private var shadowY: CGFloat {
        isSelected ? 2 : (isHovered ? 1 : 0)
    }
}

// MARK: - Settings Slider (Custom styled with dark track and thumb)

struct SettingsSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var step: CGFloat = 1.0
    
    // Local state for smooth dragging without re-renders
    @State private var localValue: CGFloat? = nil
    @State private var isDragging = false
    
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 16
    
    // Use local value during drag, otherwise use binding
    private var displayValue: CGFloat {
        localValue ?? value
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let normalizedValue = (displayValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = normalizedValue * (width - thumbSize)
            
            ZStack(alignment: .leading) {
                // Track background (dark gray)
                Capsule()
                    .fill(Color(red: 0.75, green: 0.75, blue: 0.73)) // stone300 equivalent
                    .frame(height: trackHeight)
                
                // Track fill (darker gray, left of thumb)
                Capsule()
                    .fill(Color(red: 0.55, green: 0.55, blue: 0.52)) // stone500 equivalent
                    .frame(width: max(0, thumbX + thumbSize / 2), height: trackHeight)
                
                // Thumb (black circle)
                Circle()
                    .fill(MarginColors.ink)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, thumbX))
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: isDragging)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newX = gesture.location.x
                        let clampedX = max(0, min(newX, width))
                        let normalizedX = clampedX / width
                        let rawValue = range.lowerBound + normalizedX * (range.upperBound - range.lowerBound)
                        
                        // Snap to step
                        let steppedValue = round(rawValue / step) * step
                        localValue = max(range.lowerBound, min(range.upperBound, steppedValue))
                    }
                    .onEnded { _ in
                        isDragging = false
                        // Commit the final value to the binding
                        if let finalValue = localValue {
                            print("[Slider] Committing value: \(finalValue)")
                            value = finalValue
                        }
                        localValue = nil
                    }
            )
        }
        .frame(height: thumbSize)
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
