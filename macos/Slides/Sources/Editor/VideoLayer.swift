import AVFoundation
import SwiftUI

/// Muted, looping video. The player layer applies the video's rotation itself.
struct VideoLayer: NSViewRepresentable {
    let url: URL
    let playing: Bool

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.load(url)
        return view
    }

    func updateNSView(_ view: PlayerView, context: Context) {
        if view.url != url { view.load(url) }
        if playing { view.player.play() } else { view.player.pause() }
    }

    static func dismantleNSView(_ view: PlayerView, coordinator: ()) {
        view.player.pause()
        view.player.removeAllItems()
    }

    final class PlayerView: NSView {
        let player = AVQueuePlayer()
        private(set) var url: URL?
        private var looper: AVPlayerLooper?
        private let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            player.isMuted = true
            playerLayer.player = player
            // The SwiftUI frame already has the video's aspect ratio.
            playerLayer.videoGravity = .resize
            layer = playerLayer
        }

        required init?(coder: NSCoder) { fatalError() }

        func load(_ url: URL) {
            self.url = url
            player.removeAllItems()
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        }
    }
}
