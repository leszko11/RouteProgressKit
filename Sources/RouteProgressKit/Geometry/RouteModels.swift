import Foundation

/// A geographic coordinate in decimal degrees.
public struct RouteCoordinate: Equatable, Hashable, Sendable {
    /// Latitude in decimal degrees.
    public var latitude: Double

    /// Longitude in decimal degrees.
    public var longitude: Double

    /// Creates a route coordinate.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A source point from a route, usually parsed from GPX.
public struct RoutePoint: Equatable, Sendable {
    /// Coordinate of this source point.
    public var coordinate: RouteCoordinate

    /// Elevation in meters, if the source contains one.
    public var elevation: Double?

    /// Timestamp associated with this point, if present in the source.
    public var timestamp: Date?

    /// Index of this point in the normalized route.
    public var index: Int

    /// Distance in meters from the beginning of the route.
    public var distanceFromStart: Double

    /// Creates a route point.
    public init(
        coordinate: RouteCoordinate,
        elevation: Double? = nil,
        timestamp: Date? = nil,
        index: Int = 0,
        distanceFromStart: Double = 0
    ) {
        self.coordinate = coordinate
        self.elevation = elevation
        self.timestamp = timestamp
        self.index = index
        self.distanceFromStart = distanceFromStart
    }
}

/// Geographic bounds for a route.
public struct RouteBounds: Equatable, Sendable {
    /// Minimum latitude in the route.
    public var minLatitude: Double

    /// Maximum latitude in the route.
    public var maxLatitude: Double

    /// Minimum longitude in the route.
    public var minLongitude: Double

    /// Maximum longitude in the route.
    public var maxLongitude: Double

    /// Center coordinate of the bounds.
    public var center: RouteCoordinate {
        RouteCoordinate(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
    }
}

/// A normalized route with geometry and elevation helpers.
public struct Route: Equatable, Sendable {
    /// Optional route name, such as the GPX track name.
    public var name: String?

    /// Ordered route points with normalized indexes and cumulative distance.
    public var points: [RoutePoint]

    /// Total route distance in meters.
    public var totalDistance: Double

    /// Bounds of the route, or `nil` when the route has no points.
    public var bounds: RouteBounds?

    /// Polyline operations for this route.
    public var polyline: RoutePolyline {
        RoutePolyline(points: points)
    }

    /// Elevation profile derived from source route points.
    public var elevationProfile: ElevationProfile {
        ElevationProfile(points: points)
    }

    /// Creates and normalizes a route.
    public init(name: String? = nil, points: [RoutePoint]) throws {
        guard !points.isEmpty else {
            throw RouteProgressError.emptyRoute
        }

        self.name = name

        var normalized: [RoutePoint] = []
        normalized.reserveCapacity(points.count)
        var distance: Double = 0

        for (index, point) in points.enumerated() {
            if let previous = normalized.last {
                distance += previous.coordinate.distance(to: point.coordinate)
            }
            normalized.append(
                RoutePoint(
                    coordinate: point.coordinate,
                    elevation: point.elevation,
                    timestamp: point.timestamp,
                    index: index,
                    distanceFromStart: distance
                )
            )
        }

        self.points = normalized
        self.totalDistance = distance
        self.bounds = Self.makeBounds(for: normalized)
    }

    private static func makeBounds(for points: [RoutePoint]) -> RouteBounds? {
        guard let first = points.first else { return nil }

        var minLatitude = first.coordinate.latitude
        var maxLatitude = first.coordinate.latitude
        var minLongitude = first.coordinate.longitude
        var maxLongitude = first.coordinate.longitude

        for point in points.dropFirst() {
            minLatitude = min(minLatitude, point.coordinate.latitude)
            maxLatitude = max(maxLatitude, point.coordinate.latitude)
            minLongitude = min(minLongitude, point.coordinate.longitude)
            maxLongitude = max(maxLongitude, point.coordinate.longitude)
        }

        return RouteBounds(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude
        )
    }
}

/// Errors thrown by route construction and progress calculations.
public enum RouteProgressError: Error, Equatable, Sendable {
    /// A route operation was requested for an empty route.
    case emptyRoute

    /// A route needs at least two points for the requested geometry operation.
    case insufficientRoutePoints

    /// A waypoint could not be projected onto the route.
    case waypointProjectionFailed(id: String)
}
