import AppKit
import Foundation

actor ADBClient {
    static let shared = ADBClient()
    private let executable = URL(fileURLWithPath: "/usr/local/bin/adb")

    func devices() async throws -> [AndroidDevice] {
        let result = try await run(["devices", "-l"])
        return AndroidDevice.parse(result)
    }

    func nearbyDevices() async -> [NearbyDevice] {
        // Browse Bonjour first. Besides avoiding a dependency on the ADB daemon,
        // this is the app-owned network operation that triggers macOS's Local
        // Network permission prompt.
        let bonjourDevices = await BonjourADBDiscovery().discover()
        if !bonjourDevices.isEmpty { return bonjourDevices }

        // Keep ADB mDNS as a fallback for devices already known to its daemon.
        return (try? await run(["mdns", "services"])).map(NearbyDevice.parse) ?? []
    }

    func pair(host: String, code: String) async throws {
        try validate(host: host, code: code)
        do {
            _ = try await run(["pair", host, code])
        } catch let error as ADBError {
            if case .commandFailed(let detail) = error,
               detail.localizedCaseInsensitiveContains("protocol fault") {
                throw ADBError.commandFailed("Wireless pairing could not complete. Allow ADB Remote in System Settings > Privacy & Security > Local Network, then confirm that the pairing address and six-digit code currently shown on the Android device are correct.")
            }
            throw error
        }
    }

    func connect(host: String) async throws -> String {
        let endpoint = host.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateConnectHost(endpoint)
        var output = try await run(["connect", endpoint])
        if !ADBConnectionResponse.succeeded(output), ADBConnectionResponse.shouldRetryWithFreshServer(output) {
            // ADB's long-running server can retain a broken network transport.
            // Restart it once, then retry the requested connection.
            try await restartServer()
            output = try await run(["connect", endpoint])
        }
        guard ADBConnectionResponse.succeeded(output) else {
            throw ADBError.commandFailed(ADBConnectionResponse.failureMessage(output: output, endpoint: endpoint))
        }
        return endpoint
    }
    func disconnect(_ serial: String) async throws { _ = try await run(["disconnect", serial]) }
    func tcpip(_ serial: String, port: String) async throws { _ = try await run(["-s", serial, "tcpip", port]) }
    func inputText(_ serial: String, text: String) async throws { _ = try await run(["-s", serial, "shell", "input", "text", text.replacingOccurrences(of: " ", with: "%s")]) }
    func keyEvent(_ serial: String, _ key: String) async throws { _ = try await run(["-s", serial, "shell", "input", "keyevent", key]) }
    func reverse(_ serial: String, remote: String, local: String) async throws { _ = try await run(["-s", serial, "reverse", remote, local]) }
    func removeReverse(_ serial: String, remote: String) async throws { _ = try await run(["-s", serial, "reverse", "--remove", remote]) }
    func uninstall(_ serial: String, package: String) async throws { _ = try await run(["-s", serial, "uninstall", package]) }
    func disable(_ serial: String, package: String) async throws { _ = try await run(["-s", serial, "shell", "pm", "disable-user", "--user", "0", package]) }
    func launch(_ serial: String, package: String) async throws { _ = try await run(["-s", serial, "shell", "monkey", "-p", package, "1"]) }

    func apps(_ serial: String, kind: AppKind = .all) async throws -> [InstalledApp] {
        var arguments = ["-s", serial, "shell", "pm", "list", "packages"]
        if let filter = kind.packageListArgument { arguments.append(filter) }
        let output = try await run(arguments)
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let name = String(line).replacingOccurrences(of: "package:", with: "").trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : InstalledApp(packageName: name, kind: kind)
        }.sorted { $0.packageName.localizedStandardCompare($1.packageName) == .orderedAscending }
    }

    func install(_ serial: String, apk: URL) async throws { _ = try await run(["-s", serial, "install", "-r", apk.path]) }

    func screenshot(_ serial: String) async throws -> Data {
        try ensureAvailable()
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-s", serial, "exec-out", "screencap", "-p"]
        let output = Pipe(); let error = Pipe()
        process.standardOutput = output; process.standardError = error
        try process.run(); process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else { throw ADBError.commandFailed(String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Screenshot failed") }
        return data
    }

    func mirror(_ serial: String) throws {
        let candidates = ["/opt/homebrew/bin/scrcpy", "/usr/local/bin/scrcpy"]
        guard let command = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ADBError.commandFailed("scrcpy is not installed. Install it with Homebrew: brew install scrcpy")
        }
        let process = Process(); process.executableURL = URL(fileURLWithPath: command); process.arguments = ["-s", serial]
        try process.run()
    }

    private func run(_ arguments: [String]) async throws -> String {
        try ensureAvailable()
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        let output = Pipe(); let error = Pipe(); process.standardOutput = output; process.standardError = error
        try process.run(); process.waitUntilExit()
        let result = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let detail = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? result
            throw ADBError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }

    private func ensureAvailable() throws { guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw ADBError.unavailable } }
    private func validate(host: String, code: String) throws {
        guard host.contains(":") else { throw ADBError.invalidInput("Use host:pairing-port, for example 192.168.1.8:37123.") }
        guard code.range(of: "^[0-9]{6}$", options: .regularExpression) != nil else { throw ADBError.invalidInput("Pairing code must contain six digits.") }
    }
    private func validateConnectHost(_ host: String) throws {
        let parts = host.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty,
              let port = Int(parts[1]), (1...65535).contains(port) else {
            throw ADBError.invalidInput("Enter an IP address and a valid ADB port (for example 192.168.1.8:5555).")
        }
    }

    private func restartServer() async throws {
        _ = try await run(["kill-server"])
        _ = try await run(["start-server"])
    }

}
