import Foundation

protocol EmulatorCore: AnyObject {
    var system: EmulatorSystem { get }
    var frameWidth: Int { get }
    var frameHeight: Int { get }
    var nativeFPS: Double { get }

    func loadROM(at url: URL, biosDirectory: URL) throws
    func runFrame()
    func framebuffer() -> UnsafePointer<UInt32>
    func audioSamples() -> (pointer: UnsafePointer<Int16>, count: Int)
    func setInput(player: Int, buttons: UInt32)
    func saveState() throws -> Data
    func loadState(_ data: Data) throws
    func reset()
    func shutdown()
    // System inputs (coins, service) — only meaningful for arcade (MVS/CPS) cores.
    func setSysInput(_ buttons: UInt32)
}

extension EmulatorCore {
    func setSysInput(_ buttons: UInt32) {}
}
