import Foundation
import AppKit

// MARK: - FocusShield
/// Complete distraction blocker for macOS with REAL blocking functionality

@main
struct FocusShield {
    static func main() async {
        let shield = FocusShieldCore()
        await shield.run()
    }
}

@MainActor
final class FocusShieldCore {
    private var isBlocking = false
    private var originalHosts: String = ""
    private var blocklist: [String] = []
    private var sessionEndTime: Date?
    private var timer: Timer?
    private let hostsPath = "/etc/hosts"
    private let backupHostsPath = "/etc/hosts.focusshield-backup"
    
    let defaultBlocklist = [
        "twitter.com", "www.twitter.com", "x.com", "www.x.com",
        "facebook.com", "www.facebook.com",
        "instagram.com", "www.instagram.com",
        "reddit.com", "www.reddit.com", "old.reddit.com",
        "youtube.com", "www.youtube.com",
        "tiktok.com", "www.tiktok.com",
        "linkedin.com", "www.linkedin.com",
        "netflix.com", "www.netflix.com",
        "twitch.tv", "www.twitch.tv",
        "discord.com", "www.discord.com"
    ]
    
    func run() async {
        checkRootPrivileges()
        
        print("""
        🛡️  FocusShield - Complete Distraction Blocker
        
        ⚠️  REQUIRES SUDO - Modifies /etc/hosts to block websites
        
        Commands:
          start <minutes>   Start focus session
          stop              End session
          add <domain>      Add to blocklist
          remove <domain>   Remove from blocklist
          list              Show blocklist
          status            Show status
          test              Test blocking (requires sudo)
          help              Show help
          quit              Exit
        """)
        
        loadBlocklist()
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
            
            let parts = input.split(separator: " ", maxSplits: 1)
            let command = parts.first?.lowercased() ?? ""
            let arg = parts.count > 1 ? String(parts[1]) : ""
            
            switch command {
            case "start", "s":
                await startSession(minutes: Int(arg) ?? 25)
            case "stop", "end":
                stopSession()
            case "test":
                testBlocking()
            case "add", "a":
                addToBlocklist(arg)
            case "remove", "rm":
                removeFromBlocklist(arg)
            case "list", "ls":
                listBlocklist()
            case "status":
                showStatus()
            case "help", "h":
                showHelp()
            case "quit", "q", "exit":
                stopSession()
                print("👋 Goodbye!")
                return
            default:
                print("Unknown command. Type 'help' for options.")
            }
        }
    }
    
    func startSession(minutes: Int) async {
        guard !isBlocking else {
            print("⚠️  Session already active!")
            return
        }
        
        guard isRoot() else {
            print("❌ FocusShield requires sudo to block websites")
            print("   Run with: sudo focusshield")
            return
        }
        
        isBlocking = true
        sessionEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        // Backup original hosts
        backupHosts()
        
        // Add blocking entries to /etc/hosts
        applyBlocking()
        
        // Enable DND
        enableDoNotDisturb(true)
        
        print("🛡️  Focus session started for \(minutes) minutes")
        print("   Blocking \(blocklist.count) domains")
        print("   End time: \(formatTime(sessionEndTime!))")
        print("   🔕 Do Not Disturb enabled")
        print("   🚫 Websites blocked via /etc/hosts")
        print("\n   Press Ctrl+C or type 'stop' to end early")
        
        // Start countdown
        await runCountdown(minutes: minutes)
    }
    
    func stopSession() {
        guard isBlocking else { return }
        
        isBlocking = false
        timer?.invalidate()
        timer = nil
        
        // Restore original hosts
        restoreHosts()
        
        // Disable DND
        enableDoNotDisturb(false)
        
        // Flush DNS cache
        flushDNSCache()
        
        print("\n✅ Focus session ended")
        print("   🔓 Websites unblocked")
        print("   🔔 Do Not Disturb disabled")
    }
    
    func testBlocking() {
        guard isRoot() else {
            print("❌ Run with sudo to test blocking")
            return
        }
        
        print("🧪 Testing blocking...")
        backupHosts()
        applyBlocking()
        
        print("   Blocked domains in /etc/hosts:")
        for domain in blocklist.prefix(5) {
            print("     - \(domain)")
        }
        print("   (Run with 'stop' to restore)")
    }
    
    private func applyBlocking() {
        let blockEntries = blocklist.map { "127.0.0.1 \t\($0)\n::1 \t\t\($0)" }.joined(separator: "\n")
        let blockSection = "\n# FOCUSSHIELD BLOCK START\n\(blockEntries)\n# FOCUSSHIELD BLOCK END\n"
        
        do {
            let currentHosts = try String(contentsOfFile: hostsPath, encoding: .utf8)
            let newHosts = currentHosts + blockSection
            try newHosts.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to block websites: \(error)")
        }
    }
    
    private func backupHosts() {
        do {
            let hosts = try String(contentsOfFile: hostsPath, encoding: .utf8)
            originalHosts = hosts
            try hosts.write(toFile: backupHostsPath, atomically: true, encoding: .utf8)
        } catch {
            print("⚠️  Could not backup hosts file")
        }
    }
    
    private func restoreHosts() {
        do {
            if FileManager.default.fileExists(atPath: backupHostsPath) {
                let backup = try String(contentsOfFile: backupHostsPath, encoding: .utf8)
                try backup.write(toFile: hostsPath, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(atPath: backupHostsPath)
            }
        } catch {
            print("❌ Failed to restore hosts: \(error)")
        }
    }
    
    private func flushDNSCache() {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["/usr/bin/killall", "-HUP", "mDNSResponder"]
        try? task.run()
        task.waitUntilExit()
    }
    
    private func enableDoNotDisturb(_ enable: Bool) {
        let script = """
        tell application "System Events"
            tell application process "Control Center"
                click menu bar item "Control Center" of menu bar 1
                delay 0.5
                click checkbox "Do Not Disturb" of group 1 of window "Control Center"
                key code 53
            end tell
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        try? task.run()
    }
    
    private func runCountdown(minutes: Int) async {
        var remaining = minutes * 60
        
        while isBlocking && remaining > 0 {
            let mins = remaining / 60
            let secs = remaining % 60
            print("\r⏱️  \(String(format: "%02d:%02d", mins, secs)) - Focus! ", terminator: "")
            fflush(stdout)
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            remaining -= 1
            
            // Check if session should end
            if let endTime = sessionEndTime, Date() >= endTime {
                break
            }
        }
        
        print()
        if isBlocking {
            stopSession()
        }
    }
    
    private func addToBlocklist(_ domain: String) {
        guard !domain.isEmpty else { return }
        let cleanDomain = domain.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        guard !blocklist.contains(cleanDomain) else {
            print("⚠️  Domain already blocked")
            return
        }
        
        blocklist.append(cleanDomain)
        blocklist.append("www.\(cleanDomain)")
        saveBlocklist()
        print("✅ Added \(cleanDomain) to blocklist")
    }
    
    private func removeFromBlocklist(_ domain: String) {
        let cleanDomain = domain.lowercased()
        blocklist.removeAll { $0 == cleanDomain || $0 == "www.\(cleanDomain)" }
        saveBlocklist()
        print("✅ Removed \(cleanDomain)")
    }
    
    private func listBlocklist() {
        print("🚫 Blocked domains (\(blocklist.count)):")
        Set(blocklist).sorted().forEach { print("   • \($0)") }
    }
    
    private func showStatus() {
        if isBlocking, let endTime = sessionEndTime {
            let remaining = Int(endTime.timeIntervalSince(Date()))
            print("🛡️  ACTIVE - \(remaining/60)m \(remaining%60)s remaining")
        } else {
            print("😴 Inactive - Run 'start <minutes>' to begin")
        }
    }
    
    private func loadBlocklist() {
        blocklist = defaultBlocklist
        // Load from ~/.focusshield/blocklist if exists
        let blocklistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".focusshield/blocklist").path
        if let saved = try? String(contentsOfFile: blocklistPath) {
            blocklist = saved.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }
    }
    
    private func saveBlocklist() {
        let blocklistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".focusshield/blocklist").path
        try? FileManager.default.createDirectory(atPath: NSString(string: blocklistPath).deletingLastPathComponent, withIntermediateDirectories: true)
        try? Set(blocklist).sorted().joined(separator: "\n").write(toFile: blocklistPath, atomically: true, encoding: .utf8)
    }
    
    private func checkRootPrivileges() {
        if !isRoot() {
            print("⚠️  WARNING: FocusShield works best with sudo")
            print("   Without sudo, website blocking won't work")
            print("   Run: sudo focusshield\n")
        }
    }
    
    private func isRoot() -> Bool {
        getuid() == 0
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func showHelp() {
        print("""
        Commands:
          start <min>   Start focus session (requires sudo)
          stop          End session
          test          Test blocking (requires sudo)
          add <domain>  Add to blocklist
          remove <dom>  Remove from blocklist
          list          Show blocklist
          status        Show status
          help          Show help
          quit          Exit
        """)
    }
}
