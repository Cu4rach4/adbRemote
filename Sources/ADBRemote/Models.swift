import Foundation

struct DependencyStatus: Identifiable, Sendable {
    enum Kind: String, Sendable { case adb = "ADB", scrcpy = "scrcpy" }

    let kind: Kind
    let path: String?
    let version: String?
    let detail: String

    var id: Kind { kind }
    var isAvailable: Bool { path != nil }
}

struct DependencyReport: Sendable {
    let adb: DependencyStatus
    let scrcpy: DependencyStatus

    var requiresSetup: Bool { !adb.isAvailable || !scrcpy.isAvailable }

    static func inspect() -> DependencyReport {
        DependencyReport(
            adb: inspect(kind: .adb, candidates: ["/opt/homebrew/bin/adb", "/usr/local/bin/adb"], versionArguments: ["version"]),
            scrcpy: inspect(kind: .scrcpy, candidates: ["/opt/homebrew/bin/scrcpy", "/usr/local/bin/scrcpy"], versionArguments: ["--version"])
        )
    }

    static func executable(for kind: DependencyStatus.Kind) -> URL? {
        let candidates = kind == .adb ? ["/opt/homebrew/bin/adb", "/usr/local/bin/adb"] : ["/opt/homebrew/bin/scrcpy", "/usr/local/bin/scrcpy"]
        return findExecutable(candidates: candidates).map { URL(fileURLWithPath: $0) }
    }

    private static func inspect(kind: DependencyStatus.Kind, candidates: [String], versionArguments: [String]) -> DependencyStatus {
        guard let path = findExecutable(candidates: candidates) else {
            return DependencyStatus(kind: kind, path: nil, version: nil, detail: "No instalado")
        }
        let version = commandOutput(path: path, arguments: versionArguments)?.split(whereSeparator: \.isNewline).first.map(String.init)
        return DependencyStatus(kind: kind, path: path, version: version, detail: version ?? "Instalado")
    }

    private static func findExecutable(candidates: [String]) -> String? {
        let pathCandidates = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/\(candidates[0].split(separator: "/").last!)" }
        return (candidates + pathCandidates).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func commandOutput(path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { return nil }
    }
}

struct AndroidDevice: Identifiable, Hashable, Sendable {
    let serial: String
    let state: String
    let product: String?
    let model: String?
    let transport: String?

    var id: String { serial }
    var displayName: String { model?.replacingOccurrences(of: "_", with: " ") ?? serial }
    var isOnline: Bool { state == "device" }

    static func parse(_ output: String) -> [AndroidDevice] {
        output.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 2 else { return nil }
            var values: [String: String] = [:]
            for field in fields.dropFirst(2) {
                let pair = field.split(separator: ":", maxSplits: 1).map(String.init)
                if pair.count == 2 { values[pair[0]] = pair[1] }
            }
            return AndroidDevice(serial: fields[0], state: fields[1], product: values["product"], model: values["model"], transport: values["transport_id"])
        }
    }
}

struct InstalledApp: Identifiable, Hashable, Sendable {
    let packageName: String
    let kind: AppKind
    var id: String { packageName }
}

enum AppKind: String, CaseIterable, Identifiable, Sendable {
    case all
    case user
    case system
    case disabled

    var id: Self { self }
    var title: String {
        switch self {
        case .all: "Todas"
        case .user: "Usuario"
        case .system: "Sistema"
        case .disabled: "Deshabilitadas"
        }
    }

    var packageListArgument: String? {
        switch self {
        case .all: nil
        case .user: "-3"
        case .system: "-s"
        case .disabled: "-d"
        }
    }
}

struct NearbyDevice: Identifiable, Hashable, Sendable {
    let service: String
    let endpoint: String
    var id: String { service }

    static func parse(_ output: String) -> [NearbyDevice] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 3,
                  fields[1] == "_adb-tls-connect._tcp" || fields[1] == "_adb._tcp",
                  let separator = fields.last?.lastIndex(of: ":"),
                  let port = Int(fields.last![fields.last!.index(after: separator)...]),
                  (1...65535).contains(port) else { return nil }
            return NearbyDevice(service: String(fields[0]), endpoint: String(fields.last!))
        }
    }
}

struct ManualDevice: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var ipAddress: String
    var port: String

    init(id: UUID = UUID(), name: String = "", ipAddress: String, port: String = "5555") {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
    }

    var endpoint: String { "\(ipAddress):\(port)" }
    var displayName: String { name.isEmpty ? ipAddress : name }
}

struct PortRule: Identifiable, Hashable {
    let id = UUID()
    var remote: String
    var local: String
}

enum ADBConnectionResponse {
    static func succeeded(_ output: String) -> Bool {
        let response = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return response.hasPrefix("connected to ") || response.hasPrefix("already connected to ")
    }

    static func failureMessage(output: String, endpoint: String) -> String {
        let response = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if response.localizedCaseInsensitiveContains("no route to host") {
            return "No hay ruta de red hacia \(endpoint). Verifica que el Mac y Android estén en la misma Wi‑Fi, que no haya una VPN activa y que la red no aísle clientes inalámbricos."
        }
        if response.isEmpty {
            return "ADB no pudo conectarse a \(endpoint). Comprueba que Wireless debugging esté activo y que la IP y el puerto sean actuales."
        }
        return "ADB no pudo conectarse a \(endpoint): \(response)"
    }

    static func shouldRetryWithFreshServer(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("no route to host")
    }
}

enum ADBError: LocalizedError {
    case unavailable
    case commandFailed(String)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "ADB was not found. Install Android SDK Platform-Tools with Homebrew, then use Dependencies to check again."
        case .commandFailed(let detail): detail
        case .invalidInput(let detail): detail
        }
    }
}
