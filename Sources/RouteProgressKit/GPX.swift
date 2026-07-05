import Foundation

/// Typed GPX parsing errors.
public enum GPXParseError: Error, Equatable, Sendable {
    /// The GPX XML could not be parsed.
    case invalidXML(String)

    /// A track point was missing a latitude or longitude attribute.
    case missingCoordinate

    /// A coordinate attribute was not a valid number.
    case invalidCoordinate(String)

    /// The GPX file did not contain any track points.
    case emptyTrack

    /// Input stream data could not be read.
    case unreadableStream
}

/// Parses GPX data into a normalized ``Route``.
public final class GPXParser: NSObject, XMLParserDelegate {
    private var routeName: String?
    private var points: [RoutePoint] = []
    private var currentPoint: PartialPoint?
    private var currentText = ""
    private var parseError: GPXParseError?
    private var isInsideTrackName = false
    private var isInsideTrack = false

    /// Creates a GPX parser.
    public override init() {
        super.init()
    }

    /// Parses GPX data into a route.
    public func parse(_ data: Data) throws -> Route {
        routeName = nil
        points = []
        currentPoint = nil
        currentText = ""
        parseError = nil
        isInsideTrackName = false
        isInsideTrack = false

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            if let parseError {
                throw parseError
            }
            throw GPXParseError.invalidXML(parser.parserError?.localizedDescription ?? "Invalid GPX XML")
        }

        if let parseError {
            throw parseError
        }

        guard !points.isEmpty else {
            throw GPXParseError.emptyTrack
        }

        return try Route(name: routeName, points: points)
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        let name = Self.localName(elementName)

        switch name {
        case "trk":
            isInsideTrack = true
        case "name" where isInsideTrack && routeName == nil:
            isInsideTrackName = true
        case "trkpt":
            guard let latitudeValue = attributeDict["lat"], let longitudeValue = attributeDict["lon"] else {
                parseError = .missingCoordinate
                parser.abortParsing()
                return
            }
            guard let latitude = Double(latitudeValue), let longitude = Double(longitudeValue) else {
                parseError = .invalidCoordinate("\(latitudeValue),\(longitudeValue)")
                parser.abortParsing()
                return
            }
            currentPoint = PartialPoint(coordinate: RouteCoordinate(latitude: latitude, longitude: longitude))
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = Self.localName(elementName)
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "name" where isInsideTrackName:
            routeName = trimmedText.isEmpty ? nil : trimmedText
            isInsideTrackName = false
        case "trk":
            isInsideTrack = false
        case "ele":
            if !trimmedText.isEmpty {
                currentPoint?.elevation = Double(trimmedText)
            }
        case "time":
            if !trimmedText.isEmpty {
                currentPoint?.timestamp = Self.parseDate(trimmedText)
            }
        case "trkpt":
            if let currentPoint {
                points.append(
                    RoutePoint(
                        coordinate: currentPoint.coordinate,
                        elevation: currentPoint.elevation,
                        timestamp: currentPoint.timestamp
                    )
                )
            }
            currentPoint = nil
        default:
            break
        }

        currentText = ""
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if self.parseError == nil {
            self.parseError = .invalidXML(parseError.localizedDescription)
        }
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

private struct PartialPoint {
    var coordinate: RouteCoordinate
    var elevation: Double?
    var timestamp: Date?
}

/// Loads GPX routes from common input forms.
public struct GPXRouteLoader: Sendable {
    /// Creates a GPX route loader.
    public init() {}

    /// Loads a route from GPX data.
    public func loadRoute(from data: Data) throws -> Route {
        try GPXParser().parse(data)
    }

    /// Loads a route from a GPX string.
    public func loadRoute(from string: String) throws -> Route {
        try loadRoute(from: Data(string.utf8))
    }

    /// Loads a route from a file URL.
    public func loadRoute(from url: URL) throws -> Route {
        try loadRoute(from: Data(contentsOf: url))
    }

    /// Loads a route from an input stream.
    public func loadRoute(from stream: InputStream) throws -> Route {
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw GPXParseError.unreadableStream
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }

        return try loadRoute(from: data)
    }
}
