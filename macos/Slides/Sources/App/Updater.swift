import Observation
import Sparkle

/// Sparkle's updater, observable so "Check for Updates…" enables itself when ready.
///
/// The feed (`SUFeedURL`) and public key (`SUPublicEDKey`) live in the Info.plist.
/// Debug builds never start the updater, so a local build doesn't replace itself with a release.
@MainActor
@Observable
final class Updater {
    private(set) var canCheckForUpdates = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        #if DEBUG
            let startsUpdater = false
        #else
            let startsUpdater = true
        #endif
        controller = SPUStandardUpdaterController(startingUpdater: startsUpdater, updaterDelegate: nil, userDriverDelegate: nil)
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor [weak self] in self?.canCheckForUpdates = canCheck }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
