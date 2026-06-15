import SwiftUI

/// The four status accents shared across panels, badges, and bars.
public enum HudAccent: Sendable {
    case arc
    case materia
    case limit
    case phoenix

    public func base(_ c: SaltareColors) -> Color {
        switch self {
        case .arc: c.arc
        case .materia: c.materia
        case .limit: c.limit
        case .phoenix: c.phoenix
        }
    }

    public func dim(_ c: SaltareColors) -> Color {
        switch self {
        case .arc: c.arcDim
        case .materia: c.materiaDim
        case .limit: c.limitDim
        case .phoenix: c.phoenixDim
        }
    }

    public func glow(_ c: SaltareColors) -> Color {
        switch self {
        case .arc: c.arcGlow
        case .materia: c.materiaGlow
        case .limit: c.limitGlow
        case .phoenix: c.phoenixGlow
        }
    }

    public func subtle(_ c: SaltareColors) -> Color {
        switch self {
        case .arc: c.arcSubtle
        case .materia: c.materiaSubtle
        case .limit: c.limitSubtle
        case .phoenix: c.phoenixSubtle
        }
    }
}
