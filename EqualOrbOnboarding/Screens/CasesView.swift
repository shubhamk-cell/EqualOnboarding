import SwiftUI

/// “What can I handle for you? Pick any” — twenty-five everyday jobs as two-per-row pills, scrolling under the orb.
/// The orb and its bubble arrive alone in the middle of the page; once the question is typed,
/// the options rise in underneath and push them up.
/// Continue curates on the same screen: the unpicked pills fade away and the top three picks
/// glide up to the top, keeping their size and wrapping into centred rows, the orb's dots gather into a spinning ring while the
/// bubble says it's curating, then the picks turn into sample-call cards, ready to play.
struct CasesView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @State private var phase: Phase = .picking
    /// The kept picks have moved out of the grid to the top, in wrapping rows.
    @State private var rearranged = false
    /// Each pill's width in the grid, so the picks keep their size when they move.
    @State private var pillWidths: [String: CGFloat] = [:]
    @Namespace private var pills
    @State private var top: [String] = []
    /// The options are on the page (the orb has been pushed up), and have cascaded in.
    @State private var showOptions = false
    @State private var revealed = false

    enum Phase { case picking, curating, curated }

    private let title = Catalog.title(.cases, name: "")

    private var rows: [[UseCase]] {
        stride(from: 0, to: Catalog.useCases.count, by: 2).map {
            Array(Catalog.useCases[$0..<min($0 + 2, Catalog.useCases.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !showOptions { Spacer(minLength: 0) }
            // The orb, its bubble and Continue stay put; the cards scroll between them.
            // Once the calls are ready the orb glides to the side of its bubble (as on every
            // call-player page) so the player is the focus.
            if phase == .curated {
                OrbBesideBubble(talk: talk, reserve: Catalog.curated(top.count))
                    .padding(.top, 14)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            } else {
                OrbWithBubble(talk: talk, reserve: title, spinning: phase == .curating)
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            if phase == .curated {
                // The calls fill the space between the orb and Continue: no scrolling.
                cardStack
                    .padding(.top, 20)
                    .frame(maxHeight: .infinity)
            } else if showOptions {
                options
            } else {
                Spacer(minLength: 0)
            }

            Button("Continue", action: proceed)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.picks.isEmpty)
                .opacity(phase == .curating || !revealed ? 0 : 1)
                .allowsHitTesting(phase != .curating && revealed)
                .animation(.easeInOut(duration: 0.3), value: phase)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: revealed)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .onAppear { talk.intro(title) }
        // The options wait until the orb has finished typing its question.
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !showOptions else { return }
            Task { await revealOptions() }
        }
    }

    /// The options come in and push the orb up.
    private func revealOptions() async {
        guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
        withAnimation(OrbFlight.glide) { showOptions = true }
        guard (try? await Task.sleep(for: .seconds(0.12))) != nil else { return }
        revealed = true
    }

    private var options: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                pillGrid.padding(.horizontal, 24)
                // Clear of the 14 pt fade at the top (ticks included); once curating, the gathered
                // picks and their cards sit lower still, out of the orb's glow.
                .padding(.top, phase == .picking ? 40 : 44)
                .padding(.bottom, 44)
                // The anchor includes the top padding, so scrolling to it lands the picks below the fade.
                .id("top")
            }
            .scrollBounceBehavior(.basedOnSize)
            // Curating gathers the picks at the top, so bring the top back into view.
            .onChange(of: phase) { _, p in
                if p == .curating { withAnimation(EQ.push(0.6)) { proxy.scrollTo("top", anchor: .top) } }
            }
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 14)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 40)
            }
        }
        .transition(.opacity.combined(with: .offset(y: 40)))
    }

    // MARK: Picking

    private var pillGrid: some View {
        Group {
            if rearranged {
                WrapRows(spacing: 10, centered: true) {
                    ForEach(Array(top.enumerated()), id: \.element) { i, id in
                        if let u = Catalog.useCase(id) {
                            pill(u, index: i)
                                .frame(width: pillWidths[id], height: 64)
                                .matchedGeometryEffect(id: id, in: pills)
                                // Hands over to its card: fades quickly on top while the card grows out of it.
                                .transition(.asymmetric(insertion: .identity,
                                                        removal: .opacity.animation(.easeOut(duration: 0.18))))
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
        let kept = top.contains(u.id)
        let fading = phase != .picking && !kept
        return Button {
            Haptics.select()
            withAnimation(.easeInOut(duration: 0.2)) {
                if on { model.picks.removeAll { $0 == u.id } } else { model.picks.append(u.id) }
            }
        } label: {
            HStack(spacing: 7) {
                Text(u.emoji).font(.system(size: 18))
                Text(u.label)
                    .font(.dm(14.5, .medium))
                    .tracking(-0.22)
                    .lineSpacing(0.6)
                    .foregroundStyle(on ? EQ.greenText : EQ.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)   // narrower phones: shrink a touch rather than truncate
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? EQ.mintAlt : .white.opacity(0.7)))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).inset(by: -3).fill(EQ.green.opacity(on ? 0.12 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? EQ.green : .white.opacity(0.95), lineWidth: 1.5))
            .shadow(color: Color(hex: on ? 0x00782D : 0x003214).opacity(on ? 0.12 : 0.06), radius: on ? 7 : 6, y: on ? 6 : 4)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(EQ.green))
                    .overlay(Circle().stroke(EQ.page, lineWidth: 2))
                    .scaleEffect(on ? 1 : 0.4)
                    .opacity(on ? 1 : 0)
                    .offset(x: 4, y: -6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: on)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(PressStyle(scale: 0.96))
        // Cascade in one by one, in reading order, as the options arrive (the ones below the fold
        // don't wait their turn).
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 18)
        .scaleEffect(revealed ? 1 : 0.94)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(min(index, 12)) * 0.1), value: revealed)
        .disabled(phase != .picking)
        .scaleEffect(kept && phase != .picking ? 1.03 : fading ? 0.9 : 1)
        .opacity(fading ? 0 : 1)
        .blur(radius: fading ? 2 : 0)
        .animation(kept ? .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.4)
                        : EQ.push(0.45).delay(Double(min(index, 12)) * 0.03), value: phase)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Curating

    private func proceed() {
        switch phase {
        case .picking:
            // V2 hands the picks to the instruction step instead of curating sample calls here.
            if model.variant == .v2 { model.next(); return }
            Haptics.step()
            Task { await curate() }
        case .curated:
            model.next()
        case .curating:
            break
        }
    }

    private func curate() async {
        top = Array(model.picks.prefix(3))
        phase = .curating
        await talk.clear()
        talk.full = Catalog.curating
        Task { await talk.say(Catalog.curating) }
        // Once the others have faded, the picks glide up into a column at the top.
        guard (try? await Task.sleep(for: .seconds(0.85))) != nil, model.step == .cases else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) { rearranged = true }
        guard (try? await Task.sleep(for: .seconds(1.75))) != nil, model.step == .cases else { return }
        // The picks hand over to the call player: one card per pick. Nothing plays until it's tapped.
        model.releaseOrb()
        withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) { phase = .curated }
        Haptics.land()
        Task { await talk.replace(with: Catalog.curated(top.count)) }
    }

    // MARK: Curated

    /// The top picks as sample calls, in the call player.
    private var cardStack: some View {
        CallDeck(calls: top.compactMap(Catalog.useCase))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

/// Rows that wrap: each view at its own size, onto the next row when it won't fit. Rows sit
/// on the left, or in the middle when `centered`.
struct WrapRows: Layout {
    var spacing: CGFloat = 10
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? 345, subviews: subviews)
        return CGSize(width: proposal.width ?? 345, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            let rowWidth = row.items.map { subviews[$0].sizeThatFits(.unspecified).width }.reduce(0, +)
                + spacing * CGFloat(row.items.count - 1)
            var x = bounds.minX + (centered ? (bounds.width - rowWidth) / 2 : 0)
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(items: [Int], y: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], y: CGFloat, height: CGFloat)] = []
        var items: [Int] = [], x: CGFloat = 0, y: CGFloat = 0, h: CGFloat = 0
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !items.isEmpty, x + size.width > width + 0.5 {
                rows.append((items, y, h)); y += h + spacing
                items = []; x = 0; h = 0
            }
            items.append(i); x += size.width + spacing; h = max(h, size.height)
        }
        if !items.isEmpty { rows.append((items, y, h)) }
        return rows
    }
}

/// Lays out two pills per row with widths that follow their text (weight = length²),
/// never letting either drop below 40 % of the row.
struct BrickRow: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat = 10
    var height: CGFloat = 64

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 345, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = Self.widths(total: bounds.width, weights: weights, spacing: spacing)
        var x = bounds.minX
        for (i, s) in subviews.enumerated() where i < widths.count {
            s.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: widths[i], height: height))
            x += widths[i] + spacing
        }
    }

    static func widths(total: CGFloat, weights: [CGFloat], spacing: CGFloat) -> [CGFloat] {
        guard weights.count == 2 else { return weights.map { _ in total } }
        let avail = total - spacing, minW = total * 0.4
        let w1 = min(max(avail * weights[0] / (weights[0] + weights[1]), minW), avail - minW)
        return [w1, avail - w1]
    }
}
