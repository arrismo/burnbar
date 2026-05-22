#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

extension CodexBarCLI {
    static func writeStderr(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }

    static func printVersion() -> Never {
        if let version = currentVersion() {
            print("CodexBar \(version)")
        } else {
            print("CodexBar")
        }
        Self.platformExit(0)
    }

    static func printHelp(for command: String?) -> Never {
        let version = self.currentVersion() ?? "unknown"
        switch command {
        case "usage":
            print(Self.usageHelp(version: version))
        case "cost":
            print(Self.costHelp(version: version))
        case "serve":
            print(Self.serveHelp(version: version))
        case "burnbadge", "create", "sync", "markdown", "status":
            print(Self.burnbadgeHelp(version: version))
        case "config", "validate", "dump":
            print(Self.configHelp(version: version))
        case "cache", "clear":
            print(Self.cacheHelp(version: version))
        default:
            print(Self.rootHelp(version: version))
        }
        Self.platformExit(0)
    }

    static func currentVersion(
        bundle: Bundle = .main,
        executablePath: String? = CommandLine.arguments.first) -> String?
    {
        if let version = self.currentVersion(bundleVersion: nil, executablePath: executablePath) {
            return version
        }
        return self.currentVersion(
            bundleVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
            executablePath: nil)
    }

    static func currentVersion(bundleVersion: String?, executablePath: String?) -> String? {
        if let executablePath, !executablePath.isEmpty {
            let executableURL = URL(fileURLWithPath: executablePath).absoluteURL
            if let version = Self.adjacentVersionFileVersion(for: executableURL) {
                return version
            }
            let resolvedURL = executableURL.resolvingSymlinksInPath()
            if resolvedURL != executableURL,
               let version = Self.containingAppVersion(for: resolvedURL)
            {
                return version
            }
        }
        return Self.normalizedBundleVersion(bundleVersion)
    }

    static func containingAppVersion(for executableURL: URL) -> String? {
        var path = (executableURL.path as NSString).deletingLastPathComponent
        let fileManager = FileManager.default

        while !path.isEmpty, path != "/" {
            if (path as NSString).pathExtension == "app" {
                let infoPath = ((path as NSString)
                    .appendingPathComponent("Contents") as NSString)
                    .appendingPathComponent("Info.plist")
                guard let data = fileManager.contents(atPath: infoPath),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { return nil }
                return plist["CFBundleShortVersionString"] as? String
            }

            let parent = (path as NSString).deletingLastPathComponent
            if parent == path { break }
            path = parent
        }

        return nil
    }

    static func adjacentVersionFileVersion(for executableURL: URL) -> String? {
        let versionURL = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("VERSION")
        guard let raw = try? String(contentsOf: versionURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("v"), trimmed.dropFirst().first?.isNumber == true {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    static func normalizedBundleVersion(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed != "CodexBar"
        else { return nil }
        return trimmed
    }

    static func platformExit(_ code: Int32) -> Never {
        #if canImport(Darwin)
        Darwin.exit(code)
        #else
        Glibc.exit(code)
        #endif
    }
}
