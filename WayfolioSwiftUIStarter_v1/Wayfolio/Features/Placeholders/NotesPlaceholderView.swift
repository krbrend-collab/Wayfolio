import SwiftUI

struct NotesPlaceholderView: View {
    @State private var notes: [JournalNote] = JournalNote.samples
    @State private var showingComposer = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Field Journal")
                            .font(WayfolioTypography.title)
                            .foregroundStyle(WayfolioPalette.ink)
                        Text("Searchable persistence comes next; this proves the real note-card interaction.")
                            .font(WayfolioTypography.caption)
                            .foregroundStyle(WayfolioPalette.ink.opacity(0.64))
                    }
                    Spacer()
                    Button { showingComposer = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(WayfolioPalette.brassBright)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(WayfolioPalette.navy))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New note")
                }
                .padding(14)
                .parchmentSurface()

                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(note.title)
                                .font(WayfolioTypography.headline)
                            Spacer()
                            Text(note.tag.uppercased())
                                .font(WayfolioTypography.tiny)
                                .foregroundStyle(WayfolioPalette.violet)
                        }
                        Text(note.body)
                            .font(WayfolioTypography.body)
                            .foregroundStyle(WayfolioPalette.ink.opacity(0.76))
                    }
                    .foregroundStyle(WayfolioPalette.ink)
                    .padding(14)
                    .parchmentSurface(radius: WayfolioMetrics.cardRadius)
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingComposer) {
            NoteComposer { title, body in
                notes.insert(JournalNote(title: title, body: body, tag: "Field"), at: 0)
            }
            .presentationDetents([.medium])
        }
    }
}

private struct JournalNote: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let tag: String

    static let samples = [
        JournalNote(title: "Mossglow trail", body: "Blue motes appeared along the shaded north path shortly before dusk.", tag: "Creature"),
        JournalNote(title: "Root & Kettle", body: "Ask whether the pale fern infusion is seasonal or tied to the spring harvest.", tag: "Hemlock"),
        JournalNote(title: "Lanternshell behavior", body: "The shell lights seem brighter after long periods of stillness on warm stone.", tag: "Research")
    ]
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
