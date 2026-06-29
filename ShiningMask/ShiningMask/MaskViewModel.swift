import SwiftUI
import Combine

class MaskViewModel: ObservableObject {
    @Published var ble = BLEManager()
    @Published var grid: [[Bool]] = Array(repeating: Array(repeating: false, count: 24), count: 12)
    @Published var selectedColor: (UInt8, UInt8, UInt8) = (255, 0, 0)
    @Published var brightness: Double = 80
    @Published var drawMode: DrawMode = .draw
    @Published var scrollText: String = "HELLO"
    @Published var scrollSpeed: Double = 3
    @Published var selectedAnimation: Int = 1
    @Published var activeTab: AppTab = .draw
    @Published var showDeviceList = false
    @Published var isSending = false

    enum DrawMode { case draw, erase }
    enum AppTab: String, CaseIterable {
        case draw = "Рисовать"
        case text = "Текст"
        case gallery = "Галерея"
        case animate = "Анимация"
        case settings = "Настройки"
        var icon: String {
            switch self {
            case .draw: return "pencil.tip"
            case .text: return "textformat"
            case .gallery: return "theatermasks"
            case .animate: return "sparkles"
            case .settings: return "gearshape"
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        $brightness
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] val in self?.sendBrightness(val) }
            .store(in: &cancellables)
    }

    func toggleCell(row: Int, col: Int) {
        guard row < 12, col < 24 else { return }
        grid[row][col] = drawMode == .draw
    }

    func clearGrid() { grid = Array(repeating: Array(repeating: false, count: 24), count: 12) }
    func fillGrid() { grid = Array(repeating: Array(repeating: true, count: 24), count: 12) }
    func invertGrid() { grid = grid.map { $0.map { !$0 } } }
    func loadPreset(_ preset: Preset) { grid = preset.grid }

    func sendBrightness(_ value: Double) {
        guard case .connected = ble.state else { return }
        ble.sendBrightness(Int(value))
    }

    func sendAnimation(_ index: Int) {
        guard case .connected = ble.state else { return }
        ble.sendAnimation(index)
    }

    func sendColor(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        selectedColor = (r, g, b)
    }

    // MARK: - Отправка пикселей на маску
    func sendCurrentPixels() {
        guard case .connected = ble.state else { return }
        isSending = true

        // Шаг 1: отправить DATS команду (запрос загрузки)
        // 24*12 = 288 пикселей * 3 RGB = 864 байт = 0x0360
        let dats = Data([0x9C, 0x89, 0xBA, 0x6C, 0x2F, 0x96, 0x16, 0xA8, 0xDE, 0xA8, 0x06, 0x22, 0x6E, 0x9A, 0x13, 0xFB])
        ble.sendCmd(dats)

        // Шаг 2: через 300мс отправить пиксели в 960A
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendPixelData()
        }
    }

    private func sendPixelData() {
        let r = selectedColor.0, g = selectedColor.1, b = selectedColor.2
        var rgb: [UInt8] = []
        for row in grid {
            for on in row {
                rgb += on ? [r, g, b] : [0, 0, 0]
            }
        }

        // Разбиваем на пакеты по 98 байт данных
        let chunkSize = 98
        var packets: [[UInt8]] = []
        var idx: UInt8 = 0
        var offset = 0
        while offset < rgb.count {
            let chunk = Array(rgb[offset..<min(offset + chunkSize, rgb.count)])
            packets.append([UInt8(chunk.count + 1), idx] + chunk)
            offset += chunkSize
            idx += 1
        }

        // Отправляем с задержкой между пакетами
        for (i, packet) in packets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                self.ble.sendData(Data(packet))
                if i == packets.count - 1 {
                    // После последнего пакета — команда PLAY
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let play = Data([0x5A, 0x13, 0x97, 0x3B, 0x5D, 0xD6, 0x88, 0x3D, 0x62, 0x66, 0x62, 0xF4, 0xE1, 0x76, 0x34, 0xC2])
                        self.ble.sendCmd(play)
                        self.isSending = false
                    }
                }
            }
        }
    }

    func sendText() {
        guard case .connected = ble.state else { return }
        ble.sendSpeed(Int(scrollSpeed))
    }
}

struct Preset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let grid: [[Bool]]

    static let all: [Preset] = [skull, heart, smile, diamond, cross]

    static let skull: Preset = {
        var g = blankGrid()
        let pts: [(Int,Int)] = [
            (1,4),(1,18),(2,2),(2,20),(3,1),(3,21),(4,1),(4,21),
            (5,1),(5,4),(5,5),(5,8),(5,9),(5,14),(5,15),(5,18),(5,21),
            (6,1),(6,4),(6,5),(6,8),(6,9),(6,14),(6,15),(6,18),(6,21),
            (7,1),(7,21),(8,2),(8,20),(9,3),(9,7),(9,8),(9,15),(9,16),(9,20),
            (10,5),(10,6),(10,7),(10,8),(10,15),(10,16),(10,17),(10,18),
            (11,9),(11,10),(11,13),(11,14),
        ]
        for p in pts { if p.0 < 12 && p.1 < 24 { g[p.0][p.1] = true } }
        for c in 4...18 { g[1][c] = true }
        return Preset(name: "Череп", icon: "💀", grid: g)
    }()

    static let heart: Preset = {
        var g = blankGrid()
        for r in 0..<12 {
            for c in 0..<24 {
                let x = Double(c - 12) / 7.0
                let y = Double(6 - r) / 5.0
                if pow(x*x + y*y - 1, 3) - x*x*y*y*y < 0 { g[r][c] = true }
            }
        }
        return Preset(name: "Сердце", icon: "❤️", grid: g)
    }()

    static let smile: Preset = {
        var g = blankGrid()
        for r in 0..<12 {
            for c in 0..<24 {
                let dx = Double(c) - 12.0
                let dy = Double(r) - 6.0
                let dist = (dx*dx + dy*dy).squareRoot()
                if abs(dist - 5.2) < 0.9 { g[r][c] = true }
            }
        }
        g[3][8] = true; g[3][9] = true; g[3][14] = true; g[3][15] = true
        for c in 8...15 {
            let dx = Double(c) - 12.0
            let dy2 = max(0.0, 8.0 - dx*dx*0.18)
            let r = Int(6.0 + dy2.squareRoot())
            if r < 12 { g[r][c] = true }
        }
        return Preset(name: "Улыбка", icon: "😊", grid: g)
    }()

    static let diamond: Preset = {
        var g = blankGrid()
        for r in 0..<12 {
            for c in 0..<24 {
                if abs(c - 12) + abs(r - 6) <= 5 { g[r][c] = true }
            }
        }
        return Preset(name: "Алмаз", icon: "💎", grid: g)
    }()

    static let cross: Preset = {
        var g = blankGrid()
        for c in 0..<24 { g[5][c] = true; g[6][c] = true }
        for r in 0..<12 { g[r][11] = true; g[r][12] = true }
        return Preset(name: "Крест", icon: "✝️", grid: g)
    }()

    static func blankGrid() -> [[Bool]] {
        Array(repeating: Array(repeating: false, count: 24), count: 12)
    }
}
