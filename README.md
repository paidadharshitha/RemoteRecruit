# RemoteRecruit — iOS Job Browser App

A production-quality, scalable, and fully tested iOS application built to browse remote job openings, perform instant client-side searches, and inspect structural granular metadata descriptions.

## 🏗️ Architecture & Framework Stack

The system is developed using modern iOS development guidelines:
- **Language & Runtime:** Swift 5+ with native `async/await` structural concurrency semantics.
- **UI Architecture:** Modern declarative UI framework leveraging **SwiftUI** seamlessly coupled with native performance binding updates.
- **Design Pattern:** **MVVM (Model-View-ViewModel)** with clean separation of structural tasks and protocol-oriented Dependency Injection.
- **State Automation Design:** Uses a strict explicit State Machine mapping lifecycle workflows through a robust `ViewState<T>` enum layer:
  - `.idle` — Inactive setup stage.
  - `.loading` — Active async fetching operation spinning indicator.
  - `.success([Job])` — Content loaded cleanly ready for data rows pipeline.
  - `.empty` — Safe fallback layout when search or fetch returns no matching logs.
  - `.error(String)` — Friendly user interface parsing structural errors with quick retry bindings.

---

## 🧪 Testing Paradigm & Coverage Metrics

This codebase runs strict protocol-oriented contracts allowing independent dependency mocking.
- **Total Test Cases Executed:** 44 tests (100% execution pass rate).
- **Core Coverage Focus:** - Reactive search parameters matching case-insensitive title tokens or company names.
  - Exception pipeline transitions tracking edge-case variations inside explicit ViewState structures.
  - Network fallback protocols preventing standard runtime data mutations.

---

## 🛠️ Project Local Setup Instructions

Follow these simple CLI steps to compile, launch, and preview compilation metrics locally:

```bash
# 1. Clone the project repository context
git clone <your-repository-url>
cd RemoteRecruit

# 2. Compile code verification matrix
xcodebuild build -scheme RemoteRecruit -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'

# 3. Trigger structural Unit Tests execution
xcodebuild test -scheme RemoteRecruit -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'
```

---

## 📁 Project Structure

```
RemoteRecruit/
├── Package.swift
├── Sources/RemoteRecruit/
│   ├── Models/
│   │   └── Job.swift
│   ├── Services/
│   │   └── JobService.swift
│   ├── ViewModels/
│   │   └── JobListViewModel.swift
│   └── Views/
│       ├── JobListView.swift
│       ├── JobDetailView.swift
│       └── Components/
│           └── StateViews.swift
└── Tests/RemoteRecruitTests/
    └── JobListViewModelTests.swift
```

---

## 📋 Key Features

- **Searchable Job List** with real-time filtering by title or company name
- **Explicit State Management** — loading, success, empty, and error states rendered gracefully
- **Protocol-Oriented DI** — swappable service layer for easy testing and environment switching
- **Modern Concurrency** — `async/await` with `@MainActor` isolation for thread-safe UI updates
- **Pull-to-Refresh** support built into the list view
- **Detail Screen** with metadata cards, tag flow layout, and full job descriptions
