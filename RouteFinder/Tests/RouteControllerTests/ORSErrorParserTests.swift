import Foundation
import Testing
@testable import RouteController

@Test func orsErrorParserExtractsCode2012Message() {
    let body = """
    {"error":{"code":2012,"message":"Unknown parameter 'extra_info'."},"info":{"engine":{"build_date":"2026-06-12T10:08:58Z"}}}
    """

    let message = ORSErrorParser.userFacingMessage(status: 400, body: body)

    #expect(message == "Routing service does not support this request option. Try again or check for an app update.")
    #expect(ORSErrorParser.isUnsupportedExtraInfoError(body: body))
}

@Test func orsErrorParserExtractsCode2003AvoidAreaMessage() {
    let body = """
    {"error":{"code":2003,"message":"The area of a polygon to avoid must not exceed 2.0E8 square meters."}}
    """

    let message = ORSErrorParser.userFacingMessage(status: 400, body: body)

    #expect(message?.contains("avoid zone is too large") == true)
    #expect(message?.contains("{") == false)
}

@Test func orsErrorParserExtractsGenericMessage() {
    let body = """
    {"error":{"code":2004,"message":"Distance exceeds maximum."}}
    """

    let message = ORSErrorParser.userFacingMessage(status: 400, body: body)

    #expect(message == "Routing failed: Distance exceeds maximum.")
}

@Test func externalRoutingErrorUsesParsedMessage() {
    let body = """
    {"error":{"code":2012,"message":"Unknown parameter 'extra_info'."}}
    """
    let error = ExternalRoutingError.serverError(status: 400, body: body)

    #expect(error.errorDescription == "Routing service does not support this request option. Try again or check for an app update.")
    #expect(error.errorDescription?.contains("{") == false)
}
