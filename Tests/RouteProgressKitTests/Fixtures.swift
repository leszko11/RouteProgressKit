import Foundation
@testable import RouteProgressKit

enum Fixtures {
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
}
