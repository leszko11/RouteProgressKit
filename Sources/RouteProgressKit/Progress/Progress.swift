import Foundation

/// Current user/activity location input for progress calculation.
public struct CurrentRouteLocation: Equatable, Sendable {
    /// Current geographic coordinate.
    public var coordinate: RouteCoordinate

    /// Timestamp for the current location.
    public var timestamp: Date?

    /// Activity start date, used for elapsed pace and duration-based cutoffs.
    public var activityStartDate: Date?

    /// Current speed in meters per second, when available.
    public var currentSpeed: Double?

    /// Creates current route location input.
    public init(
        coordinate: RouteCoordinate,
        timestamp: Date? = nil,
        activityStartDate: Date? = nil,
        currentSpeed: Double? = nil
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.activityStartDate = activityStartDate
        self.currentSpeed = currentSpeed
    }
}

/// A rich progress snapshot for a route plan.
public struct RouteProgress: Equatable, Sendable {
    /// Progress fraction from `0.0` to `1.0`.
    public var progressFraction: Double

    /// Distance from route start in meters.
    public var distanceFromStart: Double

    /// Distance remaining to finish in meters.
    public var distanceRemaining: Double

    /// Total route distance in meters.
    public var totalRouteDistance: Double

    /// Full location match for the current coordinate.
    public var locationMatch: LocationMatch

    /// Nearest source route point.
    public var nearestRoutePoint: RoutePoint

    /// Projected point on the route polyline.
    public var projectedPoint: ProjectedRoutePoint

    /// Nearest elevation profile sample.
    public var elevationSample: ElevationSample?

    /// Interpolated elevation at the current projected route position.
    public var elevationAtCurrentPosition: Double?

    /// Off-route distance in meters.
    public var offRouteDistance: Double

    /// Current route segment index.
    public var segmentIndex: Int

    /// Current nearest route point index.
    public var routePointIndex: Int

    /// Next waypoint after the current route position.
    public var nextWaypoint: RouteWaypoint?

    /// Distance to the next waypoint in meters.
    public var distanceToNextWaypoint: Double?

    /// ETA to the next waypoint.
    public var etaToNextWaypoint: ETAEstimate?

    /// Estimated arrival at the next waypoint.
    public var estimatedArrivalAtNextWaypoint: Date?

    /// Cutoff status for the next waypoint.
    public var nextWaypointCutoffStatus: CutoffStatus?

    /// Distance to finish in meters.
    public var distanceToFinish: Double

    /// ETA to finish.
    public var etaToFinish: ETAEstimate?

    /// Estimated finish time.
    public var estimatedFinishTime: Date?

    /// Cutoff status for finish.
    public var finishCutoffStatus: CutoffStatus?
}

/// Calculates progress for a route plan.
public struct RouteProgressCalculator: Sendable {
    /// Route plan to evaluate.
    public var plan: RoutePlan

    /// Threshold before cutoff where a target becomes at risk.
    public var cutoffWarningThreshold: TimeInterval

    /// Creates a progress calculator.
    public init(plan: RoutePlan, cutoffWarningThreshold: TimeInterval = 15 * 60) {
        self.plan = plan
        self.cutoffWarningThreshold = cutoffWarningThreshold
    }

    /// Calculates progress for a current location.
    public func progress(for currentLocation: CurrentRouteLocation) throws -> RouteProgress {
        guard let match = plan.route.polyline.nearestPoint(to: currentLocation.coordinate) else {
            throw RouteProgressError.insufficientRoutePoints
        }

        let distanceFromStart = match.projectedPoint.distanceFromStart
        let totalDistance = plan.route.totalDistance
        let distanceRemaining = max(totalDistance - distanceFromStart, 0)
        let progressFraction = totalDistance > 0 ? min(max(distanceFromStart / totalDistance, 0), 1) : 1

        let nextWaypoint = plan.nextWaypoint(after: distanceFromStart)
        let distanceToNextWaypoint = nextWaypoint?.distanceAlongRoute.map {
            max($0 - distanceFromStart, 0)
        }
        let etaToNextWaypoint = distanceToNextWaypoint.map {
            estimateETA(distance: $0, progressDistance: distanceFromStart, currentLocation: currentLocation)
        }
        let etaToFinish = estimateETA(
            distance: distanceRemaining,
            progressDistance: distanceFromStart,
            currentLocation: currentLocation
        )

        let nextCutoffStatus = nextWaypoint.map { waypoint in
            CutoffStatus.evaluate(
                cutoff: waypoint.cutoff,
                eta: etaToNextWaypoint,
                activityStartDate: currentLocation.activityStartDate,
                currentTimestamp: currentLocation.timestamp,
                warningThreshold: cutoffWarningThreshold
            )
        }

        let finishCutoffStatus = CutoffStatus.evaluate(
            cutoff: plan.finishCutoff,
            eta: etaToFinish,
            activityStartDate: currentLocation.activityStartDate,
            currentTimestamp: currentLocation.timestamp,
            warningThreshold: cutoffWarningThreshold
        )

        return RouteProgress(
            progressFraction: progressFraction,
            distanceFromStart: distanceFromStart,
            distanceRemaining: distanceRemaining,
            totalRouteDistance: totalDistance,
            locationMatch: match,
            nearestRoutePoint: match.nearestSourcePoint,
            projectedPoint: match.projectedPoint,
            elevationSample: plan.route.elevationProfile.sample(atDistance: distanceFromStart),
            elevationAtCurrentPosition: plan.route.elevationProfile.elevation(atDistance: distanceFromStart),
            offRouteDistance: match.offRouteDistance,
            segmentIndex: match.projectedPoint.segmentIndex,
            routePointIndex: match.nearestSourcePoint.index,
            nextWaypoint: nextWaypoint,
            distanceToNextWaypoint: distanceToNextWaypoint,
            etaToNextWaypoint: etaToNextWaypoint,
            estimatedArrivalAtNextWaypoint: etaToNextWaypoint?.estimatedArrivalDate,
            nextWaypointCutoffStatus: nextCutoffStatus,
            distanceToFinish: distanceRemaining,
            etaToFinish: etaToFinish,
            estimatedFinishTime: etaToFinish.estimatedArrivalDate,
            finishCutoffStatus: finishCutoffStatus
        )
    }

    /// Calculates progress for a coordinate and optional activity context.
    public func progress(
        at coordinate: RouteCoordinate,
        timestamp: Date? = nil,
        activityStartDate: Date? = nil,
        currentSpeed: Double? = nil
    ) throws -> RouteProgress {
        try progress(
            for: CurrentRouteLocation(
                coordinate: coordinate,
                timestamp: timestamp,
                activityStartDate: activityStartDate,
                currentSpeed: currentSpeed
            )
        )
    }

    private func estimateETA(
        distance: Double,
        progressDistance: Double,
        currentLocation: CurrentRouteLocation
    ) -> ETAEstimate {
        guard distance > 0 else {
            return .available(duration: 0, from: currentLocation.timestamp, basis: .currentSpeed)
        }

        if let currentSpeed = currentLocation.currentSpeed, currentSpeed > 0 {
            return .available(duration: distance / currentSpeed, from: currentLocation.timestamp, basis: .currentSpeed)
        }

        if let timestamp = currentLocation.timestamp,
           let startDate = currentLocation.activityStartDate,
           progressDistance > 0 {
            let elapsed = timestamp.timeIntervalSince(startDate)
            if elapsed > 0 {
                let metersPerSecond = progressDistance / elapsed
                if metersPerSecond > 0 {
                    return .available(duration: distance / metersPerSecond, from: timestamp, basis: .elapsedPace)
                }
            }
        }

        return .unavailable(.missingPaceBasis)
    }
}
