import Foundation
import Testing
@testable import RouteProgressKit

@Suite("Route progress")
struct RouteProgressTests {
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

    @Test("progress coordinate convenience API matches current location API")
    func progressConvenienceAPIMatchesCurrentLocationAPI() throws {
        let route = try Fixtures.lineRoute()
        let plan = try RoutePlan(route: route, finishCutoff: .durationFromStart(180))
        let calculator = RouteProgressCalculator(plan: plan, cutoffWarningThreshold: 30)
        let coordinate = RouteCoordinate(latitude: 0, longitude: 0.001)
        let timestamp = Date(timeIntervalSince1970: 60)
        let startDate = Date(timeIntervalSince1970: 0)

        let explicit = try calculator.progress(
            for: CurrentRouteLocation(
                coordinate: coordinate,
                timestamp: timestamp,
                activityStartDate: startDate,
                currentSpeed: 2
            )
        )
        let convenience = try calculator.progress(
            at: coordinate,
            timestamp: timestamp,
            activityStartDate: startDate,
            currentSpeed: 2
        )

        #expect(convenience == explicit)
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
