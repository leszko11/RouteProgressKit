import Foundation
import Testing
@testable import RouteProgressKit

@Suite("GPX parsing")
struct GPXParserTests {
    @Test("parses GPX track points with elevation and timestamps")
    func parsesTrackPoints() throws {
        let route = try GPXRouteLoader().loadRoute(from: Fixtures.sampleGPXWithTwoSegments)

        #expect(route.name == "Training Route")
        #expect(route.points.count == 4)
        #expect(route.points[0].coordinate.latitude == 50.0)
        #expect(route.points[0].coordinate.longitude == 16.0)
        #expect(route.points[0].elevation == 100)
        #expect(route.points[0].timestamp != nil)
        #expect(route.totalDistance > 250)
        #expect(route.totalDistance < 260)
        #expect(route.bounds?.minLatitude == 50.0)
        #expect(route.bounds?.maxLongitude == 16.002)
    }

    @Test("loads GPX from string and input stream")
    func loadsFromStringAndStream() throws {
        let loader = GPXRouteLoader()
        let fromString = try loader.loadRoute(from: String(decoding: Fixtures.sampleGPXWithTwoSegments, as: UTF8.self))
        let stream = InputStream(data: Fixtures.sampleGPXWithTwoSegments)
        let fromStream = try loader.loadRoute(from: stream)

        #expect(fromString.points.count == 4)
        #expect(fromStream.points.count == 4)
    }

    @Test("reports invalid GPX and empty tracks")
    func reportsInvalidInput() throws {
        #expect(throws: GPXParseError.self) {
            _ = try GPXRouteLoader().loadRoute(from: Data("<gpx><trk>".utf8))
        }
        #expect(throws: GPXParseError.self) {
            _ = try GPXRouteLoader().loadRoute(from: Data("<gpx><trk><trkseg /></trk></gpx>".utf8))
        }
        #expect(throws: GPXParseError.self) {
            _ = try GPXRouteLoader().loadRoute(from: Data("""
            <gpx><trk><trkseg><trkpt lon="16.0"><ele>100</ele></trkpt></trkseg></trk></gpx>
            """.utf8))
        }
    }
}

@Suite("Route geometry and elevation")
struct RouteGeometryTests {
    @Test("computes cumulative distance and interpolates coordinates")
    func distanceAndInterpolation() throws {
        let route = try Fixtures.lineRoute()

        #expect(route.points.count == 3)
        #expect(route.totalDistance > 220)
        #expect(route.totalDistance < 225)

        let midpoint = try #require(route.polyline.point(atDistance: route.totalDistance / 2))
        #expect(midpoint.distanceFromStart == route.totalDistance / 2)
        #expect(midpoint.coordinate.longitude > 0.0009)
        #expect(midpoint.coordinate.longitude < 0.0011)
    }

    @Test("projects arbitrary coordinates onto the route")
    func nearestProjection() throws {
        let route = try Fixtures.lineRoute()
        let match = try #require(route.polyline.nearestPoint(to: .init(latitude: 0.0005, longitude: 0.001)))

        #expect(match.projectedPoint.segmentIndex == 0 || match.projectedPoint.segmentIndex == 1)
        #expect(match.projectedPoint.distanceFromStart > 100)
        #expect(match.offRouteDistance < 56)
        #expect(match.nearestSourcePoint.index == 1 || match.nearestSourcePoint.index == 2)
    }

    @Test("builds elevation profile and statistics")
    func elevationProfile() throws {
        let route = try Fixtures.lineRoute()
        let profile = route.elevationProfile

        #expect(profile.samples.count == 3)
        #expect(profile.minElevation == 10)
        #expect(profile.maxElevation == 25)
        #expect(profile.totalAscent == 15)
        #expect(profile.totalDescent == 0)
        #expect(profile.elevation(atDistance: route.totalDistance / 2) == 15)
    }

    @Test("represents missing elevation without inventing values")
    func missingElevation() throws {
        let route = try Route(points: [
            .init(coordinate: .init(latitude: 0, longitude: 0)),
            .init(coordinate: .init(latitude: 0, longitude: 0.001))
        ])

        #expect(route.elevationProfile.samples.allSatisfy { $0.elevation == nil })
        #expect(route.elevationProfile.elevation(atDistance: 10) == nil)
        #expect(route.elevationProfile.totalAscent == nil)
    }
}

@Suite("Waypoints, progress, ETA, and cutoffs")
struct RouteProgressTests {
    @Test("projects waypoints and selects next target")
    func waypointProjection() throws {
        let route = try Fixtures.lineRoute()
        let waypoint = RouteWaypoint(
            id: "aid-1",
            name: "Aid Station 1",
            coordinate: .init(latitude: 0, longitude: 0.0015),
            kind: .aidStation
        )
        let plan = try RoutePlan(route: route, waypoints: [waypoint])

        #expect(plan.waypoints.count == 1)
        #expect(plan.waypoints[0].distanceAlongRoute! > 160)
        #expect(plan.waypoints[0].distanceAlongRoute! < 170)
    }

    @Test("calculates route progress and ETA from current speed")
    func progressFromSpeed() throws {
        let route = try Fixtures.lineRoute()
        let plan = try RoutePlan(
            route: route,
            waypoints: [
                RouteWaypoint(
                    id: "aid-1",
                    name: "Aid Station 1",
                    coordinate: .init(latitude: 0, longitude: 0.0015),
                    kind: .aidStation,
                    cutoff: .durationFromStart(100)
                )
            ],
            finishCutoff: .durationFromStart(180)
        )

        let progress = try RouteProgressCalculator(plan: plan, cutoffWarningThreshold: 30).progress(
            for: CurrentRouteLocation(
                coordinate: .init(latitude: 0, longitude: 0.001),
                timestamp: Date(timeIntervalSince1970: 60),
                activityStartDate: Date(timeIntervalSince1970: 0),
                currentSpeed: 2
            )
        )

        #expect(progress.progressFraction > 0.49)
        #expect(progress.progressFraction < 0.51)
        #expect(progress.nextWaypoint?.id == "aid-1")
        #expect(progress.distanceToNextWaypoint! > 50)
        #expect(progress.etaToNextWaypoint?.duration != nil)
        #expect(progress.nextWaypointCutoffStatus?.state == .atRisk)
        #expect(progress.finishCutoffStatus?.state == .onTrack)
        #expect(progress.elevationAtCurrentPosition == 15)
    }

    @Test("calculates ETA from elapsed pace")
    func etaFromElapsedPace() throws {
        let route = try Fixtures.lineRoute()
        let plan = try RoutePlan(route: route)

        let progress = try RouteProgressCalculator(plan: plan).progress(
            for: CurrentRouteLocation(
                coordinate: .init(latitude: 0, longitude: 0.001),
                timestamp: Date(timeIntervalSince1970: 120),
                activityStartDate: Date(timeIntervalSince1970: 0)
            )
        )

        #expect(progress.etaToFinish?.basis == .elapsedPace)
        #expect(progress.etaToFinish?.duration != nil)
    }

    @Test("reports ETA unavailable and unknown cutoff when pace data is missing")
    func etaUnavailable() throws {
        let route = try Fixtures.lineRoute()
        let plan = try RoutePlan(route: route, finishCutoff: .durationFromStart(60))
        let progress = try RouteProgressCalculator(plan: plan).progress(
            for: CurrentRouteLocation(coordinate: .init(latitude: 0, longitude: 0.001))
        )

        #expect(progress.etaToFinish?.unavailableReason == .missingPaceBasis)
        #expect(progress.finishCutoffStatus?.state == .unknown)
    }

    @Test("reports missed cutoff")
    func missedCutoff() throws {
        let route = try Fixtures.lineRoute()
        let plan = try RoutePlan(route: route, finishCutoff: .durationFromStart(30))
        let progress = try RouteProgressCalculator(plan: plan).progress(
            for: CurrentRouteLocation(
                coordinate: .init(latitude: 0, longitude: 0.001),
                timestamp: Date(timeIntervalSince1970: 60),
                activityStartDate: Date(timeIntervalSince1970: 0),
                currentSpeed: 2
            )
        )

        #expect(progress.finishCutoffStatus?.state == .missed)
    }

    @Test("progress-aware matching stays at start for shared start and finish coordinates")
    func progressAwareMatchingPrefersStartWhenNoProgressExists() throws {
        let route = try Fixtures.outAndBackRoute()
        let plan = try RoutePlan(route: route)
        let calculator = RouteProgressCalculator(plan: plan)

        let progress = try calculator.progress(
            for: CurrentRouteLocation(coordinate: route.points[0].coordinate),
            previousDistanceFromStart: nil
        )

        #expect(progress.distanceFromStart == 0)
        #expect(progress.progressFraction == 0)
    }

    @Test("progress-aware matching keeps overlapping segments continuous")
    func progressAwareMatchingKeepsOverlappingSegmentsContinuous() throws {
        let route = try Fixtures.outAndBackRoute()
        let plan = try RoutePlan(route: route)
        let calculator = RouteProgressCalculator(plan: plan)
        let firstReturnPoint = route.points[3]

        let progress = try calculator.progress(
            for: CurrentRouteLocation(coordinate: firstReturnPoint.coordinate),
            previousDistanceFromStart: route.points[2].distanceFromStart + 5
        )

        #expect(progress.distanceFromStart > route.points[2].distanceFromStart)
        #expect(progress.distanceFromStart < route.totalDistance)
        #expect(progress.segmentIndex >= 2)
    }
}

@Suite("Local DFBG fixtures")
struct DFBGFixtureTests {
    @Test("loads local DFBG GPX files when fixture directory is configured")
    func loadsLocalFixturesWhenAvailable() throws {
        guard let fixtureDirectory = ProcessInfo.processInfo.environment["DFBG_GPX_FIXTURE_DIR"] else {
            return
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: fixtureDirectory),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "gpx" }

        #expect(!urls.isEmpty)
        for url in urls {
            let route = try GPXRouteLoader().loadRoute(from: url)
            #expect(!route.points.isEmpty)
            #expect(route.totalDistance > 10_000)
            #expect(route.elevationProfile.samples.contains { $0.elevation != nil })
        }
    }
}

private enum Fixtures {
    static let sampleGPXWithTwoSegments = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="RouteProgressKit" xmlns="http://www.topografix.com/GPX/1/1">
      <trk>
        <name>Training Route</name>
        <trkseg>
          <trkpt lat="50.0" lon="16.0">
            <ele>100</ele>
            <time>2026-07-17T15:00:00Z</time>
          </trkpt>
          <trkpt lat="50.0" lon="16.001">
            <ele>110</ele>
          </trkpt>
        </trkseg>
        <trkseg>
          <trkpt lat="50.001" lon="16.001">
            <ele>105</ele>
          </trkpt>
          <trkpt lat="50.001" lon="16.002">
            <ele>120</ele>
          </trkpt>
        </trkseg>
      </trk>
    </gpx>
    """.utf8)

    static func lineRoute() throws -> Route {
        try Route(
            name: "Line",
            points: [
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0), elevation: 10),
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0.001), elevation: 15),
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0.002), elevation: 25)
            ]
        )
    }

    static func outAndBackRoute() throws -> Route {
        try Route(
            name: "Out and Back",
            points: [
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0), elevation: 10),
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0.001), elevation: 11),
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0.002), elevation: 12),
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0.001), elevation: 11),
                RoutePoint(coordinate: .init(latitude: 0, longitude: 0), elevation: 10)
            ]
        )
    }
}
