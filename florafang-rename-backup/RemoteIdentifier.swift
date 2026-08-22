//
//  RemoteIdentifier.swift
//  Quadrat
//
//  Tier 3. Off by default and safe to ship that way.
//
//  This exists so the cascade has a real seam to plug a network model into
//  later. It never fires unless you explicitly enable it, and it never fires
//  when Tier 2 was already confident — so a shipped v1 with this disabled
//  makes zero network calls, which is a real selling point against the
//  competition.
//

import Foundation
import UIKit

protocol RemoteIdentifying: Sendable {
    var isEnabled: Bool { get }
    func identify(_ image: UIImage) async throws -> Assessment?
}

/// Default implementation: does nothing. Replace or subclass when you have
/// an endpoint. Keeping the disabled version as the default means forgetting
/// to configure it fails closed, not open.
///
/// nonisolated because the cascade uses `DisabledRemoteIdentifier()` as a
/// default parameter value, and default parameters are evaluated in a
/// nonisolated context.
nonisolated struct DisabledRemoteIdentifier: RemoteIdentifying {
    var isEnabled: Bool { false }
    func identify(_ image: UIImage) async throws -> Assessment? { nil }
}

/// Sketch of a real one. Left unwired on purpose — fill in when you pick a
/// backend, and read the warning below before you do.
///
/// WARNING: if you point this at a general-purpose vision LLM, understand that
/// it will produce a confident, fluent, plausible answer whether or not it
/// knows. For a hazard feature that's worse than no answer. If you use one,
/// constrain it to the same SpiderClass label set, require it to return an
/// explicit "uncertain" option, and treat anything below your gate as a
/// refusal rather than a result.
nonisolated struct HTTPRemoteIdentifier: RemoteIdentifying {
    let endpoint: URL
    let enabled: Bool

    var isEnabled: Bool { enabled }

    func identify(_ image: UIImage) async throws -> Assessment? {
        guard enabled else { return nil }
        // TODO: multipart upload, decode response into SpiderClass + confidence,
        // then run it through the same ConfidenceGate as Tier 2. Do not let a
        // remote answer bypass the gate just because it came from a bigger model.
        return nil
    }
}
