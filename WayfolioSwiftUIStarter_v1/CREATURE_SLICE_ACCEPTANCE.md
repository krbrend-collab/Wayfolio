# Creature Discovery Slice — Acceptance Criteria

The slice is ready to merge when all of the following are true in Xcode on the target iPhone/simulator:

- Project builds with the expanded SwiftData model container.
- Existing SwiftData store migrates or initializes without data loss.
- Tubelume appears as an unidentified sighted creature on first seed.
- Its name is revealed only at `identified` or higher.
- `sighted`, `identified`, `studied`, and `mastered` states each produce visibly different Field Guide content.
- Discovery state persists across app relaunch.
- Existing navigation, Entries search/filter, and shell behavior remain intact.
- No DM-only data or hidden slime evolution content is present in the public client.

The temporary prototype discovery control is acceptable for this branch only. Runtime transport replaces it in the next slice.
