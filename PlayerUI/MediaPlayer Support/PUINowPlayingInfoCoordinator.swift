//
//  PUINowPlayingInfoCoordinator.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 22/04/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import MediaPlayer

final class PUINowPlayingInfoCoordinator {

    let player: AVPlayer

    @available(macOS 10.12.2, *)
    init(player: AVPlayer) {
        self.player = player

        observePlayer()
    }

    var basicNowPlayingInfo: PUINowPlayingInfo?

    // MARK: - Playback state

    @available(macOS 10.12.2, *)
    var playbackStateAppropriateForPlayer: MPNowPlayingPlaybackState {
        return player.rate.isZero ? .paused : .playing
    }

    // MARK: - Playback info

    @available(macOS 10.12.2, *)
    var nowPlayingInfo: [String: Any]? {
        guard let item = player.currentItem else { return nil }

        var info: [String: Any] = [
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: CMTimeGetSeconds(player.currentTime())
        ]

        if #available(macOS 10.12.3, *), let urlAsset = item.asset as? AVURLAsset {
            info[MPNowPlayingInfoPropertyAssetURL] = urlAsset.url
        }

        if #available(macOS 10.13.1, *) {
            info[MPNowPlayingInfoPropertyCurrentPlaybackDate] = item.currentDate()
        }

        if let basicInfo = basicNowPlayingInfo?.dictionaryRepresentation {
            info.merge(basicInfo, uniquingKeysWith: { a, b in b })
        }

        if item.duration.isValid, item.duration.isNumeric {
            info[MPMediaItemPropertyPlaybackDuration] = TimeInterval(CMTimeGetSeconds(item.duration))
        }

        return info
    }

    // MARK: - Player observation

    private var rateObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var timeObserver: Any?

    private func observePlayer() {
        rateObservation = player.observe(\.rate) { [weak self] _, _ in
            DispatchQueue.main.async { self?.playbackRateDidChange() }
        }

        itemObservation = player.observe(\.currentItem) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateNowPlayingInfo() }
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, 30000), queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.updateNowPlayingInfo() }
        }
    }

    private func playbackRateDidChange() {
        guard #available(macOS 10.12.2, *) else { return }

        MPNowPlayingInfoCenter.default().playbackState = playbackStateAppropriateForPlayer
    }

    private func updateNowPlayingInfo() {
        guard #available(macOS 10.12.2, *) else { return }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        rateObservation?.invalidate()
        itemObservation?.invalidate()
    }

}
