import Foundation
import Testing
@testable import BiliGlass

struct SpeedSelectionTests {
  @Test func offlineOptionsMatchRequestedList() {
    #expect(Playback.offlineSpeedOptions == [0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 32, 64, 128])
  }

  @Test func onlineOptionsReachEight() {
    #expect(Playback.onlineSpeedOptions == [0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 5, 6, 7, 8])
  }

  @Test func clampPicksNearestOfflineOption() {
    #expect(Playback.clampSpeed(0.1, isOffline: true) == 0.25)
    #expect(Playback.clampSpeed(200, isOffline: true) == 128)
    #expect(Playback.clampSpeed(1.5, isOffline: true) == 1)
    #expect(Playback.clampSpeed(20, isOffline: true) == 16)
    #expect(Playback.clampSpeed(64, isOffline: true) == 64)
  }

  @Test func clampLimitsOnlineToEight() {
    #expect(Playback.clampSpeed(0.25, isOffline: false) == 0.5)
    #expect(Playback.clampSpeed(16, isOffline: false) == 8)
    #expect(Playback.clampSpeed(5, isOffline: false) == 5)
    #expect(Playback.clampSpeed(1.25, isOffline: false) == 1.25)
  }

  @Test func formatting() {
    #expect(Playback.formatSpeed(0.25) == "0.25×")
    #expect(Playback.formatSpeed(1) == "1×")
    #expect(Playback.formatSpeed(1.5) == "1.5×")
    #expect(Playback.formatSpeed(128) == "128×")
  }
}

@MainActor struct PlaybackSpeedPreferenceTests {
  private func preservingDefaults(_ body: () -> Void) {
    let keys = ["offlinePlaybackSpeed", "onlinePlaybackSpeed"]
    let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
    defer { for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) } }
    body()
  }

  @Test func availableSpeedsFollowSource() {
    let p = Playback()
    p.isOffline = true
    #expect(p.availableSpeeds() == Playback.offlineSpeedOptions)
    p.isOffline = false
    #expect(p.availableSpeeds() == Playback.onlineSpeedOptions)
  }

  @Test func setSpeedClampsAndStoresPerSource() {
    preservingDefaults {
      let p = Playback()
      p.isOffline = true
      p.setSpeed(200)
      #expect(p.speed == 128)
      #expect(UserDefaults.standard.float(forKey: "offlinePlaybackSpeed") == 128)

      p.isOffline = false
      p.setSpeed(16)
      #expect(p.speed == 8)
      #expect(UserDefaults.standard.float(forKey: "onlinePlaybackSpeed") == 8)
      #expect(UserDefaults.standard.float(forKey: "offlinePlaybackSpeed") == 128)
    }
  }

  @Test func setSpeedKeepsTemporaryBoostRate() {
    preservingDefaults {
      let p = Playback()
      p.isOffline = true
      p.isBoosting = true
      p.setSpeed(16)
      #expect(p.speed == 16)
      #expect(p.player.rate == 0)
    }
  }
}
