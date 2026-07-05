import Foundation

/// Semantic kind for a route waypoint.
public enum WaypointKind: String, Equatable, Hashable, Sendable {
    /// Aid station or refreshment point.
    case aidStation

    /// Checkpoint or timing point.
    case checkpoint

    /// Water-only point.
    case water

    /// Food point.
    case food

    /// Summit or high point.
    case summit

    /// Generic custom waypoint.
    case custom
}

/// A waypoint associated with a route.
public struct RouteWaypoint: Equatable, Sendable {
    /// Stable waypoint identifier.
    public var id: String

    /// Display name.
    public var name: String

    /// Geographic waypoint coordinate.
    public var coordinate: RouteCoordinate

    /// Waypoint kind.
    public var kind: WaypointKind

    /// Distance in meters along the route, if known or projected.
    public var distanceAlongRoute: Double?

    /// Optional cutoff for this waypoint.
    public var cutoff: Cutoff?

    /// App-defined metadata.
    public var metadata: [String: String]

    /// Creates a waypoint.
    public init(
        id: String,
        name: String,
        coordinate: RouteCoordinate,
        kind: WaypointKind = .custom,
        distanceAlongRoute: Double? = nil,
        cutoff: Cutoff? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.kind = kind
        self.distanceAlongRoute = distanceAlongRoute
        self.cutoff = cutoff
        self.metadata = metadata
    }
}

/// A route plus optional waypoints and finish cutoff.
public struct RoutePlan: Equatable, Sendable {
    /// Route being followed.
    public var route: Route

    /// Waypoints sorted by distance along the route.
    public var waypoints: [RouteWaypoint]

    /// Optional finish cutoff.
    public var finishCutoff: Cutoff?

    /// Creates a route plan and projects waypoints without a known distance.
    public init(
        route: Route,
        waypoints: [RouteWaypoint] = [],
        finishCutoff: Cutoff? = nil
    ) throws {
        self.route = route
        self.finishCutoff = finishCutoff

        self.waypoints = try waypoints.map { waypoint in
            if waypoint.distanceAlongRoute != nil {
                return waypoint
            }

            guard let match = route.polyline.nearestPoint(to: waypoint.coordinate) else {
                throw RouteProgressError.waypointProjectionFailed(id: waypoint.id)
            }

            var projected = waypoint
            projected.distanceAlongRoute = match.projectedPoint.distanceFromStart
            return projected
        }
        .sorted {
            ($0.distanceAlongRoute ?? .greatestFiniteMagnitude) < ($1.distanceAlongRoute ?? .greatestFiniteMagnitude)
        }
    }

    /// Returns the next waypoint after a route distance.
    public func nextWaypoint(after distanceFromStart: Double) -> RouteWaypoint? {
        waypoints.first { ($0.distanceAlongRoute ?? .greatestFiniteMagnitude) > distanceFromStart }
    }
}
