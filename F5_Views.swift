import SwiftUI
import Charts
import PhotosUI
import AVFoundation
import UIKit

// MARK: - App Shell (Boot-safe for Swift Playgrounds)

struct ContentView: View {
    @StateObject private var store = VaultStore()
    @State private var hasBooted = false

    var body: some View {
        Group {
            switch store.loadingState {
            case .idle, .loading:
                BootScreen()
                    .onAppear {
                        guard !hasBooted else { return }
                        hasBooted = true
                        Task { await store.boot() }
                    }
            case .ready:
                RootTabView()
                    .environmentObject(store)
                    .preferredColorScheme(.dark)
            case .failed(let message):
                BootErrorScreen(message: message) {
                    store.loadingState = .idle
                    Task { await store.boot() }
                }
            }
        }
    }
}

struct BootScreen: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(VaultTheme.cyan.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "film.stack")
                        .font(.system(size: 52))
                        .foregroundStyle(VaultTheme.cyan)
                }
                VStack(spacing: 8) {
                    Text("Collector Vault")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Loading your vault...")
                        .font(.subheadline)
                        .foregroundStyle(VaultTheme.textSecondary)
                }
                ProgressView().tint(VaultTheme.cyan).scaleEffect(1.2)
            }
        }
        .onAppear { pulse = true }
    }
}

struct BootErrorScreen: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(VaultTheme.orange)
                Text("Could not load vault")
                    .font(.title2.bold()).foregroundStyle(.white)
                Text(message)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent).tint(VaultTheme.cyan)
            }
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var store: VaultStore
    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardHomeView()
                    .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2") }
                CollectionHomeView()
                    .tabItem { Label("Collection", systemImage: "film.stack") }
                WishlistHomeView()
                    .tabItem { Label("Wishlist", systemImage: "heart.text.square") }
                OrdersHomeView()
                    .tabItem { Label("Orders", systemImage: "shippingbox") }
                ProfileHomeView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            ToastOverlay(toast: store.activeToast)
        }
    }
}

// MARK: - Shared UI

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VaultTheme.bgTop, VaultTheme.bgMid, VaultTheme.bgBottom],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            RadialGradient(
                colors: [VaultTheme.plum.opacity(0.18), .clear],
                center: .topLeading, startRadius: 20, endRadius: 420
            ).ignoresSafeArea()
            RadialGradient(
                colors: [VaultTheme.cyan.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 10, endRadius: 380
            ).ignoresSafeArea()
        }
    }
}

struct ToastOverlay: View {
    let toast: AppToast?
    var body: some View {
        VStack {
            if let toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.style.symbol)
                    Text(toast.message).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(toast.style.tint.opacity(0.92), in: Capsule())
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeInOut, value: toast?.id)
        .allowsHitTesting(false)
    }
}

struct VaultCard: ViewModifier {
    var strong: Bool = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: VaultTheme.cardRadius, style: .continuous)
                    .fill(strong ? VaultTheme.cardStrong : VaultTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VaultTheme.cardRadius, style: .continuous)
                    .stroke(strong ? VaultTheme.strokeStrong : VaultTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func vaultCard(strong: Bool = false) -> some View { modifier(VaultCard(strong: strong)) }
}

struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(.white)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct InfoRow: View {
    let title: String; let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(VaultTheme.textSecondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundStyle(VaultTheme.textPrimary)
        }
        .font(.subheadline)
    }
}

struct BoolRow: View {
    let title: String; let value: Bool
    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(value ? .green : .gray)
        }
        .font(.subheadline)
    }
}

struct SpecChip: View {
    let title: String; let tint: Color
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
            .foregroundStyle(tint)
    }
}

struct SectionBadge: View {
    let title: String; let tint: Color
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct BuyRecommendationChip: View {
    let recommendation: BuyRecommendation
    var body: some View {
        Label(recommendation.rawValue, systemImage: recommendation.symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(recommendation.tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(recommendation.tint.opacity(0.35), lineWidth: 1))
            .foregroundStyle(recommendation.tint)
    }
}

struct FilterPill: View {
    let title: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(selected ? VaultTheme.cardStrong : VaultTheme.cardSoft, in: Capsule())
                .overlay(Capsule().stroke(selected ? VaultTheme.strokeStrong : VaultTheme.stroke, lineWidth: 1))
                .foregroundStyle(VaultTheme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let title: String; let value: String; let icon: String; let tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(12).frame(width: 190)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct ShelfStatCard: View {
    let title: String; let subtitle: String; let value: String; let systemImage: String; let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage).foregroundStyle(tint)
                Spacer()
                Text(value).font(.headline).foregroundStyle(.white)
            }
            Text(title).font(.headline).foregroundStyle(.white)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct SectionHeader: View {
    let title: String; let countText: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(VaultTheme.textPrimary)
                Text(countText).font(.caption).foregroundStyle(VaultTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct EmptyVaultCard: View {
    let title: String; let subtitle: String; let symbol: String
    init(title: String = "Nothing here", subtitle: String = "Add something to get started.", symbol: String = "film.stack") {
        self.title = title; self.subtitle = subtitle; self.symbol = symbol
    }
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40)).foregroundStyle(.white.opacity(0.9))
            Text(title).font(.headline).foregroundStyle(.white)
            Text(subtitle).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct ActionCardButton: View {
    let title: String; let subtitle: String; let systemImage: String; let tint: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.title2).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PosterArtView: View {
    let edition: MovieEdition; let height: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: VaultTheme.posterRadius, style: .continuous)
            .fill(LinearGradient(
                colors: [(Color(hex: edition.accentHex) ?? VaultTheme.cyan), .black],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: height)
            .overlay(
                CoverImageView(
                    imageID: edition.coverImageID,
                    systemImage: edition.coverSystemImage,
                    accentHex: edition.accentHex,
                    size: CGSize(width: UIScreen.main.bounds.width - 32, height: height)
                )
                .clipShape(RoundedRectangle(cornerRadius: VaultTheme.posterRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VaultTheme.posterRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

struct ChartCard: View {
    let title: String; let points: [ReportPoint]; let style: ReportChartStyle
    var body: some View {
        InfoCard(title: title) {
            if points.isEmpty {
                Text("No data").foregroundStyle(.secondary)
            } else {
                switch style {
                case .bar:
                    Chart(points) { p in
                        BarMark(x: .value("Label", p.label), y: .value("Value", p.value))
                            .foregroundStyle(VaultTheme.cyan)
                    }
                    .frame(height: 200)
                case .line:
                    Chart(points) { p in
                        LineMark(x: .value("Label", p.label), y: .value("Value", p.value))
                            .foregroundStyle(VaultTheme.cyan)
                        PointMark(x: .value("Label", p.label), y: .value("Value", p.value))
                            .foregroundStyle(VaultTheme.cyan)
                    }
                    .frame(height: 200)
                case .table:
                    ForEach(points) { p in
                        HStack {
                            Text(p.label).foregroundStyle(.white)
                            Spacer()
                            Text(String(format: "%.1f", p.value)).foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

struct PriceHistoryChartCard: View {
    let title: String; let points: [PricePoint]
    var body: some View {
        InfoCard(title: title) {
            if points.isEmpty {
                Text("No price history yet.").foregroundStyle(.secondary)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Price", p.amount))
                        .foregroundStyle(VaultTheme.green)
                    PointMark(x: .value("Date", p.date), y: .value("Price", p.amount))
                        .foregroundStyle(VaultTheme.green)
                }
                .frame(height: 200)
                ForEach(points.suffix(5)) { p in
                    HStack {
                        Text(p.retailer).foregroundStyle(.white)
                        Spacer()
                        Text(p.date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                        Text(currencyString(p.amount)).foregroundStyle(.white)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let edition: MovieEdition
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BuyRecommendationChip(recommendation: edition.buyRecommendation)
                Spacer()
                SpecChip(title: edition.wishlistPriority.title, tint: edition.wishlistPriority.tint)
                SpecChip(title: edition.purchaseUrgency.title, tint: edition.purchaseUrgency.tint)
            }
            Text(edition.recommendationReason).font(.subheadline).foregroundStyle(.white)
            if let current = edition.bestCurrentPrice { InfoRow(title: "Best Price", value: currencyString(current)) }
            if let target  = edition.wishlistTargetPrice { InfoRow(title: "Target", value: currencyString(target)) }
            if let gap     = edition.targetGap {
                InfoRow(title: "Gap", value: gap <= 0 ? "At or below target" : currencyString(gap))
            }
            if let drop = edition.bestRetailerPriceDrop, drop > 0 {
                InfoRow(title: "Price Drop", value: currencyString(drop))
            }
            if let release = edition.expectedReleaseDate {
                InfoRow(title: "Expected Release", value: release.formatted(date: .abbreviated, time: .omitted))
            }
            if !edition.reasonWanted.isEmpty {
                Text("Why you want it: " + edition.reasonWanted).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct RetailerPriceCard: View {
    let retailer: RetailerLink
    var dropText: String? {
        guard let c = retailer.currentPrice, let p = retailer.previousPrice, p > c else { return nil }
        return currencyString(p - c) + " drop"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(retailer.retailer).foregroundStyle(.white)
                Spacer()
                if retailer.isPreferred { SectionBadge(title: "Preferred", tint: .cyan) }
                if let d = dropText { SectionBadge(title: d, tint: .green) }
            }
            if let c = retailer.currentPrice { InfoRow(title: "Current", value: currencyString(c)) }
            if let p = retailer.previousPrice { InfoRow(title: "Previous", value: currencyString(p)) }
            if let l = retailer.lowestSeenPrice { InfoRow(title: "Lowest Seen", value: currencyString(l)) }
            if !retailer.note.isEmpty { Text(retailer.note).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DashboardMetricTile: View {
    let metric: MetricKind; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(VaultTheme.cyan.opacity(0.16)).frame(width: 34, height: 34)
                    Image(systemName: metric.systemImage).foregroundStyle(VaultTheme.cyan)
                }
                Spacer()
            }
            Text(value).font(.title.bold()).foregroundStyle(VaultTheme.textPrimary)
            Text(metric.rawValue).font(.caption).foregroundStyle(VaultTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .vaultCard(strong: true)
    }
}

struct EditionRowCard: View {
    let edition: MovieEdition
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [(Color(hex: edition.accentHex) ?? VaultTheme.cyan).opacity(0.92), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 84)
                .overlay(
                    CoverImageView(imageID: edition.coverImageID, systemImage: edition.coverSystemImage,
                        accentHex: edition.accentHex, size: CGSize(width: 58, height: 84))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
            VStack(alignment: .leading, spacing: 6) {
                Text(edition.title).font(.headline).foregroundStyle(VaultTheme.textPrimary)
                Text(edition.editionTitle + " - " + edition.label)
                    .font(.subheadline).foregroundStyle(VaultTheme.textSecondary).lineLimit(2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        SpecChip(title: edition.format.rawValue, tint: edition.format.tint)
                        SpecChip(title: edition.watchStatus.shortLabel, tint: edition.watchStatus.tint)
                        if edition.isBlindBuy { SpecChip(title: "Blind Buy", tint: VaultTheme.gold) }
                        if edition.isLoanedOut { SpecChip(title: "Loaned", tint: VaultTheme.cyan) }
                        if edition.isBoxSet { SpecChip(title: "Box Set", tint: .blue) }
                        if edition.hasPremiumSpecs { SpecChip(title: "Premium", tint: .purple) }
                        if edition.collectionStatus == .wishlist {
                            BuyRecommendationChip(recommendation: edition.buyRecommendation)
                            if edition.underTargetPrice { SpecChip(title: "Under Target", tint: VaultTheme.green) }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(12).vaultCard()
    }
}

struct EditionGridCard: View {
    let edition: MovieEdition
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [(Color(hex: edition.accentHex) ?? VaultTheme.cyan).opacity(0.92), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .aspectRatio(0.68, contentMode: .fit)
                .overlay(
                    CoverImageView(imageID: edition.coverImageID, systemImage: edition.coverSystemImage,
                        accentHex: edition.accentHex, size: CGSize(width: 180, height: 265))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
            Text(edition.title).font(.headline).foregroundStyle(.white).lineLimit(2)
            Text(edition.editionTitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                SpecChip(title: edition.format.rawValue, tint: edition.format.tint)
                if edition.isBlindBuy { SpecChip(title: "Blind Buy", tint: .yellow) }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct FilmGroupCard: View {
    let group: FilmGroup
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [(Color(hex: group.representative.accentHex) ?? .blue).opacity(0.88), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 102)
                .overlay(
                    CoverImageView(imageID: group.representative.coverImageID,
                        systemImage: group.representative.coverSystemImage,
                        accentHex: group.representative.accentHex,
                        size: CGSize(width: 72, height: 102))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
            VStack(alignment: .leading, spacing: 6) {
                Text(group.title).font(.headline).foregroundStyle(.white)
                Text(String(group.year) + " - " + String(group.editions.count) + " editions")
                    .font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if group.ownedCount > 0 {
                            SpecChip(title: String(group.ownedCount) + " owned", tint: .green)
                        }
                        if group.wishlistCount > 0 {
                            SpecChip(title: String(group.wishlistCount) + " wishlist", tint: .purple)
                        }
                        if group.has4KOwned { SpecChip(title: "Has 4K", tint: .orange) }
                        if group.sellTradeCount > 0 { SpecChip(title: "Sell/Trade", tint: .pink) }
                        if group.boxSetParent != nil { SpecChip(title: "Box Set", tint: .blue) }
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct OrderRowCard: View {
    let order: OrderItem
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [(Color(hex: order.accentHex) ?? VaultTheme.cyan).opacity(0.92), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 84)
                .overlay(Image(systemName: order.coverSystemImage).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 6) {
                Text(order.title).font(.headline).foregroundStyle(VaultTheme.textPrimary)
                Text(order.editionTitle + " - " + order.retailer)
                    .font(.subheadline).foregroundStyle(VaultTheme.textSecondary).lineLimit(2)
                HStack(spacing: 6) {
                    SpecChip(title: order.orderStatus.rawValue, tint: order.orderStatus.tint)
                    if let r = order.releaseDate {
                        SpecChip(title: r.formatted(date: .abbreviated, time: .omitted), tint: VaultTheme.orange)
                    }
                }
            }
            Spacer()
            Text(currencyString(order.price)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        }
        .padding(12).vaultCard()
    }
}

struct LoanStatusPill: View {
    let loan: LoanRecord
    var body: some View {
        if loan.isReturned      { SectionBadge(title: "Returned", tint: .green) }
        else if loan.isOverdue  { SectionBadge(title: "Overdue",  tint: .red) }
        else                    { SectionBadge(title: "On Loan",  tint: .cyan) }
    }
}

// MARK: - Dashboard

struct DashboardHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var showingReportBuilder   = false
    @State private var showingDashboardEditor = false
    @State private var selectedMetric: MetricKind = .backlogCount

    private var analytics: AnalyticsStore { AnalyticsStore(store: store) }
    private var visibleTiles: [DashboardTile] {
        store.dashboardConfig.tiles.filter { $0.isPinned && !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        heroSection
                        quickLinksRow
                        smartCollectionRow
                        pinnedTilesGrid
                        wishlistRadarSection
                        priceDropsSection
                        insightsSection
                        savedReportsSection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingDashboardEditor = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    Button { showingReportBuilder = true } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                }
            }
            .sheet(isPresented: $showingReportBuilder) {
                NavigationStack {
                    ReportBuilderView(initialMetric: selectedMetric).environmentObject(store)
                }
            }
            .sheet(isPresented: $showingDashboardEditor) {
                NavigationStack { DashboardEditorView().environmentObject(store) }
            }
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color.purple.opacity(0.9), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)
            VStack(alignment: .leading, spacing: 10) {
                Text("Collector Brain").font(.largeTitle.bold()).foregroundStyle(.white)
                Text("Shelves, spending, backlog, value, wishlist temptation, and incoming wallet damage.")
                    .font(.headline).foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 8) {
                    SpecChip(title: "Backlog " + String(store.summary.totalUnwatched), tint: .orange)
                    SpecChip(title: "Buy Now " + String(store.summary.buyNowCount), tint: .green)
                    SpecChip(title: currencyString(store.summary.preorderPressure) + " this month", tint: .yellow)
                }
            }
            .padding(20)
        }
        .padding(.horizontal)
    }

    private var quickLinksRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Links", countText: "Launchpad")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink(destination: WishlistHomeView().environmentObject(store)) {
                        StatTile(title: "Wishlist", value: String(store.summary.totalWishlist), icon: "heart.text.square", tint: .pink)
                    }.buttonStyle(.plain)
                    NavigationLink(destination: ReleaseCalendarView().environmentObject(store)) {
                        StatTile(title: "Calendar", value: String(store.groupedReleaseMonths().count), icon: "calendar", tint: .orange)
                    }.buttonStyle(.plain)
                    NavigationLink(destination: LocationsHomeView().environmentObject(store)) {
                        StatTile(title: "Locations", value: String(store.storageLocations.count), icon: "square.grid.3x3.fill", tint: .blue)
                    }.buttonStyle(.plain)
                    NavigationLink(destination: LoansHomeView().environmentObject(store)) {
                        StatTile(title: "Loans", value: String(store.activeLoans.count), icon: "person.crop.rectangle.stack.fill",
                            tint: store.overdueLoans.isEmpty ? .cyan : .red)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
    }

    private var smartCollectionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Smart Collections", countText: String(store.smartCollectionPresets.count) + " presets")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.smartCollectionPresets) { preset in
                        NavigationLink(destination: SmartCollectionView(preset: preset).environmentObject(store)) {
                            StatTile(title: preset.title,
                                value: String(store.smartCollectionItems(for: preset.kind).count),
                                icon: preset.kind.icon, tint: .purple)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var pinnedTilesGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pinned Metrics", countText: String(visibleTiles.count) + " tiles")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(visibleTiles) { tile in
                    Button {
                        selectedMetric = tile.metricKind
                        showingReportBuilder = true
                    } label: {
                        DashboardMetricTile(metric: tile.metricKind, value: analytics.value(for: tile.metricKind))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var wishlistRadarSection: some View {
        let candidates = store.smartCollectionItems(for: .buyNowCandidates)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wishlist Radar", countText: String(candidates.count) + " ready")
            if candidates.isEmpty {
                Text("No urgent buy-now targets right now.").foregroundStyle(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(candidates.prefix(3)) { RecommendationCard(edition: $0) }
                }
                .padding(.horizontal)
            }
        }
    }

    private var priceDropsSection: some View {
        let drops = store.recentPriceDropCandidates()
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Price Drops", countText: String(drops.count) + " drop(s)")
            if drops.isEmpty {
                Text("No fresh price drops.").foregroundStyle(.secondary).padding(.horizontal)
            } else {
                InfoCard(title: "Latest") {
                    ForEach(drops.prefix(5)) { edition in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(edition.title).foregroundStyle(.white)
                                Text(edition.bestRetailer?.retailer ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currencyString(edition.bestRetailerPriceDrop ?? 0)).foregroundStyle(.green)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Insights", countText: "Collector whispers")
            VStack(spacing: 12) {
                ForEach(analytics.generateInsights()) { insight in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(insight.title).font(.headline).foregroundStyle(.white)
                        Text(insight.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(.horizontal)
        }
    }

    private var savedReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Saved Reports", countText: String(store.savedAnalyticsReports.count) + " saved")
            if store.savedAnalyticsReports.isEmpty {
                Text("Open the report builder to create your first report.").foregroundStyle(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(store.savedAnalyticsReports) { report in
                        NavigationLink(destination: AnalyticsReportDetailView(report: report).environmentObject(store)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(report.name).font(.headline).foregroundStyle(.white)
                                Text(report.metric.rawValue + " - " + report.groupBy.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct DashboardEditorView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var tiles: [DashboardTile] = []

    var body: some View {
        List {
            ForEach($tiles) { $tile in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tile.metricKind.rawValue)
                        Text(tile.metricKind.systemImage).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Pinned", isOn: $tile.isPinned).labelsHidden()
                }
            }
            .onMove { from, to in tiles.move(fromOffsets: from, toOffset: to) }
        }
        .navigationTitle("Dashboard Editor")
        .toolbar {
            ToolbarItem(placement: .topBarLeading)  { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { store.updateTileOrder(tiles); dismiss() }
            }
        }
        .onAppear { tiles = store.dashboardConfig.tiles.sorted { $0.sortOrder < $1.sortOrder } }
    }
}

struct ReportBuilderView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let initialMetric: MetricKind
    @State private var name        = "New Report"
    @State private var metric: MetricKind          = .backlogCount
    @State private var groupBy: GroupByField        = .label
    @State private var dateRange: AnalyticsDateRange = .allTime
    @State private var chartStyle: ReportChartStyle = .bar
    @State private var onlyBlindBuys   = false
    @State private var onlyUnwatched   = false
    @State private var includeWishlist = true
    @State private var onlyBuyNow      = false

    private var reportDef: SavedAnalyticsReport {
        SavedAnalyticsReport(name: name, metric: metric, groupBy: groupBy, dateRange: dateRange,
            filters: ReportFilter(onlyBlindBuys: onlyBlindBuys, onlyUnwatched: onlyUnwatched,
                includeWishlist: includeWishlist, onlyBuyNow: onlyBuyNow),
            chartStyle: chartStyle, notes: "")
    }

    var body: some View {
        Form {
            Section("Report") {
                TextField("Name", text: $name)
                Picker("Metric", selection: $metric) {
                    ForEach(MetricKind.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Group By", selection: $groupBy) {
                    ForEach(GroupByField.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Date Range", selection: $dateRange) {
                    ForEach(AnalyticsDateRange.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Chart Style", selection: $chartStyle) {
                    ForEach(ReportChartStyle.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Filters") {
                Toggle("Only Blind Buys",  isOn: $onlyBlindBuys)
                Toggle("Only Unwatched",   isOn: $onlyUnwatched)
                Toggle("Include Wishlist", isOn: $includeWishlist)
                Toggle("Only Buy Now",     isOn: $onlyBuyNow)
            }
            Section("Preview") {
                ChartCard(title: "Preview",
                    points: ReportEngine.run(reportDef, store: store).points,
                    style: chartStyle)
            }
            Section {
                Button("Save Report") {
                    store.savedAnalyticsReports.insert(reportDef, at: 0)
                    store.showToast(.success, "Report saved")
                    dismiss()
                }
            }
        }
        .navigationTitle("Report Builder")
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        .onAppear { metric = initialMetric }
    }
}

struct AnalyticsReportDetailView: View {
    @EnvironmentObject private var store: VaultStore
    let report: SavedAnalyticsReport
    private var result: ReportResult { ReportEngine.run(report, store: store) }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    ChartCard(title: report.name, points: result.points, style: report.chartStyle).padding(.horizontal)
                    InfoCard(title: "Summary") {
                        InfoRow(title: "Metric",     value: report.metric.rawValue)
                        InfoRow(title: "Group By",   value: report.groupBy.rawValue)
                        InfoRow(title: "Date Range", value: report.dateRange.rawValue)
                        InfoRow(title: "Total",      value: String(format: "%.1f", result.total))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(report.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Collection

struct CollectionHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var search      = ""
    @State private var filter: CollectionTabFilter  = .all
    @State private var sort: CollectionSort         = .yearNewest
    @State private var viewMode: CollectionViewMode = .grouped
    @State private var showingAdd          = false
    @State private var showingScanner      = false
    @State private var showingManualEntry  = false
    @State private var showingBulkEdit     = false
    @State private var showingSmartCollections = false
    @State private var selectionMode       = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var manualBarcode       = ""
    @State private var addMode: EditModePayload = .add(nil)

    private var baseEditions: [MovieEdition] {
        switch filter {
        case .all:          return store.editions
        case .owned:        return store.editions.filter { $0.collectionStatus == .owned }
        case .wishlist:     return store.editions.filter { $0.collectionStatus == .wishlist }
        case .blindBuys:    return store.editions.filter { $0.isBlindBuy }
        case .unwatched:    return store.editions.filter { $0.watchStatus == .unwatched }
        case .premiumSpecs: return store.editions.filter { $0.hasPremiumSpecs }
        case .buyNow:       return store.editions.filter { $0.collectionStatus == .wishlist && $0.buyRecommendation == .buyNow }
        }
    }

    private var filtered: [MovieEdition] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = q.isEmpty ? baseEditions : baseEditions.filter { e in
            e.title.localizedCaseInsensitiveContains(q) ||
            e.label.localizedCaseInsensitiveContains(q) ||
            e.barcode.localizedCaseInsensitiveContains(q) ||
            e.editionTitle.localizedCaseInsensitiveContains(q) ||
            e.customTags.contains { $0.localizedCaseInsensitiveContains(q) }
        }
        return sortedEditions(text)
    }

    private var groups: [FilmGroup] {
        let grouped = Dictionary(grouping: filtered) { $0.filmKey }
        return grouped.values.map { g in
            let rep = g[0]
            return FilmGroup(id: rep.filmKey, title: rep.title, originalTitle: rep.originalTitle,
                year: rep.year, editions: g.sorted { $0.editionTitle < $1.editionTitle })
        }
        .sorted { $0.year != $1.year ? $0.year > $1.year : $0.title < $1.title }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        summaryRow
                        filterBar
                        HStack {
                            Picker("Sort", selection: $sort) {
                                ForEach(CollectionSort.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu).tint(.white)
                            Spacer()
                            Picker("View", selection: $viewMode) {
                                ForEach(CollectionViewMode.allCases) {
                                    Label($0.rawValue, systemImage: $0.systemImage).tag($0)
                                }
                            }
                            .pickerStyle(.segmented).frame(maxWidth: 160)
                        }
                        .padding(.horizontal)
                        if selectionMode { bulkBar }
                        switch viewMode {
                        case .grouped: groupedBody
                        case .list:    listBody
                        case .grid:    gridBody
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Collection")
            .searchable(text: $search, prompt: "Search titles, labels, barcodes...")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        selectionMode.toggle()
                        if !selectionMode { selectedIDs.removeAll() }
                    } label: {
                        Image(systemName: selectionMode ? "checkmark.circle.fill" : "checklist")
                    }
                    Button { showingSmartCollections = true } label: {
                        Image(systemName: "sparkles.rectangle.stack")
                    }
                    Button { showingScanner = true } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    Button { addMode = .add(nil); showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    EditEditionView(mode: addMode) { e in
                        if case .edit = addMode { store.update(e) } else { store.add(e) }
                    }
                    .environmentObject(store)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerSheet(
                    onFound: { code in
                        showingScanner = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            addMode = .add(code); showingAdd = true
                        }
                    },
                    onManualEntry: {
                        showingScanner = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showingManualEntry = true }
                    },
                    onError: { store.showToast(.error, $0.localizedDescription) }
                )
            }
            .sheet(isPresented: $showingBulkEdit) {
                NavigationStack { BulkEditView(selectedIDs: selectedIDs).environmentObject(store) }
            }
            .sheet(isPresented: $showingSmartCollections) {
                NavigationStack { SmartCollectionsHomeView().environmentObject(store) }
            }
            .alert("Manual Barcode", isPresented: $showingManualEntry) {
                TextField("Enter barcode", text: $manualBarcode).keyboardType(.numberPad)
                Button("Cancel", role: .cancel) { manualBarcode = "" }
                Button("Use") {
                    let code = manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
                    manualBarcode = ""
                    addMode = .add(code.isEmpty ? nil : code)
                    showingAdd = true
                }
            } message: { Text("Type a UPC or EAN number.") }
        }
    }

    private var summaryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatTile(title: "Films",     value: String(store.summary.totalFilms),    icon: "film",          tint: .cyan)
                StatTile(title: "Editions",  value: String(store.summary.totalEditions), icon: "film.stack",    tint: .blue)
                StatTile(title: "Unwatched", value: String(store.summary.totalUnwatched), icon: "clock",        tint: .orange)
                StatTile(title: "Buy Now",   value: String(store.summary.buyNowCount),   icon: "cart.fill.badge.plus", tint: .green)
                StatTile(title: "4K Owned",  value: String(store.summary.total4Ks),      icon: "sparkles.tv",   tint: .purple)
            }
            .padding(.horizontal)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CollectionTabFilter.allCases) { f in
                    FilterPill(title: f.rawValue, selected: filter == f) { filter = f }
                }
            }
            .padding(.horizontal)
        }
    }

    private var bulkBar: some View {
        HStack(spacing: 12) {
            Text(String(selectedIDs.count) + " selected").foregroundStyle(.white)
            Spacer()
            Button("Bulk Edit") { showingBulkEdit = true }.disabled(selectedIDs.isEmpty)
        }
        .padding()
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
    }

    @ViewBuilder private var groupedBody: some View {
        if groups.isEmpty {
            EmptyVaultCard(title: "No editions match", subtitle: "Try a different filter or add a disc.").padding(.horizontal)
        } else {
            VStack(spacing: 12) {
                ForEach(groups) { group in
                    NavigationLink(destination: FilmGroupDetailView(groupID: group.id).environmentObject(store)) {
                        FilmGroupCard(group: group)
                    }
                    .buttonStyle(.plain).padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder private var listBody: some View {
        if filtered.isEmpty {
            EmptyVaultCard(title: "No editions match", subtitle: "Try a different filter or add a disc.").padding(.horizontal)
        } else {
            VStack(spacing: 12) {
                ForEach(filtered) { edition in
                    if selectionMode {
                        Button { toggle(edition.id) } label: {
                            EditionRowCard(edition: edition)
                                .overlay(alignment: .topTrailing) { selMark(edition.id) }
                        }
                        .buttonStyle(.plain).padding(.horizontal)
                    } else {
                        NavigationLink(destination: ItemDetailView(editionID: edition.id).environmentObject(store)) {
                            EditionRowCard(edition: edition)
                        }
                        .buttonStyle(.plain).padding(.horizontal)
                    }
                }
            }
        }
    }

    @ViewBuilder private var gridBody: some View {
        if filtered.isEmpty {
            EmptyVaultCard(title: "No editions match", subtitle: "Try a different filter or add a disc.").padding(.horizontal)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(filtered) { edition in
                    if selectionMode {
                        Button { toggle(edition.id) } label: {
                            EditionGridCard(edition: edition)
                                .overlay(alignment: .topTrailing) { selMark(edition.id) }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: ItemDetailView(editionID: edition.id).environmentObject(store)) {
                            EditionGridCard(edition: edition)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func selMark(_ id: UUID) -> some View {
        Image(systemName: selectedIDs.contains(id) ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selectedIDs.contains(id) ? .green : .white.opacity(0.8))
            .padding(10)
    }

    private func sortedEditions(_ input: [MovieEdition]) -> [MovieEdition] {
        switch sort {
        case .titleAZ:           return input.sorted { $0.title < $1.title }
        case .titleZA:           return input.sorted { $0.title > $1.title }
        case .yearNewest:        return input.sorted { $0.year > $1.year }
        case .yearOldest:        return input.sorted { $0.year < $1.year }
        case .acquiredNewest:    return input.sorted { ($0.acquiredDate ?? .distantPast) > ($1.acquiredDate ?? .distantPast) }
        case .acquiredOldest:    return input.sorted { ($0.acquiredDate ?? .distantFuture) < ($1.acquiredDate ?? .distantFuture) }
        case .paidHighLow:       return input.sorted { ($0.lastPaidPrice ?? 0) > ($1.lastPaidPrice ?? 0) }
        case .paidLowHigh:       return input.sorted { ($0.lastPaidPrice ?? 0) < ($1.lastPaidPrice ?? 0) }
        case .valueHighLow:      return input.sorted { $0.effectiveValue > $1.effectiveValue }
        case .labelAZ:           return input.sorted { $0.label < $1.label }
        case .watchedFirst:      return input.sorted { $0.watchStatus == .watchedThisEdition && $1.watchStatus != .watchedThisEdition }
        case .unwatchedFirst:    return input.sorted { $0.watchStatus == .unwatched && $1.watchStatus != .unwatched }
        case .wishlistPriority:  return input.sorted { $0.wishlistPriority.rawValue > $1.wishlistPriority.rawValue }
        case .urgency:           return input.sorted { $0.purchaseUrgency.rawValue > $1.purchaseUrgency.rawValue }
        case .targetGap:         return input.sorted { ($0.targetGap ?? Double.greatestFiniteMagnitude) < ($1.targetGap ?? Double.greatestFiniteMagnitude) }
        case .oopRisk:           return input.sorted { $0.oopRiskLevel.rawValue > $1.oopRiskLevel.rawValue }
        case .releaseDateSoonest: return input.sorted { ($0.expectedReleaseDate ?? .distantFuture) < ($1.expectedReleaseDate ?? .distantFuture) }
        }
    }
}

struct FilmGroupDetailView: View {
    @EnvironmentObject private var store: VaultStore
    let groupID: String
    private var group: FilmGroup? { store.filmGroups.first { $0.id == groupID } }

    var body: some View {
        ZStack {
            AppBackground()
            if let group {
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeader(title: group.title, countText: String(group.editions.count) + " editions").padding(.top)
                        VStack(spacing: 12) {
                            ForEach(group.editions) { edition in
                                NavigationLink(destination: ItemDetailView(editionID: edition.id).environmentObject(store)) {
                                    EditionRowCard(edition: edition)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            } else {
                Text("Group not found").foregroundStyle(.white)
            }
        }
        .navigationTitle("Film")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Wishlist

struct WishlistHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var search = ""
    @State private var sort: CollectionSort = .wishlistPriority

    private var items: [MovieEdition] {
        let base = store.editions.filter { $0.collectionStatus == .wishlist }
        let searched = search.isEmpty ? base : base.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.label.localizedCaseInsensitiveContains(search)
        }
        switch sort {
        case .wishlistPriority:  return searched.sorted { $0.wishlistPriority.rawValue > $1.wishlistPriority.rawValue }
        case .urgency:           return searched.sorted { $0.purchaseUrgency.rawValue > $1.purchaseUrgency.rawValue }
        case .targetGap:         return searched.sorted { ($0.targetGap ?? Double.greatestFiniteMagnitude) < ($1.targetGap ?? Double.greatestFiniteMagnitude) }
        case .oopRisk:           return searched.sorted { $0.oopRiskLevel.rawValue > $1.oopRiskLevel.rawValue }
        case .releaseDateSoonest: return searched.sorted { ($0.expectedReleaseDate ?? .distantFuture) < ($1.expectedReleaseDate ?? .distantFuture) }
        default:                 return searched.sorted { $0.title < $1.title }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ShelfStatCard(title: "Buy Now", subtitle: "Ready",
                                value: String(store.summary.buyNowCount), systemImage: "cart.fill.badge.plus", tint: .green)
                            ShelfStatCard(title: "This Month", subtitle: "Preorder pressure",
                                value: currencyString(store.summary.preorderPressure), systemImage: "exclamationmark.dollar", tint: .orange)
                        }
                        .padding(.horizontal)
                        HStack {
                            Picker("Sort", selection: $sort) {
                                Text("Priority").tag(CollectionSort.wishlistPriority)
                                Text("Urgency").tag(CollectionSort.urgency)
                                Text("Target Gap").tag(CollectionSort.targetGap)
                                Text("OOP Risk").tag(CollectionSort.oopRisk)
                                Text("Release Date").tag(CollectionSort.releaseDateSoonest)
                                Text("Title A-Z").tag(CollectionSort.titleAZ)
                            }
                            .pickerStyle(.menu).tint(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        if items.isEmpty {
                            EmptyVaultCard(title: "Wishlist is clear", subtitle: "Add some future heartbreak.", symbol: "heart.text.square").padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(items) { edition in
                                    NavigationLink(destination: ItemDetailView(editionID: edition.id).environmentObject(store)) {
                                        VStack(spacing: 8) {
                                            EditionRowCard(edition: edition)
                                            RecommendationCard(edition: edition)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Wishlist")
            .searchable(text: $search, prompt: "Search wishlist...")
        }
    }
}

// MARK: - Smart Collections

struct SmartCollectionsHomeView: View {
    @EnvironmentObject private var store: VaultStore
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeader(title: "Smart Collections", countText: String(store.smartCollectionPresets.count) + " presets").padding(.top)
                    VStack(spacing: 12) {
                        ForEach(store.smartCollectionPresets) { preset in
                            NavigationLink(destination: SmartCollectionView(preset: preset).environmentObject(store)) {
                                ActionCardButton(title: preset.title,
                                    subtitle: String(store.smartCollectionItems(for: preset.kind).count) + " items",
                                    systemImage: preset.kind.icon, tint: .purple, action: {})
                            }
                            .buttonStyle(.plain).padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Smart Collections")
    }
}

struct SmartCollectionView: View {
    @EnvironmentObject private var store: VaultStore
    let preset: SmartCollectionPreset
    private var items: [MovieEdition] { store.smartCollectionItems(for: preset.kind) }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    SectionHeader(title: preset.title, countText: String(items.count) + " items").padding(.top)
                    if items.isEmpty {
                        EmptyVaultCard(title: "Nothing here", subtitle: "This smart shelf is peaceful.", symbol: preset.kind.icon).padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(items) { edition in
                                NavigationLink(destination: ItemDetailView(editionID: edition.id).environmentObject(store)) {
                                    EditionRowCard(edition: edition)
                                }
                                .buttonStyle(.plain).padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle(preset.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bulk Edit

struct BulkEditView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let selectedIDs: Set<UUID>
    @State private var action: BulkEditAction      = .watchedThisEdition
    @State private var tag              = ""
    @State private var locationID: UUID?
    @State private var condition: ConditionRating       = .mint
    @State private var disposition: DuplicateDisposition = .keep
    @State private var priority: WishlistPriority       = .medium
    @State private var urgency: PurchaseUrgency         = .keepAnEyeOnIt
    @State private var confirmApply = false

    var body: some View {
        Form {
            Section("Selection") { Text(String(selectedIDs.count) + " editions") }
            Section("Action") {
                Picker("Action", selection: $action) {
                    ForEach(BulkEditAction.allCases) { Text($0.rawValue).tag($0) }
                }
                switch action {
                case .addTag, .removeTag: TextField("Tag", text: $tag)
                case .moveLocation:
                    Picker("Location", selection: $locationID) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(store.storageLocations) { Text($0.name).tag(Optional($0.id)) }
                    }
                case .setCondition:
                    Picker("Condition", selection: $condition) {
                        ForEach(ConditionRating.allCases) { Text($0.rawValue).tag($0) }
                    }
                case .setDuplicateDisposition:
                    Picker("Disposition", selection: $disposition) {
                        ForEach(DuplicateDisposition.allCases) { Text($0.rawValue).tag($0) }
                    }
                case .setWishlistPriority:
                    Picker("Priority", selection: $priority) {
                        ForEach(WishlistPriority.allCases) { Text($0.title).tag($0) }
                    }
                case .setUrgency:
                    Picker("Urgency", selection: $urgency) {
                        ForEach(PurchaseUrgency.allCases) { Text($0.title).tag($0) }
                    }
                default: EmptyView()
                }
            }
        }
        .navigationTitle("Bulk Edit")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Apply") { confirmApply = true } }
        }
        .alert("Apply to " + String(selectedIDs.count) + " items?", isPresented: $confirmApply) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                switch action {
                case .watchedThisEdition:      store.bulkSetWatchStatus(selectedIDs, to: .watchedThisEdition)
                case .unwatched:               store.bulkSetWatchStatus(selectedIDs, to: .unwatched)
                case .addTag:                  store.bulkAddTag(selectedIDs, tag: tag)
                case .removeTag:               store.bulkRemoveTag(selectedIDs, tag: tag)
                case .moveLocation:            store.bulkMoveLocation(selectedIDs, locationID: locationID)
                case .setCondition:            store.bulkSetCondition(selectedIDs, condition: condition)
                case .setDuplicateDisposition: store.bulkSetDuplicateDisposition(selectedIDs, disposition: disposition)
                case .setWishlistPriority:     store.bulkSetWishlistPriority(selectedIDs, priority: priority)
                case .setUrgency:              store.bulkSetUrgency(selectedIDs, urgency: urgency)
                }
                dismiss()
            }
        }
    }
}

// MARK: - Item Detail

struct ItemDetailView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let editionID: UUID
    @State private var showingWatch       = false
    @State private var showingTransaction = false
    @State private var showingEdit        = false
    @State private var showingLoan        = false
    @State private var showingLocation    = false
    @State private var showingMarket      = false
    @State private var confirmDelete      = false

    private var edition: MovieEdition? { store.editionByID[editionID] }

    var body: some View {
        ZStack {
            AppBackground()
            if let edition {
                ScrollView {
                    VStack(spacing: 14) {
                        PosterArtView(edition: edition, height: 320).padding(.horizontal)
                        actionBar(edition)
                        adminBar(edition)
                        if edition.collectionStatus == .wishlist {
                            RecommendationCard(edition: edition).padding(.horizontal)
                        }
                        collectionCard(edition)
                        if edition.collectionStatus == .wishlist { wishlistCard(edition) }
                        specsCard(edition)
                        if !edition.discs.isEmpty { discsCard(edition) }
                        watchCard(edition)
                        financialsCard(edition)
                        marketCard(edition)
                        loansCard(edition)
                        boxSetCard(edition)
                        upgradeCard(edition)
                        if !edition.customTags.isEmpty || !edition.tags.isEmpty { tagsCard(edition) }
                        notesCard(edition)
                    }
                    .padding(.vertical)
                }
                .sheet(isPresented: $showingWatch) {
                    NavigationStack { WatchEventEntryView(edition: edition).environmentObject(store) }
                }
                .sheet(isPresented: $showingTransaction) {
                    NavigationStack { TransactionEntryView(edition: edition).environmentObject(store) }
                }
                .sheet(isPresented: $showingEdit) {
                    NavigationStack {
                        EditEditionView(mode: .edit(edition)) { store.update($0) }.environmentObject(store)
                    }
                }
                .sheet(isPresented: $showingLoan) {
                    NavigationStack { QuickLoanSheet(edition: edition).environmentObject(store) }
                }
                .sheet(isPresented: $showingLocation) { QuickLocationSheet(edition: edition).environmentObject(store) }
                .sheet(isPresented: $showingMarket) {
                    NavigationStack { MarketValueEditorView(edition: edition).environmentObject(store) }
                }
            } else {
                VStack(spacing: 12) {
                    Text("Item not found").foregroundStyle(.white)
                    Button("Close") { dismiss() }
                }
            }
        }
        .navigationTitle("Item Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let edition {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Edit") { showingEdit = true }
                    Menu {
                        NavigationLink(destination:
                            EditEditionView(mode: .addAnotherEdition(edition)) { store.add($0) }
                                .environmentObject(store)
                        ) { Text("Add Another Edition of This Film") }
                        Button(role: .destructive) { confirmDelete = true } label: { Text("Delete") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .alert("Delete This Edition?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let edition { store.delete(edition); dismiss() }
            }
        } message: { Text("This cannot be undone.") }
    }

    @ViewBuilder
    private func actionBar(_ edition: MovieEdition) -> some View {
        HStack(spacing: 12) {
            Button { showingWatch = true } label: {
                Label("Log Watch", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Button { showingTransaction = true } label: {
                Label("Transaction", systemImage: "creditcard.fill")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .buttonStyle(.plain).padding(.horizontal)
    }

    @ViewBuilder
    private func adminBar(_ edition: MovieEdition) -> some View {
        HStack(spacing: 12) {
            Button { showingLoan = true } label: {
                Label(edition.isLoanedOut ? "Edit Loan" : "Loan Out", systemImage: "arrowshape.turn.up.right.fill")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Button { showingLocation = true } label: {
                Label("Move Shelf", systemImage: "square.grid.3x3.fill")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .buttonStyle(.plain).padding(.horizontal)
        HStack(spacing: 12) {
            Button { showingMarket = true } label: {
                Label("Market Stats", systemImage: "dollarsign.circle.fill")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if let loan = store.activeLoan(for: edition.id) {
                Button { store.markLoanReturned(loan.id) } label: {
                    Label("Mark Returned", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Button { if let url = CollectorURLBuilder.ebaySoldSearchURL(for: edition) { openURL(url) } } label: {
                    Label("Search Market", systemImage: "safari.fill")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain).padding(.horizontal)
    }

    @ViewBuilder
    private func collectionCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Collection") {
            InfoRow(title: "Edition",       value: e.editionTitle)
            InfoRow(title: "Format",        value: e.format.rawValue)
            InfoRow(title: "Label",         value: e.label)
            InfoRow(title: "Region",        value: e.regionCode)
            InfoRow(title: "Barcode",       value: e.barcode.isEmpty ? "None" : e.barcode)
            InfoRow(title: "Location",      value: store.locationName(for: e))
            InfoRow(title: "Watch Status",  value: e.watchStatus.rawValue)
            InfoRow(title: "Times Watched", value: String(e.timesWatched))
            InfoRow(title: "Last Watched",  value: e.lastWatchedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Never")
            BoolRow(title: "Blind Buy", value: e.isBlindBuy)
            BoolRow(title: "Favorite",  value: e.isFavorite)
            BoolRow(title: "Box Set",   value: e.isBoxSet)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func wishlistCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Wishlist Intelligence") {
            InfoRow(title: "Priority", value: e.wishlistPriority.title)
            InfoRow(title: "Urgency",  value: e.purchaseUrgency.title)
            InfoRow(title: "OOP Risk", value: e.oopRiskLevel.title)
            BoolRow(title: "Limited Pressing", value: e.isLimitedPressing)
            if let r = e.expectedReleaseDate {
                InfoRow(title: "Expected Release", value: r.formatted(date: .abbreviated, time: .omitted))
            }
            if let s = e.targetSavingsText { InfoRow(title: "Target Check", value: s) }
            if !e.reasonWanted.isEmpty     { InfoRow(title: "Why You Want It", value: e.reasonWanted) }
        }
        .padding(.horizontal)
        if !e.retailerLinks.isEmpty {
            InfoCard(title: "Retailer Comparison") {
                ForEach(e.retailerLinks) { RetailerPriceCard(retailer: $0) }
            }
            .padding(.horizontal)
        }
        if !e.wishlistPriceHistory.isEmpty {
            PriceHistoryChartCard(title: "Wishlist Price History", points: e.wishlistPriceHistory.sorted { $0.date < $1.date })
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func specsCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Specs") {
            BoolRow(title: "IMAX Scenes",  value: e.hasIMAXScenes)
            BoolRow(title: "Dolby Vision", value: e.hasDolbyVision)
            BoolRow(title: "HDR10",        value: e.hasHDR10)
            BoolRow(title: "HDR10+",       value: e.hasHDR10Plus)
            BoolRow(title: "Dolby Atmos",  value: e.hasDolbyAtmos)
            BoolRow(title: "Dolby Audio",  value: e.hasDolbyAudio)
            BoolRow(title: "DTS:X",        value: e.hasDTSX)
            if !e.videoNotes.isEmpty { InfoRow(title: "Video Notes", value: e.videoNotes) }
            if !e.audioNotes.isEmpty { InfoRow(title: "Audio Notes", value: e.audioNotes) }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func discsCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Discs") {
            ForEach(e.discs) { disc in
                VStack(alignment: .leading, spacing: 4) {
                    Text(disc.discLabel).foregroundStyle(.white)
                    Text(disc.discType + " - " + disc.regionCode).font(.caption).foregroundStyle(.secondary)
                    if let r = disc.runtimeMinutes {
                        Text(String(r) + " min").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func watchCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Watch History") {
            let watches = store.relatedWatchEvents(for: e)
            if watches.isEmpty {
                Text("No watch events yet.").foregroundStyle(.secondary)
            } else {
                ForEach(watches) { w in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(w.watchedOn.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.white)
                        Text(w.sourceType.rawValue + " - Rewatch " + String(w.rewatchNumber)).font(.caption).foregroundStyle(.secondary)
                        if let r = w.ratingOutOfFive {
                            Text(String(format: "%.1f", r) + " / 5").font(.caption).foregroundStyle(.yellow)
                        }
                        if !w.notes.isEmpty { Text(w.notes).font(.caption).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func financialsCard(_ e: MovieEdition) -> some View {
        let txs = store.relatedTransactions(for: e)
        InfoCard(title: "Financials") {
            InfoRow(title: "Total Spend", value: currencyString(txs.filter { $0.type == .purchase || $0.type == .tradeIn }.reduce(0) { $0 + $1.amount }))
            InfoRow(title: "Total Sales", value: currencyString(txs.filter { $0.type == .sale || $0.type == .refund || $0.type == .tradeOut }.reduce(0) { $0 + $1.amount }))
            InfoRow(title: "Latest Paid", value: e.lastPaidPrice.map(currencyString) ?? "None")
            InfoRow(title: "Est. Value",  value: currencyString(e.effectiveValue))
            ForEach(txs) { tx in
                VStack(alignment: .leading, spacing: 4) {
                    Text(tx.type.rawValue + " - " + currencyString(tx.amount)).foregroundStyle(.white)
                    Text(tx.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    if !tx.retailerOrBuyer.isEmpty { Text(tx.retailerOrBuyer).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func marketCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Market Value") {
            let m = e.marketStats
            InfoRow(title: "Lowest Sold",  value: m?.lowestSold.map(currencyString) ?? "None")
            InfoRow(title: "Highest Sold", value: m?.highestSold.map(currencyString) ?? "None")
            InfoRow(title: "Median Sold",  value: m?.medianSold.map(currencyString) ?? "None")
            InfoRow(title: "Sample Size",  value: m.map { String($0.sampleSize) } ?? "None")
            InfoRow(title: "Source",       value: m?.source ?? "None")
            Button("Search eBay Sold") {
                if let url = CollectorURLBuilder.ebaySoldSearchURL(for: e) { openURL(url) }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func loansCard(_ e: MovieEdition) -> some View {
        let loans = store.relatedLoanRecords(for: e)
        if !loans.isEmpty || e.isLoanedOut {
            InfoCard(title: "Loans") {
                if loans.isEmpty {
                    Text("Marked as loaned out but no loan record yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(loans) { loan in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(loan.friendName).foregroundStyle(.white)
                                Spacer()
                                LoanStatusPill(loan: loan)
                            }
                            Text("Loaned: " + loan.dateLoaned.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            if let due = loan.dueDate {
                                Text("Due: " + due.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(loan.isOverdue ? .red : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func boxSetCard(_ e: MovieEdition) -> some View {
        let children = store.editions.filter { $0.parentBoxSetID == e.id }
        if e.isBoxSet || e.parentBoxSetID != nil || !children.isEmpty {
            InfoCard(title: "Box Set") {
                if e.isBoxSet {
                    InfoRow(title: "Children", value: String(children.count))
                    InfoRow(title: "Child Value", value: currencyString(children.reduce(0) { $0 + $1.effectiveValue }))
                    ForEach(children) { child in
                        NavigationLink(destination: ItemDetailView(editionID: child.id).environmentObject(store)) {
                            HStack {
                                Text(child.title).foregroundStyle(.white)
                                Spacer()
                                Text(child.editionTitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if let parentID = e.parentBoxSetID, let parent = store.editionByID[parentID] {
                    Text("Part of box set:").foregroundStyle(.secondary)
                    NavigationLink(destination: ItemDetailView(editionID: parent.id).environmentObject(store)) {
                        Text(parent.title + " - " + parent.editionTitle)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func upgradeCard(_ e: MovieEdition) -> some View {
        let dups = store.titleYearDuplicates(title: e.title, year: e.year, excluding: e.id)
        InfoCard(title: "Upgrade Intelligence") {
            BoolRow(title: "Upgrade Candidate", value: e.isUpgradeCandidate)
            InfoRow(title: "Disposition", value: e.duplicateDisposition.rawValue)
            if !dups.isEmpty {
                Text("Other editions of this film:").foregroundStyle(.secondary).font(.caption)
                ForEach(dups) { dup in
                    Text(dup.editionTitle + " - " + dup.format.rawValue).foregroundStyle(.white).font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func tagsCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Tags") {
            if !e.customTags.isEmpty {
                Text("Custom Tags").font(.caption.bold()).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(e.customTags, id: \.self) { SpecChip(title: $0, tint: .purple) } }
                }
            }
            if !e.tags.isEmpty {
                Text("Tags").font(.caption.bold()).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(e.tags, id: \.self) { SpecChip(title: $0, tint: .blue) } }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func notesCard(_ e: MovieEdition) -> some View {
        InfoCard(title: "Notes") {
            Text(e.collectorNotes.isEmpty ? "No collector notes yet." : e.collectorNotes)
                .foregroundStyle(e.collectorNotes.isEmpty ? .secondary : .white)
        }
        .padding(.horizontal)
    }
}

// MARK: - Watch Event Entry

struct WatchEventEntryView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let edition: MovieEdition
    @State private var watchedOn = Date()
    @State private var context: WatchContext = .homeDisc
    @State private var rating = ""
    @State private var notes  = ""
    @State private var rewatchNumber = 1

    var body: some View {
        Form {
            Section("Log Watch for " + edition.title) {
                DatePicker("Watched On", selection: $watchedOn, displayedComponents: [.date, .hourAndMinute])
                Picker("Context", selection: $context) {
                    ForEach(WatchContext.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Rating out of 5", text: $rating).keyboardType(.decimalPad)
                Stepper("Rewatch " + String(rewatchNumber), value: $rewatchNumber, in: 1...50)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Log Watch")
        .toolbar {
            ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    store.addWatchEvent(WatchEvent(
                        editionID: edition.id, filmKey: edition.filmKey,
                        watchedOn: watchedOn, sourceType: context.mappedSourceType,
                        ratingOutOfFive: Double(rating), notes: notes, rewatchNumber: rewatchNumber
                    ))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Transaction Entry

struct TransactionEntryView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let edition: MovieEdition
    @State private var type: TransactionType = .purchase
    @State private var amount = ""
    @State private var retailerOrBuyer = ""
    @State private var date  = Date()
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Transaction for " + edition.title) {
                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                TextField(type == .purchase ? "Retailer" : "Buyer", text: $retailerOrBuyer)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Transaction")
        .toolbar {
            ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    store.addTransaction(Transaction(
                        editionID: edition.id, filmKey: edition.filmKey,
                        type: type, amount: Double(amount) ?? 0,
                        retailerOrBuyer: retailerOrBuyer, date: date, notes: notes
                    ))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Market Value Editor

struct MarketValueEditorView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let edition: MovieEdition
    @State private var lowest  = ""; @State private var highest = ""
    @State private var median  = ""; @State private var average = ""
    @State private var samples = ""; @State private var source  = "Manual"
    @State private var currency = "USD"

    var body: some View {
        Form {
            Section("Market Stats") {
                TextField("Lowest Sold",  text: $lowest).keyboardType(.decimalPad)
                TextField("Highest Sold", text: $highest).keyboardType(.decimalPad)
                TextField("Median Sold",  text: $median).keyboardType(.decimalPad)
                TextField("Average Sold", text: $average).keyboardType(.decimalPad)
                TextField("Sample Size",  text: $samples).keyboardType(.numberPad)
                TextField("Source",       text: $source)
                TextField("Currency",     text: $currency)
            }
            Section {
                Button("Search eBay Sold") {
                    if let url = CollectorURLBuilder.ebaySoldSearchURL(for: edition) { openURL(url) }
                }
            }
        }
        .navigationTitle("Market Stats")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    let stats = MarketPriceStats(
                        id: edition.marketStats?.id ?? UUID(),
                        lastUpdated: Date(), currency: currency.isEmpty ? "USD" : currency,
                        lowestSold: Double(lowest), highestSold: Double(highest),
                        medianSold: Double(median), averageSold: Double(average),
                        sampleSize: Int(samples) ?? 0, source: source
                    )
                    store.updateMarketStats(for: edition.id, stats: stats)
                    dismiss()
                }
            }
        }
        .onAppear {
            lowest   = edition.marketStats?.lowestSold.map(String.init)  ?? ""
            highest  = edition.marketStats?.highestSold.map(String.init) ?? ""
            median   = edition.marketStats?.medianSold.map(String.init)  ?? ""
            average  = edition.marketStats?.averageSold.map(String.init) ?? ""
            samples  = edition.marketStats.map { String($0.sampleSize) } ?? ""
            source   = edition.marketStats?.source ?? "Manual"
            currency = edition.marketStats?.currency ?? "USD"
        }
    }
}

// MARK: - Loan Sheet

struct QuickLoanSheet: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let edition: MovieEdition
    @State private var friendName = ""
    @State private var loanedDate = Date()
    @State private var hasDueDate = true
    @State private var dueDate    = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var notes      = ""

    var body: some View {
        Form {
            Section("Loan: " + edition.title) {
                TextField("Friend Name", text: $friendName)
                DatePicker("Loaned Date", selection: $loanedDate, displayedComponents: .date)
                Toggle("Has Due Date", isOn: $hasDueDate)
                if hasDueDate { DatePicker("Due Date", selection: $dueDate, displayedComponents: .date) }
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Loan Out")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    store.addOrUpdateLoan(for: edition, friendName: friendName,
                        loanedDate: loanedDate, dueDate: hasDueDate ? dueDate : nil, notes: notes)
                    dismiss()
                }
                .disabled(friendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let loan = store.activeLoan(for: edition.id) {
                friendName = loan.friendName; loanedDate = loan.dateLoaned
                hasDueDate = loan.dueDate != nil; dueDate = loan.dueDate ?? dueDate; notes = loan.notes
            }
        }
    }
}

// MARK: - Location Sheet

struct QuickLocationSheet: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let edition: MovieEdition

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        Button {
                            store.moveEdition(edition.id, to: nil)
                            dismiss()
                        } label: {
                            HStack {
                                Text("Unassigned").foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        ForEach(store.storageLocations) { location in
                            Button {
                                store.moveEdition(edition.id, to: location.id)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(location.name).foregroundStyle(.white)
                                        if !location.displayName.isEmpty {
                                            Text(location.displayName).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Move Location")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}

// MARK: - Edit Edition

struct EditEditionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VaultStore
    @AppStorage("cv.tmdbBearerToken") private var tmdbToken = ""

    let mode: EditModePayload
    let onSave: (MovieEdition) -> Void

    @State private var title = ""; @State private var originalTitle = ""
    @State private var year  = Calendar.current.component(.year, from: Date())
    @State private var editionTitle = ""; @State private var format: FormatType = .bluRay
    @State private var editionType: EditionType    = .standard
    @State private var collectionStatus: CollectionStatus = .owned
    @State private var openWatchStatus: OpenWatchStatus   = .sealed
    @State private var watchStatus: WatchStatus           = .unwatched
    @State private var condition: ConditionRating         = .mint
    @State private var label = ""; @State private var labelID: UUID?
    @State private var studio = ""; @State private var regionCode = ""; @State private var barcode = ""
    @State private var isBlindBuy = false; @State private var isFavorite = false
    @State private var hasDamage  = false; @State private var damageNotes = ""
    @State private var coverSystemImage = "film"; @State private var accentHex = "#246BFF"
    @State private var selectedPhoto: PhotosPickerItem?; @State private var localImageData: Data?
    @State private var hasIMAXScenes = false; @State private var hasDolbyVision = false
    @State private var hasHDR10 = false; @State private var hasHDR10Plus = false
    @State private var hasDolbyAtmos = false; @State private var hasDolbyAudio = false; @State private var hasDTSX = false
    @State private var videoNotes = ""; @State private var audioNotes = ""
    @State private var lowestPriceText = ""; @State private var purchasePriceText = ""
    @State private var estimatedValueText = ""; @State private var targetPriceText = ""
    @State private var retailerLinks: [RetailerLink] = []
    @State private var wishlistPriceHistory: [PricePoint] = []
    @State private var pricePaidHistory: [PricePoint] = []
    @State private var isUpgradeCandidate = false
    @State private var duplicateDisposition: DuplicateDisposition = .keep
    @State private var wishlistPriority: WishlistPriority = .medium
    @State private var purchaseUrgency: PurchaseUrgency   = .keepAnEyeOnIt
    @State private var reasonWanted = ""; @State private var isLimitedPressing = false
    @State private var oopRiskLevel: OOPRiskLevel = .none
    @State private var hasExpectedRelease = false; @State private var expectedRelease = Date()
    @State private var customTagsText = ""; @State private var tagsText = ""
    @State private var franchiseName  = ""; @State private var boxSetName = ""
    @State private var isBoxSet = false; @State private var parentBoxSetID: UUID?
    @State private var isLoanedOut = false; @State private var loanedTo = ""
    @State private var loanNotes   = ""; @State private var cutName = ""
    @State private var hasCommentary = false; @State private var commentaryDetails = ""
    @State private var specialFeatures = ""; @State private var discs: [DiscInfo] = []
    @State private var storageLocationID: UUID?
    @State private var hasAcquiredDate = false; @State private var acquiredDate = Date()
    @State private var collectorNotes  = ""
    @State private var autoBuild = true
    @State private var importState: BarcodeImportState = .idle
    @State private var confirmDupSave = false

    private var existingEdition: MovieEdition? {
        if case .edit(let e) = mode { return e }
        return nil
    }
    private var dupBarcodes: [MovieEdition] { store.barcodeDuplicates(for: barcode, excluding: existingEdition?.id) }
    private var dupTitles: [MovieEdition] { store.titleYearDuplicates(title: title, year: year, excluding: existingEdition?.id) }
    private var titleIsEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            if titleIsEmpty {
                Section("Validation") { Text("Title is required.").foregroundStyle(.red) }
            }
            if !dupBarcodes.isEmpty || !dupTitles.isEmpty {
                Section("Duplicate Warning") {
                    if !dupBarcodes.isEmpty { Text("This barcode already exists.").foregroundStyle(.orange) }
                    if !dupTitles.isEmpty   { Text("This title and year already exist.").foregroundStyle(.orange) }
                }
            }
            if case .loading(let msg) = importState {
                Section("Lookup") { HStack { ProgressView(); Text(msg) } }
            }
            if case .failed(let msg) = importState {
                Section("Lookup") { Text(msg).foregroundStyle(.red) }
            }
            if case .noMatch(let msg) = importState {
                Section("Lookup") { Text(msg).foregroundStyle(.orange) }
            }
            Section("Basic") {
                TextField("Title", text: $title)
                TextField("Original Title", text: $originalTitle)
                Stepper("Year: " + String(year), value: $year, in: 1880...2100)
                Toggle("Auto-build edition title", isOn: $autoBuild)
                TextField("Edition Title", text: $editionTitle)
            }
            Section("Barcode / Lookup") {
                TextField("Barcode", text: $barcode).keyboardType(.numberPad)
                Button("Lookup Barcode") { Task { await lookupBarcode() } }.disabled(barcode.isEmpty)
                Button("Search TMDb by Title") { Task { await lookupTMDb() } }.disabled(titleIsEmpty)
            }
            Section("Format") {
                Picker("Format", selection: $format) {
                    ForEach(FormatType.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: format) { _ in
                    if autoBuild { editionTitle = buildEditionTitle(format: format, editionType: editionType) }
                }
                Picker("Edition Type", selection: $editionType) {
                    ForEach(EditionType.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: editionType) { _ in
                    if autoBuild { editionTitle = buildEditionTitle(format: format, editionType: editionType) }
                }
                Picker("Status", selection: $collectionStatus) {
                    ForEach(CollectionStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Open Status", selection: $openWatchStatus) {
                    ForEach(OpenWatchStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Watch Status", selection: $watchStatus) {
                    ForEach(WatchStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Condition", selection: $condition) {
                    ForEach(ConditionRating.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Label") {
                Picker("Label", selection: $labelID) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.labels) { Text($0.fullName).tag(Optional($0.id)) }
                }
                .onChange(of: labelID) { id in
                    if let id, let found = store.labels.first(where: { $0.id == id }) { label = found.fullName }
                }
                TextField("Label (free text)", text: $label)
                TextField("Studio", text: $studio)
                TextField("Region Code", text: $regionCode)
            }
            Section("Collector Flags") {
                Toggle("Blind Buy",         isOn: $isBlindBuy)
                Toggle("Favorite",          isOn: $isFavorite)
                Toggle("Has Damage",        isOn: $hasDamage)
                if hasDamage { TextField("Damage Notes", text: $damageNotes) }
                Toggle("Upgrade Candidate", isOn: $isUpgradeCandidate)
                Picker("Duplicate Disposition", selection: $duplicateDisposition) {
                    ForEach(DuplicateDisposition.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Wishlist Intelligence") {
                Picker("Priority", selection: $wishlistPriority) {
                    ForEach(WishlistPriority.allCases) { Text($0.title).tag($0) }
                }
                Picker("Urgency", selection: $purchaseUrgency) {
                    ForEach(PurchaseUrgency.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Limited Pressing", isOn: $isLimitedPressing)
                Picker("OOP Risk", selection: $oopRiskLevel) {
                    ForEach(OOPRiskLevel.allCases) { Text($0.title).tag($0) }
                }
                TextField("Why You Want It", text: $reasonWanted, axis: .vertical)
                TextField("Target Price", text: $targetPriceText).keyboardType(.decimalPad)
                Toggle("Has Expected Release Date", isOn: $hasExpectedRelease)
                if hasExpectedRelease {
                    DatePicker("Release Date", selection: $expectedRelease, displayedComponents: .date)
                }
            }
            Section("Disc Specs") {
                Toggle("IMAX Scenes",  isOn: $hasIMAXScenes)
                Toggle("Dolby Vision", isOn: $hasDolbyVision)
                Toggle("HDR10",        isOn: $hasHDR10)
                Toggle("HDR10+",       isOn: $hasHDR10Plus)
                Toggle("Dolby Atmos",  isOn: $hasDolbyAtmos)
                Toggle("Dolby Audio",  isOn: $hasDolbyAudio)
                Toggle("DTS:X",        isOn: $hasDTSX)
                TextField("Video Notes", text: $videoNotes)
                TextField("Audio Notes", text: $audioNotes)
            }
            Section("Money") {
                TextField("Lowest Known Price", text: $lowestPriceText).keyboardType(.decimalPad)
                TextField("Purchase Price",     text: $purchasePriceText).keyboardType(.decimalPad)
                TextField("Estimated Value",    text: $estimatedValueText).keyboardType(.decimalPad)
            }
            Section("Tags") {
                TextField("Custom Tags (comma separated)", text: $customTagsText)
                TextField("Tags (comma separated)", text: $tagsText)
                TextField("Franchise Name", text: $franchiseName)
                Toggle("Is Box Set", isOn: $isBoxSet)
                TextField("Box Set Name", text: $boxSetName)
                Picker("Parent Box Set", selection: $parentBoxSetID) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.editions.filter { $0.isBoxSet && $0.id != existingEdition?.id }) { e in
                        Text(e.title).tag(Optional(e.id))
                    }
                }
            }
            Section("Location") {
                Picker("Storage Location", selection: $storageLocationID) {
                    Text("Unassigned").tag(UUID?.none)
                    ForEach(store.storageLocations) { Text($0.name).tag(Optional($0.id)) }
                }
                Toggle("Loaned Out", isOn: $isLoanedOut)
                if isLoanedOut { TextField("Loaned To", text: $loanedTo); TextField("Loan Notes", text: $loanNotes) }
            }
            Section("Content") {
                TextField("Cut Name",         text: $cutName)
                Toggle("Has Commentary",      isOn: $hasCommentary)
                if hasCommentary { TextField("Commentary Details", text: $commentaryDetails) }
                TextField("Special Features", text: $specialFeatures)
            }
            Section("Artwork") {
                PhotosPicker("Choose Cover Image", selection: $selectedPhoto, matching: .images)
                TextField("Fallback Symbol (SF Symbols)", text: $coverSystemImage)
                TextField("Accent Hex (#RRGGBB)", text: $accentHex)
            }
            Section("Notes") {
                Toggle("Has Acquired Date", isOn: $hasAcquiredDate)
                if hasAcquiredDate {
                    DatePicker("Acquired Date", selection: $acquiredDate, displayedComponents: .date)
                }
                TextField("Collector Notes", text: $collectorNotes, axis: .vertical)
            }
        }
        .navigationTitle(navTitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if !dupBarcodes.isEmpty || !dupTitles.isEmpty {
                        confirmDupSave = true
                    } else { performSave() }
                }
                .disabled(titleIsEmpty)
            }
        }
        .alert("Possible Duplicate", isPresented: $confirmDupSave) {
            Button("Cancel", role: .cancel) {}
            Button("Save Anyway") { performSave() }
        } message: { Text("This looks similar to an existing item.") }
        .onAppear { populateFromMode() }
        .onChange(of: selectedPhoto) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { localImageData = data }
            }
        }
    }

    private var navTitle: String {
        switch mode {
        case .add:               return "Add Edition"
        case .edit:              return "Edit Edition"
        case .addAnotherEdition: return "Add Another Edition"
        }
    }

    private func performSave() {
        var imageID: String? = existingEdition?.coverImageID
        if let data = localImageData {
            let base = imageID?.replacingOccurrences(of: ".jpg", with: "") ?? UUID().uuidString
            imageID = ImageStore.shared.save(data, id: base)
        }
        let edition = MovieEdition(
            id: existingEdition?.id ?? UUID(),
            title: title, originalTitle: originalTitle.isEmpty ? title : originalTitle,
            year: year,
            editionTitle: editionTitle.isEmpty ? buildEditionTitle(format: format, editionType: editionType) : editionTitle,
            format: format, editionType: editionType, collectionStatus: collectionStatus,
            openWatchStatus: openWatchStatus, watchStatus: watchStatus, condition: condition,
            label: label, labelID: labelID, studio: studio, regionCode: regionCode, barcode: barcode,
            isBlindBuy: isBlindBuy, isFavorite: isFavorite, hasDamage: hasDamage, damageNotes: damageNotes,
            coverSystemImage: coverSystemImage.isEmpty ? "film" : coverSystemImage,
            accentHex: isValidHexColor(accentHex) ? accentHex : "#246BFF",
            coverImageID: imageID, remotePosterPath: nil,
            hasIMAXScenes: hasIMAXScenes, hasDolbyVision: hasDolbyVision, hasHDR10: hasHDR10,
            hasHDR10Plus: hasHDR10Plus, hasDolbyAtmos: hasDolbyAtmos, hasDolbyAudio: hasDolbyAudio, hasDTSX: hasDTSX,
            videoNotes: videoNotes, audioNotes: audioNotes,
            lowestKnownPrice: Double(lowestPriceText), purchasePrice: Double(purchasePriceText),
            estimatedValue: Double(estimatedValueText), marketStats: existingEdition?.marketStats,
            pricePaidHistory: pricePaidHistory, retailerLinks: retailerLinks,
            wishlistPriceHistory: wishlistPriceHistory,
            isUpgradeCandidate: isUpgradeCandidate, duplicateDisposition: duplicateDisposition,
            wishlistTargetPrice: Double(targetPriceText),
            expectedReleaseDate: hasExpectedRelease ? expectedRelease : nil,
            wishlistPriority: wishlistPriority, purchaseUrgency: purchaseUrgency,
            reasonWanted: reasonWanted, isLimitedPressing: isLimitedPressing, oopRiskLevel: oopRiskLevel,
            customTags: parseTags(from: customTagsText), tags: parseTags(from: tagsText),
            franchiseName: franchiseName, boxSetName: boxSetName, isBoxSet: isBoxSet, parentBoxSetID: parentBoxSetID,
            isLoanedOut: isLoanedOut, loanedTo: loanedTo,
            loanedDate: existingEdition?.loanedDate, dueDate: existingEdition?.dueDate, loanNotes: loanNotes,
            cutName: cutName, hasCommentary: hasCommentary, commentaryDetails: commentaryDetails,
            specialFeatures: specialFeatures, discs: discs, storageLocationID: storageLocationID,
            acquiredDate: hasAcquiredDate ? acquiredDate : nil,
            dateCreated: existingEdition?.dateCreated ?? Date(),
            dateModified: Date(), collectorNotes: collectorNotes,
            timesWatched: existingEdition?.timesWatched ?? 0,
            lastWatchedDate: existingEdition?.lastWatchedDate
        )
        onSave(edition)
        dismiss()
    }

    private func populateFromMode() {
        switch mode {
        case .add(let seed):
            if let seed { barcode = seed }
            editionTitle = buildEditionTitle(format: format, editionType: editionType)
        case .edit(let e):         hydrate(from: e)
        case .addAnotherEdition(let e): hydrate(from: store.templateForAnotherEdition(from: e))
        }
    }

    private func hydrate(from e: MovieEdition) {
        title = e.title; originalTitle = e.originalTitle; year = e.year; editionTitle = e.editionTitle
        format = e.format; editionType = e.editionType; collectionStatus = e.collectionStatus
        openWatchStatus = e.openWatchStatus; watchStatus = e.watchStatus; condition = e.condition
        label = e.label; labelID = e.labelID; studio = e.studio; regionCode = e.regionCode; barcode = e.barcode
        isBlindBuy = e.isBlindBuy; isFavorite = e.isFavorite; hasDamage = e.hasDamage; damageNotes = e.damageNotes
        coverSystemImage = e.coverSystemImage; accentHex = e.accentHex
        hasIMAXScenes = e.hasIMAXScenes; hasDolbyVision = e.hasDolbyVision; hasHDR10 = e.hasHDR10
        hasHDR10Plus = e.hasHDR10Plus; hasDolbyAtmos = e.hasDolbyAtmos; hasDolbyAudio = e.hasDolbyAudio; hasDTSX = e.hasDTSX
        videoNotes = e.videoNotes; audioNotes = e.audioNotes
        lowestPriceText    = e.lowestKnownPrice.map(String.init) ?? ""
        purchasePriceText  = e.purchasePrice.map(String.init) ?? ""
        estimatedValueText = e.estimatedValue.map(String.init) ?? ""
        targetPriceText    = e.wishlistTargetPrice.map(String.init) ?? ""
        pricePaidHistory = e.pricePaidHistory; retailerLinks = e.retailerLinks; wishlistPriceHistory = e.wishlistPriceHistory
        isUpgradeCandidate = e.isUpgradeCandidate; duplicateDisposition = e.duplicateDisposition
        wishlistPriority = e.wishlistPriority; purchaseUrgency = e.purchaseUrgency
        reasonWanted = e.reasonWanted; isLimitedPressing = e.isLimitedPressing; oopRiskLevel = e.oopRiskLevel
        hasExpectedRelease = e.expectedReleaseDate != nil; expectedRelease = e.expectedReleaseDate ?? Date()
        customTagsText = joinTags(e.customTags); tagsText = joinTags(e.tags)
        franchiseName = e.franchiseName; boxSetName = e.boxSetName; isBoxSet = e.isBoxSet; parentBoxSetID = e.parentBoxSetID
        isLoanedOut = e.isLoanedOut; loanedTo = e.loanedTo; loanNotes = e.loanNotes
        cutName = e.cutName; hasCommentary = e.hasCommentary; commentaryDetails = e.commentaryDetails
        specialFeatures = e.specialFeatures; discs = e.discs; storageLocationID = e.storageLocationID
        hasAcquiredDate = e.acquiredDate != nil; acquiredDate = e.acquiredDate ?? Date()
        collectorNotes = e.collectorNotes
    }

    private func lookupBarcode() async {
        let cleaned = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if let cached = BarcodeService.shared.cached(barcode: cleaned) {
            applySeed(cached); importState = .imported(cached)
            store.logBarcodeLookup(barcode: cleaned, title: cached.title, source: "Cache", success: true)
            return
        }
        importState = .loading("Looking up barcode...")
        do {
            if let seed = try await BarcodeService.shared.lookup(barcode: cleaned) {
                BarcodeService.shared.cache(seed, for: cleaned)
                applySeed(seed); importState = .imported(seed)
                store.logBarcodeLookup(barcode: cleaned, title: seed.title, source: seed.sourceName, success: true)
            } else {
                importState = .noMatch("No barcode match found.")
            }
        } catch {
            importState = .failed(error.localizedDescription)
        }
    }

    private func lookupTMDb() async {
        importState = .loading("Searching TMDb...")
        do {
            let seeds = try await TMDbService.searchMovieSeeds(title: title, year: year, barcode: barcode, token: tmdbToken)
            if let first = seeds.first { applySeed(first); importState = .imported(first) }
            else { importState = .noMatch("TMDb returned no results.") }
        } catch {
            importState = .failed(error.localizedDescription)
        }
    }

    private func applySeed(_ seed: ImportedEditionSeed) {
        title = seed.title; originalTitle = seed.originalTitle
        if let y = seed.year { year = y }
        if let f = seed.format { format = f }
        if let e = seed.editionType { editionType = e }
        editionTitle = seed.editionTitle.isEmpty ? buildEditionTitle(format: format, editionType: editionType) : seed.editionTitle
        label = seed.label; studio = seed.studio; regionCode = seed.regionCode
        barcode = seed.barcode; coverSystemImage = seed.coverSystemImage; accentHex = seed.accentHex
    }
}

// MARK: - Barcode Scanner

protocol BarcodeScannerDelegate: AnyObject {
    func scannerDidFind(code: String)
    func scannerDidFail(with error: Error)
}

final class BarcodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerDelegate?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            delegate?.scannerDidFail(with: NSError(domain: "Scanner", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Camera unavailable"])); return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer); preview = layer
    }

    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); preview?.frame = view.bounds }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
    }

    func setTorch(_ on: Bool) {
        guard let d = AVCaptureDevice.default(for: .video), d.hasTorch else { return }
        try? d.lockForConfiguration()
        d.torchMode = on ? .on : .off
        d.unlockForConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject, let code = obj.stringValue else { return }
        delegate?.scannerDidFind(code: code)
    }
}

struct BarcodeScannerUIView: UIViewControllerRepresentable {
    @Binding var torchOn: Bool
    let onFound: (String) -> Void; let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(torchOn: $torchOn, onFound: onFound, onError: onError) }
    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC(); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: BarcodeScannerVC, context: Context) { vc.setTorch(torchOn) }

    final class Coordinator: NSObject, BarcodeScannerDelegate {
        @Binding var torchOn: Bool
        let onFound: (String) -> Void; let onError: (Error) -> Void
        private var fired = false
        init(torchOn: Binding<Bool>, onFound: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
            _torchOn = torchOn; self.onFound = onFound; self.onError = onError
        }
        func scannerDidFind(code: String) { guard !fired else { return }; fired = true; onFound(code) }
        func scannerDidFail(with error: Error) { onError(error) }
    }
}

struct BarcodeScannerSheet: View {
    let onFound: (String) -> Void; let onManualEntry: () -> Void; let onError: (Error) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var torchOn = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                BarcodeScannerUIView(torchOn: $torchOn, onFound: onFound, onError: onError)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Point camera at a barcode").font(.headline).foregroundStyle(.white)
                    HStack(spacing: 12) {
                        Button { torchOn.toggle() } label: {
                            Label(torchOn ? "Torch Off" : "Torch On",
                                systemImage: torchOn ? "flashlight.off.fill" : "flashlight.on.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        Button { onManualEntry() } label: {
                            Label("Manual Entry", systemImage: "keyboard")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .foregroundStyle(.white)
                }
                .padding()
                .background(LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom))
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}

// MARK: - Orders

struct OrdersHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var filter: OrderFilter = .all
    @State private var showingAdd   = false
    @State private var editingOrder: OrderItem?

    private var filtered: [OrderItem] {
        switch filter {
        case .all:       return store.orders
        case .preorder:  return store.orders.filter { $0.orderStatus == .preorder }
        case .ordered:   return store.orders.filter { $0.orderStatus == .ordered }
        case .shipped:   return store.orders.filter { $0.orderStatus == .shipped }
        case .delivered: return store.orders.filter { $0.orderStatus == .delivered }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        HStack(spacing: 12) {
                            ShelfStatCard(title: "Open Total", subtitle: "Uncommitted spend",
                                value: currencyString(filtered.filter { $0.orderStatus != .delivered && $0.orderStatus != .cancelled }.reduce(0) { $0 + $1.price }),
                                systemImage: "creditcard", tint: .orange)
                            ShelfStatCard(title: "This Month", subtitle: "Charge pressure",
                                value: currencyString(store.summary.preorderPressure),
                                systemImage: "calendar.badge.clock", tint: .yellow)
                        }
                        .padding(.horizontal)
                        NavigationLink(destination: ReleaseCalendarView().environmentObject(store)) {
                            ActionCardButton(title: "Release Calendar", subtitle: "See grouped release months and wallet damage.", systemImage: "calendar", tint: .orange, action: {})
                        }
                        .buttonStyle(.plain).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(OrderFilter.allCases) { f in
                                    FilterPill(title: f.rawValue, selected: filter == f) { filter = f }
                                }
                            }
                            .padding(.horizontal)
                        }
                        if filtered.isEmpty {
                            EmptyVaultCard(title: "No orders found", subtitle: "Nothing marching toward your mailbox.", symbol: "shippingbox").padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filtered) { order in
                                    OrderRowCard(order: order)
                                        .contextMenu {
                                            Button("Edit") { editingOrder = order }
                                            Button("Schedule Release Reminder") {
                                                Task { await ReminderService.scheduleReleaseReminder(for: order) }
                                            }
                                            Button("Schedule Charge Reminder") {
                                                Task { await ReminderService.scheduleChargeReminder(for: order) }
                                            }
                                            Button("Convert to Owned Edition") {
                                                store.convertOrderToOwnedEdition(order.id)
                                            }
                                            Button("Delete", role: .destructive) { store.deleteOrder(order) }
                                        }
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Orders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { OrderEditorView(existing: nil) { store.addOrder($0) }.environmentObject(store) }
            }
            .sheet(item: $editingOrder) { order in
                NavigationStack { OrderEditorView(existing: order) { store.updateOrder($0) }.environmentObject(store) }
            }
        }
    }
}

struct OrderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VaultStore
    let existing: OrderItem?
    let onSave: (OrderItem) -> Void
    @State private var title = ""; @State private var editionTitle = ""; @State private var retailer = ""
    @State private var status: OrderStatus = .preorder
    @State private var releaseDate = Date(); @State private var hasRelease = true
    @State private var chargeDate  = Date(); @State private var hasCharge  = true
    @State private var orderDate   = Date()
    @State private var tracking = ""; @State private var orderNumber = ""; @State private var notes = ""
    @State private var price = ""; @State private var accentHex = "#8156D8"; @State private var coverSymbol = "shippingbox"

    var body: some View {
        Form {
            Section("Order") {
                TextField("Title",        text: $title)
                TextField("Edition",      text: $editionTitle)
                TextField("Retailer",     text: $retailer)
                TextField("Order Number", text: $orderNumber)
                Picker("Status", selection: $status) {
                    ForEach(OrderStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                DatePicker("Order Date", selection: $orderDate, displayedComponents: .date)
                Toggle("Has Release Date", isOn: $hasRelease)
                if hasRelease { DatePicker("Release Date", selection: $releaseDate, displayedComponents: .date) }
                Toggle("Has Charge Date",  isOn: $hasCharge)
                if hasCharge  { DatePicker("Charge Date",  selection: $chargeDate,  displayedComponents: .date) }
                TextField("Price",    text: $price).keyboardType(.decimalPad)
                TextField("Tracking", text: $tracking)
                TextField("Notes",    text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(existing == nil ? "Add Order" : "Edit Order")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(OrderItem(
                        id: existing?.id ?? UUID(), title: title, editionTitle: editionTitle,
                        retailer: retailer, orderStatus: status,
                        releaseDate: hasRelease ? releaseDate : nil,
                        estimatedChargeDate: hasCharge ? chargeDate : nil,
                        orderDate: orderDate, trackingNumber: tracking, orderNumber: orderNumber,
                        notes: notes, price: Double(price) ?? 0,
                        accentHex: isValidHexColor(accentHex) ? accentHex : "#8156D8",
                        coverSystemImage: coverSymbol.isEmpty ? "shippingbox" : coverSymbol,
                        linkedEditionID: nil, lineItems: existing?.lineItems ?? []
                    ))
                    dismiss()
                }
                .disabled(title.isEmpty || retailer.isEmpty)
            }
        }
        .onAppear {
            guard let e = existing else { return }
            title = e.title; editionTitle = e.editionTitle; retailer = e.retailer; status = e.orderStatus
            hasRelease = e.releaseDate != nil; releaseDate = e.releaseDate ?? Date()
            hasCharge  = e.estimatedChargeDate != nil; chargeDate = e.estimatedChargeDate ?? Date()
            orderDate = e.orderDate; tracking = e.trackingNumber; orderNumber = e.orderNumber
            notes = e.notes; price = String(e.price); accentHex = e.accentHex; coverSymbol = e.coverSystemImage
        }
    }
}

struct ReleaseCalendarView: View {
    @EnvironmentObject private var store: VaultStore
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeader(title: "Release Calendar", countText: String(store.groupedReleaseMonths().count) + " month groups").padding(.top)
                    HStack(spacing: 12) {
                        ShelfStatCard(title: "This Month", subtitle: "Projected charges",
                            value: currencyString(store.summary.preorderPressure), systemImage: "calendar.badge.clock", tint: .orange)
                        ShelfStatCard(title: "Preorders", subtitle: "Releasing this month",
                            value: String(store.preorderThisMonthCount), systemImage: "shippingbox", tint: .yellow)
                    }
                    .padding(.horizontal)
                    if store.groupedReleaseMonths().isEmpty {
                        EmptyVaultCard(title: "No upcoming releases", subtitle: "Calendar is peaceful for now.", symbol: "calendar").padding(.horizontal)
                    } else {
                        ForEach(store.groupedReleaseMonths()) { group in
                            InfoCard(title: group.title) {
                                InfoRow(title: "Projected Total", value: currencyString(group.total))
                                ForEach(group.items) { OrderRowCard(order: $0) }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Release Calendar")
    }
}

// MARK: - Locations

struct LocationsHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var showingAdd   = false
    @State private var editingLoc: StorageLocation?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        SectionHeader(title: "Locations", countText: String(store.storageLocations.count) + " spaces").padding(.top)
                        if store.storageLocations.isEmpty {
                            EmptyVaultCard(title: "No locations yet", subtitle: "Add a shelf, room, or bin.", symbol: "square.grid.3x3.fill").padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.storageLocations) { loc in
                                    NavigationLink(destination: LocationDetailView(locationID: loc.id).environmentObject(store)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(loc.name).font(.headline).foregroundStyle(.white)
                                                    if !loc.displayName.isEmpty {
                                                        Text(loc.displayName).font(.caption).foregroundStyle(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                SectionBadge(title: String(store.editionsForLocation(loc.id).count) + " items", tint: .blue)
                                            }
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { Button("Edit") { editingLoc = loc } }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { LocationEditorView { store.addLocation($0) } }
            }
            .sheet(item: $editingLoc) { loc in
                NavigationStack { LocationEditorView(existing: loc) { store.updateLocation($0) } }
            }
        }
    }
}

struct LocationDetailView: View {
    @EnvironmentObject private var store: VaultStore
    let locationID: UUID
    private var location: StorageLocation? { store.storageLocations.first { $0.id == locationID } }
    private var editions: [MovieEdition] { store.editionsForLocation(locationID) }

    var body: some View {
        ZStack {
            AppBackground()
            if let location {
                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ShelfStatCard(title: "Items",   subtitle: "Stored here", value: String(editions.count), systemImage: "shippingbox", tint: .blue)
                            ShelfStatCard(title: "Backlog", subtitle: "Unwatched",
                                value: String(editions.filter { $0.watchStatus == .unwatched && $0.collectionStatus == .owned }.count),
                                systemImage: "clock", tint: .orange)
                        }
                        .padding(.horizontal)
                        ShelfStatCard(title: "Estimated Value", subtitle: "Combined",
                            value: currencyString(editions.reduce(0) { $0 + $1.effectiveValue }),
                            systemImage: "banknote", tint: .green).padding(.horizontal)
                        if editions.isEmpty {
                            EmptyVaultCard(title: "Empty shelf", subtitle: "Move some discs here.", symbol: "shippingbox").padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(editions) { edition in
                                    NavigationLink(destination: ItemDetailView(editionID: edition.id).environmentObject(store)) {
                                        EditionRowCard(edition: edition)
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle(location.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Location not found").foregroundStyle(.white)
            }
        }
    }
}

struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: StorageLocation?
    let onSave: (StorageLocation) -> Void
    @State private var name = ""; @State private var room = ""
    @State private var shelf = ""; @State private var bin = ""; @State private var notes = ""

    init(existing: StorageLocation? = nil, onSave: @escaping (StorageLocation) -> Void) {
        self.existing = existing; self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Location") {
                TextField("Name",    text: $name)
                TextField("Room",    text: $room)
                TextField("Shelf",   text: $shelf)
                TextField("Bin/Box", text: $bin)
                TextField("Notes",   text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(existing == nil ? "Add Location" : "Edit Location")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(StorageLocation(id: existing?.id ?? UUID(), name: name, room: room, shelf: shelf, bin: bin, notes: notes))
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard let e = existing else { return }
            name = e.name; room = e.room; shelf = e.shelf; bin = e.bin; notes = e.notes
        }
    }
}

// MARK: - Loans

struct LoansHomeView: View {
    @EnvironmentObject private var store: VaultStore
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        SectionHeader(title: "Loans", countText: String(store.activeLoans.count) + " active").padding(.top)
                        if !store.overdueLoans.isEmpty {
                            InfoCard(title: "Overdue") {
                                ForEach(store.overdueLoans) { loan in
                                    HStack {
                                        Text(store.edition(for: loan)?.title ?? "Unknown").foregroundStyle(.white)
                                        Spacer()
                                        LoanStatusPill(loan: loan)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        if store.activeLoans.isEmpty {
                            EmptyVaultCard(title: "No active loans", subtitle: "Nobody gets to touch the shelf right now.", symbol: "arrowshape.turn.up.right.fill").padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.activeLoans) { loan in
                                    loanCard(loan)
                                        .contextMenu { Button("Mark Returned") { store.markLoanReturned(loan.id) } }
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Loans")
        }
    }

    private func loanCard(_ loan: LoanRecord) -> some View {
        let edition = store.edition(for: loan)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [(Color(hex: edition?.accentHex ?? "#246BFF") ?? .blue).opacity(0.88), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 84)
                .overlay(Image(systemName: edition?.coverSystemImage ?? "film").foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 6) {
                Text(edition?.title ?? "Unknown").font(.headline).foregroundStyle(.white)
                Text("Loaned to " + loan.friendName).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    LoanStatusPill(loan: loan)
                    if let due = loan.dueDate {
                        SectionBadge(title: due.formatted(date: .abbreviated, time: .omitted), tint: loan.isOverdue ? .red : .orange)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Profile

struct ProfileHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage("cv.tmdbBearerToken") private var tmdbToken = ""
    @State private var cloudSync = UserDefaults.standard.bool(forKey: "cv.cloudSyncEnabled")
    @State private var exportDoc    = JSONVaultDocument()
    @State private var csvDoc       = CSVTextDocument()
    @State private var showExporter = false; @State private var showImporter  = false
    @State private var showCSVExport = false; @State private var showCSVImport = false
    @State private var wishlistOnly  = false
    @State private var pending: [MovieEdition] = []
    @State private var showConflict  = false
    @State private var importMessage = ""
    @State private var confirmReset  = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        quickLinks
                        apiSection
                        barcodeHistorySection
                        if !importMessage.isEmpty {
                            Text(importMessage).padding().frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal)
                        }
                        actionsSection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profile")
            .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .json, defaultFilename: "collector-vault-backup") { _ in }
            .fileExporter(isPresented: $showCSVExport, document: csvDoc, contentType: .commaSeparatedText, defaultFilename: wishlistOnly ? "cv-wishlist" : "cv-collection") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        importMessage = store.importBackupData(data) ? "Vault backup imported." : "Import failed."
                    }
                }
            }
            .fileImporter(isPresented: $showCSVImport, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                if case .success(let url) = result {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                        pending = CSVVault.importCSV(text)
                        if pending.isEmpty { importMessage = "CSV had no valid rows." } else { showConflict = true }
                    }
                }
            }
            .confirmationDialog("CSV Import - " + String(pending.count) + " rows", isPresented: $showConflict, titleVisibility: .visible) {
                ForEach(ImportDuplicateMode.allCases) { mode in
                    Button(mode.rawValue) {
                        let count = store.applyImportedEditions(pending, mode: mode)
                        importMessage = "CSV imported " + String(count) + " items."
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Reset Sample Data?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { store.resetAllSampleData() }
            } message: { Text("This replaces all current data with sample content.") }
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Access", countText: "Utility hub")
            VStack(spacing: 12) {
                NavigationLink(destination: LocationsHomeView().environmentObject(store)) {
                    ActionCardButton(title: "Locations", subtitle: "Manage shelves, bins, and rooms.", systemImage: "square.grid.3x3.fill", tint: .blue, action: {})
                }.buttonStyle(.plain)
                NavigationLink(destination: LoansHomeView().environmentObject(store)) {
                    ActionCardButton(title: "Loans",
                        subtitle: store.overdueLoans.isEmpty ? "Track loans and returns." : String(store.overdueLoans.count) + " overdue items.",
                        systemImage: "arrowshape.turn.up.right.fill",
                        tint: store.overdueLoans.isEmpty ? .cyan : .red, action: {})
                }.buttonStyle(.plain)
                NavigationLink(destination: SmartCollectionsHomeView().environmentObject(store)) {
                    ActionCardButton(title: "Smart Collections", subtitle: "Blind buys, buy-now, upgrade targets.", systemImage: "sparkles.rectangle.stack", tint: .purple, action: {})
                }.buttonStyle(.plain)
                NavigationLink(destination: DashboardEditorView().environmentObject(store)) {
                    ActionCardButton(title: "Dashboard Editor", subtitle: "Pin and reorder your metrics.", systemImage: "slider.horizontal.3", tint: .yellow, action: {})
                }.buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    private var apiSection: some View {
        InfoCard(title: "API and Settings") {
            TextField("TMDb Bearer Token", text: $tmdbToken)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Toggle("Enable CloudKit Sync", isOn: Binding(
                get: { cloudSync },
                set: { cloudSync = $0; UserDefaults.standard.set($0, forKey: "cv.cloudSyncEnabled") }
            ))
            Toggle("Enable Order Reminders", isOn: Binding(
                get:  { store.remindersEnabled },
                set:  { store.remindersEnabled = $0 }
            ))
        }
        .padding(.horizontal)
    }

    private var barcodeHistorySection: some View {
        InfoCard(title: "Barcode History") {
            if store.barcodeHistory.isEmpty {
                Text("No barcode scans yet.").foregroundStyle(.secondary)
            } else {
                ForEach(store.barcodeHistory.prefix(10)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.barcode).foregroundStyle(.white)
                            Text(entry.title + " - " + entry.lookupSource).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.success ? .green : .red)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Toggle("Wishlist Only CSV", isOn: $wishlistOnly).padding(.horizontal)
            Button("Export Vault Backup") {
                exportDoc = JSONVaultDocument(data: store.exportBackupData()); showExporter = true
            }
            Button("Export Collection CSV") {
                csvDoc = CSVTextDocument(text: CSVVault.exportCSV(from: store.editions, wishlistOnly: wishlistOnly))
                showCSVExport = true
            }
            Button("Import Vault Backup") { showImporter = true }
            Button("Import Collection CSV") { showCSVImport = true }
            Button("Reset Sample Data", role: .destructive) { confirmReset = true }
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
    }
}
