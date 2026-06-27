import SwiftUI
import Combine

class MaskViewModel: ObservableObject {
    // BLE
    @Published var ble = BLEManager()

    // Canvas
    @Published var grid: [[Bool]] = Array(repeating: Array(repeating: false, count: 24), count: 12)
    @Published var selectedColor: MaskColor = .red
    @Published var brightness: Double = 80
    @Published var drawMode: DrawMode = .draw

    // Text
    @Published var scrollText: String = "HELLO"
    @Published var scrollSpeed: Double = 3

    // Animations
    @Published var selectedAnimation: Int = 0

    // UI
    @Published var activeTab: AppTab = .draw
    @Published var showDeviceList = false

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
    private var sendTimer: Timer?

    init() {
        // Авто-отправка при изменении сетки
        $grid
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.sendCurrentFrame() }
            .store(in: &cancellables)

        $brightness
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] val in self?.sendBrightness(val) }
            .store(in: &cancellables)
    }

    // MARK: - Drawing

    func toggleCell(row: Int, col: Int) {
        guard row < 12, col < 24 else { return }
        grid[row][col] = drawMode == .draw
    }

    func clearGrid() {
        grid = Array(repeating: Array(repeating: false, count: 24), count: 12)
    }

    func fillGrid() {
        grid = Array(repeating: Array(repeating: true, count: 24), count: 12)
    }

    func loadPreset(_ preset: Preset) {
        grid = preset.grid
        sendCurrentFrame()
    }

    func invertGrid() {
        grid = grid.map { $0.map { !$0 } }
    }

    // MARK: - BLE Send

    func sendCurrentFrame() {
        guard case .connected = ble.state else { return }
        let cmd = MaskCommand.pixelFrame(grid, color: selectedColor)
        ble.send(cmd)
    }

    func sendText() {
        guard case .connected = ble.state else { return }
        let cmd = MaskCommand.scrollText(scrollText, speed: UInt8(scrollSpeed))
        ble.send(cmd)
    }

    func sendAnimation(_ index: Int) {
        guard case .connected = ble.state else { return }
        let cmd = MaskCommand.builtinAnimation(UInt8(index))
        ble.send(cmd)
    }

    func sendBrightness(_ value: Double) {
        guard case .connected = ble.state else { return }
        let cmd = MaskCommand.brightness(UInt8(value))
        ble.send(cmd)
    }

    func sendColor(_ color: MaskColor) {
        selectedColor = color
        sendCurrentFrame()
    }

    // MARK: - Debug: показать байты команды

    func debugBytes(for command: Data) -> String {
        command.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// ─────────────────────────────────────────────
// MARK: - Presets
// ─────────────────────────────────────────────
struct Preset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let grid: [[Bool]]

    static let all: [Preset] = [skull, heart, smile, lightning, diamond, cross]

    static let skull = Preset(name: "Череп", icon: "💀", grid: {
        var g = blank
        let pts: [(Int,Int)] = [
            (1,4),(1,5),(1,6),(1,7),(1,8),(1,9),(1,10),(1,11),(1,12),(1,13),(1,14),(1,15),(1,16),(1,17),(1,18),(1,19),
            (2,2),(2,3),(2,4),(2,19),(2,20),(2,21),
            (3,1),(3,2),(3,21),(3,22),(4,1),(4,22),
            (5,1),(5,4),(5,5),(5,6),(5,8),(5,9),(5,10),(5,13),(5,14),(5,15),(5,17),(5,18),(5,19),(5,22),
            (6,1),(6,4),(6,5),(6,6),(6,8),(6,9),(6,10),(6,13),(6,14),(6,15),(6,17),(6,18),(6,19),(6,22),
            (7,1),(7,22),(8,1),(8,2),(8,21),(8,22),
            (9,2),(9,3),(9,7),(9,8),(9,9),(9,14),(9,15),(9,16),(9,20),(9,21),
            (10,4),(10,5),(10,6),(10,7),(10,8),(10,9),(10,14),(10,15),(10,16),(10,17),(10,18),(10,19),
            (11,9),(11,10),(11,11),(11,12),(11,13),(11,14),
        ]
        pts.forEach { if $0.0 < 12 && $0.1 < 24 { g[$0.0][$0.1] = true } }
        return g
    }())

    static let heart = Preset(name: "Сердце", icon: "❤️", grid: {
        var g = blank
        for r in 0..<12 {
            for c in 0..<24 {
                let x = Double(c - 12) / 7.0
                let y = Double(6 - r) / 5.0
                if pow(x*x + y*y - 1, 3) - x*x*y*y*y < 0 { g[r][c] = true }
            }
        }
        return g
    }())

    static let smile = Preset(name: "Улыбка", icon: "😊", grid: {
        var g = blank
        let cx = 12.0, cy = 6.0
        for r in 0..<12 {
            for c in 0..<24 {
                let x = Double(c) - cx, y = Double(r) - cy
                let d = sqrt(x*x + y*y)
                if abs(d - 5.2) < 0.9 { g[r][c] = true }
            }
        }
        [[3,8],[3,9],[3,14],[3,15]].forEach { g[$0[0]][$0[1]] = true }
        for c in 8...15 {
            let x = Double(c) - 12.0
            let y = sqrt(max(0, 8 - x*x*0.18))
            let r = Int(6.0 + y)
            if r < 12 { g[r][c] = true }
        }
        return g
    }())

    static let lightning = Preset(name: "Молния", icon: "⚡", grid: {
        var g = blank
        let pts: [(Int,Int)] = [
            (0,12),(0,13),(0,14),(0,15),
            (1,10),(1,11),(1,12),(1,13),
            (2,8),(2,9),(2,10),(2,11),
            (3,6),(3,7),(3,8),(3,9),(3,10),(3,11),(3,12),(3,13),(3,14),(3,15),
            (4,8),(4,9),(4,10),(4,11),(4,12),(4,13),
            (5,10),(5,11),(5,12),(5,13),
            (6,12),(6,13),(6,14),
            (7,14),(7,15),(7,16),
            (8,16),(8,17),
        ]
        pts.forEach { if $0.0 < 12 && $0.1 < 24 { g[$0.0][$0.1] = true } }
        return g
    }())

    static let diamond = Preset(name: "Алмаз", icon: "💎", grid: {
        var g = blank
        let cx = 12, cy = 6
        for r in 0..<12 {
            for c in 0..<24 {
                if abs(c - cx) + abs(r - cy) <= 5 { g[r][c] = true }
            }
        }
        return g
    }())

    static let cross = Preset(name: "Крест", icon: "✝️", grid: {
        var g = blank
        for c in 0..<24 { g[5][c] = true; g[6][c] = true }
        for r in 0..<12 { g[r][11] = true; g[r][12] = true }
        return g
    }())

    private static var blank: [[Bool]] {
        Array(repeating: Array(repeating: false, count: 24), count: 12)
    }
}
