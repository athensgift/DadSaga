# ADR-0016: Moment photos are files on the device; moments can be edited and deleted

**Status:** Accepted

## Context
Legendary moments (ADR-0015) needed photos, and the dad needs to fix a moment captured by mistake.

## Decision
- **Photos are JPEG files** in Application Support (`FilePhotoStore`), downscaled to 2048 px on the longest side and
  written with file protection. The moment stores only the photo's id. Nothing leaves the device (ADR-0004).
  SwiftData external storage was not used, so photos stay easy to export later (Phase 3½ video).
- **Picking:** `PhotosPicker` (no photo-library permission needed) and the camera (`NSCameraUsageDescription`).
- **Edit:** date, note and photo (keep, replace, remove). The first and the child do not change. An old photo is deleted
  only after the moment points to the new one, and a failed capture removes the photo it just saved.
- **Delete:** removes the moment, its photo and the XP it gave. This is the dad undoing his own entry, not the game
  taking something away, so it does not conflict with ADR-0006. It asks for confirmation first.
- `ProgressRepository` gains `update` and `delete`, used only for moments.

## Consequences
- Moments now carry real memories and are ready for the timeline and the saga video.
- Photos are not in iCloud backup exclusions; they are backed up with the app like the database.
