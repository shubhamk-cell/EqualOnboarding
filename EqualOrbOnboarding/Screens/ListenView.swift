import SwiftUI

// MARK: - V3, V5, V6 · Just listen

/// Sample calls in the call player (`CallDeck`), no choices: V3 the kinds of call Equal handles
/// most, V5 and V6 four everyday calls. The orb sits small beside its bubble (as on the setup
/// screens) so the player is the focus. Continue is ready from the start (no Skip). The calls are
/// heard in the voice chosen in V5 (Aanya otherwise).
struct ListenView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @State private var showContent = false
    @State private var revealed = false
    @State private var heardOne = false

    // The orb speaks in its own language (nudge it to switch).
    private var common: Bool { model.variant == .v3 }
    private let title = Catalog.listenTitle
    private let after = Catalog.listenAfter
    private var calls: [UseCase] { common ? Catalog.commonCalls.compactMap(Catalog.useCase) : Catalog.everyday }

    var body: some View {
        VStack(spacing: 0) {
            if !showContent { Spacer(minLength: 0) }
            // Room for the longer of its two lines, so the follow-up never overlaps the cards.
            OrbBesideBubble(talk: talk, reserve: after.count > title.count ? after : title)
                .padding(.top, 14)
                .padding(.horizontal, 24)
            if showContent {
                // Fills the space between the orb and Continue: no scrolling, on any phone.
                CallDeck(calls: calls, everyday: !common, revealed: revealed) { _ in
                    // After the first call, the orb sums it up.
                    guard !heardOne else { return }
                    heardOne = true
                    Task { await talk.replace(with: after) }
                }
                .padding(.top, 20)
                .frame(maxHeight: .infinity)
                .transition(.opacity.combined(with: .offset(y: 40)))
            } else {
                Spacer(minLength: 0)
            }
            Button("Continue") { model.next() }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(revealed ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: revealed)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
        }
        .onAppear { talk.intro(title) }
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !showContent else { return }
            Task {
                guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
                withAnimation(OrbFlight.glide) { showContent = true }
                guard (try? await Task.sleep(for: .seconds(0.12))) != nil else { return }
                revealed = true
            }
        }
    }
}
