import SwiftUI

struct ContentView: View {
    @StateObject var vm = MaskViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                HeaderView(vm: vm)

                // ── LED Preview ──
                MaskPreviewView(vm: vm)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                // ── Tab Content ──
                TabContentView(vm: vm)

                // ── Tab Bar ──
                TabBarView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $vm.showDeviceList) {
            DeviceListView(vm: vm)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Header
// ─────────────────────────────────────────────
struct HeaderView: View {
    @ObservedObject var vm: MaskViewModel

    var connectionColor: Color {
        switch vm.ble.state {
        case .connected:     return .green
        case .scanning:      return .orange
        case .connecting:    return .yellow
        case .error:         return .red
        default:             return Color(white: 0.35)
        }
    }

    var connectionLabel: String {
        switch vm.ble.state {
        case .connected:     return vm.ble.connectedMask?.name ?? "Маска"
        case .scanning:      return "Поиск..."
        case .connecting:    return "Подключение..."
        case .disconnected:  return "Отключено"
        case .error(let e):  return e
        default:             return "Не подключено"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHINING MASK")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: connectionColor, radius: 3)
                    Text(connectionLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(connectionColor)
                    if case .connected = vm.ble.state {
                        Text("• \(vm.ble.signalStrength) dBm")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            Spacer()
            Button(action: {
                if case .connected = vm.ble.state {
                    vm.ble.disconnect()
                } else {
                    vm.showDeviceList = true
                    vm.ble.startScanning()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: vm.ble.connectedMask != nil ? "bluetooth.slash" : "bluetooth")
                        .font(.system(size: 13, weight: .semibold))
                    Text(vm.ble.connectedMask != nil ? "Откл." : "Найти")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(vm.ble.connectedMask != nil ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .foregroundColor(vm.ble.connectedMask != nil ? .red : .blue)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(vm.ble.connectedMask != nil ? Color.red.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.05))
    }
}

// ─────────────────────────────────────────────
// MARK: - LED Preview
// ─────────────────────────────────────────────
struct MaskPreviewView: View {
    @ObservedObject var vm: MaskViewModel
    let cellSize: CGFloat = 12
    let gap: CGFloat = 1.5

    var ledColor: Color {
        Color(
            red: Double(vm.selectedColor.r) / 255,
            green: Double(vm.selectedColor.g) / 255,
            blue: Double(vm.selectedColor.b) / 255
        )
    }

    var body: some View {
        let cols = 24, rows = 12
        let w = CGFloat(cols) * (cellSize + gap)

        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(white: 0.12), lineWidth: 1))

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { c in
                            let on = vm.grid[r][c]
                            RoundedRectangle(cornerRadius: 2)
                                .fill(on ? ledColor : Color(white: 0.08))
                                .frame(width: cellSize, height: cellSize)
                                .shadow(color: on ? ledColor.opacity(0.8) : .clear, radius: 3)
                                .onTapGesture { vm.toggleCell(row: r, col: c) }
                        }
                    }
                }
            }
            .padding(10)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let x = val.location.x - 10
                        let y = val.location.y - 10
                        let c = Int(x / (cellSize + gap))
                        let r = Int(y / (cellSize + gap))
                        if r >= 0 && r < rows && c >= 0 && c < cols {
                            vm.toggleCell(row: r, col: c)
                        }
                    }
            )
        }
        .frame(height: CGFloat(rows) * (cellSize + gap) + 20)
    }
}

// ─────────────────────────────────────────────
// MARK: - Tab Content
// ─────────────────────────────────────────────
struct TabContentView: View {
    @ObservedObject var vm: MaskViewModel

    var body: some View {
        Group {
            switch vm.activeTab {
            case .draw:     DrawTabView(vm: vm)
            case .text:     TextTabView(vm: vm)
            case .gallery:  GalleryTabView(vm: vm)
            case .animate:  AnimateTabView(vm: vm)
            case .settings: SettingsTabView(vm: vm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// ─────────────────────────────────────────────
// MARK: - Draw Tab
// ─────────────────────────────────────────────
struct DrawTabView: View {
    @ObservedObject var vm: MaskViewModel

    let colors: [MaskColor] = [.red, .green, .blue, .white, .yellow, .cyan, .magenta]
    let colorValues: [Color] = [.red, .green, .blue, .white, .yellow, .cyan, Color(red: 1, green: 0, blue: 0.78)]

    var body: some View {
        VStack(spacing: 16) {
            // Draw/Erase/Clear
            HStack(spacing: 10) {
                ForEach(["draw","erase","clear","invert","fill"], id: \.self) { action in
                    Button(action: {
                        switch action {
                        case "draw":   vm.drawMode = .draw
                        case "erase":  vm.drawMode = .erase
                        case "clear":  vm.clearGrid()
                        case "invert": vm.invertGrid()
                        case "fill":   vm.fillGrid()
                        default: break
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: iconFor(action))
                                .font(.system(size: 16))
                            Text(labelFor(action))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive(action) ? Color.blue.opacity(0.3) : Color(white: 0.1))
                        .foregroundColor(isActive(action) ? .blue : .gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive(action) ? Color.blue.opacity(0.5) : .clear, lineWidth: 1))
                    }
                }
            }

            // Color Palette
            HStack(spacing: 10) {
                ForEach(0..<colors.count, id: \.self) { i in
                    Circle()
                        .fill(colorValues[i])
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Color.white, lineWidth: vm.selectedColor.r == colors[i].r && vm.selectedColor.g == colors[i].g ? 2.5 : 0))
                        .shadow(color: colorValues[i].opacity(0.7), radius: 4)
                        .onTapGesture { vm.sendColor(colors[i]) }
                }
                Spacer()
            }

            // Brightness
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Яркость").font(.system(size: 12, weight: .medium)).foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(vm.brightness))%").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
                Slider(value: $vm.brightness, in: 10...100)
                    .accentColor(.blue)
            }
        }
    }

    func iconFor(_ a: String) -> String {
        switch a {
        case "draw":   return "pencil.tip"
        case "erase":  return "eraser"
        case "clear":  return "trash"
        case "invert": return "arrow.2.squarepath"
        case "fill":   return "square.fill"
        default:       return "questionmark"
        }
    }

    func labelFor(_ a: String) -> String {
        switch a {
        case "draw":   return "Рисовать"
        case "erase":  return "Стереть"
        case "clear":  return "Очистить"
        case "invert": return "Инверт"
        case "fill":   return "Залить"
        default:       return a
        }
    }

    func isActive(_ a: String) -> Bool {
        (a == "draw" && vm.drawMode == .draw) || (a == "erase" && vm.drawMode == .erase)
    }
}

// ─────────────────────────────────────────────
// MARK: - Text Tab
// ─────────────────────────────────────────────
struct TextTabView: View {
    @ObservedObject var vm: MaskViewModel

    var body: some View {
        VStack(spacing: 16) {
            TextField("Текст для маски...", text: $vm.scrollText)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(white: 0.08))
                .cornerRadius(12)
                .foregroundColor(.white)
                .textInputAutocapitalization(.characters)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Скорость прокрутки").font(.system(size: 12)).foregroundColor(.gray)
                    Spacer()
                    Text(speedLabel).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
                Slider(value: $vm.scrollSpeed, in: 1...10, step: 1).accentColor(.orange)
            }

            Button(action: vm.sendText) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 18))
                    Text("Отправить на маску").font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .foregroundColor(.black)
                .cornerRadius(14)
            }
        }
    }

    var speedLabel: String {
        let s = Int(vm.scrollSpeed)
        if s <= 3 { return "Медленно" }
        if s <= 6 { return "Средне" }
        return "Быстро"
    }
}

// ─────────────────────────────────────────────
// MARK: - Gallery Tab
// ─────────────────────────────────────────────
struct GalleryTabView: View {
    @ObservedObject var vm: MaskViewModel
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Preset.all) { preset in
                Button(action: {
                    vm.loadPreset(preset)
                    vm.activeTab = .draw
                }) {
                    VStack(spacing: 8) {
                        Text(preset.icon).font(.system(size: 32))
                        Text(preset.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.09))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.15), lineWidth: 1))
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Animate Tab
// ─────────────────────────────────────────────
struct AnimateTabView: View {
    @ObservedObject var vm: MaskViewModel

    let animations = [
        ("Волна", "water.waves", 0),
        ("Вспышка", "bolt.fill", 1),
        ("Пульс", "heart.fill", 2),
        ("Матрица", "network", 3),
        ("Сканер", "viewfinder", 4),
        ("Радуга", "rainbow", 5),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Встроенные анимации маски")
                .font(.system(size: 12)).foregroundColor(.gray)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(animations, id: \.0) { anim in
                    Button(action: {
                        vm.selectedAnimation = anim.2
                        vm.sendAnimation(anim.2)
                    }) {
                        HStack {
                            Image(systemName: anim.1)
                                .font(.system(size: 20))
                                .frame(width: 36)
                            Text(anim.0)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(vm.selectedAnimation == anim.2 ? Color.purple.opacity(0.3) : Color(white: 0.09))
                        .foregroundColor(vm.selectedAnimation == anim.2 ? .purple : .gray)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(vm.selectedAnimation == anim.2 ? Color.purple.opacity(0.5) : .clear, lineWidth: 1))
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Settings Tab
// ─────────────────────────────────────────────
struct SettingsTabView: View {
    @ObservedObject var vm: MaskViewModel

    var body: some View {
        VStack(spacing: 0) {
            settingsSection("Протокол BLE") {
                infoRow("Service UUID", value: MaskUUID.service.uuidString)
                infoRow("Write UUID", value: MaskUUID.writeChar.uuidString)
                infoRow("Notify UUID", value: MaskUUID.notifyChar.uuidString)
            }

            settingsSection("Отладка") {
                Button("Отправить тестовую команду") {
                    let test = Data([0xAA, 0x55, 0x00, 0x00])
                    vm.ble.send(test)
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }

            settingsSection("Как найти протокол") {
                VStack(alignment: .leading, spacing: 8) {
                    step("1", "Скачай nRF Connect в App Store")
                    step("2", "Подключись к маске через nRF Connect")
                    step("3", "Открой оригинальное Shining Mask и отправь команду")
                    step("4", "В nRF Connect смотри что записывается в характеристику")
                    step("5", "Скопируй UUID сервиса и характеристики в BLEManager.swift")
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .background(Color(white: 0.08))
            .cornerRadius(12)
        }
        .padding(.bottom, 14)
    }

    func infoRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }

    func step(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 10, weight: .black))
                .frame(width: 18, height: 18)
                .background(Color.blue.opacity(0.3))
                .foregroundColor(.blue)
                .clipShape(Circle())
            Text(text).font(.system(size: 12)).foregroundColor(.gray)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Tab Bar
// ─────────────────────────────────────────────
struct TabBarView: View {
    @ObservedObject var vm: MaskViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MaskViewModel.AppTab.allCases, id: \.self) { tab in
                Button(action: { vm.activeTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: vm.activeTab == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(vm.activeTab == tab ? .white : Color(white: 0.4))
                }
            }
        }
        .background(Color(white: 0.06))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color(white: 0.15)), alignment: .top)
    }
}

// ─────────────────────────────────────────────
// MARK: - Device List Sheet
// ─────────────────────────────────────────────
struct DeviceListView: View {
    @ObservedObject var vm: MaskViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                if vm.ble.discoveredDevices.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView().progressViewStyle(.circular).scaleEffect(1.5)
                        Text("Ищем маску...")
                            .foregroundColor(.gray)
                    }
                } else {
                    List(vm.ble.discoveredDevices, id: \.identifier) { device in
                        Button(action: {
                            vm.ble.connect(to: device)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name ?? "Неизвестное устройство")
                                        .foregroundColor(.white)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(device.identifier.uuidString.prefix(18) + "...")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray).font(.system(size: 12))
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Выбери маску")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        vm.ble.stopScanning()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: vm.ble.startScanning) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
