import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(DeviceStore.self) private var store
    @State private var showPairing = false
    @State private var showAddDevice = false

    var body: some View {
        NavigationSplitView {
            List(selection: Bindable(store).selectedID) {
                Section("Devices") {
                    ForEach(store.devices) { device in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.name(for: device)).font(.headline)
                            Text(device.serial).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(device.id)
                    }
                }
                if !store.nearbyDevices.isEmpty {
                    Section("Nearby wireless") {
                        ForEach(store.nearbyDevices) { nearby in
                            NearbyDeviceRow(nearby: nearby)
                        }
                    }
                }
                if !store.manualDevices.isEmpty {
                    Section("Saved by IP") {
                        ForEach(store.manualDevices) { device in
                            ManualDeviceRow(device: device)
                        }
                    }
                }
            }
            .navigationTitle("ADB Remote")
            .toolbar {
                ToolbarItemGroup {
                    Button { showPairing = true } label: { Image(systemName: "link.badge.plus") }.help("Pair wireless device")
                    Button { showAddDevice = true } label: { Image(systemName: "plus.rectangle.on.rectangle") }.help("Add device by IP address")
                    Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }.help("Refresh devices")
                }
            }
        } detail: {
            if let device = store.selected { DeviceDetail(device: device) }
            else { ContentUnavailableView("No Device Selected", systemImage: "iphone.slash", description: Text("Connect a device with USB or pair it over Wi-Fi.")) }
        }
        .alert("ADB Remote", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .sheet(isPresented: $showPairing) { PairingSheet() }
        .sheet(isPresented: $showAddDevice) { AddDeviceSheet() }
        .sheet(isPresented: Bindable(store).showDependencySetup) { DependencySetupSheet() }
        .safeAreaInset(edge: .bottom) { statusBar }
    }

    private var statusBar: some View {
        HStack {
            Circle().fill(store.devices.contains(where: \.isOnline) ? .green : .secondary).frame(width: 8, height: 8)
            Text(store.status).font(.caption)
            Spacer()
            Text(store.dependencies.adb.isAvailable ? "ADB listo" : "ADB no instalado").font(.caption).foregroundStyle(.secondary)
            Button("Dependencias") { store.showDependencySetup = true }.font(.caption)
        }
            .padding(.horizontal).padding(.vertical, 7).background(.bar)
    }
}

private struct DependencySetupSheet: View {
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Dependencias locales").font(.title2.bold())
            Text("ADB Remote usa herramientas instaladas localmente. Se comprobaron al abrir la aplicación.")
                .foregroundStyle(.secondary)
            dependencyRow(store.dependencies.adb, required: true, command: "brew install --cask android-platform-tools")
            dependencyRow(store.dependencies.scrcpy, required: false, command: "brew install scrcpy")
            Divider()
            Text("Versiones validadas").font(.headline)
            Text("Android SDK Platform-Tools 37.0.1 (adb 1.0.41) y scrcpy 4.1. Se recomienda usar versiones estables actuales.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Volver a comprobar") { store.refreshDependencies() }
                Spacer()
                Button("Listo") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 590)
    }

    @ViewBuilder private func dependencyRow(_ dependency: DependencyStatus, required: Bool, command: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: dependency.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(dependency.isAvailable ? .green : .orange)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(dependency.kind.rawValue)\(required ? " (obligatorio)" : " (para Mirror)")").font(.headline)
                if let path = dependency.path {
                    Text(dependency.version ?? "Instalado").font(.callout)
                    Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                } else {
                    Text("No encontrado. Instálalo con Homebrew:").font(.callout)
                    HStack {
                        Text(command).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Button("Copiar") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string) }
                    }
                }
            }
            Spacer()
        }
    }
}

private struct ManualDeviceRow: View {
    @Environment(DeviceStore.self) private var store
    let device: ManualDevice

    var body: some View {
        HStack(spacing: 8) {
            Button { store.connect(device) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.displayName).lineLimit(1)
                    Text(device.endpoint).font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Connect to \(device.endpoint)")
            Spacer()
            Button { store.connect(device) } label: { Image(systemName: "wifi") }
                .buttonStyle(.borderless).help("Connect")
            Button(role: .destructive) { store.removeManualDevice(device) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("Remove saved device")
        }
    }
}

private struct NearbyDeviceRow: View {
    @Environment(DeviceStore.self) private var store
    let nearby: NearbyDevice

    var body: some View {
        Button {
            let endpoint = nearby.endpoint
            store.perform({ _ = try await ADBClient.shared.connect(host: endpoint) }, success: "Connected to \(endpoint)")
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(nearby.service)
                    .lineLimit(1)
                Text(nearby.endpoint)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Connect")
    }
}

private struct PairingSheet: View {
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var code = ""
    @State private var needsPairingCode = false
    @State private var isConnecting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(needsPairingCode ? "Pair Wireless Device" : "Connect Wirelessly").font(.title2)
            if needsPairingCode {
                Text("Direct connection was not available. Enter the pairing address shown in Wireless debugging and its six-digit code.")
                    .font(.callout).foregroundStyle(.secondary)
                TextField("Host: pairing port", text: $host).textFieldStyle(.roundedBorder)
                TextField("Six-digit pairing code", text: $code).textFieldStyle(.roundedBorder)
            } else {
                Text("Try connecting directly first. Use the IP address and port shown by Wireless debugging.")
                    .font(.callout).foregroundStyle(.secondary)
                TextField("Host:port", text: $host).textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(needsPairingCode ? "Pair" : "Connect") { connectOrPair() }
                    .buttonStyle(.borderedProminent)
                    .disabled(host.isEmpty || (needsPairingCode && code.isEmpty) || isConnecting)
            }
        }.padding(24).frame(width: 420)
    }

    private func connectOrPair() {
        isConnecting = true
        Task {
            do {
                if needsPairingCode {
                    try await ADBClient.shared.pair(host: host, code: code)
                    store.status = "Device paired"
                } else {
                    _ = try await ADBClient.shared.connect(host: host)
                    await store.refresh()
                    let endpoint = host.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard store.devices.contains(where: { $0.serial.caseInsensitiveCompare(endpoint) == .orderedSame && $0.isOnline }) else {
                        throw ADBError.commandFailed("ADB did not confirm an online connection to \(endpoint). Check the current Wireless debugging port and try again.")
                    }
                    store.status = "Connected to \(endpoint)"
                }
                dismiss()
            } catch {
                store.present(error)
            }
            isConnecting = false
        }
    }
}

private struct AddDeviceSheet: View {
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ipAddress = ""
    @State private var port = "5555"
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Device by IP").font(.title2)
            Text("The device must have wireless debugging enabled and be reachable on your network.").font(.callout).foregroundStyle(.secondary)
            TextField("Name (optional)", text: $name).textFieldStyle(.roundedBorder)
            TextField("IP address", text: $ipAddress).textFieldStyle(.roundedBorder)
            TextField("ADB port", text: $port).textFieldStyle(.roundedBorder)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Add & Connect") { store.addManualDevice(name: name, ipAddress: ipAddress, port: port); dismiss() }.buttonStyle(.borderedProminent).disabled(ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || port.isEmpty) }
        }.padding(24).frame(width: 380)
    }
}
