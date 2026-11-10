import SlidesCore
import SwiftUI

struct ProjectPickerView: View {
    let app: AppModel

    @State private var query = ""
    @State private var sort = Sort.recent

    enum Sort: String, CaseIterable {
        case recent = "Last Modified"
        case oldest = "Oldest First"
        case name = "Name"
    }

    private var filtered: [ProjectSummary] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty ? app.projects : app.projects.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return switch sort {
        case .recent: base.sorted { $0.modified > $1.modified }
        case .oldest: base.sorted { $0.modified < $1.modified }
        case .name: base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 28, alignment: .top)], alignment: .leading, spacing: 28) {
                ForEach(filtered) { project in
                    ProjectCard(
                        project: project,
                        onOpen: { app.open(project) },
                        onDelete: { app.delete(project) },
                        onReveal: { app.revealInFinder(project) }
                    )
                }
            }
            .padding(28)
        }
        .overlay {
            if app.projects.isEmpty {
                ContentUnavailableView {
                    Label { Text("No Projects") } icon: { TablerIcon("photo", size: 40) }
                } description: {
                    Text("A project is one carousel of photos and videos.")
                } actions: {
                    Button("New Project", action: app.newProject)
                        .buttonStyle(.borderedProminent)
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .navigationTitle("Slides")
        .navigationSubtitle("\(app.projects.count) \(app.projects.count == 1 ? "project" : "projects")")
        .searchable(text: $query, placement: .toolbar, prompt: "Search projects")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label { Text("Sort") } icon: { TablerIcon("arrows-sort", size: 18) }
                }
                .help("Sort projects")
                Button(action: app.newProject) {
                    Label { Text("New Project") } icon: { TablerIcon("plus", size: 18) }
                }
                .help("New project (⌘N)")
            }
        }
        .onAppear(perform: app.refresh)
    }
}

private struct ProjectCard: View {
    let project: ProjectSummary
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    // Covers change on every save, so they are read fresh instead of from the media cache.
                    if let image = NSImage(contentsOf: project.coverURL) {
                        Image(nsImage: image).resizable().scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 0.5))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.accentColor, lineWidth: hovering ? 3 : 0).padding(-4))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(project.frameCount) \(project.frameCount == 1 ? "slide" : "slides") · \(project.modified.formatted(.relative(presentation: .named)))")
                    if project.hasPanorama {
                        TablerIcon("panorama-horizontal", size: 14).help("Contains a panorama")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Show in Finder", action: onReveal)
            Divider()
            Button("Move to Trash", role: .destructive, action: onDelete)
        }
    }
}
