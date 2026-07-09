import AVFoundation
import Foundation

@MainActor
final class DictationController: NSObject, ObservableObject {
  enum Phase: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)
  }

  @Published private(set) var phase: Phase = .idle

  private var recorder: AVAudioRecorder?
  private var recordingURL: URL?

  var isRecording: Bool {
    phase == .recording
  }

  var isTranscribing: Bool {
    phase == .transcribing
  }

  var statusText: String {
    switch phase {
    case .idle:
      return ""
    case .recording:
      return "Recording"
    case .transcribing:
      return "Transcribing"
    case .error(let message):
      return message
    }
  }

  func start() async -> String? {
    phase = .idle
    let hasAccess = await Self.requestMicrophoneAccess()
    guard hasAccess else {
      phase = .error("Microphone access is off.")
      return "Microphone access is off."
    }

    do {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobmaxxing-dictation-\(UUID().uuidString)")
        .appendingPathExtension("m4a")
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]
      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.isMeteringEnabled = true
      recorder.record()
      self.recorder = recorder
      recordingURL = url
      phase = .recording
      return nil
    } catch {
      recorder = nil
      recordingURL = nil
      let message = "Dictation could not start: \(error.localizedDescription)"
      phase = .error(message)
      return message
    }
  }

  func stopAndTranscribe() async -> String {
    guard let recorder, let recordingURL else {
      phase = .error("No active recording.")
      return "ERROR: No active recording."
    }

    recorder.stop()
    self.recorder = nil
    self.recordingURL = nil
    phase = .transcribing

    let audioPath = recordingURL.path
    let result = await Task.detached(priority: .userInitiated) {
      defer {
        try? FileManager.default.removeItem(atPath: audioPath)
      }
      return LocalScriptRunner.run(repoRelativePath: "scripts/transcribe_faster_whisper.sh", arguments: [audioPath], timeout: 180)
    }.value
    if result.hasPrefix("ERROR:") {
      phase = .error(String(result.dropFirst("ERROR:".count)).trimmed)
    } else {
      phase = .idle
    }
    return result
  }

  private static func requestMicrophoneAccess() async -> Bool {
    await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        continuation.resume(returning: granted)
      }
    }
  }
}
