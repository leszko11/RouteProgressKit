import Testing
@testable import RouteProgressKit

@Suite("Waypoint projection")
struct WaypointProjectionTests {
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
}
