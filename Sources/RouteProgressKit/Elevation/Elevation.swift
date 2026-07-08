import Foundation

/// A sample in an elevation profile.
public struct ElevationSample: Equatable, Sendable {
    /// Distance in meters from the route start.
    public var distanceFromStart: Double

    /// Elevation in meters, if present in the source route.
    public var elevation: Double?

    /// Coordinate for this elevation sample.
    public var coordinate: RouteCoordinate

    /// Index of the source route point.
    public var sourcePointIndex: Int
}

/// Elevation data derived from a route.
public struct ElevationProfile: Equatable, Sendable {
    /// Ordered elevation samples.
    public var samples: [ElevationSample]

    /// Minimum known elevation in meters.
    public var minElevation: Double?

    /// Maximum known elevation in meters.
    public var maxElevation: Double?

    /// Total positive elevation gain in meters, when every segment has elevation data.
    public var totalAscent: Double?

    /// Total negative elevation loss in meters, when every segment has elevation data.
    public var totalDescent: Double?

    /// Creates an elevation profile from route points.
    public init(points: [RoutePoint]) {
        self.samples = points.map {
            ElevationSample(
                distanceFromStart: $0.distanceFromStart,
                elevation: $0.elevation,
                coordinate: $0.coordinate,
                sourcePointIndex: $0.index
            )
        }

        let elevations = samples.compactMap(\.elevation)
        self.minElevation = elevations.min()
        self.maxElevation = elevations.max()

        if points.count > 1, points.allSatisfy({ $0.elevation != nil }) {
            var ascent: Double = 0
            var descent: Double = 0
            for index in 0..<(points.count - 1) {
                let start = points[index].elevation ?? 0
                let end = points[index + 1].elevation ?? 0
                let delta = end - start
                if delta > 0 {
                    ascent += delta
                } else {
                    descent += abs(delta)
                }
            }
            self.totalAscent = ascent
            self.totalDescent = descent
        } else {
            self.totalAscent = nil
            self.totalDescent = nil
        }
    }

    /// Interpolates elevation at a distance from the route start.
    public func elevation(atDistance distance: Double) -> Double? {
        guard let first = samples.first else { return nil }
        guard samples.count > 1 else { return first.elevation }

        if distance <= 0 {
            return first.elevation
        }

        guard let last = samples.last else { return nil }
        if distance >= last.distanceFromStart {
            return last.elevation
        }

        for index in 0..<(samples.count - 1) {
            let start = samples[index]
            let end = samples[index + 1]
            guard distance <= end.distanceFromStart else { continue }

            let segmentLength = end.distanceFromStart - start.distanceFromStart
            let fraction = segmentLength > 0 ? (distance - start.distanceFromStart) / segmentLength : 0
            return interpolateElevation(start: start.elevation, end: end.elevation, fraction: fraction)
        }

        return nil
    }

    /// Returns the nearest profile sample at a distance from the route start.
    public func sample(atDistance distance: Double) -> ElevationSample? {
        samples.min {
            abs($0.distanceFromStart - distance) < abs($1.distanceFromStart - distance)
        }
    }
}
