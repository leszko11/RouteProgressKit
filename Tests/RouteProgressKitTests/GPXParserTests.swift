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
