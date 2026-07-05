<p align="center">
  <img src="Assets/logo.png" width="400" max-width="80%" alt="RouteProgressKit logo">
</p>

<h1 align="center">RouteProgressKit</h1>

<p align="center">
  A lightweight Swift package for route progress, GPX geometry, elevation, ETA, and cutoff tracking.
</p>

<p align="center">
  <a href="https://swiftpackageindex.com/leszko11/RouteProgressKit">
    <img src="https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/leszko11/RouteProgressKit/badge?type=swift-versions" alt="Swift versions">
  </a>
  <a href="https://swiftpackageindex.com/leszko11/RouteProgressKit">
    <img src="https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/leszko11/RouteProgressKit/badge?type=platforms" alt="Platforms">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT license">
  </a>
</p>

It answers the practical questions an app needs during an activity:

- Where is this location on the route?
- How far is it to the next waypoint or aid station?
- How far is it to the finish?
- What is the current elevation profile position?
- Is the current ETA on track for a cutoff?

The package is domain-only. It has no SwiftUI, UIKit, MapKit, CoreLocation, or third-party dependency requirement.

## Platforms

RouteProgressKit targets Apple platforms 26+:

- iOS 26+
- macOS 26+
- watchOS 26+
- tvOS 26+
- visionOS 26+

The package uses Swift 6 mode and value types that are `Sendable` where appropriate.

## Installation

Add RouteProgressKit to your package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/leszko11/RouteProgressKit.git", from: "0.1.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["RouteProgressKit"]
)
```

## Parse GPX

```swift
import Foundation
import RouteProgressKit

let route = try GPXRouteLoader().loadRoute(from: gpxData)

print(route.name ?? "Unnamed route")
print(route.points.count)
print(route.totalDistance)
```

`GPXRouteLoader` accepts:

- `Data`
- `String`
- `URL`
- `InputStream`

The parser supports common GPX track data:

- `gpx > trk > trkseg > trkpt`
- `lat` / `lon`
- optional `ele`
- optional `time`
- multiple track segments

Invalid GPX is reported with `GPXParseError`.

## Work With Route Geometry

```swift
let halfway = route.totalDistance / 2
let point = route.polyline.point(atDistance: halfway)

let match = route.polyline.nearestPoint(
    to: RouteCoordinate(latitude: 50.3436, longitude: 16.8881)
)

print(match?.projectedPoint.distanceFromStart ?? 0)
print(match?.offRouteDistance ?? 0)
```

Route geometry includes:

- cumulative distance in meters
- interpolation by distance
- nearest source point
- projected point on the polyline
- off-route distance
- route bounds and center coordinate

## Elevation Profile

```swift
let profile = route.elevationProfile

print(profile.minElevation ?? 0)
print(profile.maxElevation ?? 0)
print(profile.totalAscent ?? 0)
print(profile.totalDescent ?? 0)

let currentElevation = profile.elevation(atDistance: 12_500)
```

Missing elevation is represented as `nil`. RouteProgressKit does not invent elevation data.

## Waypoints And Aid Stations

Use the neutral `RouteWaypoint` model for aid stations, checkpoints, water points, summits, or app-defined targets.

```swift
let waypoints = [
    RouteWaypoint(
        id: "aid-1",
        name: "Przelecz Gieraltowska",
        coordinate: RouteCoordinate(latitude: 50.332, longitude: 16.918),
        kind: .aidStation,
        cutoff: .durationFromStart(2.5 * 60 * 60)
    )
]

let plan = try RoutePlan(
    route: route,
    waypoints: waypoints,
    finishCutoff: .durationFromStart(7 * 60 * 60)
)
```

If a waypoint does not provide `distanceAlongRoute`, `RoutePlan` projects it onto the route and fills the distance automatically.

## Current Progress

```swift
let calculator = RouteProgressCalculator(plan: plan)

let progress = try calculator.progress(
    for: CurrentRouteLocation(
        coordinate: RouteCoordinate(latitude: 50.3436, longitude: 16.8881),
        timestamp: Date(),
        activityStartDate: startDate,
        currentSpeed: 2.4
    )
)

print(progress.progressFraction)
print(progress.distanceFromStart)
print(progress.distanceRemaining)
print(progress.nextWaypoint?.name ?? "Finish")
print(progress.distanceToNextWaypoint ?? progress.distanceToFinish)
print(progress.etaToFinish?.duration ?? 0)
print(progress.finishCutoffStatus?.state as Any)
```

`RouteProgress` includes:

- progress fraction
- distance from start
- distance remaining
- nearest route point
- projected route point
- elevation sample and interpolated elevation
- off-route distance
- current segment and source point index
- next waypoint
- distance and ETA to next waypoint
- distance and ETA to finish
- cutoff status for waypoint and finish

## ETA And Cutoff Behavior

ETA is deliberately typed so apps can avoid fake precision.

RouteProgressKit estimates ETA from:

1. `currentSpeed` when provided.
2. elapsed pace when `activityStartDate`, `timestamp`, and current route progress are available.
3. `.missingPaceBasis` when neither basis exists.

Cutoff states are:

- `.none`
- `.unknown`
- `.onTrack`
- `.atRisk`
- `.missed`

Configure the warning threshold with `RouteProgressCalculator(plan:cutoffWarningThreshold:)`.

## License

RouteProgressKit is available under the MIT license. See [LICENSE](LICENSE).
