import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import QuartzCore
#endif

/// Vsync-aligned display frame tick delivered by the hardware refresh clock.
public struct DisplayFrameTick: Sendable {
  /// Target presentation timestamp in seconds (platform display link time base).
  public let targetTimestamp: Double
  /// Elapsed seconds since the previous frame.
  public let deltaTime: Double

  /// Creates a display frame tick.
  public init(targetTimestamp: Double, deltaTime: Double) {
    self.targetTimestamp = targetTimestamp
    self.deltaTime = deltaTime
  }
}

/// Drives high-frequency display updates decoupled from the physics simulation tick.
@MainActor
public final class SimulationDisplayClock {
  private var lastTargetTimestamp: CFTimeInterval?
  private var frameHandler: ((DisplayFrameTick) -> Void)?

#if os(iOS) || os(tvOS) || os(visionOS)
  private var displayLink: CADisplayLink?
#else
  private var displayTask: Task<Void, Never>?
#endif

  /// Target display refresh rate in hertz.
  public var targetFrameRate: Int = 60

  /// Creates a simulation display clock.
  public init() {}

  /// Starts invoking `onFrame` at the display refresh rate with vsync-aligned timestamps.
  public func start(onFrame: @escaping (DisplayFrameTick) -> Void) {
    stop()
    frameHandler = onFrame
    lastTargetTimestamp = nil

#if os(iOS) || os(tvOS) || os(visionOS)
    let link = CADisplayLink(target: DisplayLinkTarget { [weak self] link in
      self?.handleDisplayLinkTick(link)
    }, selector: #selector(DisplayLinkTarget.tick))
    link.preferredFrameRateRange = CAFrameRateRange(
      minimum: Float(targetFrameRate),
      maximum: Float(max(targetFrameRate, 120)),
      preferred: Float(targetFrameRate)
    )
    link.add(to: .main, forMode: .common)
    displayLink = link
#else
    startDisplayTaskLoop()
#endif
  }

  /// Stops display frame callbacks.
  public func stop() {
#if os(iOS) || os(tvOS) || os(visionOS)
    displayLink?.invalidate()
    displayLink = nil
#else
    displayTask?.cancel()
    displayTask = nil
#endif
    lastTargetTimestamp = nil
    frameHandler = nil
  }

  fileprivate func deliverFrame(targetTimestamp: CFTimeInterval) {
    let delta: Double
    if let lastTargetTimestamp {
      delta = max(0, targetTimestamp - lastTargetTimestamp)
    } else {
      delta = 1.0 / Double(max(targetFrameRate, 1))
    }
    lastTargetTimestamp = targetTimestamp
    let tick = DisplayFrameTick(targetTimestamp: targetTimestamp, deltaTime: delta)
    frameHandler?(tick)
  }

#if os(iOS) || os(tvOS) || os(visionOS)
  private func handleDisplayLinkTick(_ link: CADisplayLink) {
    deliverFrame(targetTimestamp: link.targetTimestamp)
  }
#else
  private func startDisplayTaskLoop() {
    let interval = Duration.milliseconds(max(1, 1_000 / max(targetFrameRate, 1)))
    displayTask = Task { [weak self] in
      while !Task.isCancelled {
        let now = CFAbsoluteTimeGetCurrent()
        await MainActor.run {
          self?.deliverFrame(targetTimestamp: now)
        }
        try? await Task.sleep(for: interval)
      }
    }
  }
#endif
}

#if os(iOS) || os(tvOS) || os(visionOS)
private final class DisplayLinkTarget: NSObject {
  private let handler: (CADisplayLink) -> Void

  init(handler: @escaping (CADisplayLink) -> Void) {
    self.handler = handler
  }

  @objc func tick(link: CADisplayLink) {
    handler(link)
  }
}
#endif
