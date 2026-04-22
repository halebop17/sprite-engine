import Foundation

// Converts a MAME Neo Geo zip to Geolith's .neo format.
// Reference: https://gitlab.com/jgemu/geolith/-/blob/master/docs/neo_file_format.md
//
// .neo layout
//   [0-3]    magic: 'N','E','O',0x01
//   [4-7]    P ROM size   (LE uint32)
//   [8-11]   S ROM size
//   [12-15]  M1 ROM size
//   [16-19]  V1 ROM size
//   [20-23]  V2 ROM size  (0 → single combined V ROM)
//   [24-27]  C ROM size
//   [28-31]  year, [32-35] genre, [36-39] screenshot, [40-43] NGH
//   [44-76]  name (33 bytes), [77-93] manufacturer (17 bytes)
//   [94-4095] reserved / zeroed
//   [4096+]  P, S, M1, V1, [V2], C blobs

enum NeoConversionError: Error, LocalizedError {
    case extractionFailed(Int32)
    case missingPROM, missingSROM, missingM1ROM, missingVROM, missingCROM
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let code): return "ZIP extraction failed (exit \(code))"
        case .missingPROM:   return "P ROM not found in archive"
        case .missingSROM:   return "S ROM not found in archive"
        case .missingM1ROM:  return "M1 ROM not found in archive"
        case .missingVROM:   return "V ROM not found in archive"
        case .missingCROM:   return "C ROM not found in archive"
        case .writeFailed(let e): return "Write failed: \(e.localizedDescription)"
        }
    }
}

struct NeoConverter {

    static var outputDirectory: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpriteEngine/Converted", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // Convert a MAME Neo Geo zip → .neo file. Returns the output URL.
    func convert(zipURL: URL, progress: ((Double) -> Void)? = nil) async throws -> URL {
        let stem = zipURL.deletingPathExtension().lastPathComponent
        let outputURL = Self.outputDirectory.appendingPathComponent(stem + ".neo")

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoConvert_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        progress?(0.05)
        try extractZip(at: zipURL, to: tmpDir, overwrite: true)

        // Pull in parent ROMs (MAME clone sets). Use -n (no-overwrite) so the
        // clone's own ROMs take precedence over anything in the parent.
        let parentDir = zipURL.deletingLastPathComponent()
        if let siblings = try? FileManager.default.contentsOfDirectory(
            at: parentDir, includingPropertiesForKeys: nil
        ) {
            for candidate in siblings
            where candidate.pathExtension.lowercased() == "zip"
               && candidate.lastPathComponent != zipURL.lastPathComponent
            {
                try? extractZip(at: candidate, to: tmpDir, overwrite: false)
            }
        }

        progress?(0.25)
        let roms = try collectROMs(in: tmpDir)
        progress?(0.45)

        let pData  = concatenate(roms.p)
        let sData  = concatenate(roms.s)
        let mData  = concatenate(roms.m)
        let vData  = concatenate(roms.v)
        let cData  = buildCData(roms.c)

        guard !pData.isEmpty else { throw NeoConversionError.missingPROM }
        guard !sData.isEmpty else { throw NeoConversionError.missingSROM }
        guard !mData.isEmpty else { throw NeoConversionError.missingM1ROM }
        guard !vData.isEmpty else { throw NeoConversionError.missingVROM }
        guard !cData.isEmpty else { throw NeoConversionError.missingCROM }

        progress?(0.75)
        let neoData = buildNEO(stem: stem, p: pData, s: sData, m: mData, v: vData, c: cData)

        do {
            try neoData.write(to: outputURL)
        } catch {
            throw NeoConversionError.writeFailed(error)
        }

        progress?(1.0)
        return outputURL
    }

    // MARK: - Extraction

    private func extractZip(at url: URL, to directory: URL, overwrite: Bool) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        // -q quiet, -o overwrite / -n no-overwrite, flatten into directory
        let overwriteFlag = overwrite ? "-o" : "-n"
        proc.arguments = [overwriteFlag, "-q", "-j", url.path, "-d", directory.path]
        try proc.run()
        proc.waitUntilExit()
        if overwrite && proc.terminationStatus != 0 {
            throw NeoConversionError.extractionFailed(proc.terminationStatus)
        }
    }

    // MARK: - ROM collection

    private struct ROMPart {
        let index: Int
        let data: Data
    }

    private struct ROMSet {
        var p: [ROMPart] = []
        var s: [ROMPart] = []
        var m: [ROMPart] = []
        var v: [ROMPart] = []
        var c: [ROMPart] = []
    }

    private func collectROMs(in directory: URL) throws -> ROMSet {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return ROMSet() }

        var set = ROMSet()

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { continue }

            switch ext {
            case "p1":            set.p.append(ROMPart(index: 1,    data: data))
            case "p2", "sp2":     set.p.append(ROMPart(index: 2,    data: data))
            case "p3":            set.p.append(ROMPart(index: 3,    data: data))
            case "p4":            set.p.append(ROMPart(index: 4,    data: data))
            case "s1":            set.s.append(ROMPart(index: 1,    data: data))
            case "m1":            set.m.append(ROMPart(index: 1,    data: data))
            case "v1":            set.v.append(ROMPart(index: 1,    data: data))
            case "v2":            set.v.append(ROMPart(index: 2,    data: data))
            case "v3":            set.v.append(ROMPart(index: 3,    data: data))
            case "v4":            set.v.append(ROMPart(index: 4,    data: data))
            case "v5":            set.v.append(ROMPart(index: 5,    data: data))
            case "v6":            set.v.append(ROMPart(index: 6,    data: data))
            case "c1":            set.c.append(ROMPart(index: 1,    data: data))
            case "c2":            set.c.append(ROMPart(index: 2,    data: data))
            case "c3":            set.c.append(ROMPart(index: 3,    data: data))
            case "c4":            set.c.append(ROMPart(index: 4,    data: data))
            case "c5":            set.c.append(ROMPart(index: 5,    data: data))
            case "c6":            set.c.append(ROMPart(index: 6,    data: data))
            case "c7":            set.c.append(ROMPart(index: 7,    data: data))
            case "c8":            set.c.append(ROMPart(index: 8,    data: data))
            default: break
            }
        }

        return set
    }

    // MARK: - ROM assembly

    private func concatenate(_ parts: [ROMPart]) -> Data {
        parts.sorted { $0.index < $1.index }
             .reduce(into: Data()) { $0.append($1.data) }
    }

    // C ROMs are interleaved in pairs: (c1,c2), (c3,c4), …
    // Within each pair every byte alternates: c1[0], c2[0], c1[1], c2[1], …
    private func buildCData(_ parts: [ROMPart]) -> Data {
        let sorted = parts.sorted { $0.index < $1.index }
        var result = Data()
        var i = 0
        while i < sorted.count {
            if i + 1 < sorted.count {
                result.append(interleave(sorted[i].data, sorted[i + 1].data))
            } else {
                result.append(sorted[i].data)
            }
            i += 2
        }
        return result
    }

    private func interleave(_ a: Data, _ b: Data) -> Data {
        let len = max(a.count, b.count)
        var out = Data(count: len * 2)
        out.withUnsafeMutableBytes { dst in
            let ptr = dst.baseAddress!.assumingMemoryBound(to: UInt8.self)
            a.withUnsafeBytes { src in
                let s = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
                for i in 0..<a.count { ptr[i * 2] = s[i] }
            }
            b.withUnsafeBytes { src in
                let s = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
                for i in 0..<b.count { ptr[i * 2 + 1] = s[i] }
            }
        }
        return out
    }

    // MARK: - Header

    private func buildNEO(stem: String, p: Data, s: Data, m: Data, v: Data, c: Data) -> Data {
        var header = Data(count: 4096)

        // Magic
        header[0] = UInt8(ascii: "N")
        header[1] = UInt8(ascii: "E")
        header[2] = UInt8(ascii: "O")
        header[3] = 0x01

        func writeLE32(_ value: UInt32, at offset: Int) {
            header[offset]     = UInt8(value & 0xFF)
            header[offset + 1] = UInt8((value >> 8)  & 0xFF)
            header[offset + 2] = UInt8((value >> 16) & 0xFF)
            header[offset + 3] = UInt8((value >> 24) & 0xFF)
        }

        writeLE32(UInt32(p.count), at: 4)
        writeLE32(UInt32(s.count), at: 8)
        writeLE32(UInt32(m.count), at: 12)
        writeLE32(UInt32(v.count), at: 16)
        // v2sz = 0 (single combined V ROM)
        writeLE32(UInt32(c.count), at: 24)
        // year / genre / screenshot / NGH all zero (unknown at conversion time)

        // Name field: bytes 44-76 (33 bytes)
        let nameBytes = Array(stem.prefix(32).utf8)
        for (i, b) in nameBytes.enumerated() { header[44 + i] = b }

        var result = header
        result.append(p)
        result.append(s)
        result.append(m)
        result.append(v)
        result.append(c)
        return result
    }
}
