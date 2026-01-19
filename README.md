# Margin

A minimal, intentional writing environment for macOS.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Philosophy

Margin is built on the belief that great writing needs space to breathe. In a world of cluttered interfaces and constant notifications, Margin offers a sanctuary for focused thought.

## Features

### 🎨 Editorial Typography
- **Instrument Serif** for display headings
- **Newsreader** for body text
- **Georgia** fallback for maximum compatibility
- Multiple typography systems to match your style

### 📐 Intentional Layouts
- **Essay Mode** (700px) — For long-form writing
- **Brief Mode** (800px) — For reports and documents  
- **Scratch Mode** (900px) — For freeform notes

### ✍️ Rich Text Editing
- Notion-style heading shortcuts (⌥⌘1, ⌥⌘2, ⌥⌘3)
- Bold, italic, and inline formatting
- Clean, distraction-free canvas

### 🤖 AI Assistance (Optional)
- On-demand editorial help via slash commands
- Supports OpenAI and Anthropic APIs
- Privacy-first: your words stay local unless you ask for help

### 💾 Local-First Storage
- All documents saved locally
- No cloud sync, no accounts required
- Your thoughts remain yours

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/margin.git
   cd margin
   ```

2. Open in Xcode:
   ```bash
   open margin-files/margin-files.xcodeproj
   ```

3. Build and run (⌘R)

## Project Structure

```
margin-files/
├── margin-files/
│   ├── MarginApp.swift          # App entry point
│   ├── ContentView.swift        # Main layout & views
│   ├── EditorialCanvasView.swift # Writing canvas
│   ├── RichTextEditor.swift     # NSTextView wrapper
│   ├── DesignSystem.swift       # Colors, typography, components
│   ├── AppState.swift           # Global app state
│   ├── AppSettings.swift        # User preferences
│   ├── Canvas.swift             # Document model
│   ├── StorageManager.swift     # Local persistence
│   ├── AIService.swift          # AI integration
│   ├── TypeSystem.swift         # Typography definitions
│   └── LayoutMode.swift         # Layout configurations
└── README.md
```

## Architecture

Margin follows a clean SwiftUI architecture:

- **Views** — Pure SwiftUI with `NSViewRepresentable` for rich text
- **State** — `@EnvironmentObject` for global app state
- **Models** — Simple structs for documents and settings
- **Services** — Isolated services for storage and AI

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Draft | ⌘N |
| Heading 1 | ⌥⌘1 |
| Heading 2 | ⌥⌘2 |
| Heading 3 | ⌥⌘3 |
| Body Text | ⌥⌘0 |
| Bold | ⌘B |
| Italic | ⌘I |
| Toggle Library | ⇧⌘L |
| Toggle AI Panel | ⇧⌘A |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with intention. Write with margin.*
