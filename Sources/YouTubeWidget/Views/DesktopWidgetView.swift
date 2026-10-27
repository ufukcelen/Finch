import SwiftUI

public struct DesktopWidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Glassmorphism background with native window drag support
            WindowDragArea()
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.35),
                                            Color.white.opacity(0.10),
                                            Color.black.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)

            VStack(spacing: 10) {
                // Top Drag Handle Bar
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Color.primary.opacity(0.25))
                        .frame(width: 42, height: 4)
                        .overlay(WindowDragArea(showHandCursor: true))
                    Spacer()
                }
                .padding(.top, -2)

                // MARK: - Header
                HStack(spacing: 10) {
                    // YouTube Logo & Avatar
                    ZStack(alignment: .bottomTrailing) {
                        if let avatarStr = viewModel.stats.avatarURL, let url = URL(string: avatarStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 38, height: 38)
                                        .clipShape(Circle())
                                case .failure, .empty:
                                    channelAvatarPlaceholder
                                @unknown default:
                                    channelAvatarPlaceholder
                                }
                            }
                        } else {
                            channelAvatarPlaceholder
                        }

                        // Little YouTube badge
                        Circle()
                            .fill(Color(red: 1.0, green: 0.1, blue: 0.1))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: 0.5)
                            )
                            .offset(x: 2, y: 2)
                    }

                    // Channel Name & Handle
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(viewModel.stats.channelTitle)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }

                        Text(viewModel.stats.handle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Refresh Button
                    Button {
                        withAnimation(.linear(duration: 0.8).repeatCount(1, autoreverses: false)) {
                            viewModel.isSpinning = true
                        }
                        Task {
                            await viewModel.refresh()
                            viewModel.isSpinning = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(viewModel.isSpinning || viewModel.isLoading ? 360 : 0))
                            .animation(
                                viewModel.isSpinning || viewModel.isLoading ?
                                    .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                                value: viewModel.isSpinning || viewModel.isLoading
                            )
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Verileri Yenile")

                    // Settings Button
                    Button {
                        DesktopWindowManager.shared.openSettingsWindow()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Ayarlar")
                }

                Divider()
                    .opacity(0.4)

                // MARK: - Subscriber Count Section
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(viewModel.stats.subscriberCount)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .primary.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            // Live Pulse Indicator
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                                        .scaleEffect(1.8)
                                        .opacity(0.6)
                                )
                        }

                        Text("ABONE SAYISI")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                    }

                    Spacer()

                    // Quick YouTube Open Button
                    Button {
                        viewModel.openChannel()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.video.fill")
                                .font(.system(size: 10))
                            Text("Kanalı Aç")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.15, blue: 0.15), Color(red: 0.8, green: 0.0, blue: 0.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                // MARK: - Latest Short Video Card
                Button {
                    viewModel.openLatestShort()
                } label: {
                    HStack(spacing: 10) {
                        // Thumbnail Preview
                        ZStack {
                            if let thumbStr = viewModel.stats.latestShortThumbnail, let url = URL(string: thumbStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 48, height: 68)
                                            .clipped()
                                    case .failure, .empty:
                                        shortPlaceholder
                                    @unknown default:
                                        shortPlaceholder
                                    }
                                }
                            } else {
                                shortPlaceholder
                            }

                            // Play badge
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .offset(x: 1)
                                )
                        }
                        .frame(width: 48, height: 68)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )

                        // Short Info
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("SON KISA VİDEO (SHORTS)")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .foregroundColor(.red)
                                    .tracking(0.8)

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .opacity(viewModel.isShortHovered ? 1.0 : 0.4)
                            }

                            Text(viewModel.stats.latestShortTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            // View Count Pill
                            HStack(spacing: 4) {
                                Text("🔥")
                                    .font(.system(size: 10))

                                Text(viewModel.stats.latestShortViews)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(viewModel.isShortHovered ? 0.08 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(viewModel.isShortHovered ? 0.15 : 0.06), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.isShortHovered = hovering
                    }
                }

                // MARK: - Footer (Relative update time & error info)
                HStack {
                    if let error = viewModel.lastErrorMessage {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    } else {
                        Text("Son güncelleme: \(formattedDate(viewModel.stats.lastUpdated))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                    }

                    Spacer()

                    // Drag badge with native performDrag
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 9))
                        Text("Sürükle")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .overlay(WindowDragArea(showHandCursor: true))
                    )
                    .help("Masaüstünde istediğiniz yere taşımak için basılı tutup sürükleyin")
                }
            }
            .padding(14)
        }
        .frame(width: 340, height: 260)
    }

    private var channelAvatarPlaceholder: some View {
        Circle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 38, height: 38)
            .overlay(
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            )
    }

    private var shortPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.4))
            .frame(width: 48, height: 68)
            .overlay(
                Image(systemName: "play.rectangle")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
