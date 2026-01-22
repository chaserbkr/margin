# Margin Product Context

> A minimal, intentional writing environment for macOS

## Product Vision

Margin is a native macOS writing application designed for focused, long-form writing. It prioritizes intentionality over features, offering a distraction-free environment that treats writing as a craft. The app embraces a local-first philosophy—no accounts, no cloud sync, no subscriptions—just you and your words.

---

## Core Philosophy

### Local-First Privacy
- All documents stored locally in `~/Library/Application Support/Margin/`
- No cloud sync, no accounts, no tracking
- API keys for optional AI features stored securely in macOS Keychain
- Users own their data completely

### Intentional Design
- Minimal UI that stays out of the way
- Editorial aesthetic with refined typography
- Considered constraints that encourage focused writing
- No feature bloat—every capability serves the core writing experience

---

## Architecture Overview

### Technology Stack
- **Framework**: SwiftUI with NSView integration for advanced text editing
- **Text Engine**: Custom `EditorialNSTextView` (NSTextView subclass)
- **Storage**: JSON files + PNG images in Application Support
- **State Management**: Observable objects with SwiftUI bindings

### File Structure
```
~/Library/Application Support/Margin/
├── Canvases/           # JSON document files
│   └── {UUID}.json     # Individual documents
└── Images/             # Image assets
    └── {canvasID}_{imageID}.png
```

### Core Files
| File | Purpose |
|------|---------|
| `MarginApp.swift` | App entry point, menu commands, keyboard shortcuts |
| `AppState.swift` | Central state management, document lifecycle |
| `AppSettings.swift` | User preferences, AI provider config, Keychain access |
| `Canvas.swift` | Document model, media blocks, attributed content |
| `ContentView.swift` | Main window layout, panels, toolbars |
| `EditorialCanvasView.swift` | Writing canvas, text editor container |
| `RichTextEditor.swift` | Custom NSTextView with rich formatting |
| `LayoutMode.swift` | Write/Plan mode definitions and capabilities |
| `TypeSystem.swift` | Typography system definitions |
| `DesignSystem.swift` | Colors, spacing, visual components |
| `StorageManager.swift` | File persistence, image management |
| `AIService.swift` | AI integration (OpenAI, Anthropic) |

---

## Document Model

### Canvas
The core document unit containing:
- **Content**: Attributed text with rich formatting
- **Media**: Inline images, image piles, floating images
- **Layout Mode**: Write or Plan
- **Type System**: Typography selection
- **Metadata**: Timestamps, word count

### Media Types

#### Inline Media Blocks
Images embedded in document flow:
- Adjustable width (15-100% of page)
- Three wrap styles: Block, Wrap Left, Wrap Right
- Caption support
- Maintains aspect ratio

#### Image Piles
Multiple images stacked as a carousel:
- Carousel navigation (prev/next)
- Dot indicators showing position
- Created by dropping image onto image
- 25-100% display width

#### Floating Images
Absolutely positioned images with text reflow:
- Text flows around image bounds
- 8-point resize handles
- Drag to reposition
- Supports pile creation
- Full undo/redo support

#### Freeform Canvas Objects (Plan Mode only)
- Sticky notes (yellow background)
- Text boxes (bordered containers)
- Image objects
- Z-index stacking

---

## Layout Modes

### Write Mode (Default)
**Purpose**: Focused editorial writing

| Property | Value |
|----------|-------|
| Max Width | 680px |
| Horizontal Padding | 80px |
| Top Padding | 80px |
| Line Height | 1.6x |
| Paragraph Spacing | 1.5x |

**Capabilities**:
- Full rich text editing
- Inline media with text wrapping
- Image resize and reorder
- Block-level drag & drop

### Plan Mode
**Purpose**: Spatial thinking and exploration

| Property | Value |
|----------|-------|
| Max Width | 680px (fixed page) |
| Horizontal Padding | 40px |
| Top Padding | 40px |
| Line Height | 1.5x |
| Paragraph Spacing | 1.4x |

**Capabilities**:
- Document rendered as locked page
- Freeform canvas behind document
- Sticky notes and text boxes
- Dot grid background
- Image piles allowed

---

## Typography System

Four distinct type systems, each with complete styling:

### Editorial Serif (Default)
- **Body**: Georgia, 19px
- **Heading**: Georgia Bold, 28px
- **Character**: Classic, refined, long-form focus

### Modern Sans
- **Body**: SF Pro (system), 19px
- **Heading**: SF Pro Semibold, 28px
- **Character**: Clean, contemporary

### Technical Mono
- **Body**: System Monospace, 14px
- **Heading**: System Mono Bold, 24px
- **Character**: Precise, structured

### Humanist Sans
- **Body**: Avenir Next, 19px
- **Heading**: Avenir Next Bold, 28px
- **Character**: Warm, approachable

Each system includes:
- Body font
- Heading font (H1)
- Subheading font (H2, H3)
- Caption font
- Paragraph styles with line height and spacing

---

## Design System

### Color Palette

#### Core
- **Paper**: `#FDFCF8` (warm off-white background)
- **Ink**: `#1C1C1E` (near-black text)

#### Stone Scale (Warm Grays)
- stone50: `#FBFBF9`
- stone100: `#F5F5F0`
- stone200: `#E6E6E0`
- stone300: `#D4D4CD`
- stone400: `#A3A39C`
- stone500: `#73736D`
- stone600: `#52524D`
- stone800: `#2E2E2C`
- stone900: `#1C1C1E`

#### Purple Accent (AI Features)
- purple50: `#FAF5FF`
- purple500: `#A855F7`
- purple600: `#9333EA`

### Spacing Scale
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px
- xxl: 48px
- xxxl: 64px

### UI Components
- **Header Bar**: 44px height, status/library/AI/settings buttons
- **Library Sidebar**: 320px width, collapsible
- **AI Panel**: 360px width, collapsible
- **Floating Toolbar**: Left side, type system quick access
- **Layout Mode Picker**: Floating pill, bottom center

---

## Text Formatting

### Available Styles
- **Bold** (Cmd+B)
- **Italic** (Cmd+I)
- **Heading 1** (Cmd+Option+1)
- **Heading 2** (Cmd+Option+2)
- **Heading 3** (Cmd+Option+3)
- **Body** (Cmd+Option+0)
- Links

### Text Features
- Smart quote substitution
- Smart dash substitution
- Continuous spell checking
- Undo/redo with full history
- Placeholder text ("Start writing...")

---

## AI Assistance (Optional)

### Providers
- **OpenAI**: GPT-4 Turbo
- **Anthropic**: Claude 3 Sonnet

### Commands
| Command | Purpose |
|---------|---------|
| Summarize | Create a concise summary |
| Create Outline | Generate structured outline |
| Rewrite for Clarity | Improve clarity and readability |
| Rewrite Calmly | Soften tone, reduce urgency |
| Extract Decisions | Pull out key decisions |
| Identify Next Steps | List actionable next steps |

### Privacy Model
- AI is optional and disabled by default
- Only operates on selected text
- API keys stored in Keychain
- No data sent without explicit action

---

## Keyboard Shortcuts

### Document
| Shortcut | Action |
|----------|--------|
| Cmd+N | New Draft |
| Cmd+S | Save (auto-save enabled) |

### Formatting
| Shortcut | Action |
|----------|--------|
| Cmd+B | Bold |
| Cmd+I | Italic |
| Cmd+Option+1 | Heading 1 |
| Cmd+Option+2 | Heading 2 |
| Cmd+Option+3 | Heading 3 |
| Cmd+Option+0 | Body Text |

### Panels
| Shortcut | Action |
|----------|--------|
| Cmd+Shift+L | Toggle Library |
| Cmd+Shift+A | Toggle AI Panel |
| Escape | Close menus/modals |

---

## Document Metadata

Each document tracks:
- **Word Count**: Calculated from plain text
- **Reading Time**: Estimated at 200 WPM
- **Created At**: ISO8601 timestamp
- **Updated At**: ISO8601 timestamp
- **Draft Version**: Visual indicator ("DRAFT 03")

---

## Storage & Persistence

### Auto-Save
- Triggers after 30 seconds of inactivity
- Atomic writes for data safety
- JSON with pretty printing for debugging

### Canvas Format
```json
{
  "id": "UUID",
  "title": "Document Title",
  "content": {
    "plainText": "...",
    "attributeRuns": [...]
  },
  "mediaBlocks": [...],
  "floatingImages": [...],
  "canvasObjects": [...],
  "layoutMode": "write",
  "typeSystem": "editorialSerif",
  "enableTextWrapping": false,
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T14:45:00Z"
}
```

### Backward Compatibility
- Legacy `inlineMediaBlocks` automatically migrated to `mediaBlocks`
- Legacy layout mode values (`essay`, `brief`, `scratch`) mapped to current modes
- New fields added with defaults for older documents

---

## UI/UX Patterns

### Panel Navigation
- Sidebars slide in/out with spring animation
- Left: Document library with search
- Right: AI assistant panel

### Document Selection
- List sorted by last modified
- Hover states for actions (duplicate, delete)
- Search filters by title and content

### Image Interaction
- Drag & drop to insert
- Drop on image to create pile
- Resize handles on selection
- Visual feedback during operations

### Animations
- Duration: 0.15s - 0.3s
- Easing: ease-out
- Scale effects on buttons
- Opacity transitions for panels

---

## Notable Design Decisions

1. **NSTextView over SwiftUI Text**: Required for proper rich text editing, selection, and undo support

2. **WKWebView for Image Piles**: JavaScript-based carousel for smooth interaction within the native app

3. **Local-Only Storage**: Intentional decision for privacy and simplicity—no sync complexity

4. **Constrained Layout Modes**: Only two modes (Write/Plan) to prevent feature creep while covering key use cases

5. **Fixed Type Systems**: Complete typography packages rather than individual font/size pickers—encourages consistency

6. **Optional AI**: Privacy-conscious design with AI as an opt-in enhancement, not a core dependency

---

## Future Considerations

When extending Margin, maintain these principles:
- **Simplicity over features**: Every addition should justify its complexity
- **Local-first**: Avoid features requiring accounts or cloud services
- **Editorial quality**: Typography and layout should feel refined
- **Privacy by default**: Never send data without explicit user action
- **Native experience**: Leverage macOS capabilities, avoid web-like patterns
