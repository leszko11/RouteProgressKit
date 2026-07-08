import Testing
@testable import RouteProgressKit

@Suite("Route geometry")
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
}
