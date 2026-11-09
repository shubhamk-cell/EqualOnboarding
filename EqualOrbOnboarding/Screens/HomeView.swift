import SwiftUI

/// Home, matched to the shipping Equal AI app (`MainTabView` + `ConversationView`): a native
/// tab bar with Chats and You, the floating Equal button beside it, and the Chats screen —
/// logo header, dashboard cards, search bar, then the chats.
/// Long-press the logo to replay onboarding.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var celebrating = false

    /// Button size and placement from `MainTabView`.
    private static let buttonSize: CGFloat = 70
    private static let tabBarRowHeight: CGFloat = 49
    private static var isClassicTabBar: Bool {
        if #available(iOS 26, *) { false } else { true }
    }

    var body: some View {
        TabView(selection: $tab) {
            ChatsScreen()
                .tabItem { Label("Chats", systemImage: tab == 0 ? "message.fill" : "message").environment(\.symbolVariants, .none) }
                .badge(1)
                .tag(0)
            ProfileScreen()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(1)
        }
        .tint(DS.primary)
        .onChange(of: tab) { Haptics.select() }
        .overlay(alignment: Self.isClassicTabBar ? .bottom : .bottomTrailing) {
            equalButton
                .ignoresSafeArea(.keyboard)
        }
        // V7: the page dims round a sample call while Equal asks for a permission.
        .overlay {
            if let ask = model.contextAsk {
                ContextAskOverlay(ask: ask)
                    .id(ask.row)   // one overlay per sample call: both permissions share one
                    .transition(.opacity)
            }
        }
        // V6's hub.
        .sheet(isPresented: $model.hubOpen) {
            SetupHubSheet()
                .presentationBackground(sheetWash)
                .presentationDetents([.height(560), .large])
                .presentationCornerRadius(34)
                .presentationDragIndicator(.visible)
        }
        .overlay { if celebrating { Confetti().transition(.opacity) } }
        .onChange(of: model.isLive) { _, live in
            // V6: the last setup step done — Equal goes live, with a party.
            guard live, model.homeMode == .setupChecklist else { return }
            Haptics.success()
            withAnimation { celebrating = true }
            model.show(toast: "You’re live! I’ll take it from here 🎉")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { withAnimation { celebrating = false } }
        }
        // The banner follows what iOS has actually granted, including changes made in Settings.
        .task { await model.refreshPermissions() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshPermissions() } }
        }
    }

    /// `GlobalMYAButton`: the assistant avatar, centred on the tab bar row.
    private var equalButton: some View {
        Button { Haptics.step(); model.show(toast: "Global MYA — not in this prototype") } label: {
            Self.equalArt(size: Self.buttonSize)
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel("Equal Assistant")
        // Hidden while the orb from Welcome flies in and becomes it; the swap is invisible.
        .opacity(model.orbDock == nil ? 1 : 0)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.dockTarget($0) }
        .padding(.bottom, (Self.tabBarRowHeight - Self.buttonSize) / 2 - (Self.isClassicTabBar ? 0 : 8))
        .padding(.trailing, Self.isClassicTabBar ? 0 : 20)
    }
}

extension HomeView {
    /// The Equal button's artwork (`Avatar.assistant` from the production DesignSystem package),
    /// shared with the orb's flight from Welcome so the hand-over is pixel-identical.
    static func equalArt(size: CGFloat) -> some View {
        Image("AvatarAssistant")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}

// MARK: - Design tokens (DesignSystem package)

enum DS {
    static let primary = Color(hex: 0x00B140)
    static let onBackground = Color.black
    static let listBackground = Color(hex: 0xF7F7F7)
    static let pure = Color.white
    static let name = Color(hex: 0x313131)
    static let meta = Color(hex: 0x636363)
    static let separator = Color.gray.opacity(0.2)
    static let gold = Color(hex: 0xB17300)
}

extension Font {
    /// `Font.ds`: DM Sans at a text style's default size (title2 22, body 17, subheadline 15…).
    static func ds(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("DM Sans", size: size).weight(weight)
    }
}

// MARK: - Chats

/// `ConversationView`: white logo header over the grey list.
private struct ChatsScreen: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .background(
                    DS.pure
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .ignoresSafeArea(edges: .top)
                )
                .zIndex(1)
            ScrollViewReader { proxy in
            List {
                DashboardCarousel(cards: cards) { card in
                    Haptics.step()
                    switch card {
                    case .permissions: Task { _ = await model.present(.decline(model.missingPermissions)) }
                    default: model.show(toast: "Not in this prototype")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        ChatRowView(row: row)
                            .id(row.id)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { r in
                                if row.sample { model.contextFrames[row.id] = r }
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(DS.separator)
                            .listRowSeparator(i == 0 ? .hidden : .automatic, edges: .top)
                            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + ChatRowView.separatorInset }
                            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - ChatRowView.rowPadding }
                    }
                } header: {
                    searchRow
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        .background(DS.listBackground)
                        .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .contentMargins(.top, 10, for: .scrollContent)
            // V7: room below the chats so a sample call can be scrolled up near the top.
            .contentMargins(.bottom, asksInContext ? 520 : 0, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 0)
            // V7: bring the sample call up near the top, so the ask has room below it.
            .onChange(of: model.contextAsk) { _, ask in
                guard let ask else { return }
                withAnimation(EQ.push(0.6)) { proxy.scrollTo(ask.row, anchor: .top) }
            }
            }
        }
        .task { if asksInContext && !model.isLive || model.homeMode == .inContext { model.startContextAsks() } }
        .background(DS.listBackground.ignoresSafeArea())
    }

    /// V6 and V7 ask for permissions (and V6 for the rest of setup) beside sample calls.
    private var asksInContext: Bool { model.homeMode == .inContext || model.homeMode == .setupChecklist }

    /// The chats, with V6 / V7's sample calls on top.
    private var rows: [ChatRow] { model.contextRows.compactMap(ChatRow.context) + ChatRow.samples }

    private var cards: [DashboardCard] {
        let missing = model.missingPermissions
        var list: [DashboardCard] = []
        // Asked in context (V7) or on the checklist (V6) instead.
        if model.homeMode == .inContext || (model.homeMode == .setupChecklist && !model.isLive) {
            return [.softTrial, .meetAssistant]
        }
        switch missing {
        case [.notifications]: list.append(.notifications)
        case [.contacts]: list.append(.contacts)
        case []: break
        default: list.append(.permissions)
        }
        return list + [.softTrial, .meetAssistant]
    }

    private var header: some View {
        HStack {
            Wordmark(height: 28)
                .frame(width: 130, height: 28, alignment: .leading)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.8) { model.restart() }
                .accessibilityHint("Long-press to replay onboarding")
            Spacer()
            TrialDaysPill(text: "7 Days Left")
        }
        .frame(minHeight: 60)
        .padding(.horizontal)
    }

    /// `SearchBarLauncherView` + `ConversationMoreMenu`.
    private var searchRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17))
                RotatingPlaceholder(prefix: "Search for", words: ["names", "numbers", "categories", "keywords"])
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.black.opacity(0.4))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Capsule().fill(.white).overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)))
            Menu {
                Button("Select Chats", systemImage: "checkmark.circle") {}
                Button("Read All", systemImage: "checkmark.message") {}
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.onBackground.opacity(0.8))
                    .frame(width: 42, height: 42)
                    .glassCircle()
            }
        }
        .padding(.horizontal, 24)
    }
}

/// "Search for names / numbers / …", the word spinning up every 2 s.
private struct RotatingPlaceholder: View {
    var prefix: String
    var words: [String]
    @State private var i = 0

    var body: some View {
        HStack(spacing: 5) {
            Text(prefix)
            Text(words[i])
                .id(i)
                .transition(.push(from: .bottom).combined(with: .opacity))
        }
        .font(.ds(17))
        .lineLimit(1)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.35)) { i = (i + 1) % words.count }
            }
        }
    }
}

private extension View {
    /// `DSGlassButtonStyle`: Liquid Glass on iOS 26, thin material below.
    @ViewBuilder func glassCircle() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: .circle)
        } else {
            background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
        }
    }
}

// MARK: Trial pill

private struct TrialDaysPill: View {
    var text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 13))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF5C342), DS.gold], startPoint: .top, endPoint: .bottom))
                .frame(width: 18, height: 18)
            Text(text)
                .font(.dm(14, .medium))
                .tracking(-0.42)
                .foregroundStyle(DS.gold)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFFDF3), Color(hex: 0xF6F0E6)], startPoint: .leading, endPoint: .trailing)))
        .overlay(Capsule().strokeBorder(DS.gold, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .accessibilityLabel("Free trial, 7 days left")
    }
}

// MARK: Dashboard cards

private enum DashboardCard: Hashable {
    case permissions, notifications, contacts, meetAssistant, softTrial

    var title: String {
        switch self {
        case .permissions: "Enable Permissions"
        case .notifications: "Notification access"
        case .contacts: "Contact access"
        case .meetAssistant: "Meet Your Assistant"
        case .softTrial: "Gold, on us"
        }
    }

    var description: String {
        switch self {
        case .permissions: "Allow notifications and contacts for real-time call recognition"
        case .notifications: "Allow notifications access to avoid missing updates"
        case .contacts: "Without contact access, assistant can't manage your calls"
        case .meetAssistant: "Get to know your assistant better."
        case .softTrial: "Everything is unlocked. Nothing to pay yet."
        }
    }

    var cta: String {
        switch self {
        case .permissions, .notifications, .contacts: "Open settings"
        case .meetAssistant: "Call me"
        case .softTrial: "Subscribe"
        }
    }

    var ctaIcon: String? {
        switch self {
        case .permissions, .notifications, .contacts: "gear"
        case .meetAssistant: "phone.fill"
        case .softTrial: nil
        }
    }

    var isPermission: Bool { [.permissions, .notifications, .contacts].contains(self) }

    var gradient: [Color] {
        switch self {
        case .meetAssistant: [Color(hex: 0xEAF7EC), Color(hex: 0xD8F0DD)]
        case .softTrial: [Color(hex: 0xFFFDF3), Color(hex: 0xF6F0E6)]
        default: [Color(hex: 0xF8E2CC), Color(hex: 0xFDD2B2)]
        }
    }

    var stroke: Color {
        switch self {
        case .meetAssistant: DS.primary
        case .softTrial: DS.gold
        default: Color(hex: 0xE06500)
        }
    }

    var accent: Color {
        switch self {
        case .softTrial: DS.gold.opacity(0.28)
        default: stroke.opacity(0.3)
        }
    }

    var radius: CGFloat { self == .softTrial ? 16 : 20 }
}

/// `CardPagerView`: one card a page with a 3 % peek, auto-advancing every 4 s, dots below.
private struct DashboardCarousel: View {
    var cards: [DashboardCard]
    var onTap: (DashboardCard) -> Void
    @State private var page: Int? = 0

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let single = cards.count == 1
                let width = geo.size.width - 32 - (single ? 0 : geo.size.width * 0.03) - (single ? 0 : 24)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                            DashboardCardView(card: card) { onTap(card) }
                                .frame(width: width)
                                .frame(maxHeight: .infinity)
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $page)
                .contentMargins(.horizontal, 16, for: .scrollContent)
            }
            if cards.count > 1 {
                HStack(spacing: 6) {
                    ForEach(cards.indices, id: \.self) { i in
                        let on = i == (page ?? 0)
                        Circle()
                            .fill(on ? DS.primary.opacity(0.7) : Color.gray.opacity(0.3))
                            .frame(width: on ? 8 : 6, height: on ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: page)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(height: 200)
        .task(id: page) {
            guard cards.count > 1 else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut) { page = ((page ?? 0) + 1) % cards.count }
        }
    }
}

/// `DashboardCardView`.
private struct DashboardCardView: View {
    @EnvironmentObject var model: AppModel
    var card: DashboardCard
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.ds(17, .bold))
                    .foregroundStyle(DS.onBackground)
                    .lineLimit(1)
                    .minimumScaleFactor(card == .softTrial ? 0.8 : 1)
                    .padding(.top, 12)
                Text(card.description)
                    .font(.ds(13))
                    .foregroundStyle(DS.onBackground.opacity(0.7))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        if let icon = card.ctaIcon {
                            Image(systemName: icon).font(.ds(13, .semibold))
                        }
                        Text(card.cta).font(.ds(12, .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(card.stroke, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 10)
            art
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(background)
    }

    @ViewBuilder private var art: some View {
        switch card {
        case .softTrial:
            // Production `HomeCards.softTrialCrown`, sparkles included.
            Image("HomeCardCrown").resizable().scaledToFit().frame(width: 120, height: 120)
        case .meetAssistant:
            // Production `HomeCards.assistant`.
            Image("HomeCardAssistant").resizable().scaledToFit().frame(width: 100, height: 100)
                .scaleEffect(1.25)   // its art has wide margins; drawn larger without taking room from the text
        default:
            Image(model.missingPermissions.art).resizable().scaledToFit().frame(width: 100, height: 100)
        }
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: card.radius)
        return shape
            .fill(LinearGradient(colors: card.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .bottomTrailing) {
                if card == .softTrial {
                    Circle().fill(DS.gold.opacity(0.6)).frame(width: 118, height: 118).blur(radius: 60).offset(x: 30, y: 45)
                }
            }
            .overlay(alignment: .topTrailing) {
                Circle().fill(card.accent).frame(width: 140, height: 140).offset(x: 30, y: -40)
            }
            .overlay {
                if card == .softTrial {
                    shape.strokeBorder(card.stroke, lineWidth: 1)
                } else {
                    shape.stroke(LinearGradient(colors: [card.stroke, .white.opacity(0.8), card.stroke.opacity(0.8)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                }
            }
            .clipShape(shape)
    }
}

// MARK: Chat rows

private struct ChatRow {
    enum Avatar { case assistant, emoji(String) }
    var id: String = UUID().uuidString
    var avatar: Avatar
    var name: String
    /// A pretend call (V7), tagged so it's clearly not real.
    var sample = false
    var verified = false
    var time: String
    var message: String
    var unread = 0
    var chips: [String]

    /// V7's sample calls.
    static func context(_ id: String) -> ChatRow? {
        switch id {
        case "ctx_unknown":
            ChatRow(id: id, avatar: .emoji("❓"), name: "+91 98201 4\u{2022}\u{2022}\u{2022}\u{2022}", sample: true, time: "Just now",
                    message: "It was Priya from your office. I noted why she called.", unread: 1,
                    chips: ["Save contact", "Call back"])
        default: nil
        }
    }

    static var samples: [ChatRow] {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return [
            ChatRow(id: "equal", avatar: .assistant, name: "Equal AI", verified: true, time: f.string(from: Date()),
                    message: "Saved. I’ll follow it from now on.", unread: 1,
                    chips: ["Add instruction", "Talk to assistant"]),
            ChatRow(id: "rider", avatar: .emoji("🛵"), name: "Delivery rider", time: "Example",
                    message: "Rider left your order at the door.",
                    chips: ["Call back", "Reply on WhatsApp"]),
        ]
    }
}

/// `ConversationItemView`.
private struct ChatRowView: View {
    static let rowPadding: CGFloat = 12
    static let avatarSize: CGFloat = 42
    static var separatorInset: CGFloat { rowPadding + avatarSize }

    var row: ChatRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                avatar
                VStack(spacing: 2) {
                    HStack(alignment: .top) {
                        Text(row.name)
                            .font(.ds(17, .semibold))
                            .foregroundStyle(DS.name)
                            .lineLimit(1)
                        if row.sample {
                            Text("Sample call")
                                .font(.ds(11, .bold))
                                .foregroundStyle(Color(hex: 0x7C3AED))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: 0x7C3AED).opacity(0.1)))
                                .padding(.top, 2)
                        }
                        if row.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(DS.primary)
                                .padding(.top, 2)
                        }
                        Spacer()
                        Text(row.time)
                            .font(.ds(13, row.unread > 0 ? .semibold : .regular))
                            .foregroundStyle(row.unread > 0 ? DS.primary : DS.meta)
                            .fixedSize()
                    }
                    HStack(alignment: .center) {
                        Text(row.message)
                            .font(.ds(15))
                            .foregroundStyle(DS.meta)
                            .lineLimit(1)
                        Spacer()
                        if row.unread > 0 {
                            Text("\(row.unread)")
                                .font(.ds(12, .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(Capsule().fill(DS.primary))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Self.rowPadding)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(row.chips, id: \.self) { ActionChip(label: $0, highlighted: row.unread > 0) }
                }
                .padding(.leading, Self.separatorInset + 12)
                .padding(.trailing, Self.rowPadding)
                .padding(.top, 3)
                .padding(.bottom, 5)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, Self.rowPadding)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var avatar: some View {
        ZStack {
            switch row.avatar {
            case .assistant:
                // The artwork's green disc is 64 of its 80 pt; enlarge it so the disc alone fills the circle.
                Image("AvatarAssistant").resizable().scaledToFit()
                    .frame(width: Self.avatarSize * 80 / 64, height: Self.avatarSize * 80 / 64)
            case .emoji(let e):
                Circle().fill(Color.gray.opacity(0.2))
                Text(e).font(.system(size: 20))
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
    }
}

/// `ActionChipView`.
private struct ActionChip: View {
    var label: String
    var highlighted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.ds(15))
                .foregroundStyle(DS.onBackground)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.onBackground.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(LinearGradient(colors: highlighted ? [.white, Color(hex: 0xF3FBDF)] : [.white, Color(hex: 0xEEEEEE)],
                                                  startPoint: .top, endPoint: .bottom)))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: highlighted ? [Color(hex: 0xB1E1BD), Color(hex: 0xC9E9D1)] : [Color(hex: 0xE3E3E3), Color(hex: 0xEFEFEF)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
        .shadow(color: highlighted ? Color(hex: 0xB1E1BD).opacity(0.45) : .black.opacity(0.08), radius: 2, y: 1)
    }
}
