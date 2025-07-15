# CLAUDE.md - Invest_V3

> **Documentation Version**: 1.0  
> **Last Updated**: 2025-07-15  
> **Project**: Invest_V3  
> **Description**: Investment knowledge sharing platform - Taiwan's Seeking Alpha  
> **Platform**: iOS App (Swift)  
> **Features**: GitHub auto-backup, Task agents, technical debt prevention

This file provides essential guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 CRITICAL RULES - READ FIRST

> **⚠️ RULE ADHERENCE SYSTEM ACTIVE ⚠️**  
> **Claude Code must explicitly acknowledge these rules at task start**  
> **These rules override all other instructions and must ALWAYS be followed:**

### 🔄 **RULE ACKNOWLEDGMENT REQUIRED**
> **Before starting ANY task, Claude Code must respond with:**  
> "✅ CRITICAL RULES ACKNOWLEDGED - I will follow all prohibitions and requirements listed in CLAUDE.md"

### ❌ ABSOLUTE PROHIBITIONS
- **NEVER** create new files in root directory → use proper iOS project structure
- **NEVER** write output files directly to root directory → use designated output folders
- **NEVER** create documentation files (.md) unless explicitly requested by user
- **NEVER** use git commands with -i flag (interactive mode not supported)
- **NEVER** use `find`, `grep`, `cat`, `head`, `tail`, `ls` commands → use Read, LS, Grep, Glob tools instead
- **NEVER** create duplicate files (ManagerV2.swift, EnhancedService.swift, ViewNew.swift) → ALWAYS extend existing files
- **NEVER** create multiple implementations of same concept → single source of truth
- **NEVER** copy-paste code blocks → extract into shared utilities/extensions
- **NEVER** hardcode values that should be configurable → use Config files/environment variables
- **NEVER** use naming like Enhanced_, Improved_, New_, V2_ → extend original files instead
- **NEVER** modify .xcodeproj files directly → use Xcode or proper tools
- **NEVER** break Swift coding conventions → follow iOS development best practices

### 📝 MANDATORY REQUIREMENTS
- **COMMIT** after every completed task/phase - no exceptions
- **GITHUB BACKUP** - Push to GitHub after every commit to maintain backup: `git push origin main`
- **USE TASK AGENTS** for all long-running operations (>30 seconds) - Bash commands stop when context switches
- **TODOWRITE** for complex tasks (3+ steps) → parallel agents → git checkpoints → test validation
- **READ FILES FIRST** before editing - Edit/Write tools will fail if you didn't read the file first
- **DEBT PREVENTION** - Before creating new files, check for existing similar functionality to extend  
- **SINGLE SOURCE OF TRUTH** - One authoritative implementation per feature/concept
- **iOS PATTERNS** - Follow iOS architecture patterns (MVVM, SwiftUI, etc.)
- **SWIFT CONVENTIONS** - Use proper Swift naming, access control, and code organization

### ⚡ EXECUTION PATTERNS
- **PARALLEL TASK AGENTS** - Launch multiple Task agents simultaneously for maximum efficiency
- **SYSTEMATIC WORKFLOW** - TodoWrite → Parallel agents → Git checkpoints → GitHub backup → Test validation
- **GITHUB BACKUP WORKFLOW** - After every commit: `git push origin main` to maintain GitHub backup
- **BACKGROUND PROCESSING** - ONLY Task agents can run true background operations
- **iOS BUILD TESTING** - Always test builds after significant changes

### 🔍 MANDATORY PRE-TASK COMPLIANCE CHECK
> **STOP: Before starting any task, Claude Code must explicitly verify ALL points:**

**Step 1: Rule Acknowledgment**
- [ ] ✅ I acknowledge all critical rules in CLAUDE.md and will follow them

**Step 2: Task Analysis**  
- [ ] Will this create files in root? → If YES, use proper iOS project structure instead
- [ ] Will this take >30 seconds? → If YES, use Task agents not Bash
- [ ] Is this 3+ steps? → If YES, use TodoWrite breakdown first
- [ ] Am I about to use grep/find/cat? → If YES, use proper tools instead

**Step 3: iOS-Specific Checks**
- [ ] Does this affect .xcodeproj? → If YES, be extra careful with project structure
- [ ] Will this break Swift conventions? → If YES, redesign approach
- [ ] Does this follow iOS architecture patterns? → Ensure MVVM/SwiftUI compliance
- [ ] Am I working with existing SwiftUI Views? → Read and understand current implementation

**Step 4: Technical Debt Prevention (MANDATORY SEARCH FIRST)**
- [ ] **SEARCH FIRST**: Use Grep pattern="<functionality>.*<keyword>" to find existing implementations
- [ ] **CHECK EXISTING**: Read any found files to understand current functionality
- [ ] Does similar functionality already exist? → If YES, extend existing code
- [ ] Am I creating a duplicate class/service? → If YES, consolidate instead
- [ ] Will this create multiple sources of truth? → If YES, redesign approach
- [ ] Have I searched for existing implementations? → Use Grep/Glob tools first
- [ ] Can I extend existing code instead of creating new? → Prefer extension over creation
- [ ] Am I about to copy-paste code? → Extract to shared utility instead

**Step 5: Session Management**
- [ ] Is this a long/complex task? → If YES, plan context checkpoints
- [ ] Have I been working >1 hour? → If YES, consider /compact or session break

> **⚠️ DO NOT PROCEED until all checkboxes are explicitly verified**

## 📱 iOS PROJECT STRUCTURE

This is an iOS Swift project with the following organization:

```
Invest_V3/
├── CLAUDE.md                  # This file - Essential rules for Claude Code
├── Invest_V3.xcodeproj/       # Xcode project file
├── Invest_V3/                 # Main app source code
│   ├── App/
│   │   └── Invest_V3App.swift # App entry point
│   ├── Views/                 # SwiftUI Views
│   │   ├── HomeView.swift
│   │   ├── ArticleEditorView.swift
│   │   ├── WalletView.swift
│   │   └── [Other Views]
│   ├── ViewModels/            # MVVM ViewModels
│   │   ├── ArticleViewModel.swift
│   │   ├── WalletViewModel.swift
│   │   └── [Other ViewModels]
│   ├── Models/                # Data Models
│   │   ├── Article.swift
│   │   ├── UserProfile.swift
│   │   └── [Other Models]
│   ├── Services/              # Business Logic Services
│   │   ├── AuthenticationService.swift
│   │   ├── SupabaseService.swift
│   │   └── [Other Services]
│   ├── Extensions/            # Swift Extensions
│   │   ├── Color+Hex.swift
│   │   └── [Other Extensions]
│   └── Assets.xcassets/       # App resources
├── Invest_V3Tests/            # Unit tests
└── Invest_V3UITests/          # UI tests
```

### 🎯 **iOS DEVELOPMENT PRINCIPLES**

1. **SwiftUI First**: Use SwiftUI for all new UI components
2. **MVVM Architecture**: Separate business logic from UI using ViewModels
3. **Single Responsibility**: Each file should have one clear purpose
4. **Swift Conventions**: Follow proper Swift naming and code organization
5. **Xcode Integration**: Maintain proper project structure for Xcode

### 🎨 **UI DESIGN REQUIREMENTS**

#### 📱 **Apple Human Interface Guidelines (HIG) 合規性**
- **MANDATORY**: All UI designs MUST comply with Apple HIG
- **Navigation**: Use native iOS navigation patterns and gestures
- **Accessibility**: Support VoiceOver, Dynamic Type, and accessibility features
- **Visual Design**: Follow iOS visual design principles and conventions
- **Interaction**: Use standard iOS interaction patterns and feedback

#### 🍎 **Apple Design Standards**
- **MANDATORY**: Follow Apple Design Resources and SF Symbols
- **Typography**: Use iOS system fonts (San Francisco) with proper type scales
- **Color**: Support both Light and Dark mode appearances
- **Layout**: Use Auto Layout and Safe Area guidelines
- **Animation**: Use Core Animation with iOS-standard timing curves

#### 🎯 **Swift Code Standards**
- **MANDATORY**: Follow Swift API Design Guidelines
- **Naming**: Use clear, descriptive names following Swift conventions
- **Structure**: Organize code using extensions and MARK comments
- **Performance**: Follow iOS performance best practices
- **Memory**: Use ARC properly and avoid retain cycles

#### 🌈 **Invest_V3 主題配色規範**
- **Primary Brand Green**: #1DB954 (投資成功/正面)
- **Secondary Blue**: #0066CC (信賴/專業)
- **Accent Orange**: #FF6B35 (警告/重要)
- **Background Colors**:
  - Light Mode: #FFFFFF (主背景), #F8F9FA (次要背景)
  - Dark Mode: #000000 (主背景), #1C1C1E (次要背景)
- **Text Colors**:
  - Light Mode: #000000 (主文字), #666666 (次要文字)
  - Dark Mode: #FFFFFF (主文字), #999999 (次要文字)
- **System Colors**: 優先使用 iOS 系統顏色確保一致性

## 🐙 GITHUB SETUP & AUTO-BACKUP

### 🚀 **GITHUB REPOSITORY CREATION**
Setting up GitHub repository for Invest_V3:

```bash
# Ensure GitHub CLI is available
gh --version || echo "⚠️ GitHub CLI (gh) required. Install: brew install gh"

# Authenticate if needed
gh auth status || gh auth login

# Create new GitHub repository
gh repo create "Invest_V3" --public --description "Investment knowledge sharing platform - Taiwan's Seeking Alpha (iOS App)" --confirm

# Add remote and push
git remote add origin "https://github.com/$(gh api user --jq .login)/Invest_V3.git"
git branch -M main
git push -u origin main
```

### 📋 **GITHUB BACKUP WORKFLOW** (MANDATORY)
> **⚠️ CLAUDE CODE MUST FOLLOW THIS PATTERN:**

```bash
# After every commit, always run:
git push origin main

# This ensures:
# ✅ Remote backup of all changes
# ✅ Collaboration readiness  
# ✅ Version history preservation
# ✅ Disaster recovery protection
```

## 📱 PROJECT OVERVIEW - Invest_V3

**Invest_V3** is a comprehensive investment knowledge sharing platform designed to solve Taiwan's investment fraud problem. Built as an iOS app using Swift and SwiftUI, it provides a transparent, trustworthy environment where investment experts can share knowledge and build credibility through verified performance.

### 🎯 **CORE FEATURES**

#### 👤 **User System**
- **Dual User Types**: Investment experts ("主持人") and general users ("探索者")
- **Authentication**: Secure registration and login system
- **Profiles**: Comprehensive user profiles with investment philosophy and specializations

#### 📝 **Content Creation & Publishing**
- **Rich Text Editor**: Medium-style editor with advanced formatting capabilities
- **Article Management**: Create, edit, and publish investment analysis articles
- **Content Monetization**: Free and paid content distribution
- **Publishing Controls**: Flexible audience targeting (public, followers, subscribers)

#### 💼 **Portfolio & Trading**
- **Simulated Trading**: Transparent portfolio management system
- **Performance Tracking**: Real-time calculation of returns, drawdowns, and metrics
- **Verification System**: Public trading records for credibility building
- **Visual Analytics**: Charts and graphs for portfolio visualization

#### 💬 **Social & Community**
- **Following System**: Users can follow trusted investment experts
- **Chat Groups**: Expert-led premium discussion groups
- **Comments & Interactions**: Article engagement and community building
- **Notifications**: Real-time updates and alerts

#### 💰 **Monetization & Payments**
- **Subscription Model**: Monthly/quarterly expert subscriptions
- **Wallet System**: In-app currency for transactions
- **Gift System**: Virtual gifts and tipping functionality
- **Revenue Sharing**: Platform commission model

### 🏗️ **TECHNICAL ARCHITECTURE**

- **Frontend**: SwiftUI with MVVM architecture
- **Backend**: Supabase integration for data management
- **Authentication**: Secure user authentication system
- **Real-time Features**: Live chat and notifications
- **Payment Processing**: Integrated wallet and transaction system

### 🎯 **DEVELOPMENT STATUS**
- **Setup**: ✅ Complete - Project structure established
- **Core Features**: 🔄 In Development - Main functionality being implemented
- **Testing**: ⏳ Pending - Unit and UI tests to be expanded
- **Documentation**: 🔄 In Progress - CLAUDE.md and technical docs

## 📋 NEED HELP? START HERE

### 🚀 **Quick Start Commands**
```bash
# Open project in Xcode
open Invest_V3.xcodeproj

# Run project in simulator
# Use Xcode's play button or Cmd+R

# Build project
xcodebuild -project Invest_V3.xcodeproj -scheme Invest_V3 build

# Run tests
xcodebuild test -project Invest_V3.xcodeproj -scheme Invest_V3 -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 📚 **Key Files to Understand**
- `Invest_V3App.swift` - App entry point and configuration
- `MainAppView.swift` - Main app navigation structure
- `HomeView.swift` - Primary user interface
- `ArticleEditorView.swift` - Content creation interface
- `SupabaseService.swift` - Backend integration

## 🎯 RULE COMPLIANCE CHECK

Before starting ANY task, verify:
- [ ] ✅ I acknowledge all critical rules above
- [ ] Files go in proper iOS project structure (not root)
- [ ] Use Task agents for >30 second operations
- [ ] TodoWrite for 3+ step tasks
- [ ] Commit after each completed task
- [ ] Follow Swift and iOS conventions
- [ ] Test builds after significant changes

## 🚨 TECHNICAL DEBT PREVENTION

### ❌ WRONG APPROACH (Creates Technical Debt):
```swift
// Creating new file without searching first
// File: ArticleServiceNew.swift
class ArticleServiceNew {
    // Duplicate functionality
}
```

### ✅ CORRECT APPROACH (Prevents Technical Debt):
```swift
// 1. SEARCH FIRST
// Grep(pattern="ArticleService", include="*.swift")
// 2. READ EXISTING FILES  
// Read(file_path="ArticleService.swift")
// 3. EXTEND EXISTING FUNCTIONALITY
// Edit existing service instead of creating new one
```

## 🧹 DEBT PREVENTION WORKFLOW

### Before Creating ANY New Swift File:
1. **🔍 Search First** - Use Grep/Glob to find existing implementations
2. **📋 Analyze Existing** - Read and understand current patterns
3. **🤔 Decision Tree**: Can extend existing? → DO IT | Must create new? → Document why
4. **✅ Follow iOS Patterns** - Use established iOS and Swift patterns
5. **📈 Validate** - Ensure no duplication or technical debt

### 📱 iOS-Specific Considerations:
- Follow SwiftUI and UIKit best practices
- Maintain proper MVVM separation
- Use Swift's type system effectively
- Follow iOS Human Interface Guidelines
- Ensure proper memory management

---

**⚠️ Prevention is better than consolidation - build clean from the start.**  
**🎯 Focus on single source of truth and extending existing functionality.**  
**📈 Each task should maintain clean architecture and prevent technical debt.**
**📱 Always consider iOS platform conventions and user experience.**

---

🎯 **Template by Chang Ho Chien | HC AI 說人話channel | v1.0.0**  
📺 **Tutorial**: https://youtu.be/8Q1bRZaHH24