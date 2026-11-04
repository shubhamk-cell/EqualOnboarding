import SwiftUI

/// Chats home after onboarding: the pinned Equal AI thread (rule saved), the example rider call,
/// and — if call forwarding was skipped — a card to finish setup.
/// Long-press the logo to replay onboarding.
struct HomeView: View {
    @EnvironmentObject var model: AppModel

    private var now: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    searchRow
                    if !model.fwdDone {
                        setupCard
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.95).combined(with: .opacity)))
                    }
                    VStack(spacing: 0) {
                        equalRow
                        Rectangle().fill(EQ.hair).frame(height: 1)
                        riderRow
                    }
                    .padding(.horizontal, 20)
                    Text("\(model.displayName), your real calls will show up here.")
                        .font(.dm(14))
                        .lineSpacing(3)
                        .foregroundStyle(EQ.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.top, 28)
                        .padding(.bottom, 140)
                }
            }
        }
        .background(EQ.page.ignoresSafeArea())
        .overlay(alignment: .bottom) { navbar }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Wordmark(height: 24)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.8) { model.restart() }
                .accessibilityHint("Long-press to replay onboarding")
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(EQ.green).frame(width: 8, height: 8)
                Text("Available").font(.dm(15, .medium)).foregroundStyle(EQ.green)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EQ.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.74), in: Capsule())
            .overlay(Capsule().stroke(EQ.hair, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.74))
                .ignoresSafeArea(edges: .top)
                .shadow(color: EQ.hair, radius: 0, y: 1)
        )
        .zIndex(3)
    }

    private var searchRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                Text("Search for names").font(.dm(16))
                Spacer()
            }
            .foregroundStyle(EQ.placeholder)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(EQ.hair, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: 0x111111))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .background(Color.white.opacity(0.74), in: Circle())
                .overlay(Circle().stroke(EQ.hair, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var setupCard: some View {
        Button {
            Task {
                let r = await model.present(.permissionSheet)
                if r == "settings" {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { model.fwdDone = true }
                    model.show(toast: "Live Voicemail on")
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Enable Permissions").font(.dm(17, .semibold)).tracking(-0.34)
                    .foregroundStyle(Color(hex: 0x111111))
                Text("Allow notifications and contacts for real-time call recognition")
                    .font(.dm(12.5)).lineSpacing(2)
                    .foregroundStyle(EQ.secondary)
                    .frame(maxWidth: 190, alignment: .leading)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                Label("Open settings", systemImage: "gearshape.fill")
                    .font(.dm(13, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Capsule().fill(Color(hex: 0xE8620A)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(alignment: .trailing) {
                Text("⚙️").font(.system(size: 60)).shadow(color: .black.opacity(0.15), radius: 5, y: 6).padding(.trailing, 14)
            }
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFE8D6), Color(hex: 0xFFF4EA)], startPoint: .leading, endPoint: .trailing)))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 8)
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }

    // MARK: Rows

    private var equalRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image("EqualAvatar").resizable().frame(width: 56, height: 56).clipShape(Circle())
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("Equal AI").font(.dm(18, .semibold)).tracking(-0.36).foregroundStyle(Color(hex: 0x111111))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(now).font(.dm(13, .semibold)).foregroundStyle(EQ.green)
                        Badge(count: 1)
                    }
                }
                Text("Saved. I’ll follow it from now on.")
                    .font(.dm(17)).foregroundStyle(EQ.secondary).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                chipRow(["✏️ Add instruction", "💬 Talk to assistant"], read: false)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 14)
    }

    private var riderRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("🛵").font(.system(size: 22))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(hex: 0xFFE9D6)))
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Delivery rider").font(.dm(18, .semibold)).tracking(-0.36).foregroundStyle(Color(hex: 0x111111))
                    Spacer()
                    Text("Example").font(.dm(13)).foregroundStyle(EQ.secondary)
                }
                Text("Rider left your order at the door.")
                    .font(.dm(17)).foregroundStyle(EQ.secondary).lineLimit(1)
                chipRow(["📞 Call back", "💬 Reply on WhatsApp"], read: true)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 14)
    }

    private func chipRow(_ items: [String], read: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items, id: \.self) { HomeChip(text: $0, read: read) }
            }
            .padding(.trailing, 24)
        }
        .padding(.trailing, -24)
    }

    // MARK: Nav

    private var navbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Image(systemName: "bubble.left.fill").font(.system(size: 19))
                    Text("Chats").font(.dm(12, .semibold))
                }
                .foregroundStyle(EQ.green)
                .padding(.horizontal, 26)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: 0xF0F6E5)).shadow(color: .black.opacity(0.18), radius: 2.5))
                .overlay(alignment: .topTrailing) { Badge(count: 1).offset(x: -12, y: -2) }
                VStack(spacing: 2) {
                    Text("🙂").font(.system(size: 14))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color(hex: 0xF3D7A8)))
                    Text("You").font(.dm(12, .medium)).foregroundStyle(EQ.secondary)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 6)
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.74), in: Capsule())
            .overlay(Capsule().stroke(EQ.hair, lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 8)

            Button { model.show(toast: "Global MYA — not in this prototype") } label: {
                Image("EqualAvatar").resizable().frame(width: 64, height: 64).clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1))
                    .shadow(color: Color(hex: 0x006E28).opacity(0.22), radius: 3, y: 2)
                    .shadow(color: EQ.green.opacity(0.38), radius: 15, y: 12)
            }
            .buttonStyle(PressStyle(scale: 0.94))
            .accessibilityLabel("Talk to Equal")
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(stops: [.init(color: EQ.page.opacity(0), location: 0), .init(color: EQ.page, location: 0.42)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct Badge: View {
    var count: Int
    var body: some View {
        Text("\(count)")
            .font(.dm(11, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(EQ.green))
            .overlay(Capsule().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
    }
}

private struct HomeChip: View {
    var text: String
    var read: Bool
    var body: some View {
        HStack(spacing: 8) {
            Text(text).font(.dm(14)).foregroundStyle(Color(hex: 0x111111))
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(EQ.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(
            Capsule().fill(read
                ? AnyShapeStyle(LinearGradient(colors: [.white, Color(hex: 0xEBEBEB)], startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(LinearGradient(colors: [EQ.lime.opacity(0.01), EQ.lime.opacity(0.18)], startPoint: .top, endPoint: .bottom)))
        )
        .background(Capsule().fill(.white))
        .overlay(Capsule().stroke(read ? Color.black.opacity(0.08) : EQ.green.opacity(0.36), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 0.5)
    }
}
