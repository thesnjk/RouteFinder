import Contracts
import Foundation
import Testing

@Test func fleetBonjourBaseURLHTTP() {
    let url = FleetBonjour.baseURL(host: "192.168.1.10", port: 8080, usesTLS: false)
    #expect(url?.absoluteString == "http://192.168.1.10:8080")
}

@Test func fleetBonjourBaseURLHTTPS() {
    let url = FleetBonjour.baseURL(host: "192.168.1.10", port: 8443, usesTLS: true)
    #expect(url?.absoluteString == "https://192.168.1.10:8443")
}

@Test func fleetBonjourBaseURLIPv6() {
    let url = FleetBonjour.baseURL(host: "fe80::1", port: 8080, usesTLS: false)
    #expect(url?.absoluteString == "http://[fe80::1]:8080")
}

@Test func fleetBonjourBaseURLRejectsInvalidPort() {
    #expect(FleetBonjour.baseURL(host: "localhost", port: 0, usesTLS: false) == nil)
    #expect(FleetBonjour.baseURL(host: "localhost", port: 70_000, usesTLS: false) == nil)
}

@Test func fleetBonjourUsesTLSFromTXTRecord() {
    let record: [String: Data] = [
        FleetBonjour.txtTLSKey: Data("1".utf8),
    ]
    #expect(FleetBonjour.usesTLS(fromTXTRecord: record))
}

@Test func fleetBonjourUsesTLSFromTXTRecordWhenDisabled() {
    let record: [String: Data] = [
        FleetBonjour.txtTLSKey: Data("0".utf8),
    ]
    #expect(!FleetBonjour.usesTLS(fromTXTRecord: record))
}

@Test func fleetBonjourUsesTLSFromTXTRecordWhenMissing() {
    #expect(!FleetBonjour.usesTLS(fromTXTRecord: nil))
    #expect(!FleetBonjour.usesTLS(fromTXTRecord: [:]))
}
