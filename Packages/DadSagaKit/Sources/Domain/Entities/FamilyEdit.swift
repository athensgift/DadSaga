import Foundation

/// A child's field a family edit can change (ADR-0065 §4). Not `order`: "My family" never reorders.
public enum ChildField: Hashable, Sendable, CaseIterable {
    case name, birthDay, gender, skinTone
}

/// A child the edit changes: `child` carries the id and the new values, and only `fields` are applied, so a field the
/// dad didn't touch keeps what is stored (a partner's change, or a value this version can't name, ADR-0065 §1).
public struct ChildEdit: Hashable, Sendable {
    public var child: Child
    public var fields: Set<ChildField>

    public init(child: Child, fields: Set<ChildField>) {
        self.child = child
        self.fields = fields
    }

    /// `stored` with this edit's fields set on it.
    public func applied(to stored: Child) -> Child {
        var result = stored
        if fields.contains(.name) { result.name = child.name }
        if fields.contains(.birthDay) { result.birthDay = child.birthDay }
        if fields.contains(.gender) { result.gender = child.gender }
        if fields.contains(.skinTone) { result.skinTone = child.skinTone }
        return result
    }
}

/// What "My family" changed since it opened, not the family as it stands (ADR-0065 §4).
public struct FamilyEdit: Hashable, Sendable {
    /// The children added, in the order added.
    public var added: [Child]
    public var removedIDs: Set<UUID>
    /// The children changed, in the editor's order.
    public var changed: [ChildEdit]
    /// The partner answer; `nil` when unchanged.
    public var hasPartner: Bool?

    public init(added: [Child] = [], removedIDs: Set<UUID> = [], changed: [ChildEdit] = [], hasPartner: Bool? = nil) {
        self.added = added
        self.removedIDs = removedIDs
        self.changed = changed
        self.hasPartner = hasPartner
    }

    /// The difference between what the editor showed and what it saves.
    public init(shown: [Child], hasPartner shownHasPartner: Bool, edited: [Child], hasPartner editedHasPartner: Bool) {
        let shownByID = Dictionary(shown.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let editedIDs = Set(edited.map(\.id))
        added = edited.filter { shownByID[$0.id] == nil }
        removedIDs = Set(shown.map(\.id)).subtracting(editedIDs)
        changed = edited.compactMap { child in
            guard let before = shownByID[child.id] else { return nil }
            var fields: Set<ChildField> = []
            if child.name != before.name { fields.insert(.name) }
            if child.birthDay != before.birthDay { fields.insert(.birthDay) }
            if child.gender != before.gender { fields.insert(.gender) }
            if child.skinTone != before.skinTone { fields.insert(.skinTone) }
            return fields.isEmpty ? nil : ChildEdit(child: child, fields: fields)
        }
        hasPartner = editedHasPartner == shownHasPartner ? nil : editedHasPartner
    }

    public var isEmpty: Bool {
        added.isEmpty && removedIDs.isEmpty && changed.isEmpty && hasPartner == nil
    }

    /// `family` with this edit on it: removed ids gone, each change's fields set on a child still there (a change to a
    /// child no longer there is ignored), added children not already there appended. A child the edit doesn't name
    /// stays as it is.
    public func applied(to family: [Child]) -> [Child] {
        let changes = Dictionary(changed.map { ($0.child.id, $0) }, uniquingKeysWith: { _, last in last })
        var result = family
            .filter { !removedIDs.contains($0.id) }
            .map { child in changes[child.id].map { $0.applied(to: child) } ?? child }
        for child in added where !result.contains(where: { $0.id == child.id }) && !removedIDs.contains(child.id) {
            result.append(child)
        }
        return result
    }
}
