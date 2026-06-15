import Foundation
import UIKit
import Network
import Contacts
import EventKit
import SaltareAgent

/// The on-device tool catalog. Order is DELIBERATE — it's the prompt-cache
/// prefix (`ToolRegistry` never reorders; MCP appends after). Ported from the
/// Android `:agent` tools, minus the ones with no iOS API (alarm/timer/system
/// share-sheet) and with calendar-create moved to EventKit write.
enum AgentTools {

    static func local(capabilities: LauncherCapabilities) -> [ToolSpec] {
        [
            openApp(capabilities),
            phoneCall, sendSMS, sendEmail, openURL, showMap, // visible-intent tools
            deviceStatus,
            contactsSearch, calendarUpcoming, createCalendarEvent, // GRANT-gated
        ]
    }

    // MARK: - open_app

    private static func openApp(_ capabilities: LauncherCapabilities) -> ToolSpec {
        ToolSpec(
            name: "open_app",
            description: "Launch an installed app by name. Call this when the user names an app or asks for something that lives inside one (e.g. 'open maps', 'spotify').",
            properties: ["name": .schema(type: "string", description: "App name as the user said it")],
            required: ["name"],
            execute: { input in
                switch await capabilities.openApp(input.str("name")) {
                case let .launched(label): return .success("Launched \(label).")
                case let .notFound(query): return .error("No installed app matches '\(query)'.")
                case let .ambiguous(candidates): return .error("Multiple matches: \(candidates.joined(separator: ", ")). Ask the user which one.")
                }
            }
        )
    }

    // MARK: - visible-intent tools (every one opens a screen the user confirms)

    private static let phoneCall = ToolSpec(
        name: "phone_call",
        description: "Open the phone dialer pre-filled with a number. Call this when the user asks to call someone (resolve names to numbers with contacts_search first).",
        properties: ["number": .schema(type: "string", description: "Phone number to dial")],
        required: ["number"],
        execute: { input in
            let digits = input.str("number").filter { !$0.isWhitespace }
            return await open("tel:\(digits)", success: "Opened the dialer with \(input.str("number")) — the user taps call to connect.")
        }
    )

    private static let sendSMS = ToolSpec(
        name: "send_sms",
        description: "Open Messages with recipient and body pre-filled. Call this when the user asks to text or message someone.",
        properties: ["number": .schema(type: "string", description: "Phone number"), "body": .schema(type: "string", description: "Message body")],
        required: ["number"],
        execute: { input in
            let digits = input.str("number").filter { !$0.isWhitespace }
            let body = encode(input.str("body"))
            return await open("sms:\(digits)&body=\(body)", success: "Opened Messages to \(input.str("number")) — the user reviews and sends.")
        }
    )

    private static let sendEmail = ToolSpec(
        name: "send_email",
        description: "Open the mail composer pre-filled. Call this when the user asks to email someone.",
        properties: [
            "to": .schema(type: "string", description: "Recipient email address"),
            "subject": .schema(type: "string", description: "Email subject"),
            "body": .schema(type: "string", description: "Email body"),
        ],
        required: ["to"],
        execute: { input in
            let url = "mailto:\(input.str("to"))?subject=\(encode(input.str("subject")))&body=\(encode(input.str("body")))"
            return await open(url, success: "Opened the mail composer to \(input.str("to")).")
        }
    )

    private static let openURL = ToolSpec(
        name: "open_url",
        description: "Open a URL in the browser. Call this for websites, searches, or links the user asks for.",
        properties: ["url": .schema(type: "string", description: "Full http(s) URL")],
        required: ["url"],
        execute: { input in
            await open(input.str("url"), success: "Opened \(input.str("url")) in the browser.")
        }
    )

    private static let showMap = ToolSpec(
        name: "show_map",
        description: "Open Maps at a place or address. Call this for directions, navigation, or 'where is' questions.",
        properties: ["query": .schema(type: "string", description: "Place name or address")],
        required: ["query"],
        execute: { input in
            await open("maps://?q=\(encode(input.str("query")))", success: "Opened Maps at '\(input.str("query"))'.")
        }
    )

    // MARK: - device_status (no DND/volume read on iOS — battery + network only)

    private static let deviceStatus = ToolSpec(
        name: "device_status",
        description: "Read current device state: battery, charging, network. Call this before answering any question about the phone itself.",
        execute: { _ in
            let battery = await MainActor.run { () -> String in
                UIDevice.current.isBatteryMonitoringEnabled = true
                let level = UIDevice.current.batteryLevel
                let percent = level < 0 ? "unknown" : "\(Int(level * 100))%"
                let state = UIDevice.current.batteryState
                let charging = state == .charging || state == .full
                return "Battery \(percent)\(charging ? " (charging)" : "")"
            }
            return .success("\(battery). Network: \(await NetworkSnapshot.current()).")
        }
    )

    // MARK: - GRANT-gated read/write tools

    private static let contactsSearch = ToolSpec(
        name: "contacts_search",
        description: "Search the user's contacts by name and return matching names with phone numbers. Call this to resolve a person's name to a number before phone_call or send_sms.",
        properties: ["name": .schema(type: "string", description: "Full or partial contact name")],
        required: ["name"],
        requiredPermission: AgentPermission.contacts.rawValue,
        execute: { input in
            let query = input.str("name")
            let store = CNContactStore()
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            guard let found = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: query), keysToFetch: keys) else {
                return .error("Couldn't read contacts.")
            }
            let rows = found.prefix(8).compactMap { contact -> String? in
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                guard let phone = contact.phoneNumbers.first?.value.stringValue, !name.isEmpty else { return nil }
                return "\(name): \(phone)"
            }
            return .success(rows.isEmpty ? "No contacts match '\(query)'." : rows.joined(separator: "\n"))
        }
    )

    private static let calendarUpcoming = ToolSpec(
        name: "calendar_upcoming",
        description: "List the user's calendar events for the next N days (default 3). Call this for 'what's on my calendar' or scheduling questions.",
        properties: ["days": .schema(type: "integer", description: "How many days ahead, 1-14")],
        requiredPermission: AgentPermission.calendar.rawValue,
        execute: { input in
            let days = min(14, max(1, input.int("days") ?? 3))
            let store = EKEventStore()
            let start = Date()
            let end = start.addingTimeInterval(Double(days) * 86_400)
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE dd MMM HH:mm"
            let rows = store.events(matching: predicate).prefix(15).map { event in
                "\(formatter.string(from: event.startDate)) — \(event.title ?? "(untitled)")"
            }
            return .success(rows.isEmpty ? "No events in the next \(days) day(s)." : rows.joined(separator: "\n"))
        }
    )

    private static let createCalendarEvent = ToolSpec(
        name: "create_calendar_event",
        description: "Add an event to the user's calendar. Call this when the user asks to schedule something. Times are epoch milliseconds.",
        properties: [
            "title": .schema(type: "string", description: "Event title"),
            "start_epoch_millis": .schema(type: "integer", description: "Start time, epoch milliseconds"),
            "end_epoch_millis": .schema(type: "integer", description: "End time, epoch milliseconds"),
            "location": .schema(type: "string", description: "Optional location"),
        ],
        required: ["title"],
        requiredPermission: AgentPermission.calendar.rawValue,
        execute: { input in
            let store = EKEventStore()
            let event = EKEvent(eventStore: store)
            event.title = input.str("title").isEmpty ? "New event" : input.str("title")
            event.calendar = store.defaultCalendarForNewEvents
            let start = input.double("start_epoch_millis").map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date().addingTimeInterval(3600)
            event.startDate = start
            event.endDate = input.double("end_epoch_millis").map { Date(timeIntervalSince1970: $0 / 1000) } ?? start.addingTimeInterval(3600)
            let location = input.str("location")
            if !location.isEmpty { event.location = location }
            do {
                try store.save(event, span: .thisEvent)
                return .success("Added '\(event.title ?? "event")' to your calendar.")
            } catch {
                return .error("Couldn't create the event: \(error.localizedDescription)")
            }
        }
    )

    // MARK: - helpers

    private static func open(_ urlString: String, success: String) async -> ToolOutcome {
        let ok = await MainActor.run { () -> Bool in
            guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else { return false }
            UIApplication.shared.open(url)
            return true
        }
        return ok ? .success(success) : .error("No installed app can handle this action.")
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}

/// One-shot network reachability snapshot for `device_status`.
private enum NetworkSnapshot {
    static func current() async -> String {
        let monitor = NWPathMonitor()
        let once = Once()
        let status: String = await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                once.run {
                    monitor.cancel()
                    let value: String
                    switch path.status {
                    case .satisfied where path.usesInterfaceType(.wifi): value = "wifi"
                    case .satisfied where path.usesInterfaceType(.cellular): value = "cellular"
                    case .satisfied: value = "online"
                    default: value = "offline"
                    }
                    continuation.resume(returning: value)
                }
            }
            monitor.start(queue: DispatchQueue(label: "ai.saltare.netcheck"))
        }
        return status
    }
}

/// Resume-once guard so the path handler can't double-resume the continuation.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func run(_ body: () -> Void) {
        lock.lock()
        let go = !fired
        fired = true
        lock.unlock()
        if go { body() }
    }
}
