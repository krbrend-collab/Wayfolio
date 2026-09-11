import SwiftUI

struct NotesPlaceholderView: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @EnvironmentObject private var session: GameSessionClient
    @State private var notes: [JournalNote] = []
    @State private var showingComposer = false
    @State private var selectedSection: JournalSection = .sessions
    @State private var searchText = ""
    @State private var selectedRecord: JournalNote?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Field Journal")
                                .font(WayfolioTypography.title)
                                .foregroundStyle(WayfolioPalette.parchment)
                            Text("Observations, remembered places, and questions gathered along the road.")
                                .font(WayfolioTypography.caption)
                                .foregroundStyle(WayfolioPalette.parchment.opacity(0.68))
                        }
                        Spacer()
                    }
                    .padding(14)
                    .projectionPane(.info)

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(JournalSection.allCases) { section in
                                WayfolioFilterChip(title: section.title, selected: selectedSection == section) {
                                    withAnimation(.snappy(duration: 0.2)) { selectedSection = section }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollIndicators(.hidden)

                    journalContents
                }
                .padding(.horizontal, WayfolioMetrics.contentInset)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)

            journalToolbar
                .padding(.horizontal, WayfolioMetrics.contentInset)
                .padding(.bottom, 6)
        }
        .onChange(of: selectedSection) { _, _ in
            audio.playUISound("navigation_select")
        }
        .onAppear { loadPrivateNotes() }
        .onChange(of: session.selectedCharacterID) { _, _ in loadPrivateNotes() }
        .onChange(of: notes) { _, _ in savePrivateNotes() }
        .sheet(isPresented: $showingComposer) {
            NoteComposer { title, body in
                notes.insert(JournalNote(id: "note-\(UUID().uuidString)", title: title, body: body, tag: "Field"), at: 0)
                audio.playUISound("navigation_select")
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $selectedRecord) { record in
            JournalRecordDetail(record: record)
        }
    }

    private var journalToolbar: some View {
        HStack(spacing: 8) {
            Label {
                TextField("Search journal", text: $searchText)
            } icon: {
                Image(systemName: "magnifyingglass")
            }
            .font(WayfolioTypography.body)
            .foregroundStyle(WayfolioPalette.parchment)
            .padding(.horizontal, 12)
            .frame(maxWidth: 272, minHeight: 38)
            .background(.ultraThinMaterial, in: Capsule())
            .background(WayfolioPalette.navy.opacity(0.54), in: Capsule())
            .overlay(Capsule().stroke(WayfolioPalette.brass.opacity(0.75), lineWidth: 1))
            .shadow(color: WayfolioPalette.cyan.opacity(0.18), radius: 9)

            Button {
                audio.playUISound("navigation_select")
                showingComposer = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .frame(width: 38, height: 38)
                    .foregroundStyle(WayfolioPalette.brassBright)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(WayfolioPalette.navy.opacity(0.62), in: Circle())
                    .overlay(Circle().stroke(WayfolioPalette.brass, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create a new private note")
        }
    }

    @ViewBuilder
    private var journalContents: some View {
        switch selectedSection {
        case .all:
            Group {
                let records = allRecords.filter { matches($0.title + " " + $0.body) }
                if records.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No journal records yet", message: "Confirmed experiences and private notes will appear here as the journey unfolds.")
                } else {
                    journalSectionTitle("All Records", detail: "Sessions, quests, research, recipes, and notes")
                    ForEach(records) { journalCard($0) }
                }
            }
        case .notes:
            Group {
                if !notes.isEmpty {
                    journalSectionTitle("My Notes", detail: "Private notes saved on this Wayfolio")
                    ForEach(notes.filter { matches($0.title + " " + $0.body) }) { note in journalCard(note) }
                } else {
                    WayfolioStateCard(kind: .empty, title: "No field notes yet", message: "Use New Note to record a private observation.")
                }
            }
        case .quests:
            Group {
                if !session.pendingThreads.isEmpty {
                    journalSectionTitle("Open Threads", detail: "Unresolved intentions and questions")
                    ForEach(Array(session.pendingThreads.filter(matches).enumerated()), id: \.offset) { index, entry in
                        journalCard(JournalNote(id: "quest-\(stableID(entry))", title: "Thread \(index + 1)", body: entry, tag: "Open"))
                    }
                } else {
                    WayfolioStateCard(kind: .empty, title: "No active quests", message: "Published objectives will appear here when the journey reveals them.")
                }
            }
        case .sessions:
            Group {
                if !publishedSessionRecords.isEmpty {
                    journalSectionTitle("Journey Record", detail: "Facts published by the active game")
                    ForEach(publishedSessionRecords.filter { matches($0.title + " " + $0.body) }) { record in
                        journalCard(record)
                    }
                }

                if publishedSessionRecords.isEmpty && !session.completedWork.isEmpty {
                    journalSectionTitle("Journey Record", detail: "Confirmed work imported from the active journey")
                    ForEach(Array(session.completedWork.filter(matches).enumerated()), id: \.offset) { index, entry in
                        journalCard(JournalNote(id: "milestone-\(stableID(entry))", title: "Milestone \(index + 1)", body: entry, tag: "Confirmed"))
                    }
                }

                if publishedSessionRecords.isEmpty && session.completedWork.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No session records yet", message: "Confirmed journey records will appear here as play unfolds.")
                }
            }
        case .research:
            Group {
                if session.experiments.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No research records", message: "Confirmed experiments and findings will appear here as play unfolds.")
                } else {
                    ForEach(session.experiments.filter { matches($0.question + " " + $0.samples.joined(separator: " ")) }) { experiment in
                        journalCard(JournalNote(id: experiment.id, title: experiment.question, body: experiment.samples.joined(separator: " · "), tag: experiment.status))
                    }
                }
            }
        case .recipes:
            Group {
                if session.recipes.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No known recipes", message: "Recipes appear only after the active journey confirms the character knows them.")
                } else {
                    ForEach(session.recipes.filter { matches($0.name + " " + $0.notes.joined(separator: " ")) }) { recipe in
                        journalCard(JournalNote(id: recipe.id, title: recipe.name, body: recipe.notes.joined(separator: " "), tag: recipe.status))
                    }
                }
            }
        }
    }

    private func journalSectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(WayfolioTypography.headline)
            Text(detail).font(WayfolioTypography.tiny).foregroundStyle(WayfolioPalette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func journalCard(_ note: JournalNote) -> some View {
        Button {
            selectedRecord = note
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(WayfolioPalette.navy.opacity(0.10))
                    Image(systemName: journalSymbol(for: note.tag))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(WayfolioPalette.navy)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(note.title).font(WayfolioTypography.headline)
                        Spacer()
                        Text(note.tag.uppercased()).font(WayfolioTypography.tiny).foregroundStyle(WayfolioPalette.violet)
                    }
                    Text(note.body)
                        .font(WayfolioTypography.reading)
                        .foregroundStyle(WayfolioPalette.ink.opacity(0.76))
                        .lineLimit(3)
                }
            }
            .foregroundStyle(WayfolioPalette.ink)
            .padding(14)
            .parchmentSurface(radius: WayfolioMetrics.cardRadius)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this record in reading mode")
    }

    private var allRecords: [JournalNote] {
        let questRecords = session.pendingThreads.enumerated().map { JournalNote(id: "quest-\(stableID($0.element))", title: "Thread \($0.offset + 1)", body: $0.element, tag: "Open") }
        let researchRecords = session.experiments.map { JournalNote(id: $0.id, title: $0.question, body: $0.samples.joined(separator: " · "), tag: $0.status) }
        let recipeRecords = session.recipes.map { JournalNote(id: $0.id, title: $0.name, body: $0.notes.joined(separator: " "), tag: $0.status) }
        return unique(notes + publishedRecords + questRecords + researchRecords + recipeRecords)
    }

    private var publishedRecords: [JournalNote] {
        session.knowledgeRecords.compactMap { record in
            guard ["session", "discovery", "quest", "research", "recipe"].contains(record.kind) else { return nil }
            return JournalNote(id: record.id, title: record.name,
                               body: record.notes.joined(separator: " "), tag: record.status)
        }
    }

    private var publishedSessionRecords: [JournalNote] {
        let records = publishedRecords.filter { record in
            session.knowledgeRecords.first(where: { $0.id == record.id })?.kind == "session"
        }
        if !records.isEmpty { return records }
        return session.journal.enumerated().map {
            JournalNote(id: "session-\(stableID($0.element))", title: "Record \($0.offset + 1)", body: $0.element, tag: "Game")
        }
    }

    private func unique(_ records: [JournalNote]) -> [JournalNote] {
        var seen = Set<String>()
        return records.filter { seen.insert($0.id).inserted }
    }

    private func stableID(_ value: String) -> String {
        String(value.unicodeScalars.reduce(into: UInt64(1469598103934665603)) { hash, scalar in
            hash = (hash ^ UInt64(scalar.value)) &* 1099511628211
        }, radix: 16)
    }

    private func journalSymbol(for tag: String) -> String {
        let value = tag.lowercased()
        if value.contains("recipe") || value.contains("ready") { return "fork.knife" }
        if value.contains("research") || value.contains("experiment") { return "flask.fill" }
        if value.contains("open") || value.contains("quest") { return "signpost.right.fill" }
        if value.contains("field") { return "pencil.and.scribble" }
        return "book.pages.fill"
    }

    private func matches(_ value: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || value.localizedCaseInsensitiveContains(query)
    }

    private var privateNotesKey: String {
        "wayfolio.private-journal.\(session.selectedCharacterID)"
    }

    private func loadPrivateNotes() {
        guard let data = UserDefaults.standard.data(forKey: privateNotesKey),
              let saved = try? JSONDecoder().decode([JournalNote].self, from: data) else {
            notes = []
            return
        }
        notes = saved
    }

    private func savePrivateNotes() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: privateNotesKey)
    }
}

private enum JournalSection: String, CaseIterable, Identifiable {
    case all, sessions, quests, research, recipes, notes
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

private struct JournalNote: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let body: String
    let tag: String

}

private struct JournalRecordDetail: View {
    @Environment(\.dismiss) private var dismiss
    let record: JournalNote

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(record.tag.uppercased())
                        .font(WayfolioTypography.caption)
                        .tracking(1.3)
                        .foregroundStyle(WayfolioPalette.cyan)
                    Text(record.title)
                        .font(WayfolioTypography.display)
                        .foregroundStyle(WayfolioPalette.parchment)
                    Divider().overlay(WayfolioPalette.cyan.opacity(0.46))
                    Text(record.body)
                        .font(WayfolioTypography.reading)
                        .lineSpacing(5)
                        .foregroundStyle(WayfolioPalette.parchment.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
            }
            .background(WayfolioPalette.midnight.ignoresSafeArea())
            .navigationTitle("Journal Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", systemImage: "chevron.left") { dismiss() }
                }
            }
        }
    }
}

private struct NoteComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Observation", text: $bodyText, axis: .vertical)
                    .lineLimit(4...8)
            }
            .navigationTitle("New Field Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title.isEmpty ? "Untitled Note" : title, bodyText)
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
