//
//  DataProtection.swift
//  FloraFang
//
//  Applies stronger-than-default file protection and backup exclusion to
//  the app's on-disk storage.
//
//  WHY THIS EXISTS: FloraFang's privacy pitch is "100% on-device, nothing
//  leaves your phone," but the OS default for a file an app doesn't set
//  protection on is .completeUntilFirstUserAuthentication (decrypted after
//  first unlock post reboot, then readable even while the device is locked
//  again), and files are included in iCloud/iTunes backups unless
//  explicitly excluded. That is a real gap between the privacy copy and
//  what actually happens to exposure incident photos and field log entries
//  sitting in Application Support. Same lesson already learned building
//  Cairn Skin, applied here too.
//
//  This sweeps the whole Application Support directory rather than a single
//  hardcoded SwiftData store filename, because that avoids depending on
//  SwiftData's internal default naming, and it is safe today because
//  Application Support is used ONLY by the SwiftData store, nothing else
//  writes there. If that ever changes, revisit this.
//
//  Nothing here needs a background task exemption: FloraFang has none, and
//  .complete protection (inaccessible whenever the device is locked) is the
//  strongest class, matching the "your phone only" pitch.
//

import Foundation

enum DataProtection {

    /// Call once at launch. Cheap and idempotent, safe to call every time.
    /// Also retroactively protects anything created in a previous session,
    /// which matters the first time this ships to an existing install.
    static func secureApplicationSupport() {
        guard let dir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        // Application Support isn't guaranteed to exist yet on a fresh
        // install; SwiftData creates it on first write if we don't. Create
        // it ourselves first so protection is already in place before
        // SwiftData ever writes its first file into it.
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        secure(directoryAndContents: dir)
    }

    private static func secure(directoryAndContents url: URL) {
        let fm = FileManager.default

        // Setting protection on the directory makes it the default for any
        // file created inside it afterward (documented Data Protection
        // inheritance behavior), which covers new field log photos and
        // exposure incident records as they are saved, not just what
        // already exists.
        apply(to: url)

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let itemURL as URL in enumerator {
            apply(to: itemURL)
        }
    }

    private static func apply(to url: URL) {
        let fm = FileManager.default

        // Complete: inaccessible whenever the device is locked. Best match
        // for an app with no background task that needs this data while
        // locked, and the strongest claim consistent with "your phone only."
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)

        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
    }
}
