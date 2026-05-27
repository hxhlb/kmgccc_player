#!/usr/bin/env swift

import AppKit
import CryptoKit
import Foundation
import ImageIO

private let magic = Array("KMGASSET".utf8)
private let formatVersion: UInt8 = 1
private let algorithmAESGCM256: UInt8 = 1

private struct Arguments {
    var input: URL?
    var output: URL?
    var logicalRoot = "BKThemes"
    var force = false
    var allowlist: URL?
    var xcassets: URL?
}

private struct ManifestEntry: Codable {
    let sourceKind: String
    let logicalName: String
    let originalAssetName: String?
    let originalPath: String
    let encryptedPath: String
    let originalExtension: String
    let appearance: String
    let scale: String
    let sha256Plaintext: String
    let sha256CipherFile: String
    let width: Int?
    let height: Int?
    let generatedAt: String
    let formatVersion: Int
}

private struct Manifest: Codable {
    let generatedAt: String
    let formatVersion: Int
    let algorithm: String
    let entries: [ManifestEntry]
}

private struct AssetAllowlist: Codable {
    struct XCAsset: Codable {
        let name: String
        let mode: String?
    }

    let bkThemes: Bool?
    let xcassetsSourceRoots: [String]?
    let xcassets: [XCAsset]?
}

private struct XCAssetContents: Codable {
    struct Image: Codable {
        struct Appearance: Codable {
            let appearance: String?
            let value: String?
        }

        let filename: String?
        let idiom: String?
        let scale: String?
        let appearances: [Appearance]?
    }

    let images: [Image]
}

private enum ToolError: Error, CustomStringConvertible {
    case missingArgument(String)
    case invalidHexKey
    case unsupportedFile(URL)
    case invalidAllowlist(URL)
    case missingXCAsset(String)
    case unsupportedXCAsset(String)

    var description: String {
        switch self {
        case .missingArgument(let name):
            return "missing required argument: \(name)"
        case .invalidHexKey:
            return "KMG_ART_ASSET_KEY_HEX must be 64 hex characters when provided"
        case .unsupportedFile(let url):
            return "unsupported file: \(url.path)"
        case .invalidAllowlist(let url):
            return "invalid encrypted asset allowlist: \(url.path)"
        case .missingXCAsset(let name):
            return "missing xcasset image set: \(name)"
        case .unsupportedXCAsset(let name):
            return "unsupported xcasset image set: \(name)"
        }
    }
}

private func parseArguments() throws -> Arguments {
    var result = Arguments()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--input":
            guard let value = iterator.next() else { throw ToolError.missingArgument("--input") }
            result.input = URL(fileURLWithPath: value)
        case "--output":
            guard let value = iterator.next() else { throw ToolError.missingArgument("--output") }
            result.output = URL(fileURLWithPath: value)
        case "--logical-root":
            guard let value = iterator.next() else { throw ToolError.missingArgument("--logical-root") }
            result.logicalRoot = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        case "--force":
            result.force = true
        case "--allowlist":
            guard let value = iterator.next() else { throw ToolError.missingArgument("--allowlist") }
            result.allowlist = URL(fileURLWithPath: value)
        case "--xcassets":
            guard let value = iterator.next() else { throw ToolError.missingArgument("--xcassets") }
            result.xcassets = URL(fileURLWithPath: value)
        default:
            throw ToolError.missingArgument("unknown argument \(arg)")
        }
    }
    return result
}

private func embeddedKeyMaterial() -> SymmetricKey {
    let a: [UInt8] = [0x38, 0xa5, 0x4c, 0x13, 0x77, 0xd1, 0x90, 0x2e]
    let b: [UInt8] = [0xc6, 0x0b, 0xf2, 0x44, 0x9d, 0x21, 0x6a, 0xbc]
    let c: [UInt8] = [0x05, 0xe9, 0x73, 0x8f, 0x12, 0x56, 0xd8, 0x3a]
    let d: [UInt8] = [0xb1, 0x64, 0x2f, 0xce, 0x49, 0x80, 0x0d, 0xf7]
    var material: [UInt8] = []
    for (index, byte) in (a + c + b + d).enumerated() {
        material.append(byte ^ UInt8((index &* 29 + 0x5d) & 0xff))
    }
    let digest = SHA256.hash(data: Data(material + Array("kmgccc-player-art-assets-v1".utf8)))
    return SymmetricKey(data: Data(digest))
}

private func keyFromEnvironment() throws -> SymmetricKey? {
    guard let hex = ProcessInfo.processInfo.environment["KMG_ART_ASSET_KEY_HEX"], !hex.isEmpty else {
        return nil
    }
    guard hex.count == 64 else { throw ToolError.invalidHexKey }

    var bytes: [UInt8] = []
    bytes.reserveCapacity(32)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<next], radix: 16) else {
            throw ToolError.invalidHexKey
        }
        bytes.append(byte)
        index = next
    }
    return SymmetricKey(data: Data(bytes))
}

private func appendUInt16(_ value: UInt16, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

private func appendUInt64(_ value: UInt64, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func imageDimensions(for url: URL) -> (Int?, Int?) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else {
        return (nil, nil)
    }
    return (
        properties[kCGImagePropertyPixelWidth] as? Int,
        properties[kCGImagePropertyPixelHeight] as? Int
    )
}

private func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
    let sealed = try AES.GCM.seal(plaintext, using: key)
    var output = Data()
    output.append(contentsOf: magic)
    output.append(formatVersion)
    output.append(algorithmAESGCM256)
    output.append(0)
    appendUInt16(UInt16(sealed.nonce.withUnsafeBytes { $0.count }), to: &output)
    appendUInt16(UInt16(sealed.tag.count), to: &output)
    appendUInt64(UInt64(sealed.ciphertext.count), to: &output)
    sealed.nonce.withUnsafeBytes { output.append(contentsOf: $0) }
    output.append(sealed.ciphertext)
    output.append(sealed.tag)
    return output
}

private func loadExistingManifest(from url: URL) -> [String: ManifestEntry] {
    guard let data = try? Data(contentsOf: url),
          let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
    else {
        return [:]
    }
    return Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.logicalName, $0) })
}

private func supportedImageFiles(in input: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: input,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }
    return try enumerator.compactMap { item in
        guard let url = item as? URL else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { return nil }
        guard supportedImageExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        return url
    }.sorted { $0.path < $1.path }
}

private let supportedImageExtensions = Set(["png", "jpg", "jpeg", "webp"])

private func relativePath(from file: URL, root: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let filePath = file.standardizedFileURL.path
    var relative = String(filePath.dropFirst(rootPath.count))
    if relative.hasPrefix("/") { relative.removeFirst() }
    return relative
}

private func loadAllowlist(from url: URL?) throws -> AssetAllowlist? {
    guard let url else { return nil }
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AssetAllowlist.self, from: data)
    } catch {
        throw ToolError.invalidAllowlist(url)
    }
}

private func appearanceName(for image: XCAssetContents.Image) -> String {
    guard let appearances = image.appearances, !appearances.isEmpty else {
        return "universal"
    }
    if appearances.contains(where: { $0.appearance == "luminosity" && $0.value == "dark" }) {
        return "dark"
    }
    if appearances.contains(where: { $0.appearance == "luminosity" && $0.value == "light" }) {
        return "light"
    }
    return appearances.compactMap(\.value).joined(separator: "-").isEmpty
        ? "universal"
        : appearances.compactMap(\.value).joined(separator: "-")
}

private func variantStem(assetName: String, appearance: String, scale: String, multipleImages: Bool) -> String {
    guard multipleImages else { return assetName }
    var parts: [String] = []
    if appearance != "universal" {
        parts.append(appearance)
    }
    if scale != "universal" {
        parts.append(scale.replacingOccurrences(of: "@", with: ""))
    }
    if parts.isEmpty {
        parts.append("universal")
    }
    return "\(assetName)/\(parts.joined(separator: "-"))"
}

private func xcassetDirectory(named name: String, roots: [URL]) -> URL? {
    for root in roots {
        let candidate = root.appendingPathComponent("\(name).imageset")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return candidate
        }
    }
    return nil
}

private func run() throws {
    let args = try parseArguments()
    guard let input = args.input else { throw ToolError.missingArgument("--input") }
    guard let output = args.output else { throw ToolError.missingArgument("--output") }

    let allowlist = try loadAllowlist(from: args.allowlist)
    let key = try keyFromEnvironment() ?? embeddedKeyMaterial()
    let generatedAt = ISO8601DateFormatter().string(from: Date())
    let manifestURL = output.appendingPathComponent("manifest.json")
    let existing = loadExistingManifest(from: manifestURL)
    let inputRoot = input.standardizedFileURL

    var encrypted = 0
    var skipped = 0
    var failed = 0
    var entries: [ManifestEntry] = []

    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    if allowlist?.bkThemes ?? true {
        for file in try supportedImageFiles(in: inputRoot) {
            do {
                let originalData = try Data(contentsOf: file)
                let plaintextHash = sha256Hex(originalData)
                let relative = relativePath(from: file, root: inputRoot)
                guard !relative.isEmpty else { throw ToolError.unsupportedFile(file) }

                let stem = (relative as NSString).deletingPathExtension
                let logicalName = "\(args.logicalRoot)/\(stem)"
                let encryptedRelative = "\(args.logicalRoot)/\(stem).kmgasset"
                let encryptedURL = output.appendingPathComponent(encryptedRelative)
                let previous = existing[logicalName]

                if !args.force,
                   let previous,
                   previous.sha256Plaintext == plaintextHash,
                   FileManager.default.fileExists(atPath: encryptedURL.path)
                {
                    skipped += 1
                    entries.append(previous)
                    continue
                }

                try FileManager.default.createDirectory(
                    at: encryptedURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let cipherFile = try encrypt(originalData, key: key)
                try cipherFile.write(to: encryptedURL, options: [.atomic])
                let dimensions = imageDimensions(for: file)
                entries.append(
                    ManifestEntry(
                        sourceKind: "bkThemes",
                        logicalName: logicalName,
                        originalAssetName: nil,
                        originalPath: relative,
                        encryptedPath: encryptedRelative,
                        originalExtension: file.pathExtension.lowercased(),
                        appearance: "universal",
                        scale: "universal",
                        sha256Plaintext: plaintextHash,
                        sha256CipherFile: sha256Hex(cipherFile),
                        width: dimensions.0,
                        height: dimensions.1,
                        generatedAt: generatedAt,
                        formatVersion: Int(formatVersion)
                    )
                )
                encrypted += 1
            } catch {
                failed += 1
                fputs("error: \(file.path): \(error)\n", stderr)
            }
        }
    }

    let xcassetRoots = (allowlist?.xcassetsSourceRoots ?? [])
        .map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL }
        + [args.xcassets].compactMap { $0?.standardizedFileURL }

    for requested in allowlist?.xcassets ?? [] {
        do {
            guard let imageset = xcassetDirectory(named: requested.name, roots: xcassetRoots) else {
                throw ToolError.missingXCAsset(requested.name)
            }
            let contentsURL = imageset.appendingPathComponent("Contents.json")
            let contents = try JSONDecoder().decode(
                XCAssetContents.self,
                from: Data(contentsOf: contentsURL)
            )
            let images = contents.images.filter { image in
                guard let filename = image.filename else { return false }
                return supportedImageExtensions.contains((filename as NSString).pathExtension.lowercased())
            }
            guard !images.isEmpty else {
                throw ToolError.unsupportedXCAsset(requested.name)
            }

            for image in images {
                guard let filename = image.filename else { continue }
                let file = imageset.appendingPathComponent(filename)
                let originalData = try Data(contentsOf: file)
                let plaintextHash = sha256Hex(originalData)
                let appearance = appearanceName(for: image)
                let scale = image.scale ?? "universal"
                let stem = variantStem(
                    assetName: requested.name,
                    appearance: appearance,
                    scale: scale,
                    multipleImages: images.count > 1
                )
                let logicalName = "XCAssets/\(stem)"
                let encryptedRelative = "XCAssets/\(stem).kmgasset"
                let encryptedURL = output.appendingPathComponent(encryptedRelative)
                let previous = existing[logicalName]

                if !args.force,
                   let previous,
                   previous.sha256Plaintext == plaintextHash,
                   FileManager.default.fileExists(atPath: encryptedURL.path) {
                    skipped += 1
                    entries.append(previous)
                    continue
                }

                try FileManager.default.createDirectory(
                    at: encryptedURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let cipherFile = try encrypt(originalData, key: key)
                try cipherFile.write(to: encryptedURL, options: [.atomic])
                let dimensions = imageDimensions(for: file)
                entries.append(
                    ManifestEntry(
                        sourceKind: "xcassets",
                        logicalName: logicalName,
                        originalAssetName: requested.name,
                        originalPath: "\(imageset.lastPathComponent)/\(filename)",
                        encryptedPath: encryptedRelative,
                        originalExtension: file.pathExtension.lowercased(),
                        appearance: appearance,
                        scale: scale,
                        sha256Plaintext: plaintextHash,
                        sha256CipherFile: sha256Hex(cipherFile),
                        width: dimensions.0,
                        height: dimensions.1,
                        generatedAt: generatedAt,
                        formatVersion: Int(formatVersion)
                    )
                )
                encrypted += 1
            }
        } catch {
            failed += 1
            fputs("error: XCAssets/\(requested.name): \(error)\n", stderr)
        }
    }

    let manifest = Manifest(
        generatedAt: generatedAt,
        formatVersion: Int(formatVersion),
        algorithm: "AES.GCM.256",
        entries: entries.sorted { $0.logicalName < $1.logicalName }
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])

    print("Encrypted: \(encrypted)")
    print("Skipped: \(skipped)")
    print("Failed: \(failed)")
    print("Output: \(output.path)")

    if failed > 0 {
        exit(1)
    }
}

do {
    try run()
} catch {
    fputs("error: \(error)\n", stderr)
    exit(2)
}
