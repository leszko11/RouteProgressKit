import Foundation

/// A cutoff or time limit for a waypoint or finish.
public enum Cutoff: Equatable, Sendable {
    /// Cutoff at an absolute date.
    case absolute(Date)

    /// Cutoff as a duration from activity start.
    case durationFromStart(TimeInterval)

    /// Cutoff represented both ways.
    case absoluteAndDuration(Date, TimeInterval)

    /// Resolves the cutoff date when enough context is available.
    public func resolvedDate(activityStartDate: Date?) -> Date? {
        switch self {
        case let .absolute(date):
            return date
        case let .durationFromStart(duration):
            return activityStartDate?.addingTimeInterval(duration)
        case let .absoluteAndDuration(date, _):
            return date
        }
    }

    /// Returns the duration from start when this cutoff carries one.
    public var durationFromStart: TimeInterval? {
        switch self {
        case .absolute:
            return nil
        case let .durationFromStart(duration):
            return duration
        case let .absoluteAndDuration(_, duration):
            return duration
        }
    }
}

/// Strategy used to calculate an ETA.
public enum ETABasis: Equatable, Sendable {
    /// ETA based on provided current speed.
    case currentSpeed

    /// ETA based on elapsed activity pace.
    case elapsedPace
}

/// Reason an ETA could not be calculated.
public enum ETAUnavailableReason: Equatable, Sendable {
    /// No speed, start date, or timestamp was available.
    case missingPaceBasis

    /// Distance was not positive.
    case nonPositiveDistance
}

/// A typed ETA result.
public struct ETAEstimate: Equatable, Sendable {
    /// Estimated duration from the current position.
    public var duration: TimeInterval?

    /// Estimated arrival date, when current time is known.
    public var estimatedArrivalDate: Date?

    /// Basis used for the estimate.
    public var basis: ETABasis?

    /// Reason the estimate is unavailable.
    public var unavailableReason: ETAUnavailableReason?

    /// Creates an available ETA.
    public static func available(duration: TimeInterval, from timestamp: Date?, basis: ETABasis) -> ETAEstimate {
        ETAEstimate(
            duration: duration,
            estimatedArrivalDate: timestamp?.addingTimeInterval(duration),
            basis: basis,
            unavailableReason: nil
        )
    }

    /// Creates an unavailable ETA.
    public static func unavailable(_ reason: ETAUnavailableReason) -> ETAEstimate {
        ETAEstimate(
            duration: nil,
            estimatedArrivalDate: nil,
            basis: nil,
            unavailableReason: reason
        )
    }
}

/// Cutoff classification.
public enum CutoffState: Equatable, Sendable {
    /// No cutoff is configured.
    case none

    /// Cutoff exists, but ETA or timing context is missing.
    case unknown

    /// ETA is comfortably before cutoff.
    case onTrack

    /// ETA is close to the cutoff threshold.
    case atRisk

    /// The cutoff has been missed or ETA is after cutoff.
    case missed
}

/// Status of progress against a cutoff.
public struct CutoffStatus: Equatable, Sendable {
    /// Current cutoff state.
    public var state: CutoffState

    /// Resolved cutoff date, when available.
    public var cutoffDate: Date?

    /// Time remaining until cutoff from the current timestamp.
    public var timeRemaining: TimeInterval?

    /// ETA minus cutoff. Positive means projected arrival is late.
    public var etaDelta: TimeInterval?

    /// Evaluates a cutoff.
    public static func evaluate(
        cutoff: Cutoff?,
        eta: ETAEstimate?,
        activityStartDate: Date?,
        currentTimestamp: Date?,
        warningThreshold: TimeInterval
    ) -> CutoffStatus {
        guard let cutoff else {
            return CutoffStatus(state: .none, cutoffDate: nil, timeRemaining: nil, etaDelta: nil)
        }

        let cutoffDate = cutoff.resolvedDate(activityStartDate: activityStartDate)
        let timeRemaining = currentTimestamp.flatMap { current in
            cutoffDate.map { $0.timeIntervalSince(current) }
        }

        if let timeRemaining, timeRemaining < 0 {
            return CutoffStatus(state: .missed, cutoffDate: cutoffDate, timeRemaining: timeRemaining, etaDelta: nil)
        }

        guard let eta, eta.unavailableReason == nil else {
            return CutoffStatus(state: .unknown, cutoffDate: cutoffDate, timeRemaining: timeRemaining, etaDelta: nil)
        }

        let etaDelta: TimeInterval?
        if let estimatedArrivalDate = eta.estimatedArrivalDate, let cutoffDate {
            etaDelta = estimatedArrivalDate.timeIntervalSince(cutoffDate)
        } else if let duration = eta.duration, let remaining = timeRemaining {
            etaDelta = duration - remaining
        } else if let duration = eta.duration, let cutoffDuration = cutoff.durationFromStart,
                  let currentTimestamp, let activityStartDate {
            let elapsed = currentTimestamp.timeIntervalSince(activityStartDate)
            etaDelta = elapsed + duration - cutoffDuration
        } else {
            etaDelta = nil
        }

        guard let etaDelta else {
            return CutoffStatus(state: .unknown, cutoffDate: cutoffDate, timeRemaining: timeRemaining, etaDelta: nil)
        }

        if etaDelta > 0 {
            return CutoffStatus(state: .missed, cutoffDate: cutoffDate, timeRemaining: timeRemaining, etaDelta: etaDelta)
        }
        if abs(etaDelta) <= warningThreshold {
            return CutoffStatus(state: .atRisk, cutoffDate: cutoffDate, timeRemaining: timeRemaining, etaDelta: etaDelta)
        }
        return CutoffStatus(state: .onTrack, cutoffDate: cutoffDate, timeRemaining: timeRemaining, etaDelta: etaDelta)
    }
}
