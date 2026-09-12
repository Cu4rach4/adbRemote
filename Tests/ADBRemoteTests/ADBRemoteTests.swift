import Testing
@testable import ADBRemote

@Test func parsesExtendedDeviceList() {
    let devices = AndroidDevice.parse("List of devices attached\n192.168.1.4:5555 device product:panther model:Pixel_7 transport_id:2\nABC unauthorized")
    #expect(devices.count == 2)
    #expect(devices[0].displayName == "Pixel 7")
    #expect(!devices[1].isOnline)
}

@Test func manualDeviceUsesDefaultAdbPort() {
    let device = ManualDevice(ipAddress: "192.168.1.8")
    #expect(device.endpoint == "192.168.1.8:5555")
    #expect(device.displayName == "192.168.1.8")
}

@Test func parsesADBMDNSServices() {
    let devices = NearbyDevice.parse("""
    List of discovered mdns services
    adb-AB12CD34 _adb-tls-connect._tcp 192.168.1.24:38571
    adb-PAIR _adb-tls-pairing._tcp 192.168.1.24:37123
    """)

    #expect(devices.count == 1)
    #expect(devices[0].endpoint == "192.168.1.24:38571")
}

@Test func adbConnectionAcceptsTheRequestedEndpoint() {
    let device = ManualDevice(ipAddress: "192.168.1.116", port: "5555")
    #expect(device.endpoint == "192.168.1.116:5555")
    #expect(ADBConnectionResponse.succeeded("connected to 192.168.1.116:5555"))
    #expect(ADBConnectionResponse.succeeded("already connected to 192.168.1.116:5555"))
}

@Test func adbConnectionReportsNoRouteAsNetworkProblem() {
    let output = "failed to connect to '192.168.1.116:5555': No route to host"
    #expect(!ADBConnectionResponse.succeeded(output))
    #expect(ADBConnectionResponse.shouldRetryWithFreshServer(output))
    #expect(ADBConnectionResponse.failureMessage(output: output, endpoint: "192.168.1.116:5555").localizedCaseInsensitiveContains("ruta de red"))
}
