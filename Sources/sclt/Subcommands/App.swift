//
//  App.swift
//  sclt
//
//  Created by Keisuke Chinone on 2026/11/08.
//

import Foundation
import ArgumentParser
import Observation
import SwiftLI

/// A complete full-screen, keyboard-driven app written with SwiftLI alone:
/// a tab bar, a list with multi-line rows pushing a detail page through a
/// typed navigation path, a settings form with a text field, a confirmation
/// alert, a toast overlay, a key-hint line, and a loading screen — the same
/// structure the SwiftUI version would have.
struct AppCommand: FullScreenCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "A full-screen keyboard-driven sample app",
        discussion: """
        Items tab: j/k or ↑/↓ move the selection (rows span several lines and
        the list keeps the whole row in view), Return opens the detail page,
        Escape or q goes back, d asks before deleting, PageUp/PageDown page.
        Settings tab: type into the field; Escape leaves it, Ctrl-S saves.
        Ctrl-T switches tabs, ? toggles help, q at the root quits, Ctrl-C quits
        anywhere. Resize the window to see the text re-wrap.
        """,
        version: "0.0.3",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )

    @State private var model = AppModel()
    @Environment(\.dismiss) private var dismiss

    // Nothing is parsed from the command line; the model is view state.
    private enum CodingKeys: CodingKey {}

    var body: some Scene {
        RootView()
            .environment(model)
            // Screen-wide shortcuts: whatever the focused control leaves
            // alone arrives here, innermost handler first.
            .onKeyPress { press in
                if press.modifiers.contains(.control), press.key == "t" {
                    model.screen = model.screen == .items ? .settings : .items
                    return .handled
                }
                switch press.key {
                case "?":
                    model.showsHelp.toggle()
                    return .handled
                case "q":
                    dismiss()
                    return .handled
                default:
                    return .ignored
                }
            }
    }
}

// MARK: - Model

enum Screen: Hashable, Sendable { case items, settings }

enum Route: Hashable, Sendable {
    case detail(Item.ID)
    case settings
}

struct Item: Identifiable, Hashable, Sendable {
    let id: Int
    var title: String
    var summary: String
    /// Words in the summary shown in colour.
    var highlights: [String]
    var updatedAt: Date
    var stars: Int
    var comments: Int
    var starred: Bool
    var done: Bool

    /// The summary with the highlighted words coloured — one `Text` that
    /// still wraps to the available width.
    var richSummary: AttributedString {
        var text = AttributedString(summary)
        for word in highlights {
            var searchRange = text.startIndex..<text.endIndex
            while let found = text[searchRange].range(of: word) {
                text[found].foregroundColor = .orange
                text[found].fontWeight = .bold
                searchRange = found.upperBound..<text.endIndex
            }
        }
        if done {
            text.foregroundColor = .secondary
            text.strikethrough = true
        }
        return text
    }
}

@Observable
final class AppModel: @unchecked Sendable {
    var items: [Item] = []
    var isLoading = true
    var screen: Screen = .items
    var showsHelp = false
    var toast: String?
    var userName = ""
    var notifies = true

    /// Simulates fetching the first page.
    func load() async {
        try? await Task.sleep(nanoseconds: 900_000_000)
        items = Self.page(from: 1, count: 12)
        isLoading = false
    }

    /// Appends the next page — called by the list when the selection nears
    /// the end.
    func loadMore() {
        guard items.count < 60 else { return }
        items += Self.page(from: items.count + 1, count: 12)
        show("Loaded \(items.count) items")
    }

    func toggleDone(_ id: Item.ID?) {
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].done.toggle()
        items[index].updatedAt = Date()
    }

    func toggleStar(_ id: Item.ID?) {
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].starred.toggle()
        items[index].stars += items[index].starred ? 1 : -1
    }

    func delete(_ id: Item.ID?) {
        guard let id else { return }
        items.removeAll { $0.id == id }
        show("Deleted item \(id)")
    }

    func item(_ id: Item.ID) -> Item? {
        items.first { $0.id == id }
    }

    /// Shows a toast for a moment.
    func show(_ message: String) {
        toast = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if self?.toast == message { self?.toast = nil }
        }
    }

    private static let topics = [
        ("Reactive rendering", "The render loop coalesces every state write made in one turn into a single frame, so a key handler that updates three values draws once.", ["coalesces", "single frame"]),
        ("Word wrapping", "Text wraps to the available width by default, including runs of mixed colour and weight, and re-wraps when the terminal is resized.", ["wraps", "resized"]),
        ("Typed navigation", "A NavigationStack with a path binding pushes values; navigationDestination(for:) turns each value into the page that shows it.", ["path binding", "navigationDestination"]),
        ("Focus follows", "A ScrollView keeps the focused child in view, and a List keeps the whole selected row visible however many lines it spans.", ["focused child", "selected row"]),
        ("Lifecycle", "task, onAppear, onDisappear and onChange are keyed by structural identity, so every ForEach row gets its own and a vanished row's task is cancelled.", ["structural identity", "cancelled"]),
        ("Tabs", "A TabView keeps each tab alive while it is hidden: state, scroll positions, selections and the focused control all survive a switch.", ["alive", "survive"]),
    ]

    static func page(from start: Int, count: Int) -> [Item] {
        (0..<count).map { offset in
            let number = start + offset
            let topic = topics[(number - 1) % topics.count]
            return Item(
                id: number,
                title: "#\(number) \(topic.0)",
                summary: topic.1,
                highlights: topic.2,
                updatedAt: Date().addingTimeInterval(-Double(number) * 3_700),
                stars: (number * 7) % 23,
                comments: (number * 3) % 9,
                starred: number % 4 == 0,
                done: number % 5 == 0
            )
        }
    }
}

// MARK: - Views

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.isLoading {
            VStack(alignment: .leading, spacing: 1) {
                ProgressView("Loading items…")          // spins by itself
                Text("Ctrl-C quits even while loading, and the terminal is restored.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .task { await model.load() }
        } else {
            TabView(selection: Bindable(model).screen) {
                Tab("Items", value: Screen.items) { ItemListView() }
                    .badge(model.items.filter { !$0.done }.count)
                Tab("Settings", value: Screen.settings) { SettingsView() }
            }
            .overlay(alignment: .bottomTrailing) {
                if let toast = model.toast {
                    Text(" \(toast) ").background(.green).foregroundStyle(.black).bold()
                }
            }
            .overlay(alignment: .center) {
                if model.showsHelp { HelpCard() }
            }
            .safeAreaInset(edge: .bottom) {
                Text(" j/k ↑/↓ move   ⏎ open   d delete   Ctrl-T tabs   ? help   q quit ")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keys").bold()
            Text("j / k, ↑ / ↓   move the selection")
            Text("PageUp / PageDown   move a screenful")
            Text("⏎   open the detail page")
            Text("Escape, q   back (q quits at the root)")
            Text("d   delete after confirming")
            Text("s   star / unstar,  x   mark done")
            Text("Ctrl-T   switch tab,  Ctrl-S   save settings")
            Text("?   close this help").foregroundStyle(.secondary)
        }
        .padding()
        .border(.cyan)
    }
}

struct ItemListView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Item.ID?
    @State private var path: [Route] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack(path: $path) {
            List(model.items, selection: $selection) { item in
                ItemRow(item: item)                  // several lines, wrapped
            }
            .onReachEnd(within: 2) { model.loadMore() }
            .onSubmit { if let id = selection { path.append(.detail(id)) } }
            .onKeyPress { press in
                switch press.key {
                case "j":
                    move(1)
                    return .handled
                case "k":
                    move(-1)
                    return .handled
                case "d":
                    if selection != nil { confirmDelete = true }
                    return .handled
                case "s":
                    model.toggleStar(selection)
                    return .handled
                case "x":
                    model.toggleDone(selection)
                    return .handled
                default:
                    return .ignored
                }
            }
            .alert("Delete this item?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { model.delete(selection) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .navigationTitle("Items")
            .navigationSubtitle("\(model.items.count) items — selection follows the whole row")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let id): DetailView(id: id)
                case .settings: SettingsView()
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            // Demonstrates onChange: a state write here lands in the next frame.
            if let newValue, newValue % 10 == 0 { model.show("Selected #\(newValue)") }
        }
    }

    private func move(_ delta: Int) {
        let ids = model.items.map(\.id)
        guard !ids.isEmpty else { return }
        let current = selection.flatMap { ids.firstIndex(of: $0) } ?? -1
        let next = Swift.min(Swift.max(current + delta, 0), ids.count - 1)
        selection = ids[next]
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(item.title).bold()
                Spacer()
                Text(item.updatedAt, style: .relative).foregroundColor(.secondary)
            }
            Text(item.richSummary)                   // mixed styles, wraps to the width
            HStack(spacing: 4) {
                Text("★ \(item.stars)").foregroundColor(item.starred ? .yellow : .secondary)
                Text("● \(item.comments)").foregroundColor(.secondary)
                if item.done { Text("done").foregroundColor(.green) }
            }
        }
    }
}

struct DetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: Item.ID
    /// Per-page state: survives re-renders, resets when another item opens.
    @State private var visits = 0

    var body: some View {
        if let item = model.item(id) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).bold().foregroundStyle(.cyan)
                Text(item.richSummary)
                HStack(spacing: 2) {
                    Text("Updated ") + Text(item.updatedAt, style: .relative).foregroundStyle(.yellow)
                    Text("★ \(item.stars)   ● \(item.comments)").foregroundStyle(.secondary)
                }
                Text("Opened \(visits) time(s) on this page — Escape or q goes back, s stars, x marks done.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 1)
            .navigationTitle(item.title)
            .onAppear { visits += 1 }
            .onKeyPress(keys: [.escape, "q"]) { _ in
                dismiss()                              // pops this page
                return .handled
            }
            .onKeyPress("s") { model.toggleStar(id); return .handled }
            .onKeyPress("x") { model.toggleDone(id); return .handled }
        } else {
            Text("This item was deleted.").foregroundStyle(.red)
                .onKeyPress(keys: [.escape, "q"]) { _ in dismiss(); return .handled }
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draftName = ""
    @State private var draftNotifies = true
    @State private var saves = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 1) {
                    Text("Name:")
                    TextField("Your name", text: $draftName)
                }
                Toggle("Notifications", isOn: $draftNotifies)
                Button("Save") { save() }
                Text("Saved \(saves) time(s). While the field has focus, letters go into it; Escape leaves it and Ctrl-S saves from anywhere on this tab.")
                    .foregroundStyle(.secondary)
                if !model.userName.isEmpty {
                    Text("Hello, ") + Text(model.userName).bold().foregroundStyle(.green) + Text("!")
                }
            }
            .padding(.top, 1)
            .navigationTitle("Settings")
            .onKeyPress { press in
                if press.modifiers.contains(.control), press.key == "s" {
                    save()
                    return .handled
                }
                return .ignored
            }
        }
    }

    private func save() {
        model.userName = draftName
        model.notifies = draftNotifies
        saves += 1
        model.show("Settings saved")
    }
}
