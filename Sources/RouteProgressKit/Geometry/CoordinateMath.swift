import Foundation

extension RouteCoordinate {
    private static let earthRadiusMeters = 6_371_000.0

    /// Returns the haversine distance to another coordinate in meters.
    public func distance(to other: RouteCoordinate) -> Double {
        let latitude1 = latitude.radians
        let latitude2 = other.latitude.radians
        let deltaLatitude = (other.latitude - latitude).radians
        let deltaLongitude = (other.longitude - longitude).radians

        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return Self.earthRadiusMeters * c
    }

    func interpolated(to other: RouteCoordinate, fraction: Double) -> RouteCoordinate {
        let clamped = min(max(fraction, 0), 1)
        return RouteCoordinate(
            latitude: latitude + (other.latitude - latitude) * clamped,
            longitude: longitude + (other.longitude - longitude) * clamped
        )
    }

    func projectedMeters(relativeTo origin: RouteCoordinate) -> Point2D {
        let latitudeScale = Double.pi / 180 * Self.earthRadiusMeters
        let longitudeScale = latitudeScale * cos(origin.latitude.radians)
        return Point2D(
            x: (longitude - origin.longitude) * longitudeScale,
            y: (latitude - origin.latitude) * latitudeScale
        )
    }
}

struct Point2D: Sendable {
    var x: Double
    var y: Double

    static func - (lhs: Point2D, rhs: Point2D) -> Point2D {
        Point2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    var squaredLength: Double {
        x * x + y * y
    }

    func dot(_ other: Point2D) -> Double {
        x * other.x + y * other.y
    }
}

extension Double {
    var radians: Double {
        self * .pi / 180
    }
}
