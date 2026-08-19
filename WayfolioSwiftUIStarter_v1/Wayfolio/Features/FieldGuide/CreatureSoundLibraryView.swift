import SwiftUI

struct CreatureSoundLibraryView: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine

    private let families = [
        CreatureSoundSample("Beast", "creature_beast_alert"),
        CreatureSoundSample("Avian", "creature_avian_alert"),
        CreatureSoundSample("Reptile", "creature_reptile_alert"),
        CreatureSoundSample("Insect", "creature_insect_alert"),
        CreatureSoundSample("Ooze", "creature_ooze_alert"),
        CreatureSoundSample("Construct", "creature_construct_alert"),
        CreatureSoundSample("Undead", "creature_undead_alert"),
        CreatureSoundSample("Dragon", "creature_dragon_alert"),
        CreatureSoundSample("Plant", "creature_plant_alert"),
        CreatureSoundSample("Elemental", "creature_elemental_alert")
    ]

    private let forms = [
        CreatureSoundSample("Small & timid", "creature_small_timid_startle"),
        CreatureSoundSample("Large predator", "creature_large_predator_warning"),
        CreatureSoundSample("Curious slime", "creature_slime_curious_move"),
        CreatureSoundSample("Hostile slime", "creature_slime_hostile_attack"),
        CreatureSoundSample("Mournful spirit", "creature_spirit_mournful_appear"),
        CreatureSoundSample("Hostile spirit", "creature_spirit_hostile_whisper"),
        CreatureSoundSample("Skeleton", "creature_skeletal_idle_rattle"),
        CreatureSoundSample("Swarm", "creature_swarm_agitated"),
        CreatureSoundSample("Crystalline", "creature_crystalline_alert"),
        CreatureSoundSample("Fungal colony", "creature_fungal_spore_release"),
        CreatureSoundSample("Armored shell", "creature_shell_armored_move"),
        CreatureSoundSample("Floating arcane", "creature_floating_arcane_pulse")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Creature Sound Library", systemImage: "waveform.badge.magnifyingglass")
                .font(WayfolioTypography.title)
            Text("Preview every sound family currently available to encounters.")
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.68))
            soundSection("Creature families", samples: families)
            soundSection("Body forms & dispositions", samples: forms)
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(16)
        .parchmentSurface()
    }

    private func soundSection(_ title: String, samples: [CreatureSoundSample]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(WayfolioTypography.caption)
                .tracking(1)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(samples) { sample in
                    Button {
                        audio.playWorldSound(sample.cue, volume: 0.82)
                    } label: {
                        Label(sample.label, systemImage: "speaker.wave.2.fill")
                            .font(WayfolioTypography.caption)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .tint(WayfolioPalette.navy)
                    .accessibilityHint("Plays the \(sample.label) encounter sound")
                }
            }
        }
    }
}

private struct CreatureSoundSample: Identifiable {
    let label: String
    let cue: String
    var id: String { cue }

    init(_ label: String, _ cue: String) {
        self.label = label
        self.cue = cue
    }
}
