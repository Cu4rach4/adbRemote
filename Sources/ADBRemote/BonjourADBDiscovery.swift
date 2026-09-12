@preconcurrency import Foundation

/// Finds Android devices that advertise Wireless debugging through Bonjour.
/// This is independent of the local ADB server, so discovery still works when
/// `adb mdns services` is unavailable or its daemon has not started.
@MainActor
final class BonjourADBDiscovery: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var found: [NearbyDevice] = []

    func discover(timeout: Duration = .seconds(2)) async -> [NearbyDevice] {
        browser.delegate = self
        browser.searchForServices(ofType: "_adb-tls-connect._tcp.", inDomain: "local.")
        try? await Task.sleep(for: timeout)
        browser.stop()
        return found.sorted { $0.service.localizedStandardCompare($1.service) == .orderedAscending }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service) // Keep the service alive until it resolves.
        service.resolve(withTimeout: 2)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty, sender.port > 0 else { return }
        let device = NearbyDevice(service: sender.name, endpoint: "\(host):\(sender.port)")
        guard !found.contains(where: { $0.endpoint.caseInsensitiveCompare(device.endpoint) == .orderedSame }) else { return }
        found.append(device)
    }
}
