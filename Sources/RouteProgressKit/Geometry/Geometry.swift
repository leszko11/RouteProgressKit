import Foundation

/// A projected point on a route polyline.
public struct ProjectedRoutePoint: Equatable, Sendable {
    /// Coordinate on the route polyline.
    public var coordinate: RouteCoordinate

    /// Distance in meters from the route start.
    public var distanceFromStart: Double

    /// Index of the source segment containing the projected point.
    public var segmentIndex: Int

    /// Fraction from the segment start to segment end.
    public var fractionAlongSegment: Double

    /// Interpolated elevation at this projected point, when available.
    public var elevation: Double?
}

/// A match from an arbitrary coordinate to a route.
public struct LocationMatch: Equatable, Sendable {
    /// Nearest source route point.
    public var nearestSourcePoint: RoutePoint

    /// Nearest projected point on the route polyline.
    public var projectedPoint: ProjectedRoutePoint

    /// Distance in meters from the input coordinate to the projected point.
    public var offRouteDistance: Double
}

/// Geometry operations for a route polyline.
public struct RoutePolyline: Equatable, Sendable {
    /// Source points for the polyline.
    public var points: [RoutePoint]

    /// Creates a route polyline.
    public init(points: [RoutePoint]) {
        self.points = points
    }

    /// Returns the interpolated point at a distance from the route start.
    public func point(atDistance distance: Double) -> ProjectedRoutePoint? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else {
            return ProjectedRoutePoint(
                coordinate: first.coordinate,
                distanceFromStart: 0,
                segmentIndex: 0,
                fractionAlongSegment: 0,
                elevation: first.elevation
            )
        }

        if distance <= 0 {
            return ProjectedRoutePoint(
                coordinate: first.coordinate,
                distanceFromStart: 0,
                segmentIndex: 0,
                fractionAlongSegment: 0,
                elevation: first.elevation
            )
        }

        guard let last = points.last else { return nil }
        if distance >= last.distanceFromStart {
            return ProjectedRoutePoint(
                coordinate: last.coordinate,
                distanceFromStart: last.distanceFromStart,
                segmentIndex: max(points.count - 2, 0),
                fractionAlongSegment: 1,
                elevation: last.elevation
            )
        }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            guard distance <= end.distanceFromStart else { continue }

            let segmentLength = end.distanceFromStart - start.distanceFromStart
            let fraction = segmentLength > 0 ? (distance - start.distanceFromStart) / segmentLength : 0
            return ProjectedRoutePoint(
                coordinate: start.coordinate.interpolated(to: end.coordinate, fraction: fraction),
                distanceFromStart: distance,
                segmentIndex: index,
                fractionAlongSegment: fraction,
                elevation: interpolateElevation(start: start.elevation, end: end.elevation, fraction: fraction)
            )
        }

        return nil
    }

    /// Finds the nearest source point and nearest projected point for a coordinate.
    public func nearestPoint(to coordinate: RouteCoordinate) -> LocationMatch? {
        guard let first = points.first else { return nil }

        let nearestSource = points.min {
            $0.coordinate.distance(to: coordinate) < $1.coordinate.distance(to: coordinate)
        } ?? first

        guard points.count > 1 else {
            return LocationMatch(
                nearestSourcePoint: nearestSource,
                projectedPoint: ProjectedRoutePoint(
                    coordinate: first.coordinate,
                    distanceFromStart: 0,
                    segmentIndex: 0,
                    fractionAlongSegment: 0,
                    elevation: first.elevation
                ),
                offRouteDistance: first.coordinate.distance(to: coordinate)
            )
        }

        var bestProjectedPoint: ProjectedRoutePoint?
        var bestDistance = Double.greatestFiniteMagnitude

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let origin = start.coordinate
            let startPoint = Point2D(x: 0, y: 0)
            let endPoint = end.coordinate.projectedMeters(relativeTo: origin)
            let targetPoint = coordinate.projectedMeters(relativeTo: origin)
            let segment = endPoint - startPoint
            let segmentLengthSquared = segment.squaredLength
            let fraction: Double

            if segmentLengthSquared == 0 {
                fraction = 0
            } else {
                fraction = min(max((targetPoint - startPoint).dot(segment) / segmentLengthSquared, 0), 1)
            }

            let projectedCoordinate = start.coordinate.interpolated(to: end.coordinate, fraction: fraction)
            let offRouteDistance = projectedCoordinate.distance(to: coordinate)
            guard offRouteDistance < bestDistance else { continue }

            let segmentDistance = end.distanceFromStart - start.distanceFromStart
            bestDistance = offRouteDistance
            bestProjectedPoint = ProjectedRoutePoint(
                coordinate: projectedCoordinate,
                distanceFromStart: start.distanceFromStart + segmentDistance * fraction,
                segmentIndex: index,
                fractionAlongSegment: fraction,
                elevation: interpolateElevation(start: start.elevation, end: end.elevation, fraction: fraction)
            )
        }

        guard let projectedPoint = bestProjectedPoint else { return nil }

        return LocationMatch(
            nearestSourcePoint: nearestSource,
            projectedPoint: projectedPoint,
            offRouteDistance: bestDistance
        )
    }
}

func interpolateElevation(start: Double?, end: Double?, fraction: Double) -> Double? {
    guard let start, let end else { return nil }
    return start + (end - start) * min(max(fraction, 0), 1)
}
