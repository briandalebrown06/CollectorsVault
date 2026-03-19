import SwiftUI
import UIKit
import CloudKit
import UserNotifications
import UniformTypeIdentifiers

// MARK: - ImageStore

final class ImageStore {
    static let shared = ImageStore()
    private init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private let folder: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CollectorVault/CoverImages", isDirectory: true)
    }()

    @discardableResult
    func save(_ data: Data, id: String = UUID().uuidString) -> String {
        let filename = id + ".jpg"
        let url = folder.appendingPathComponent(filename)
        if let image = UIImage(data: data),
           let jpeg = image.jpegData(compressionQuality: 0.82) {
            try? jpeg.write(to: url)
        } else {
            try? data.write(to: url)
        }
        return filename
    }

    func load(id: String) -> UIImage? {
        let url = folder.appendingPathComponent(id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(id: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(id))
    }
}

// MARK: - CoverImageView

struct CoverImageView: View {
    let imageID:     String?
    let systemImage: String
    let accentHex:   String
    let size:        CGSize

    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                ZStack {
                    (Color(hex: accentHex) ?? VaultTheme.cyan).opacity(0.85)
                    Image(systemName: systemImage)
                        .font(.system(size: size.width * 0.35))
                        .foregroundStyle(.white)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .onAppear {
            guard let id = imageID else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = ImageStore.shared.load(id: id)
                DispatchQueue.main.async { image = loaded }
            }
        }
    }
}

// MARK: - PersistenceService

final class PersistenceService {
    static let shared = PersistenceService()
    private init() {
        try? FileManager.default.createDirectory(at: baseFolder, withIntermediateDirectories: true)
    }

    private let baseFolder: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CollectorVault/Data", isDirectory: true)
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting    = .prettyPrinted
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func save<T: Encodable>(_ value: T, to filename: String) async {
        let url = baseFolder.appendingPathComponent(filename)
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomicWrite)
        }
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) async -> T? {
        let url = baseFolder.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func migrateFromUserDefaultsIfNeeded() async {
        let key = "cv.persistenceMigrated.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let ud = UserDefaults.standard
        let dec = decoder

        func migrate<T: Decodable>(_ type: T.Type, udKey: String, filename: String) async {
            guard let data = ud.data(forKey: udKey),
                  let value = try? dec.decode(type, from: data) else { return }
            await save(value, to: filename)
            ud.removeObject(forKey: udKey)
        }

        await migrate([MovieEdition].self,          udKey: "collectorvault.editions",           filename: "editions.json")
        await migrate([OrderItem].self,              udKey: "collectorvault.orders",             filename: "orders.json")
        await migrate([WatchEvent].self,             udKey: "collectorvault.watchEvents",        filename: "watchEvents.json")
        await migrate([Transaction].self,            udKey: "collectorvault.transactions",       filename: "transactions.json")
        await migrate([StorageLocation].self,        udKey: "collectorvault.storageLocations",   filename: "storageLocations.json")
        await migrate([LoanRecord].self,             udKey: "collectorvault.loanRecords",        filename: "loanRecords.json")
        await migrate([LabelInfo].self,              udKey: "collectorvault.labels",             filename: "labels.json")
        await migrate([BarcodeHistoryEntry].self,    udKey: "collectorvault.barcodeHistory",     filename: "barcodeHistory.json")
        await migrate(DashboardConfig.self,          udKey: "collectorvault.dashboardConfig",    filename: "dashboardConfig.json")
        await migrate([SavedAnalyticsReport].self,   udKey: "collectorvault.savedAnalyticsReports", filename: "savedReports.json")
        await migrate([SmartCollectionPreset].self,  udKey: "collectorvault.smartCollections",   filename: "smartCollections.json")
        await migrate(FeatureEntitlements.self,      udKey: "collectorvault.entitlements",       filename: "entitlements.json")

        ud.set(true, forKey: key)
    }

    func exportBackup(
        editions: [MovieEdition],
        orders: [OrderItem],
        watchEvents: [WatchEvent],
        transactions: [Transaction],
        storageLocations: [StorageLocation],
        loanRecords: [LoanRecord],
        labels: [LabelInfo],
        barcodeHistory: [BarcodeHistoryEntry],
        dashboardConfig: DashboardConfig,
        savedReports: [SavedAnalyticsReport],
        smartCollections: [SmartCollectionPreset],
        entitlements: FeatureEntitlements
    ) -> Data {
        let backup = VaultBackup(
            schemaVersion: VaultBackup.currentSchemaVersion,
            editions: editions, orders: orders, watchEvents: watchEvents,
            transactions: transactions, storageLocations: storageLocations,
            loanRecords: loanRecords, labels: labels, barcodeHistory: barcodeHistory,
            dashboardConfig: dashboardConfig, savedAnalyticsReports: savedReports,
            smartCollectionPresets: smartCollections, entitlements: entitlements,
            exportedAt: Date()
        )
        return (try? encoder.encode(backup)) ?? Data()
    }

    func importBackup(from data: Data) -> VaultBackup? {
        try? decoder.decode(VaultBackup.self, from: data)
    }
}

// MARK: - BarcodeService

final class BarcodeService {
    static let shared = BarcodeService()
    private init() {}
    private let cacheKey = "cv.barcodeLookupCache"

    func cached(barcode: String) -> ImportedEditionSeed? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: ImportedEditionSeed].self, from: data)
        else { return nil }
        return dict[barcode]
    }

    func cache(_ seed: ImportedEditionSeed, for barcode: String) {
        var dict = loadDict()
        dict[barcode] = seed
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadDict() -> [String: ImportedEditionSeed] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: ImportedEditionSeed].self, from: data)
        else { return [:] }
        return dict
    }

    func lookup(barcode: String) async throws -> ImportedEditionSeed? {
        try await Task.sleep(nanoseconds: 200_000_000)
        let db: [String: ImportedEditionSeed] = [
            "191329262527": ImportedEditionSeed(
                barcode: barcode, title: "Suspiria", originalTitle: "Suspiria",
                year: 1977, editionTitle: "4K UHD Steelbook",
                format: .uhd4K, editionType: .steelbook,
                label: "Synapse Films", studio: "Synapse Films",
                regionCode: "Region Free",
                coverSystemImage: "sparkles.tv", accentHex: "#8B1E2D",
                notes: "Imported from mock barcode catalog.",
                sourceName: "Mock Catalog", remotePosterPath: nil
            ),
            "715515298615": ImportedEditionSeed(
                barcode: barcode, title: "Cure", originalTitle: "Cure",
                year: 1997, editionTitle: "Blu-ray",
                format: .bluRay, editionType: .standard,
                label: "Criterion", studio: "Criterion",
                regionCode: "A",
                coverSystemImage: "moon.stars", accentHex: "#A9A9A9",
                notes: "Imported from mock barcode catalog.",
                sourceName: "Mock Catalog", remotePosterPath: nil
            )
        ]
        return db[barcode.trimmingCharacters(in: .whitespacesAndNewlines)]
    }
}

// MARK: - TMDbService

private struct TMDbSearchResponse: Decodable {
    let results: [TMDbMovie]
}
private struct TMDbMovie: Decodable {
    let title:          String
    let original_title: String?
    let release_date:   String?
    let poster_path:    String?
}

enum TMDbServiceError: LocalizedError {
    case missingToken, invalidURL, badResponse, noResults
    var errorDescription: String? {
        switch self {
        case .missingToken:  return "TMDb token is missing."
        case .invalidURL:    return "TMDb request URL was invalid."
        case .badResponse:   return "TMDb returned an invalid response."
        case .noResults:     return "TMDb returned no results."
        }
    }
}

enum TMDbService {
    static func searchMovieSeeds(
        title: String, year: Int?, barcode: String, token: String
    ) async throws -> [ImportedEditionSeed] {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw TMDbServiceError.missingToken }
        var components = URLComponents(string: "https://api.themoviedb.org/3/search/movie")
        var items = [URLQueryItem(name: "query", value: title)]
        if let year { items.append(URLQueryItem(name: "year", value: String(year))) }
        components?.queryItems = items
        guard let url = components?.url else { throw TMDbServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer " + clean, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TMDbServiceError.badResponse
        }
        let decoded = try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
        guard !decoded.results.isEmpty else { throw TMDbServiceError.noResults }
        return decoded.results.prefix(12).map { movie in
            let fmt = FormatType.infer(from: movie.title)
            let edt = EditionType.infer(from: movie.title)
            return ImportedEditionSeed(
                barcode: barcode, title: movie.title,
                originalTitle: movie.original_title ?? movie.title,
                year: movie.release_date.flatMap { Int($0.prefix(4)) },
                editionTitle: fmt != nil ? buildEditionTitle(format: fmt ?? .bluRay, editionType: edt ?? .standard) : "",
                format: fmt, editionType: edt,
                label: "", studio: "", regionCode: "",
                coverSystemImage: "film", accentHex: (fmt ?? .bluRay).tintHex,
                notes: "Enriched from TMDb.", sourceName: "TMDb",
                remotePosterPath: movie.poster_path
            )
        }
    }
}

// MARK: - ReminderService

enum ReminderService {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch { return false }
    }

    static func scheduleReleaseReminder(for order: OrderItem) async {
        guard let date = order.releaseDate, await requestAuthorization() else { return }
        await schedule(
            id: "release-" + order.id.uuidString,
            title: "Release Reminder",
            body: order.title + " releases on " + date.formatted(date: .abbreviated, time: .omitted) + ".",
            date: date
        )
    }

    static func scheduleChargeReminder(for order: OrderItem) async {
        guard let date = order.estimatedChargeDate, await requestAuthorization() else { return }
        await schedule(
            id: "charge-" + order.id.uuidString,
            title: "Charge Reminder",
            body: order.title + " may charge on " + date.formatted(date: .abbreviated, time: .omitted) + ".",
            date: date
        )
    }

    private static func schedule(id: String, title: String, body: String, date: Date) async {
        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        let comps        = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let trigger      = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request      = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - CollectorURLBuilder

enum CollectorURLBuilder {
    static func ebaySoldSearchURL(for edition: MovieEdition) -> URL? {
        let query = [edition.title, edition.editionTitle, edition.barcode]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.ebay.com/sch/i.html?_nkw=" + escaped + "&LH_Sold=1&LH_Complete=1")
    }
}

// MARK: - CSV

enum CSVVault {
    private static let headers = [
        "title","originalTitle","year","editionTitle","format","editionType",
        "collectionStatus","openWatchStatus","watchStatus","condition",
        "label","studio","regionCode","barcode",
        "isBlindBuy","isFavorite","hasDamage","damageNotes",
        "lowestKnownPrice","purchasePrice","estimatedValue","wishlistTargetPrice",
        "expectedReleaseDate","isUpgradeCandidate","duplicateDisposition",
        "wishlistPriority","purchaseUrgency","reasonWanted","isLimitedPressing",
        "oopRiskLevel","customTags","tags","franchiseName","boxSetName",
        "isBoxSet","parentBoxSetID","isLoanedOut","loanedTo","acquiredDate",
        "dateCreated","dateModified","collectorNotes"
    ]

    static func exportCSV(from editions: [MovieEdition], wishlistOnly: Bool = false) -> String {
        let rows = wishlistOnly ? editions.filter { $0.collectionStatus == .wishlist } : editions
        var lines = [headers.joined(separator: ",")]
        for e in rows {
            let values: [String] = [
                e.title, e.originalTitle, String(e.year), e.editionTitle,
                e.format.rawValue, e.editionType.rawValue,
                e.collectionStatus.rawValue, e.openWatchStatus.rawValue,
                e.watchStatus.rawValue, e.condition.rawValue,
                e.label, e.studio, e.regionCode, e.barcode,
                String(e.isBlindBuy), String(e.isFavorite), String(e.hasDamage), e.damageNotes,
                e.lowestKnownPrice.map(String.init) ?? "",
                e.purchasePrice.map(String.init) ?? "",
                e.estimatedValue.map(String.init) ?? "",
                e.wishlistTargetPrice.map(String.init) ?? "",
                csvDate(e.expectedReleaseDate),
                String(e.isUpgradeCandidate), e.duplicateDisposition.rawValue,
                e.wishlistPriority.title, e.purchaseUrgency.title,
                e.reasonWanted, String(e.isLimitedPressing), e.oopRiskLevel.title,
                joinTags(e.customTags), joinTags(e.tags),
                e.franchiseName, e.boxSetName,
                String(e.isBoxSet), e.parentBoxSetID?.uuidString ?? "",
                String(e.isLoanedOut), e.loanedTo,
                csvDate(e.acquiredDate), csvDate(e.dateCreated), csvDate(e.dateModified),
                e.collectorNotes
            ]
            lines.append(values.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func importCSV(_ text: String) -> [MovieEdition] {
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count > 1 else { return [] }
        let headerFields = splitCSVLine(lines[0])
        var results: [MovieEdition] = []
        for line in lines.dropFirst() {
            let fields = splitCSVLine(line)
            var map: [String: String] = [:]
            for (idx, key) in headerFields.enumerated() where idx < fields.count {
                map[key] = fields[idx]
            }
            guard let title = map["title"], !title.isEmpty,
                  let yearStr = map["year"], let year = Int(yearStr)
            else { continue }
            let fmt  = FormatType(rawValue:    map["format"] ?? "")           ?? .bluRay
            let edt  = EditionType(rawValue:   map["editionType"] ?? "")      ?? .standard
            let cs   = CollectionStatus(rawValue: map["collectionStatus"] ?? "") ?? .owned
            let ows  = OpenWatchStatus(rawValue: map["openWatchStatus"] ?? "") ?? .sealed
            let ws   = WatchStatus(rawValue:   map["watchStatus"] ?? "")      ?? .unwatched
            let cond = ConditionRating(rawValue: map["condition"] ?? "")      ?? .mint
            let disp = DuplicateDisposition(rawValue: map["duplicateDisposition"] ?? "") ?? .keep
            let pri  = WishlistPriority.allCases.first { $0.title == (map["wishlistPriority"] ?? "") } ?? .medium
            let urg  = PurchaseUrgency.allCases.first  { $0.title == (map["purchaseUrgency"] ?? "") }  ?? .keepAnEyeOnIt
            let oop  = OOPRiskLevel.allCases.first     { $0.title == (map["oopRiskLevel"] ?? "") }     ?? .none
            results.append(MovieEdition(
                title: title, originalTitle: map["originalTitle"] ?? title, year: year,
                editionTitle: map["editionTitle"] ?? buildEditionTitle(format: fmt, editionType: edt),
                format: fmt, editionType: edt, collectionStatus: cs,
                openWatchStatus: ows, watchStatus: ws, condition: cond,
                label: map["label"] ?? "", labelID: nil,
                studio: map["studio"] ?? "", regionCode: map["regionCode"] ?? "", barcode: map["barcode"] ?? "",
                isBlindBuy: map["isBlindBuy"] == "true", isFavorite: map["isFavorite"] == "true",
                hasDamage: map["hasDamage"] == "true", damageNotes: map["damageNotes"] ?? "",
                coverSystemImage: "film", accentHex: fmt.tintHex,
                coverImageID: nil, remotePosterPath: nil,
                hasIMAXScenes: false, hasDolbyVision: false, hasHDR10: false,
                hasHDR10Plus: false, hasDolbyAtmos: false, hasDolbyAudio: false, hasDTSX: false,
                videoNotes: "", audioNotes: "",
                lowestKnownPrice: Double(map["lowestKnownPrice"] ?? ""),
                purchasePrice: Double(map["purchasePrice"] ?? ""),
                estimatedValue: Double(map["estimatedValue"] ?? ""),
                marketStats: nil, pricePaidHistory: [], retailerLinks: [], wishlistPriceHistory: [],
                isUpgradeCandidate: map["isUpgradeCandidate"] == "true",
                duplicateDisposition: disp,
                wishlistTargetPrice: Double(map["wishlistTargetPrice"] ?? ""),
                expectedReleaseDate: parseISODate(map["expectedReleaseDate"] ?? ""),
                wishlistPriority: pri, purchaseUrgency: urg,
                reasonWanted: map["reasonWanted"] ?? "",
                isLimitedPressing: map["isLimitedPressing"] == "true",
                oopRiskLevel: oop,
                customTags: parseTags(from: map["customTags"] ?? ""),
                tags: parseTags(from: map["tags"] ?? ""),
                franchiseName: map["franchiseName"] ?? "", boxSetName: map["boxSetName"] ?? "",
                isBoxSet: map["isBoxSet"] == "true",
                parentBoxSetID: UUID(uuidString: map["parentBoxSetID"] ?? ""),
                isLoanedOut: map["isLoanedOut"] == "true", loanedTo: map["loanedTo"] ?? "",
                loanedDate: nil, dueDate: nil, loanNotes: "",
                cutName: "", hasCommentary: false, commentaryDetails: "", specialFeatures: "",
                discs: [], storageLocationID: nil,
                acquiredDate: parseISODate(map["acquiredDate"] ?? ""),
                dateCreated: parseISODate(map["dateCreated"] ?? "") ?? Date(),
                dateModified: parseISODate(map["dateModified"] ?? "") ?? Date(),
                collectorNotes: map["collectorNotes"] ?? "",
                timesWatched: 0, lastWatchedDate: nil
            ))
        }
        return results
    }

    private static func csvEscape(_ text: String) -> String {
        let needs = text.contains(",") || text.contains("\"") || text.contains("\n")
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        return needs ? "\"" + escaped + "\"" : escaped
    }

    private static func csvDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return ISO8601DateFormatter().string(from: date)
    }

    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var idx = line.startIndex
        while idx < line.endIndex {
            let ch = line[idx]
            if ch == "\"" {
                let next = line.index(after: idx)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\""); idx = line.index(after: next); continue
                } else { inQuotes.toggle() }
            } else if ch == "," && !inQuotes {
                result.append(current); current = ""
            } else { current.append(ch) }
            idx = line.index(after: idx)
        }
        result.append(current)
        return result
    }
}

// MARK: - File Documents

struct JSONVaultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct CSVTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        self.text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}
