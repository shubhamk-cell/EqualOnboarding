import SwiftUI
import AVFoundation

/// V8's picks: “Pick any 3”, with no Skip and no Continue. The third pick sets everything off on
/// the same page: the other options fade, the three gather at the top and shimmer while the orb
/// curates, then each turns into a voice note: its fill shrinks into the note's cover, its emoji
/// and name glide into place, and its player unrolls underneath. Continue arrives after.
struct PickThreeView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @StateObject private var player = CallPlayer()
    @State private var phase: Phase = .picking
    /// The picks have moved out of the grid to the top, in wrapping rows.
    @State private var rearranged = false
    /// The picks have grown into call cards; their insides fade in a beat later.
    @State private var expanded = false
    @State private var cardContent = false
    @State private var shimmer = false
    @State private var curating: Task<Void, Never>?
    /// Just before the picks turn into voice notes they let go of what doesn't carry over (outline,
    /// tick, glow, their own copy of the name), so only the fill, emoji and name are seen moving.
    @State private var handing = false
    /// Each pill's width in the grid, so the picks keep their size when they move.
    @State private var pillWidths: [String: CGFloat] = [:]
    @Namespace private var pills
    /// Each pick's call length, worked out once the picks are made, for the time beside its wave.
    @State private var lengths: [String: Double] = [:]
    @State private var showOptions = false
    @State private var revealed = false

    enum Phase { case picking, curating, ready }

    private static let needed = 3
    private let title = Catalog.pickThree

    private var rows: [[UseCase]] {
        stride(from: 0, to: Catalog.useCases.count, by: 2).map {
            Array(Catalog.useCases[$0..<min($0 + 2, Catalog.useCases.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !showOptions { Spacer(minLength: 0) }
            // The orb stays centred under its bubble throughout, picks to voice notes.
            OrbWithBubble(talk: talk, reserve: phase == .ready ? Catalog.curated(Self.needed) : title,
                          spinning: phase == .curating)
                .padding(.top, 10)
                .padding(.horizontal, 24)

            if showOptions {
                options
            } else {
                // The bubble's room above the orb is reserved while it types, so lift the pair
                // until the orb itself sits in the middle of the page.
                Spacer(minLength: 0)
                Color.clear.frame(height: 150)
            }

            if cardContent {
                Button(model.nextCTA) {
                    player.stop()
                    model.next()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .offset(y: 30)))
            }
        }
        .onAppear {
            // Back from a later step: start over with nothing picked.
            model.picks = []
            talk.intro(title)
            // Back on the sample calls (or while they're being made) returns to picking.
            model.localBack = (.cases, {
                guard phase != .picking else { return false }
                backToPicking()
                return true
            })
        }
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !showOptions else { return }
            Task { await revealOptions() }
        }
        .onChange(of: player.finished) { _, done in if done { Haptics.success() } }
        .onDisappear { player.stop() }
    }

    private func revealOptions() async {
        guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
        withAnimation(OrbFlight.glide) { showOptions = true }
        guard (try? await Task.sleep(for: .seconds(0.12))) != nil else { return }
        revealed = true
    }

    private var options: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Group {
                    // The notes don't fade in: they're built from the picks' own parts.
                    if expanded { cards.transition(.identity) } else { pillGrid }
                }
                .padding(.horizontal, 24)
                .padding(.top, expanded ? 8 : phase == .picking ? 40 : 44)
                .padding(.bottom, expanded ? 20 : 44)
                .id("top")
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: phase) { _, p in
                if p == .curating { withAnimation(EQ.push(0.6)) { proxy.scrollTo("top", anchor: .top) } }
            }
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 14)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: expanded ? 20 : 40)
            }
        }
        .transition(.opacity.combined(with: .offset(y: 40)))
    }

    // MARK: Picking

    private var pillGrid: some View {
        Group {
            if rearranged {
                WrapRows(spacing: 10, centered: true) {
                    ForEach(Array(model.picks.enumerated()), id: \.element) { i, id in
                        if let u = Catalog.useCase(id) {
                            pill(u, index: i)
                                .frame(width: pillWidths[id], height: 64)
                                .matchedGeometryEffect(id: id, in: pills)
                                // Hands over to its voice note: by then it has let go of what doesn't
                                // carry over, and its fill fades as it shrinks into the note's cover.
                                .transition(.asymmetric(insertion: .identity,
                                                        removal: .opacity.animation(.easeOut(duration: 0.35))))
                                .zIndex(1)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(rows.indices, id: \.self) { r in
                        BrickRow(weights: rows[r].map { CGFloat($0.label.count * $0.label.count) }) {
                            ForEach(rows[r]) { u in
                                pill(u, index: r * 2 + (rows[r].firstIndex(of: u) ?? 0))
                                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pillWidths[u.id] = $0 }
                                    .matchedGeometryEffect(id: u.id, in: pills)
                            }
                        }
                    }
                }
            }
        }
    }

    private func pill(_ u: UseCase, index: Int) -> some View {
        let on = model.picks.contains(u.id)
        let fading = phase != .picking && !on
        let letGo = handing && on
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button { toggle(u) } label: {
            HStack(spacing: 8) {
                // Who's on the call, as a small round photo; it grows into the voice note's cover.
                if let photo = Catalog.cover(u.id) {
                    Image(photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .matchedGeometryEffect(id: "\(u.id).cover", in: pills)
                } else {
                    Text(u.emoji)
                        .font(.system(size: 18))
                        .matchedGeometryEffect(id: "\(u.id).emoji", in: pills, properties: .position)
                        .opacity(letGo ? 0 : 1)
                }
                Text(u.label)
                    .font(.dm(14.5, .medium))
                    .tracking(-0.22)
                    .lineSpacing(0.6)
                    .foregroundStyle(on ? EQ.greenText : EQ.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .matchedGeometryEffect(id: "\(u.id).label", in: pills, properties: .position, anchor: .leading)
                    .opacity(letGo ? 0 : 1)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                shape.fill(on ? EQ.mintAlt : .white.opacity(0.7))
                    .opacity(letGo ? 0 : 1)
            }
            .background(shape.inset(by: -3).fill(EQ.green.opacity(on && !letGo ? 0.12 : 0)))
            // While curating, a sheen sweeps across the picks.
            .overlay {
                if on && phase == .curating {
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, .white.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.5)
                            .offset(x: shimmer ? g.size.width * 1.2 : -g.size.width * 0.7)
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
            }
            .overlay(shape.strokeBorder(on ? EQ.green : EQ.edge, lineWidth: on ? 1.5 : 1).opacity(letGo ? 0 : 1))
            .shadow(color: Color(hex: on ? 0x00782D : 0x003214).opacity(letGo ? 0 : on ? 0.12 : 0.06), radius: on ? 7 : 6, y: on ? 6 : 4)
            .overlay(alignment: .topTrailing) {
                // The pick's number (1, 2, 3) in the order it was picked, rather than a tick.
                Text("\((model.picks.firstIndex(of: u.id) ?? 0) + 1)")
                    .font(.dm(11.5, .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(EQ.green))
                    .overlay(Circle().stroke(EQ.page, lineWidth: 2))
                    .scaleEffect(on && !letGo ? 1 : 0.4)
                    .opacity(on && !letGo ? 1 : 0)
                    .offset(x: 4, y: -6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: on)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 18)
        .scaleEffect(revealed ? 1 : 0.94)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(min(index, 12)) * 0.1), value: revealed)
        .disabled(phase != .picking)
        .scaleEffect(on && phase != .picking ? 1.03 : fading ? 0.9 : 1)
        .opacity(fading ? 0 : 1)
        .blur(radius: fading ? 2 : 0)
        .animation(on ? .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.4)
                      : EQ.push(0.45).delay(Double(min(index, 12)) * 0.03), value: phase)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func toggle(_ u: UseCase) {
        guard phase == .picking else { return }
        // Never more than three, even with quick taps during the beat before curating (unticking
        // one still works then).
        let adding = !model.picks.contains(u.id)
        guard !adding || model.picks.count < Self.needed else { return }
        Haptics.select()
        withAnimation(.easeInOut(duration: 0.2)) {
            if model.picks.contains(u.id) { model.picks.removeAll { $0 == u.id } } else { model.picks.append(u.id) }
        }
        if model.picks.count == Self.needed { curating = Task { await curate() } }
    }

    // MARK: Curating

    /// Back to choosing, on this page, starting fresh: all three picks are cleared.
    private func backToPicking() {
        curating?.cancel()
        player.stop()
        var still = Transaction(); still.disablesAnimations = true
        withTransaction(still) { shimmer = false; handing = false; cardContent = false }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            expanded = false
            rearranged = false
            phase = .picking
        }
        // The ticks come off just after the options are back in place.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.25)) { model.picks = [] }
        }
        Task { await talk.replace(with: title) }
    }

    private func curate() async {
        // A beat to see the third tick land (and to untick it, if it was a slip).
        guard (try? await Task.sleep(for: .seconds(0.55))) != nil,
              model.picks.count == Self.needed, phase == .picking else { return }
        Haptics.step()
        phase = .curating
        await talk.clear()
        talk.full = Catalog.curating
        Task { await talk.say(Catalog.curating) }
        // Once the others have faded, the picks glide up and gather at the top.
        guard (try? await Task.sleep(for: .seconds(0.85))) != nil, model.step == .cases else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) { rearranged = true }
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false).delay(0.4)) { shimmer = true }
        for id in model.picks {
            if let u = Catalog.useCase(id) { lengths[id] = Self.length(u, voice: model.voice, name: model.addressName) }
        }
        guard (try? await Task.sleep(for: .seconds(1.9))) != nil, model.step == .cases else { return }
        // Each pick turns into its voice note: what stays behind goes first, then the fill, emoji
        // and name travel.
        withAnimation(.easeOut(duration: 0.14)) { handing = true }
        guard (try? await Task.sleep(for: .seconds(0.12))) != nil, model.step == .cases else { return }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
            phase = .ready
            expanded = true
        }
        Haptics.land()
        guard (try? await Task.sleep(for: .seconds(0.4))) != nil else { return }
        withAnimation(.easeOut(duration: 0.4)) { cardContent = true }
        // The orb has its say only once the notes have fully formed (players drawn in).
        guard (try? await Task.sleep(for: .seconds(0.95))) != nil, model.step == .cases else { return }
        await talk.replace(with: Catalog.curated(Self.needed))
    }

    // MARK: Cards

    private var cards: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.picks.enumerated()), id: \.element) { i, id in
                if let u = Catalog.useCase(id) {
                    card(u, index: i)
                        // Room to breathe either side of each divider.
                        .padding(.vertical, 20)
                        // A hairline between the notes.
                        .overlay(alignment: .top) {
                            if i > 0 {
                                Rectangle().fill(EQ.ink.opacity(0.09)).frame(height: 1)
                                    .opacity(cardContent ? 1 : 0)
                                    .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.08), value: cardContent)
                            }
                        }
                        .transition(.identity)
                }
            }
        }
    }

    /// A voice note with no container: a large cover on the left, and beside it the call's name over
    /// its player (play button, waveform, time), always there on every note.
    private func card(_ u: UseCase, index: Int) -> some View {
        let current = player.id == u.id
        let playing = current && player.playing
        let started = current && (playing || player.elapsed > 0)
        let progress = current ? min(1, player.elapsed / max(0.1, player.duration)) : 0
        let tint = Color(hex: Catalog.cardTints[index % Catalog.cardTints.count])
        return HStack(alignment: .center, spacing: 14) {
            // Out of the pick: its fill shrinks into this cover, and its emoji and name glide over
            // to these.
            // A photo of who's on the call where there is one (the emoji on a tint otherwise).
            let photo = Catalog.cover(u.id)
            Text(photo == nil ? u.emoji : "")
                .font(.system(size: 32))
                .matchedGeometryEffect(id: "\(u.id).emoji", in: pills, properties: .position)
                .frame(width: 76, height: 76)
                .background {
                    // Round, like a contact's profile photo.
                    let shape = Circle()
                    Group {
                        if let photo {
                            Image(photo).resizable().scaledToFill()
                        } else {
                            tint
                        }
                    }
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(.white, lineWidth: 1.5))
                    .shadow(color: Color(hex: 0x003214).opacity(0.1), radius: 6, y: 3)
                    .matchedGeometryEffect(id: "\(u.id).cover", in: pills)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(u.label)
                    .font(.dm(16, .semibold))
                    .foregroundStyle(EQ.ink)
                    // Whole names only: a long one takes a second line rather than cutting off.
                    .lineLimit(2)
                    .matchedGeometryEffect(id: "\(u.id).label", in: pills, properties: .position, anchor: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // One light button to hear the call: it fills green behind its label as the call
                // plays, and shows the length until then (the time so far once it's going).
                Button { play(u) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .contentTransition(.symbolEffect(.replace))
                        Text(playing ? "Pause" : started ? "Resume" : "Listen to this call")
                            .font(.dm(14, .semibold))
                            .contentTransition(.opacity)
                        Text(player.timeLabel(started ? player.elapsed : (lengths[u.id] ?? 0)))
                            .font(.dm(13, .medium))
                            .monospacedDigit()
                            .opacity(0.65)
                    }
                    .foregroundStyle(EQ.greenDeep)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule().fill(EQ.green.opacity(0.13)))
                    .background(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(EQ.green.opacity(0.16))
                                .frame(width: max(0, g.size.width * progress))
                        }
                    }
                    .clipShape(Capsule())
                    .animation(.linear(duration: 0.1), value: progress)
                    .animation(.easeInOut(duration: 0.2), value: playing)
                }
                .buttonStyle(PressStyle(scale: 0.96))
                .padding(.top, 8)
                .accessibilityLabel(playing ? "Pause \(u.label)" : "Listen to \(u.label)")
                // Pops in once the note has formed, one after another.
                .scaleEffect(cardContent ? 1 : 0.6, anchor: .leading)
                .opacity(cardContent ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.08), value: cardContent)
            }
        }
    }

    /// A call's length before it's loaded: its recordings' lengths (or the player's estimate)
    /// plus the gaps between lines.
    private static func length(_ u: UseCase, voice: Voice, name: String) -> Double {
        let s = CallPlayer.Script.make(u, everyday: false, voice: voice, name: name)
        return s.lines.enumerated().map { i, l in
            if let url = s.audio[i], let p = try? AVAudioPlayer(contentsOf: url) { return p.duration }
            return Double(l.line.count) * 0.065 + 0.3
        }.reduce(0, +) + Double(s.lines.count) * 0.35
    }

    private func play(_ u: UseCase) {
        Haptics.select()
        if player.id == u.id {
            if player.playing { player.pause() } else { player.play() }
            return
        }
        player.load(.make(u, everyday: false, voice: model.voice, name: model.addressName), id: u.id)
        player.play()
    }
}
