import Testing
@testable import RouteProgressKit

@Suite("Elevation profile")
struct ElevationProfileTests {
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
