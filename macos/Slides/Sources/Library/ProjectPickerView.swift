import SlidesCore
import SwiftUI

struct ProjectPickerView: View {
    let app: AppModel

    @State private var query = ""
    @State private var sort = Sort.recent

    enum Sort: String, CaseIterable {
        case recent = "Recent"
        case oldest = "Oldest"
        case name = "Name"
    }

    private var filtered: [ProjectSummary] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = q.isEmpty ? app.projects : app.projects.filter { $0.name.lowercased().contains(q) }
        return switch sort {
        case .recent: base.sorted { $0.modified > $1.modified }
        case .oldest: base.sorted { $0.modified < $1.modified }
        case .name: base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 196, maximum: 260), spacing: 24, alignment: .top)], alignment: .leading, spacing: 24) {
                    NewProjectCard(action: app.newProject)
                    ForEach(filtered) { project in
                        ProjectCard(
                            project: project,
                            onOpen: { app.open(project) },
                            onDelete: { app.delete(project) },
                            onReveal: { app.revealInFinder(project) }
                        )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
            footer
        }
        .background(Theme.background)
        .onAppear(perform: app.refresh)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Slides").font(Theme.font(18, .semibold))
            Text("\(app.projects.count)")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.textMuted)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.font(12))
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 220, height: 28)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.outline, lineWidth: 0.5))

            Menu {
                ForEach(Sort.allCases, id: \.self) { option in
                    Button(option.rawValue) { sort = option }
                }
            } label: {
                Text("SORT  \(sort.rawValue)").font(Theme.mono(10))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button(action: app.newProject) {
                Label("New", systemImage: "plus")
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Theme.text, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .frame(height: 64)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineSoft).frame(height: 0.5) }
    }

    private var footer: some View {
        HStack {
            Text("\(app.projects.count) \(app.projects.count == 1 ? "project" : "projects")")
            Spacer()
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
        }
        .font(Theme.mono(10))
        .foregroundStyle(Theme.textMuted.opacity(0.7))
        .padding(.horizontal, 32)
        .frame(height: 36)
        .overlay(alignment: .top) { Rectangle().fill(Theme.outlineSoft).frame(height: 0.5) }
    }
}

private struct NewProjectCard: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surface.opacity(hovering ? 0.8 : 0.4))
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.outline, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 22, weight: .light))
                            Text("New project").font(Theme.font(12))
                        }
                        .foregroundStyle(hovering ? Theme.text : Theme.textMuted)
                    }
                // Same height as a project card's title and details.
                Text(" ").font(Theme.font(13)).padding(.bottom, 16)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(Theme.surface)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay {
                        // Covers change on every save, so they are read fresh instead of from the media cache.
                        if let image = NSImage(contentsOf: project.coverURL) {
                            Image(nsImage: image).resizable().scaledToFill()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(hovering ? Theme.textMuted : Theme.outline, lineWidth: 0.5))
                if hovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(hex: 0x0F0F11).opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .help("Move to Trash")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(Theme.font(13, .medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(project.frameCount) \(project.frameCount == 1 ? "slide" : "slides") · \(project.modified.formatted(.relative(presentation: .named)))")
                    if project.hasPanorama {
                        Text("PANO")
                            .font(Theme.mono(8, .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.outline, lineWidth: 0.5))
                    }
                }
                .font(Theme.font(11))
                .foregroundStyle(Theme.textMuted)
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
