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
  private var transcriptionTask: Task<LocalScriptRunResult, Never>?
  private var operationID: UUID?

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
    cancel()
    let startID = UUID()
    operationID = startID
    let hasAccess = await Self.requestMicrophoneAccess()
    guard operationID == startID else {
      return "Dictation cancelled."
    }
    guard hasAccess else {
      operationID = nil
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
      operationID = nil
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
    phase = .transcribing

    let audioPath = recordingURL.path
    let currentOperationID = operationID
    let task = Task {
      await LocalScriptRunner.runAsync(
        repoRelativePath: "scripts/transcribe_faster_whisper.sh",
        arguments: [audioPath],
        timeout: 180
      )
    }
    transcriptionTask = task
    let runResult = await task.value
    try? FileManager.default.removeItem(atPath: audioPath)
    guard operationID == currentOperationID else {
      return "ERROR: Dictation cancelled."
    }
    transcriptionTask = nil
    operationID = nil
    self.recordingURL = nil
    if runResult.wasCancelled {
      phase = .idle
      return "ERROR: Dictation cancelled."
    }
    let result = runResult.displayText
    if result.hasPrefix("ERROR:") {
      phase = .error(String(result.dropFirst("ERROR:".count)).trimmed)
    } else {
      phase = .idle
    }
    return result
  }

  func cancel() {
    recorder?.stop()
    recorder = nil
    transcriptionTask?.cancel()
    transcriptionTask = nil
    if let recordingURL {
      try? FileManager.default.removeItem(at: recordingURL)
    }
    recordingURL = nil
    operationID = nil
    phase = .idle
  }

  private static func requestMicrophoneAccess() async -> Bool {
    await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        continuation.resume(returning: granted)
      }
    }
  }
}
