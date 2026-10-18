import Observation

/// The single owner of app state. Later phases add EditState and EditHistory here.
@MainActor
@Observable
final class AppModel {
    var statusMessage = "Phase 0 is set up. The camera arrives in Phase 1."
}
