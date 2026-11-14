import SwiftUI

/// A Cloud runtime's status: a filled 8-point dot, green when it answers and
/// red when it does not.
///
/// The offline state also carries one diagonal slash, cut in the row's own
/// background colour, so the two states stay distinguishable without colour.
/// A disabled runtime uses the same offline dot, with its "Disabled" text.
struct RuntimeStatusDot: View {
    let online: Bool
    /// The row background the dot sits on; the slash is drawn in it so it
    /// reads as a cut through the dot rather than a second colour.
    var cutout: Color = Theme.surface

    private var state: RuntimeDotState { RuntimeDotState(online: online) }

    var body: some View {
        ZStack {
            Circle().fill(online ? Theme.dotOnline : Theme.dotOffline)
            if state.drawsSlash {
                // A horizontal capsule turned 45°: its ends fall outside the
                // circle, so it reads as one clean cut across the dot.
                Capsule()
                    .fill(cutout)
                    .frame(width: state.diameter * 2, height: state.slashWidth)
                    .rotationEffect(.degrees(state.slashAngleDegrees))
            }
        }
        .frame(width: state.diameter, height: state.diameter)
        .clipShape(Circle())
    }
}
