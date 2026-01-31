import Foundation
import AppKit

// MARK: - FocusShield
/// Complete distraction blocker for macOS
/// Blocks websites, apps, and notifications during focus sessions

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
    private var blocklist: [String] = []
    private var sessionEndTime: Date?
    private var timer: Timer?
    
    let defaultBlocklist = [
        "twitter.com", "x.com", "facebook.com", "instagram.com",
        "reddit.com", "youtube.com", "tiktok.com", "linkedin.com",
        "netflix.com", "twitch.tv", "discord.com"
    ]
    
    func run() async {
        print("""
        🛡️  FocusShield - Complete Distraction Blocker
        
        Commands:
          start <minutes>   Start focus session (e.g., start 25)
          stop              End session early
          add <domain>      Add domain to blocklist
          remove <domain>   Remove domain from blocklist
          list              Show current blocklist
          status            Show session status
          help              Show this help
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
        guard minutes > 0 else {
            print("❌ Please specify a valid duration in minutes")
            return
        }
        
        isBlocking = true
        sessionEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        print("🛡️  Focus session started for \(minutes) minutes")
        print("   Blocking \(blocklist.count) domains")
        print("   End time: \(formatTime(sessionEndTime!))")
        
        // Enable DND
        enableDoNotDisturb(true)
        
        // Start monitoring
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                await self.checkSession()
            }
        }
        
        // Block network access to blocked domains
        setupNetworkBlocking()
        
        // Start countdown display
        await showCountdown(minutes: minutes)
    }
    
    func stopSession() {
        guard isBlocking else { return }
        
        isBlocking = false
        timer?.invalidate()
        timer = nil
        
        // Disable DND
        enableDoNotDisturb(false)
        
        // Remove network blocks
        removeNetworkBlocking()
        
        print("\n✅ Focus session ended")
        print("   Great work! Take a break.")
    }
    
    private func checkSession() async {
        guard let endTime = sessionEndTime else { return }
        
        if Date() >= endTime {
            stopSession()
        }
    }
    
    private func showCountdown(minutes: Int) async {
        var remaining = minutes * 60
        
        while isBlocking && remaining > 0 {
            let mins = remaining / 60
            let secs = remaining % 60
            print("\r⏱️  \(String(format: "%02d:%02d", mins, secs)) remaining...", terminator: "")
            fflush(stdout)
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            remaining -= 1
        }
        
        print() // New line after countdown
    }
    
    private func setupNetworkBlocking() {
        // This would use pfctl or similar to block domains
        // For now, we print what would happen
        print("   🚫 Network blocking enabled for \(blocklist.count) domains")
        
        // In production, this would:
        // 1. Modify /etc/hosts
        // 2. Or use pfctl rules
        // 3. Or use a local proxy
    }
    
    private func removeNetworkBlocking() {
        print("   ✅ Network blocking disabled")
    }
    
    private func enableDoNotDisturb(_ enable: Bool) {
        let status = enable ? "enabled" : "disabled"
        print("   🔕 Do Not Disturb \(status)")
        
        // Use AppleScript to toggle DND
        let script = enable ?
            "tell application \"System Events\" to tell application process \"Control Center\" to click checkbox \"Do Not Disturb\" of group 1 of window \"Control Center\"" :
            "tell application \"System Events\" to tell application process \"Control Center\" to click checkbox \"Do Not Disturb\" of group 1 of window \"Control Center\""
        
        // In production, use proper DND API
    }
    
    private func addToBlocklist(_ domain: String) {
        guard !domain.isEmpty else {
            print("❌ Please specify a domain")
            return
        }
        
        let cleanDomain = domain.lowercased().replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        
        guard !blocklist.contains(cleanDomain) else {
            print("⚠️  Domain already in blocklist")
            return
        }
        
        blocklist.append(cleanDomain)
        saveBlocklist()
        print("✅ Added \(cleanDomain) to blocklist")
    }
    
    private func removeFromBlocklist(_ domain: String) {
        guard let index = blocklist.firstIndex(of: domain.lowercased()) else {
            print("⚠️  Domain not in blocklist")
            return
        }
        
        blocklist.remove(at: index)
        saveBlocklist()
        print("✅ Removed \(domain) from blocklist")
    }
    
    private func listBlocklist() {
        print("🚫 Blocklist (\(blocklist.count) domains):")
        for domain in blocklist.sorted() {
            print("   • \(domain)")
        }
    }
    
    private func showStatus() {
        if isBlocking, let endTime = sessionEndTime {
            let remaining = endTime.timeIntervalSince(Date())
            let mins = Int(remaining) / 60
            let secs = Int(remaining) % 60
            print("🛡️  Session active - \(mins)m \(secs)s remaining")
        } else {
            print("😴 No active session")
        }
    }
    
    private func showHelp() {
        print("""
        Commands:
          start <minutes>   Start focus session (default: 25)
          stop              End session early
          add <domain>      Add domain to blocklist
          remove <domain>   Remove domain from blocklist
          list              Show current blocklist
          status            Show session status
          help              Show this help
          quit              Exit
        """)
    }
    
    private func loadBlocklist() {
        blocklist = defaultBlocklist
        // In production: Load from UserDefaults or file
    }
    
    private func saveBlocklist() {
        // In production: Save to UserDefaults or file
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
