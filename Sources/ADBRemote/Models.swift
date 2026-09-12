import Foundation

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
        case .unavailable: "ADB was not found at /usr/local/bin/adb."
        case .commandFailed(let detail): detail
        case .invalidInput(let detail): detail
        }
    }
}
