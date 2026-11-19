import SwiftUI

public extension EnvironmentValues {
    /// Draws the hero and the children at rest, already in place: no idling and no pop-in. Reduce Motion stops the
    /// idling too; this is for pictures of a screen that must come out the same every time (ADR-0034).
    @Entry var avatarsAreStill = false
}
