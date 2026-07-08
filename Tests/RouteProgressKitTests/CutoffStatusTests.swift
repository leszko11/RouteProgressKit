import Foundation
import Testing
@testable import RouteProgressKit

@Suite("Cutoff status")
struct CutoffStatusTests {
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
}
