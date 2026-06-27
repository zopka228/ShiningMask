import SwiftUI

struct ContentView: View {
    @StateObject var vm = MaskViewModel()
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderView(vm: vm)
                MaskPreviewView(vm: vm).padding(.horizontal, 12).padding(.vertical, 10)
                TabContentView(vm: vm)
                TabBarView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $vm.showDeviceList) { DeviceListView(vm: vm) }
    }
}

struct HeaderView: View {
    @ObservedObject var vm: MaskViewModel
    var connectionColor: Color {
        switch vm.ble.state {
        case .connected: return .green
        case .scanning: return .orange
        case .connecting: return .yellow
        case .error: return .red
        default: return Color(white: 0.35)
        }
    }
    var connectionLabel: String {
        switch vm.ble.state {
        case .connected: return vm.ble.connectedMask?.name ?? "Маска"
        case .scanning: return "Поиск..."
        case .connecting: return "Подключение..."
        case .disconnected: return "Отключено"
        case .error(let e): return e
        default: return "Не подключено"
        }
    }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHINING MASK").font(.system(size: 17, weight: .black, design: .monospaced)).foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle().fill(connectionColor).frame(width: 7, height: 7).shadow(color: connectionColor, radius: 3)
                    Text(connectionLabel).font(.system(size: 11, weight: .medium)).foregroundColor(connectionColor)
                }
            }
            Spacer()
            Button(action: {
                if case .connected = vm.ble.state { vm.ble.disconnect() }
                else { vm.showDeviceList = true; vm.ble.startScanning() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: vm.ble.connectedMask != nil ? "bluetooth.slash" : "bluetooth").font(.system(size: 13, weight: .semibold))
                    Text(vm.ble.connectedMask != nil ? "Откл." : "Найти").font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(vm.ble.connectedMask != nil ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .foregroundColor(vm.ble.connectedMask != nil ? .red : .blue)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(white: 0.05))
    }
}

struct MaskPreviewView: View {
    @ObservedObject var vm: MaskViewModel
    let cellSize: CGFloat = 12
    let gap: CGFloat = 1.5
    var ledColor: Color {
        Color(red: Double(vm.selectedColor.0)/255, green: Double(vm.selectedColor.1)/255, blue: Double(vm.selectedColor.2)/255)
    }
    var body: some View {
        let cols = 24, rows = 12
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.04))
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
            .gesture(DragGesture(minimumDistance: 0).onChanged { val in
                let x = val.location.x - 10, y = val.location.y - 10
                let c = Int(x / (cellSize + gap)), r = Int(y / (cellSize + gap))
                if r >= 0 && r < rows && c >= 0 && c < cols { vm.toggleCell(row: r, col: c) }
            })
        }
        .frame(height: CGFloat(rows) * (cellSize + gap) + 20)
    }
}

struct TabContentView: View {
    @ObservedObject var vm: MaskViewModel
    var body: some View {
        Group {
            switch vm.activeTab {
            case .draw:    DrawTabView(vm: vm)
            case .text:    TextTabView(vm: vm)
            case .gallery: GalleryTabView(vm: vm)
            case .animate: AnimateTabView(vm: vm)
            case .settings: SettingsTabView(vm: vm)
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.top, 12)
    }
}

struct DrawTabView: View {
    @ObservedObject var vm: MaskViewModel
    let palette: [(UInt8, UInt8, UInt8, Color)] = [
        (255,0,0,.red),(0,255,0,.green),(0,0,255,.blue),
        (255,255,255,.white),(255,220,0,.yellow),(0,220,255,.cyan),(255,0,200,Color(red:1,green:0,blue:0.78))
    ]
    var body: some View {
        VStack(spacing: 16) {
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
                            Image(systemName: iconFor(action)).font(.system(size: 16))
                            Text(labelFor(action)).font(.system(size: 9, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(isActive(action) ? Color.blue.opacity(0.3) : Color(white: 0.1))
                        .foregroundColor(isActive(action) ? .blue : .gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            HStack(spacing: 10) {
                ForEach(0..<palette.count, id: \.self) { i in
                    let p = palette[i]
                    Circle().fill(p.3).frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Color.white, lineWidth: vm.selectedColor.0 == p.0 && vm.selectedColor.1 == p.1 ? 2.5 : 0))
                        .shadow(color: p.3.opacity(0.7), radius: 4)
                        .onTapGesture { vm.sendColor(p.0, p.1, p.2) }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Яркость").font(.system(size: 12, weight: .medium)).foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(vm.brightness))%").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
                Slider(value: $vm.brightness, in: 10...100).accentColor(.blue)
            }
        }
    }
    func iconFor(_ a: String) -> String {
        switch a { case "draw": return "pencil.tip"; case "erase": return "eraser"; case "clear": return "trash"; case "invert": return "arrow.2.squarepath"; default: return "square.fill" }
    }
    func labelFor(_ a: String) -> String {
        switch a { case "draw": return "Рисовать"; case "erase": return "Стереть"; case "clear": return "Очистить"; case "invert": return "Инверт"; default: return "Залить" }
    }
    func isActive(_ a: String) -> Bool { (a == "draw" && vm.drawMode == .draw) || (a == "erase" && vm.drawMode == .erase) }
}

struct TextTabView: View {
    @ObservedObject var vm: MaskViewModel
    var body: some View {
        VStack(spacing: 16) {
            TextField("Текст для маски...", text: $vm.scrollText)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center).padding()
                .background(Color(white: 0.08)).cornerRadius(12).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Скорость").font(.system(size: 12)).foregroundColor(.gray)
                    Spacer()
                    Text(vm.scrollSpeed <= 3 ? "Медленно" : vm.scrollSpeed <= 6 ? "Средне" : "Быстро").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
                Slider(value: $vm.scrollSpeed, in: 1...10, step: 1).accentColor(.orange)
            }
            Button(action: vm.sendText) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 18))
                    Text("Отправить").font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.orange).foregroundColor(.black).cornerRadius(14)
            }
        }
    }
}

struct GalleryTabView: View {
    @ObservedObject var vm: MaskViewModel
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Preset.all) { preset in
                Button(action: { vm.loadPreset(preset); vm.activeTab = .draw }) {
                    VStack(spacing: 8) {
                        Text(preset.icon).font(.system(size: 28))
                        Text(preset.name).font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(white: 0.09)).cornerRadius(14)
                }
            }
        }
    }
}

struct AnimateTabView: View {
    @ObservedObject var vm: MaskViewModel
    let animations = [("Волна","water.waves",1),("Вспышка","bolt.fill",2),("Пульс","heart.fill",3),
                      ("Матрица","network",4),("Сканер","viewfinder",5),("Радуга","rainbow",6)]
    var body: some View {
        VStack(spacing: 12) {
            Text("Встроенные анимации").font(.system(size: 12)).foregroundColor(.gray)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(animations, id: \.0) { anim in
                    Button(action: { vm.selectedAnimation = anim.2; vm.sendAnimation(anim.2) }) {
                        HStack {
                            Image(systemName: anim.1).font(.system(size: 20)).frame(width: 36)
                            Text(anim.0).font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 14)
                        .background(vm.selectedAnimation == anim.2 ? Color.purple.opacity(0.3) : Color(white: 0.09))
                        .foregroundColor(vm.selectedAnimation == anim.2 ? .purple : .gray)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

struct SettingsTabView: View {
    @ObservedObject var vm: MaskViewModel
    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("BLE UUID").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Service: FFF0").font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                    Text("Write: ...9600").font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                    Text("Data: ...960A").font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                    Text("Notify: ...9601").font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                }
                .padding(12).background(Color(white: 0.08)).cornerRadius(12)
            }
        }
    }
}

struct TabBarView: View {
    @ObservedObject var vm: MaskViewModel
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MaskViewModel.AppTab.allCases, id: \.self) { tab in
                Button(action: { vm.activeTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 18, weight: vm.activeTab == tab ? .semibold : .regular))
                        Text(tab.rawValue).font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .foregroundColor(vm.activeTab == tab ? .white : Color(white: 0.4))
                }
            }
        }
        .background(Color(white: 0.06))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color(white: 0.15)), alignment: .top)
    }
}

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
                        Text("Ищем маску...").foregroundColor(.gray)
                    }
                } else {
                    List(vm.ble.discoveredDevices, id: \.identifier) { device in
                        Button(action: { vm.ble.connect(to: device); dismiss() }) {
                            HStack {
                                Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name ?? "Неизвестное устройство").foregroundColor(.white).font(.system(size: 15, weight: .medium))
                                    Text(device.identifier.uuidString.prefix(18) + "...").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Выбери маску").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { vm.ble.stopScanning(); dismiss() }.foregroundColor(.blue) }
                ToolbarItem(placement: .primaryAction) { Button(action: vm.ble.startScanning) { Image(systemName: "arrow.clockwise") }.foregroundColor(.blue) }
            }
        }
        .preferredColorScheme(.dark)
    }
}
