import Contracts
import DataLayer
import Foundation

// MARK: - RegCheck Provider

/// Commercial UK registration lookup via RegCheck SOAP endpoint.
public struct RegCheckRegistryProvider: VehicleRegistryProvider {
    private static let checkURL = URL(string: "https://www.regcheck.org.uk/api/reg.asmx/Check")!
    private static let providerTimeoutSeconds: TimeInterval = 3.5

    private let username: String
    private let session: URLSession

    /// Creates a RegCheck provider with the configured account username.
    public init(username: String, session: URLSession = SecureURLSession.shared) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VehicleRegistryError.notConfigured
        }
        self.username = trimmed
        self.session = session
    }

    /// Creates a RegCheck provider using the persisted username when available.
    public init(session: URLSession = SecureURLSession.shared) throws {
        let stored = VehicleProfileStore.loadRegCheckUsername() ?? ""
        try self.init(username: stored, session: session)
    }

    public func fetchSpecifications(for registrationMark: String) async throws -> VehicleSpecificationProfile {
        let normalized = RegistrationNormalizer.normalize(registrationMark)
        guard !normalized.isEmpty else {
            throw VehicleRegistryError.emptyRegistration
        }

        var components = URLComponents(url: Self.checkURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "RegistrationNumber", value: normalized),
            URLQueryItem(name: "username", value: username),
        ]

        guard let url = components?.url else {
            throw VehicleRegistryError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.providerTimeoutSeconds
        request.applyAppIdentity()

        guard request.isSecureHTTPS else {
            throw VehicleRegistryError.invalidConfiguration
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VehicleRegistryError.networkFailure("Invalid response")
        }

        switch http.statusCode {
        case 200:
            break
        case 404:
            print("[RegCheck API Error] Asset not found in registry cluster")
            throw VehicleRegistryError.notFound(registration: normalized)
        case 401, 403:
            throw VehicleRegistryError.notConfigured
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw VehicleRegistryError.networkFailure("HTTP \(http.statusCode): \(body)")
        }

        do {
            let payload = try RegCheckResponseParser.parse(data: data, registrationMark: normalized)
            return payload.toSpecificationProfile(registrationMark: normalized)
        } catch let error as RegCheckParseError {
            throw VehicleRegistryError.decodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Parse Errors

enum RegCheckParseError: Error, LocalizedError, Sendable {
    case unableToParse(registrationMark: String)

    var errorDescription: String? {
        switch self {
        case .unableToParse(let registrationMark):
            return "Unable to parse RegCheck response for \(registrationMark)"
        }
    }
}

// MARK: - RegCheck XML / JSON Parsing

struct RegCheckTextValue: Decodable, Sendable {
    let currentTextValue: String?

    init(currentTextValue: String?) {
        self.currentTextValue = currentTextValue
    }

    enum CodingKeys: String, CodingKey {
        case currentTextValue = "CurrentTextValue"
    }
}

/// Performance and classification fields decoded from RegCheck vehicle JSON.
struct RegCheckRawPayload: Sendable {
    let description: String?
    let engineSizeCc: String?
    let powerBhp: String?
    let powerKw: String?
    let grossVehicleWeight: String?
    let bodyStyle: String?
    let lengthMeters: String?
    let widthMeters: String?
    let wheelbaseMeters: String?

    private static let kilowattToBrakeHorsepower = 1.34102
    private static let cubicCentimeterToHorsepower = 0.085
    private static let defaultHorsepower = 150

    var calculatedHP: Int {
        if let rawBhp = powerBhp {
            let numericBhp = rawBhp.filter { $0.isNumber || $0 == "." }
            if let bhp = Double(numericBhp) {
                return Int(round(bhp))
            }
        }
        if let rawKw = powerKw {
            let numericKw = rawKw.filter { $0.isNumber || $0 == "." }
            if let kw = Double(numericKw) {
                return Int(round(kw * Self.kilowattToBrakeHorsepower))
            }
        }
        if let rawCc = engineSizeCc {
            let numericCc = rawCc.filter { $0.isNumber || $0 == "." }
            if let cc = Double(numericCc) {
                return Int(round(cc * Self.cubicCentimeterToHorsepower))
            }
        }
        return Self.defaultHorsepower
    }

    var isCommercialHGV: Bool {
        guard let style = bodyStyle?.lowercased() else { return false }
        return style.contains("hgv")
            || style.contains("articulated")
            || style.contains("lorry")
            || style.contains("truck")
    }
}

struct RegCheckVehiclePayload: Decodable, Sendable {
    let description: String?
    let carMake: RegCheckTextValue?
    let carModel: RegCheckTextValue?
    let engineSize: RegCheckTextValue?
    let fuelType: RegCheckTextValue?
    let grossWeight: String?
    let netWeight: String?
    let height: String?
    let makeDescription: RegCheckTextValue?
    let modelDescription: RegCheckTextValue?
    let powerKw: String?
    let powerBhp: String?
    let grossVehicleWeight: String?
    let bodyStyle: String?
    let lengthMeters: String?
    let widthMeters: String?
    let wheelbaseMeters: String?

    init(
        description: String?,
        carMake: RegCheckTextValue?,
        carModel: RegCheckTextValue?,
        engineSize: RegCheckTextValue?,
        fuelType: RegCheckTextValue?,
        grossWeight: String?,
        netWeight: String?,
        height: String? = nil,
        makeDescription: RegCheckTextValue?,
        modelDescription: RegCheckTextValue?,
        powerKw: String? = nil,
        powerBhp: String? = nil,
        grossVehicleWeight: String? = nil,
        bodyStyle: String? = nil,
        lengthMeters: String? = nil,
        widthMeters: String? = nil,
        wheelbaseMeters: String? = nil
    ) {
        self.description = description
        self.carMake = carMake
        self.carModel = carModel
        self.engineSize = engineSize
        self.fuelType = fuelType
        self.grossWeight = grossWeight
        self.netWeight = netWeight
        self.height = height
        self.makeDescription = makeDescription
        self.modelDescription = modelDescription
        self.powerKw = powerKw
        self.powerBhp = powerBhp
        self.grossVehicleWeight = grossVehicleWeight
        self.bodyStyle = bodyStyle
        self.lengthMeters = lengthMeters
        self.widthMeters = widthMeters
        self.wheelbaseMeters = wheelbaseMeters
    }

    enum CodingKeys: String, CodingKey {
        case description = "Description"
        case carMake = "CarMake"
        case carModel = "CarModel"
        case engineSize = "EngineSize"
        case fuelType = "FuelType"
        case grossWeight = "GrossWeight"
        case weight = "Weight"
        case netWeight = "NetWeight"
        case height = "Height"
        case makeDescription = "MakeDescription"
        case modelDescription = "ModelDescription"
        case powerKw = "PowerKw"
        case powerBhp = "PowerBhp"
        case grossVehicleWeight = "GrossVehicleWeight"
        case bodyStyle = "BodyStyle"
        case lengthMeters = "Length"
        case widthMeters = "Width"
        case wheelbaseMeters = "Wheelbase"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        carMake = try container.decodeIfPresent(RegCheckTextValue.self, forKey: .carMake)
        carModel = try container.decodeIfPresent(RegCheckTextValue.self, forKey: .carModel)
        engineSize = try container.decodeIfPresent(RegCheckTextValue.self, forKey: .engineSize)
        fuelType = try container.decodeIfPresent(RegCheckTextValue.self, forKey: .fuelType)
        grossWeight = try container.decodeIfPresent(String.self, forKey: .grossWeight)
            ?? container.decodeIfPresent(String.self, forKey: .weight)
        netWeight = try container.decodeIfPresent(String.self, forKey: .netWeight)
        height = try container.decodeIfPresent(String.self, forKey: .height)
        makeDescription = try container.decodeIfPresent(RegCheckTextValue.self, forKey: .makeDescription)
        modelDescription = try container.decodeIfPresent(RegCheckTextValue.self, forKey: .modelDescription)
        powerKw = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .powerKw)
        powerBhp = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .powerBhp)
        grossVehicleWeight = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .grossVehicleWeight)
        bodyStyle = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .bodyStyle)
        lengthMeters = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .lengthMeters)
        widthMeters = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .widthMeters)
        wheelbaseMeters = try RegCheckFlexibleFieldDecoder.decodeString(from: container, forKey: .wheelbaseMeters)
    }

    var rawPayload: RegCheckRawPayload {
        RegCheckRawPayload(
            description: description,
            engineSizeCc: engineSize?.currentTextValue,
            powerBhp: powerBhp,
            powerKw: powerKw,
            grossVehicleWeight: grossVehicleWeight,
            bodyStyle: bodyStyle,
            lengthMeters: lengthMeters,
            widthMeters: widthMeters,
            wheelbaseMeters: wheelbaseMeters
        )
    }

    var resolvedMake: String {
        let candidates = [
            carMake?.currentTextValue,
            makeDescription?.currentTextValue,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Unknown"
    }

    var resolvedModel: String {
        let candidates = [
            carModel?.currentTextValue,
            modelDescription?.currentTextValue,
            description,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Unknown"
    }

    func classificationCorpus() -> String {
        [
            description,
            carMake?.currentTextValue,
            carModel?.currentTextValue,
            makeDescription?.currentTextValue,
            modelDescription?.currentTextValue,
            engineSize?.currentTextValue,
            fuelType?.currentTextValue,
            bodyStyle,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    func resolvedGrossWeightKilograms() -> Double? {
        VehicleProfileClassifier.parseWeightKilograms(from: grossVehicleWeight)
            ?? VehicleProfileClassifier.parseWeightKilograms(from: grossWeight)
            ?? VehicleProfileClassifier.parseWeightKilograms(from: netWeight)
    }

    func resolvedHeightMeters() -> Double? {
        VehicleProfileClassifier.parseHeightMeters(from: height)
    }

    func resolvedLengthMeters() -> Double? {
        VehicleProfileClassifier.parseDimensionMeters(from: lengthMeters, maxMeters: 16.0)
    }

    func resolvedWidthMeters() -> Double? {
        VehicleProfileClassifier.parseDimensionMeters(from: widthMeters, maxMeters: 2.6)
    }

    func resolvedWheelbaseMeters() -> Double? {
        VehicleProfileClassifier.parseDimensionMeters(from: wheelbaseMeters, maxMeters: 7.0)
    }

    func resolvedPassengerSignatureDimensions() -> (length: Double, width: Double, wheelbase: Double)? {
        let corpus = classificationCorpus().uppercased()
        if corpus.contains("XC60") {
            return (length: 4.68, width: 1.90, wheelbase: 2.86)
        }
        return nil
    }

    func classifyVehicleClass() -> VehicleProfileClass {
        let raw = rawPayload

        if VehicleProfileClassifier.isPassengerBodyStyle(raw.bodyStyle) {
            return .passengerCar
        }

        if raw.isCommercialHGV {
            return .heavyGoodsVehicle
        }

        if let weight = resolvedGrossWeightKilograms() {
            if weight >= 7_500 {
                return .heavyGoodsVehicle
            }
            if weight >= 2_500 {
                return .lightCommercialVehicle
            }
        }

        let keywordClass = VehicleProfileClassifier.classify(
            from: classificationCorpus(),
            bodyStyle: raw.bodyStyle
        )
        if keywordClass != .passengerCar {
            return keywordClass
        }

        return .passengerCar
    }

    func toSpecificationProfile(registrationMark: String) -> VehicleSpecificationProfile {
        let vehicleClass = classifyVehicleClass()
        let signatureDimensions = vehicleClass == .passengerCar
            ? resolvedPassengerSignatureDimensions()
            : nil
        return VehicleSpecificationProfileBuilder.build(
            registrationMark: registrationMark,
            vehicleClass: vehicleClass,
            make: resolvedMake,
            model: resolvedModel,
            grossWeightKilograms: resolvedGrossWeightKilograms(),
            heightMeters: resolvedHeightMeters(),
            enginePowerHorsepower: rawPayload.calculatedHP,
            lengthMetersOverride: resolvedLengthMeters() ?? signatureDimensions?.length,
            widthMetersOverride: resolvedWidthMeters() ?? signatureDimensions?.width,
            wheelbaseMetersOverride: resolvedWheelbaseMeters() ?? signatureDimensions?.wheelbase,
            source: .verifiedAPI
        )
    }
}

enum RegCheckFlexibleFieldDecoder {
    static func decodeString<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> String? {
        if let string = try container.decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let textValue = try container.decodeIfPresent(RegCheckTextValue.self, forKey: key) {
            return textValue.currentTextValue
        }
        return nil
    }
}

enum RegCheckJSONPayloadUnwrapper {
    static func normalizedJSONData(from text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") else { return nil }
        let cleaned = RegCheckXMLScrubber.unwrapCDATA(in: trimmed)
        guard let rawData = cleaned.data(using: .utf8) else { return nil }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: rawData, options: []) else {
            return rawData
        }

        if let root = jsonObject as? [String: Any],
           let vehicleData = root["VehicleData"] as? [String: Any],
           let innerData = try? JSONSerialization.data(withJSONObject: vehicleData, options: []) {
            return innerData
        }

        return rawData
    }
}

enum RegCheckResponseParser {
    static func parse(data: Data, registrationMark: String) throws -> RegCheckVehiclePayload {
        let scrubbed = RegCheckXMLScrubber.scrub(data: data)
        let trimmedBody = scrubbed.trimmingCharacters(in: .whitespacesAndNewlines)

        if let directPayload = decodeJSONPayload(from: trimmedBody) {
            return directPayload
        }

        let scrubbedData = Data(scrubbed.utf8)
        var vehicleJson = RegCheckXMLVehicleJsonExtractor.extract(from: scrubbedData)
        if vehicleJson == nil || vehicleJson?.isEmpty == true {
            vehicleJson = RegCheckRegexVehicleJsonExtractor.extract(from: scrubbed)
        }

        if let vehicleJson, !vehicleJson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanedJson = RegCheckXMLScrubber.unwrapCDATA(in: vehicleJson)
            if let payload = decodeJSONPayload(from: cleanedJson) {
                return payload
            }
            if let regexPayload = RegCheckRegexFieldExtractor.extract(from: cleanedJson) {
                return regexPayload
            }
        }

        if let regexPayload = RegCheckRegexFieldExtractor.extract(from: scrubbed) {
            return regexPayload
        }

        throw RegCheckParseError.unableToParse(registrationMark: registrationMark)
    }

    private static func decodeJSONPayload(from text: String) -> RegCheckVehiclePayload? {
        guard let jsonData = RegCheckJSONPayloadUnwrapper.normalizedJSONData(from: text) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(RegCheckVehiclePayload.self, from: jsonData)
        } catch {
            DecodingDiagnostics.logDecodingError(
                error,
                context: "RegCheck vehicleJson",
                responsePreview: DecodingDiagnostics.preview(of: jsonData)
            )
            return nil
        }
    }
}

enum RegCheckXMLScrubber {
    static func scrub(data: Data) -> String {
        var text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }
        text = text.replacingOccurrences(
            of: #"xmlns(?::[A-Za-z0-9_]+)?="[^"]*""#,
            with: "",
            options: .regularExpression
        )
        return text
    }

    static func unwrapCDATA(in text: String) -> String {
        let pattern = #"<!\[CDATA\[(.*?)\]\]>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return text
        }
        return String(text[captureRange])
    }
}

enum RegCheckRegexVehicleJsonExtractor {
    static func extract(from text: String) -> String? {
        let patterns = [
            #"<vehicleJson[^>]*>(.*?)</vehicleJson>"#,
            #"<VehicleJson[^>]*>(.*?)</VehicleJson>"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern: pattern, in: text) {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}

enum RegCheckRegexFieldExtractor {
    static func extract(from text: String) -> RegCheckVehiclePayload? {
        let description = captureField(named: "Description", in: text)
        let carMake = captureField(named: "CarMake", in: text)
            ?? captureNestedTextValue(label: "CarMake", in: text)
        let carModel = captureField(named: "CarModel", in: text)
            ?? captureNestedTextValue(label: "CarModel", in: text)
        let registrationYear = captureField(named: "RegistrationYear", in: text)
        let engineSize = captureField(named: "EngineSize", in: text)
            ?? captureNestedTextValue(label: "EngineSize", in: text)
        let grossWeight = captureField(named: "GrossWeight", in: text)
            ?? captureField(named: "Weight", in: text)
        let grossVehicleWeight = captureField(named: "GrossVehicleWeight", in: text)
        let powerKw = captureField(named: "PowerKw", in: text)
            ?? captureNestedTextValue(label: "PowerKw", in: text)
        let powerBhp = captureField(named: "PowerBhp", in: text)
            ?? captureNestedTextValue(label: "PowerBhp", in: text)
        let bodyStyle = captureField(named: "BodyStyle", in: text)
            ?? captureNestedTextValue(label: "BodyStyle", in: text)
        let lengthMeters = captureField(named: "Length", in: text)
            ?? captureNestedTextValue(label: "Length", in: text)
        let widthMeters = captureField(named: "Width", in: text)
            ?? captureNestedTextValue(label: "Width", in: text)
        let wheelbaseMeters = captureField(named: "Wheelbase", in: text)
            ?? captureNestedTextValue(label: "Wheelbase", in: text)
        let height = captureField(named: "Height", in: text)
            ?? captureField(named: "VehicleHeight", in: text)
            ?? captureNestedTextValue(label: "Height", in: text)
        let makeDescription = captureNestedTextValue(label: "MakeDescription", in: text)
        let modelDescription = captureNestedTextValue(label: "ModelDescription", in: text)

        guard description != nil
            || carMake != nil
            || carModel != nil
            || registrationYear != nil
            || grossWeight != nil
            || grossVehicleWeight != nil
            || powerKw != nil
            || powerBhp != nil
            || bodyStyle != nil
            || lengthMeters != nil
            || widthMeters != nil
            || wheelbaseMeters != nil
            || height != nil else {
            return nil
        }

        return RegCheckVehiclePayload(
            description: description ?? registrationYear,
            carMake: carMake.map { RegCheckTextValue(currentTextValue: $0) },
            carModel: carModel.map { RegCheckTextValue(currentTextValue: $0) },
            engineSize: engineSize.map { RegCheckTextValue(currentTextValue: $0) },
            fuelType: nil,
            grossWeight: grossWeight,
            netWeight: nil,
            height: height,
            makeDescription: makeDescription.map { RegCheckTextValue(currentTextValue: $0) },
            modelDescription: modelDescription.map { RegCheckTextValue(currentTextValue: $0) },
            powerKw: powerKw,
            powerBhp: powerBhp,
            grossVehicleWeight: grossVehicleWeight,
            bodyStyle: bodyStyle,
            lengthMeters: lengthMeters,
            widthMeters: widthMeters,
            wheelbaseMeters: wheelbaseMeters
        )
    }

    private static func captureField(named field: String, in text: String) -> String? {
        let patterns = [
            #""\#(field)"\s*:\s*"([^"]+)""#,
            #""\#(field)"\s*:\s*\{[^}]*"CurrentTextValue"\s*:\s*"([^"]+)""#,
            #"<\#(field)[^>]*>([^<]+)</\#(field)>"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern: pattern, in: text) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func captureNestedTextValue(label: String, in text: String) -> String? {
        let pattern = #"<\#(label)[^>]*>.*?<CurrentTextValue[^>]*>([^<]+)</CurrentTextValue>"#
        return firstCapture(pattern: pattern, in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}

final class RegCheckXMLVehicleJsonExtractor: NSObject, XMLParserDelegate {
    private var capturedJson: String?
    private var isInsideVehicleJson = false
    private var currentText = ""

    static func extract(from data: Data) -> String? {
        let scrubbed = RegCheckXMLScrubber.scrub(data: data)
        guard let scrubData = scrubbed.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: scrubData)
        let delegate = RegCheckXMLVehicleJsonExtractor()
        parser.delegate = delegate
        guard parser.parse() else {
            return nil
        }
        return delegate.capturedJson
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let name = qName ?? elementName
        if name.caseInsensitiveCompare("vehicleJson") == .orderedSame {
            isInsideVehicleJson = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideVehicleJson {
            currentText.append(string)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = qName ?? elementName
        if name.caseInsensitiveCompare("vehicleJson") == .orderedSame {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                capturedJson = trimmed
            }
            isInsideVehicleJson = false
            currentText = ""
        }
    }
}
