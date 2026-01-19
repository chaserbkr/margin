import SwiftUI
import AppKit

// MARK: - Margin Design System
// Based on the editorial design aesthetic

enum MarginColors {
    // Core palette
    static let paper = Color(hex: "FDFCF8")
    static let ink = Color(hex: "1C1C1E")

    // NSColor versions for AppKit
    static let inkNS = NSColor(red: 0x1C/255.0, green: 0x1C/255.0, blue: 0x1E/255.0, alpha: 1.0)
    static let paperNS = NSColor(red: 0xFD/255.0, green: 0xFC/255.0, blue: 0xF8/255.0, alpha: 1.0)
    
    // Stone scale (warm grays)
    static let stone50 = Color(hex: "FBFBF9")
    static let stone100 = Color(hex: "F5F5F0")
    static let stone200 = Color(hex: "E6E6E0")
    static let stone300 = Color(hex: "D4D4CD")
    static let stone400 = Color(hex: "A3A39C")
    static let stone500 = Color(hex: "73736D")
    static let stone600 = Color(hex: "52524D")
    static let stone800 = Color(hex: "2E2E2C")
    static let stone900 = Color(hex: "1C1C1E")
    
    // Accent colors
    static let purple50 = Color(hex: "FAF5FF")
    static let purple100 = Color(hex: "F3E8FF")
    static let purple200 = Color(hex: "E9D5FF")
    static let purple400 = Color(hex: "C084FC")
    static let purple500 = Color(hex: "A855F7")
    static let purple600 = Color(hex: "9333EA")
    static let purple700 = Color(hex: "7C3AED")
    static let purple900 = Color(hex: "581C87")
    
    // macOS window controls
    static let windowClose = Color(hex: "FF5F57")
    static let windowMinimize = Color(hex: "FEBC2E")
    static let windowZoom = Color(hex: "28C840")
    
    // Desktop background
    static let desktopBg = Color(hex: "F2F0EB")
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

enum MarginTypography {
    // Display - Instrument Serif
    static func display(size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size)
    }

    static func displayFont(size: CGFloat) -> NSFont {
        NSFont(name: "InstrumentSerif-Regular", size: size) ?? NSFont.systemFont(ofSize: size)
    }
    
    // Body - Newsreader (fallback to Georgia)
    static func body(size: CGFloat) -> Font {
        .custom("Newsreader", size: size)
    }
    
    static func bodyFont(size: CGFloat) -> NSFont {
        NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
    }
    
    // UI - Inter (fallback to system)
    static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    
    static func uiFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
    
    // Mono - JetBrains Mono (fallback to system mono)
    static func mono(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - Spacing & Layout

enum MarginSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    
    // Canvas widths for different modes
    static let essayWidth: CGFloat = 700
    static let briefWidth: CGFloat = 800
    static let scratchWidth: CGFloat = 900
}

// MARK: - Shadows

extension View {
    func softShadow() -> some View {
        self.shadow(color: MarginColors.ink.opacity(0.05), radius: 10, x: 0, y: 4)
            .shadow(color: MarginColors.ink.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    func floatShadow() -> some View {
        self.shadow(color: MarginColors.ink.opacity(0.08), radius: 18, x: 0, y: 12)
            .shadow(color: MarginColors.ink.opacity(0.04), radius: 6, x: 0, y: 4)
    }
}

// MARK: - Button Styles

struct MarginPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MarginTypography.ui(size: 13, weight: .medium))
            .foregroundColor(MarginColors.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MarginColors.ink)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MarginSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MarginTypography.ui(size: 13, weight: .medium))
            .foregroundColor(MarginColors.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MarginColors.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(MarginColors.stone200, lineWidth: 1)
            )
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MarginIconButtonStyle: ButtonStyle {
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(isActive ? MarginColors.stone100 : Color.clear)
            .foregroundColor(isActive ? MarginColors.ink : MarginColors.stone500)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Layout Mode Pill

struct LayoutModePicker: View {
    @Binding var mode: LayoutMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(LayoutMode.allCases, id: \.self) { layoutMode in
                LayoutModeButton(
                    layoutMode: layoutMode,
                    isSelected: mode == layoutMode
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = layoutMode
                    }
                }
            }
        }
        .padding(3)
        .background(MarginColors.stone100.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MarginColors.stone200.opacity(0.5), lineWidth: 1)
        )
    }
}

struct LayoutModeButton: View {
    let layoutMode: LayoutMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(layoutMode.displayName)
                .font(MarginTypography.ui(size: 11, weight: .medium))
                .foregroundColor(isSelected ? MarginColors.ink : MarginColors.stone500)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? MarginColors.paper : Color.clear)
                        .shadow(color: isSelected ? MarginColors.ink.opacity(0.05) : .clear, radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window Controls (Decorative)

struct WindowControlsView: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(MarginColors.windowClose)
                .frame(width: 12, height: 12)
            Circle()
                .fill(MarginColors.windowMinimize)
                .frame(width: 12, height: 12)
            Circle()
                .fill(MarginColors.windowZoom)
                .frame(width: 12, height: 12)
        }
        .opacity(0.6)
    }
}

// MARK: - Divider

struct MarginDivider: View {
    var vertical: Bool = false
    
    var body: some View {
        if vertical {
            Rectangle()
                .fill(MarginColors.stone200)
                .frame(width: 1)
        } else {
            Rectangle()
                .fill(MarginColors.stone100)
                .frame(height: 1)
        }
    }
}
