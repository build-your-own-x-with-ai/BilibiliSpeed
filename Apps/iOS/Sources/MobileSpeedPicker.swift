import SwiftUI

/// iOS/iPadOS speed selection picker
struct MobileSpeedPicker: View {
  let playback: Playback
  @Environment(\.dismiss) private var dismiss
  @State private var speeds: [Float] = []

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(speeds, id: \.self) { speed in
            Button {
              playback.setSpeed(speed)
              dismiss()
            } label: {
              HStack {
                Text(Playback.formatSpeed(speed))
                  .foregroundStyle(.primary)
                Spacer()
                if playback.speed == speed {
                  Image(systemName: "checkmark")
                    .foregroundStyle(.pink)
                }
              }
            }
          }
        } header: {
          Text("选择播放速度")
        } footer: {
          if !playback.isOffline {
            Text("在线播放速度限制为 2×")
          }
        }
      }
      .navigationTitle("播放速度")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
        }
      }
    }
    .onAppear {
      speeds = playback.availableSpeeds()
    }
    .onChange(of: playback.isOffline) { _, _ in
      speeds = playback.availableSpeeds()
    }
  }
}
