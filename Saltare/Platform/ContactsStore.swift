import Contacts
import SaltareKit

/// The three states the universal input cares about (`.limited` counts as
/// authorized — iOS 18 limited access still resolves matches).
enum ContactsAuthorization {
    case notDetermined, authorized, denied
}

/// Contacts access for the universal input. `search` runs off the main actor
/// (a native name predicate); the GRANT row drives `requestAccess`.
protocol ContactsProviding: Sendable {
    var authorization: ContactsAuthorization { get }
    func requestAccess() async -> Bool
    func search(_ query: String) async -> [Contact]
}

struct SystemContactsStore: ContactsProviding {
    var authorization: ContactsAuthorization {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func search(_ query: String) async -> [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let predicate = CNContact.predicateForContacts(matchingName: trimmed)
        guard let found = try? store.unifiedContacts(matching: predicate, keysToFetch: keys) else { return [] }
        return found.prefix(8).compactMap { contact -> Contact? in
            guard let phone = contact.phoneNumbers.first?.value.stringValue else { return nil }
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            return name.isEmpty ? nil : Contact(name: name, number: phone)
        }.prefix(3).map { $0 }
    }
}
