#if os(iOS)
  import AVFoundation
  import Foundation
  import Observation
  import TollCore

  /// Before bed's breathing tone (D80): a soft sine made on the phone, nothing loaded or fetched.
  /// The person asked for it, so it plays as a timer does: through the silent switch, on with the
  /// screen locked (the background audio mode), and other audio pauses until it ends. It rises and
  /// falls with `Breath` and fades away at the end. No visual pacer anywhere.
  @MainActor
  @Observable
  public final class BreathTone {
    public static let shared = BreathTone()

    /// When the tone ends, while it plays; nil once it has stopped.
    public private(set) var endsAt: Date?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var ending: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    private init() {}

    public var playing: Bool { endsAt != nil }

    /// Starts the tone from the bottom of a breath; a tone already playing starts over.
    public func start(_ breath: Breath, config: TollConfig.Helpers = TollConfig.defaults.helpers) {
      halt()
      let session = AVAudioSession.sharedInstance()
      do {
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
      } catch {
        return
      }
      let engine = AVAudioEngine()
      let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
      guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
      else { return }
      let tone = ToneGenerator(
        breath: breath, low: config.lowHz, high: config.highHz, loudness: config.loudness,
        rate: rate)
      let source = Self.source(tone, format: format)
      engine.attach(source)
      engine.connect(source, to: engine.mainMixerNode, format: format)
      do {
        try engine.start()
      } catch {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        return
      }
      self.engine = engine
      endsAt = Date().addingTimeInterval(breath.length)
      // The tone's own fade ends it; this lets the engine and the session go after.
      ending = Task { [weak self] in
        try? await Task.sleep(for: .seconds(breath.length + 0.5))
        guard !Task.isCancelled else { return }
        self?.halt()
      }
      // A call or an alarm takes the audio, and headphones coming out stop the engine: either way
      // the tone ends there and doesn't come back.
      let watched: [(Notification.Name, AnyObject)] = [
        (AVAudioSession.interruptionNotification, session),
        (Notification.Name.AVAudioEngineConfigurationChange, engine),
      ]
      observers = watched.map { name, object in
        NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) {
          [weak self] _ in
          MainActor.assumeIsolated { self?.halt() }
        }
      }
    }

    /// "Stop the tone": a short fade, never a click.
    public func stop() {
      guard let engine else { return }
      ending?.cancel()
      ending = Task { [weak self] in
        for step in stride(from: 9, through: 0, by: -1) {
          engine.mainMixerNode.outputVolume = Float(step) / 10
          try? await Task.sleep(for: .milliseconds(40))
        }
        self?.halt()
      }
    }

    private func halt() {
      ending?.cancel()
      ending = nil
      for observer in observers { NotificationCenter.default.removeObserver(observer) }
      observers = []
      guard let engine else { return }
      engine.stop()
      self.engine = nil
      endsAt = nil
      try? AVAudioSession.sharedInstance().setActive(
        false, options: .notifyOthersOnDeactivation)
    }

    /// Made outside the main actor: the render block runs on the audio thread, and a closure
    /// formed on the main actor would be checked for it there.
    private nonisolated static func source(_ tone: ToneGenerator, format: AVAudioFormat)
      -> AVAudioSourceNode
    {
      AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
        tone.render(Int(frameCount), into: UnsafeMutableAudioBufferListPointer(audioBufferList))
        return noErr
      }
    }
  }

  /// The sine itself, one sample at a time, following the breath's pitch and loudness. Unchecked
  /// Sendable: once the engine starts, only the render thread touches its counters.
  private final class ToneGenerator: @unchecked Sendable {
    let breath: Breath
    let low: Double
    let high: Double
    let loudness: Double
    let rate: Double
    private var frame = 0
    private var phase = 0.0

    init(breath: Breath, low: Double, high: Double, loudness: Double, rate: Double) {
      self.breath = breath
      self.low = low
      self.high = high
      self.loudness = loudness
      self.rate = rate
    }

    func render(_ frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
      for index in 0..<frames {
        let seconds = Double(frame) / rate
        let hertz = low + (high - low) * breath.pitch(at: seconds)
        // The phase carries on as the pitch moves, so the glide has no steps.
        phase += 2 * .pi * hertz / rate
        if phase >= 2 * .pi { phase -= 2 * .pi }
        let sample = Float(sin(phase) * breath.gain(at: seconds) * loudness)
        for buffer in buffers {
          buffer.mData?.assumingMemoryBound(to: Float.self)[index] = sample
        }
        frame += 1
      }
    }
  }
#endif
