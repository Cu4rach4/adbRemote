import SwiftUI
import UniformTypeIdentifiers

struct DeviceDetail: View {
    @Environment(DeviceStore.self) private var store
    let device: AndroidDevice
    @State private var alias = ""
    @State private var text = ""
    @State private var showApps = false
    @State private var showPorts = false
    @State private var tcpPort = "5555"
    @State private var isDropTarget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Divider()
                HStack(alignment: .top, spacing: 16) {
                    actionPanel
                    installPanel
                }
                GroupBox("Send Text") {
                    HStack { TextField("Type text for this device", text: $text); Button("Send") { store.perform({ try await ADBClient.shared.inputText(device.serial, text: text) }, success: "Text sent") }.disabled(text.isEmpty || !device.isOnline) }
                    .padding(4)
                }
                GroupBox("Network") {
                    HStack { TextField("TCP/IP port", text: $tcpPort).frame(width: 100); Button("Enable TCP/IP") { store.perform({ try await ADBClient.shared.tcpip(device.serial, port: tcpPort) }, success: "TCP/IP mode enabled on port \(tcpPort)") }.disabled(!device.isOnline); Spacer(); Button("Port Forwarding") { showPorts = true }.disabled(!device.isOnline) }
                    .padding(4)
                }
            }.padding(28)
        }
        .navigationTitle(store.name(for: device))
        .sheet(isPresented: $showApps) { AppsSheet(device: device) }
        .sheet(isPresented: $showPorts) { PortSheet(device: device) }
        .onAppear { alias = store.aliases[device.serial] ?? "" }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Image(systemName: device.isOnline ? "iphone.gen3" : "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(device.isOnline ? .blue : .orange)
            VStack(alignment: .leading) { Text(store.name(for: device)).font(.title2.bold()); Text(device.serial).font(.callout).foregroundStyle(.secondary); Text(device.isOnline ? "Connected" : device.state.capitalized).font(.caption).foregroundStyle(device.isOnline ? .green : .orange) }
            Spacer()
            TextField("Custom name", text: $alias).frame(width: 190).onSubmit { store.aliases[device.serial] = alias }
        }
    }

    private var actionPanel: some View {
        GroupBox("Quick Actions") {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow { action("arrow.uturn.backward", "Back", "4"); action("house", "Home", "3"); action("line.3.horizontal", "Menu", "82") }
                GridRow { action("return", "Enter", "66"); Button { store.perform({ try await ADBClient.shared.mirror(device.serial) }, success: "Mirroring started") } label: { Label("Mirror", systemImage: "rectangle.on.rectangle") }.disabled(!device.isOnline); Button { capture() } label: { Label("Screenshot", systemImage: "camera") }.disabled(!device.isOnline) }
                GridRow { Button { showApps = true } label: { Label("Apps", systemImage: "square.grid.2x2") }.disabled(!device.isOnline); Button(role: .destructive) { store.perform({ try await ADBClient.shared.disconnect(device.serial) }, success: "Disconnected") } label: { Label("Disconnect", systemImage: "wifi.slash") }.disabled(!device.serial.contains(":")); EmptyView() }
            }.padding(5)
        }
    }

    private var installPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APK Installation").font(.headline)
            Text("Drop an APK here to install it on \(store.name(for: device)).").foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isDropTarget ? Color.accentColor : Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .overlay { Label("Drop APK", systemImage: "arrow.down.app").foregroundStyle(isDropTarget ? Color.accentColor : Color.secondary) }
                .frame(minWidth: 240, minHeight: 124)
                .dropDestination(for: URL.self) { urls, _ in install(urls.first); return true } isTargeted: { isDropTarget = $0 }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func action(_ icon: String, _ label: String, _ key: String) -> some View { Button { store.perform({ try await ADBClient.shared.keyEvent(device.serial, key) }, success: "\(label) sent") } label: { Label(label, systemImage: icon) }.disabled(!device.isOnline) }
    private func install(_ url: URL?) { guard let url, url.pathExtension.lowercased() == "apk" else { store.present(ADBError.invalidInput("Please drop a valid .apk file.")); return }; store.perform({ try await ADBClient.shared.install(device.serial, apk: url) }, success: "APK installed") }
    private func capture() { Task { do { store.saveScreenshot(try await ADBClient.shared.screenshot(device.serial)) } catch { store.present(error) } } }
}

private struct AppsSheet: View {
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let device: AndroidDevice
    @State private var apps: [InstalledApp] = []
    @State private var query = ""
    @State private var loading = true
    @State private var kind: AppKind = .all
    var filtered: [InstalledApp] { query.isEmpty ? apps : apps.filter { $0.packageName.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Aplicaciones instaladas").font(.title2); Spacer(); TextField("Buscar", text: $query).frame(width: 180); Button("Listo") { dismiss() } }.padding()
            Picker("Tipo de aplicación", selection: $kind) {
                ForEach(AppKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom)
            if loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if filtered.isEmpty { ContentUnavailableView("No se encontraron aplicaciones", systemImage: "square.grid.2x2", description: Text("No hay aplicaciones \(kind.title.lowercased()) que coincidan con la búsqueda.")) }
            else { List(filtered) { app in HStack { Text(app.packageName).textSelection(.enabled); Spacer(); Button { store.perform({ try await ADBClient.shared.launch(device.serial, package: app.packageName) }, success: "Launched \(app.packageName)") } label: { Image(systemName: "play") }.help("Launch"); Button { store.perform({ try await ADBClient.shared.disable(device.serial, package: app.packageName) }, success: "Disabled \(app.packageName)") } label: { Image(systemName: "nosign") }.help("Disable"); Button(role: .destructive) { store.perform({ try await ADBClient.shared.uninstall(device.serial, package: app.packageName) }, success: "Uninstalled \(app.packageName)"); apps.removeAll { $0 == app } } label: { Image(systemName: "trash") }.help("Uninstall") } }.frame(minHeight: 320) }
        }
        .frame(width: 640, height: 520)
        .task(id: kind) {
            loading = true
            do { apps = try await ADBClient.shared.apps(device.serial, kind: kind) }
            catch { store.present(error); apps = [] }
            loading = false
        }
    }
}

private struct PortSheet: View {
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let device: AndroidDevice
    @State private var remote = "tcp:8081"
    @State private var local = "tcp:8081"
    @State private var rules: [PortRule] = []
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Reverse TCP Ports").font(.title2); HStack { TextField("Remote", text: $remote); TextField("Local", text: $local); Button("Add") { let rule = PortRule(remote: remote, local: local); store.perform({ try await ADBClient.shared.reverse(device.serial, remote: rule.remote, local: rule.local) }, success: "Port rule added"); rules.append(rule) }.disabled(remote.isEmpty || local.isEmpty) }; List { ForEach(rules) { rule in HStack { Text("\(rule.remote) -> \(rule.local)"); Spacer(); Button(role: .destructive) { store.perform({ try await ADBClient.shared.removeReverse(device.serial, remote: rule.remote) }, success: "Port rule removed"); rules.removeAll { $0.id == rule.id } } label: { Image(systemName: "trash") } } }; }; HStack { Spacer(); Button("Done") { dismiss() } } }.padding(24).frame(width: 520, height: 380) }
}
