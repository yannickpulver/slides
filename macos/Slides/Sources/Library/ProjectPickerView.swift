import SlidesCore
import SwiftUI

struct ProjectPickerView: View {
    let app: AppModel

    @State private var query = ""
    @State private var sort = Sort.recent
    @AppStorage("projectsView") private var viewMode = ViewMode.grid

    enum ViewMode: String {
        case grid
        case filmstrip
    }

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
            switch viewMode {
            case .grid:
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
            case .filmstrip:
                LazyVStack(alignment: .leading, spacing: 32) {
                    ForEach(filtered) { project in
                        ProjectFilmstrip(
                            project: project,
                            library: app.library,
                            onOpen: { app.open(project, slide: $0) },
                            onCopy: { app.copy($0, of: project) },
                            onDelete: { app.delete(project) },
                            onReveal: { app.revealInFinder(project) }
                        )
                    }
                }
                .padding(.vertical, 28)
            }
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
                Button {
                    viewMode = viewMode == .grid ? .filmstrip : .grid
                } label: {
                    switch viewMode {
                    case .grid: Label { Text("Show as Filmstrip") } icon: { TablerIcon("layout-rows", size: 18) }
                    case .filmstrip: Label { Text("Show as Grid") } icon: { TablerIcon("layout-grid", size: 18) }
                    }
                }
                .help(viewMode == .grid ? "Show each project as a row of its slides" : "Show projects as a grid of covers")
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
        .onChange(of: app.projects) { _, projects in SlideThumbnails.shared.keep(projects) }
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
            ProjectCaption(project: project)
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

/// Name, slide count, date and panorama mark of a project.
private struct ProjectCaption: View {
    let project: ProjectSummary

    var body: some View {
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
}

/// One project as a row: its name, then all its slides side by side. A click opens the project on that slide.
struct ProjectFilmstrip: View {
    let project: ProjectSummary
    let library: ProjectLibrary
    let onOpen: (Slide.ID?) -> Void
    let onCopy: (Slide.ID) -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    /// Frame height in points.
    static let height = 200.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectCaption(project: project)
                .padding(.horizontal, 28)
                .contentShape(Rectangle())
                .onTapGesture { onOpen(nil) }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(project.slides) { slide in
                        FilmstripSlide(slide: slide, project: project, library: library)
                            .onTapGesture { onOpen(slide.id) }
                            .contextMenu {
                                Button("Open") { onOpen(slide.id) }
                                Button("Copy") { onCopy(slide.id) }
                                Button("Show in Finder", action: onReveal)
                                Divider()
                                Button("Move to Trash", role: .destructive, action: onDelete)
                            }
                    }
                }
                .padding(.horizontal, 28)
                // Room for the hover ring and the shadow.
                .padding(.vertical, 6)
            }
        }
        .contextMenu {
            Button("Open") { onOpen(nil) }
            Button("Show in Finder", action: onReveal)
            Divider()
            Button("Move to Trash", role: .destructive, action: onDelete)
        }
    }
}

/// One slide in a project row. A panorama shows its frames edge to edge.
private struct FilmstripSlide: View {
    let slide: Slide
    let project: ProjectSummary
    let library: ProjectLibrary

    @State private var hovering = false

    var body: some View {
        let frameWidth = ProjectFilmstrip.height * project.format.width / project.format.height
        let frames = SlideThumbnails.shared.frames(of: slide, in: project, library: library)
        HStack(spacing: 0) {
            ForEach(0..<slide.span, id: \.self) { part in
                if let frames, part < frames.count {
                    Image(decorative: frames[part], scale: 2)
                        .resizable()
                        .frame(width: frameWidth, height: ProjectFilmstrip.height)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: frameWidth, height: ProjectFilmstrip.height)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor, lineWidth: hovering ? 3 : 0).padding(-4))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
