import Combine
import Foundation

@MainActor
final class FilmLogStore: ObservableObject {
    @Published private(set) var data = FilmLogData()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    var stockCount: Int {
        data.stocks.count
    }

    func rollSummaries(for page: WorkflowPage) -> [RollSummary] {
        allRollSummaries().filter { summary in
            switch page {
            case .unloaded:
                summary.currentStatus == .inStorage
            case .loaded:
                summary.currentStatus == .loaded
            case .finished:
                [.finished, .inDevelopment, .developed].contains(summary.currentStatus)
            }
        }
    }

    func count(for page: WorkflowPage) -> Int {
        rollSummaries(for: page).count
    }

    func addFilmStock(_ input: NewFilmStockInput) {
        let stockId = UUID()
        let logoFileName = saveImageData(input.logoData, prefix: "logo")
        let trimmedBrand = input.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = input.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSize = input.size.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpiry = input.expiryDate.trimmingCharacters(in: .whitespacesAndNewlines)

        let stock = FilmStock(
            id: stockId,
            brand: trimmedBrand,
            model: trimmedModel,
            iso: input.iso,
            size: trimmedSize,
            framesPerRoll: input.framesPerRoll,
            numberOfRolls: input.numberOfRolls,
            expiryDate: trimmedExpiry,
            logoFileName: logoFileName
        )
        data.stocks.append(stock)

        for index in 1...input.numberOfRolls {
            let roll = FilmRoll(filmStockId: stockId, rollNumber: index)
            data.rolls.append(roll)
            data.statusHistory.append(
                RollStatusHistory(rollId: roll.id, status: .inStorage, changedAt: Self.todayString())
            )
        }

        save()
    }

    func deleteRoll(_ rollId: UUID, stockId: UUID) {
        data.rolls.removeAll { $0.id == rollId }
        data.statusHistory.removeAll { $0.rollId == rollId }
        data.cameraLoads.removeAll { $0.rollId == rollId }
        data.photos.removeAll { $0.rollId == rollId }

        let remainingRolls = data.rolls.filter { $0.filmStockId == stockId }.count
        if let stockIndex = data.stocks.firstIndex(where: { $0.id == stockId }) {
            data.stocks[stockIndex].numberOfRolls = remainingRolls
        }

        save()
    }

    func recordLoad(rollId: UUID, cameraBody: String, lens: String, loadedAt: String) {
        data.cameraLoads.append(
            CameraLoad(
                rollId: rollId,
                cameraBody: cameraBody.trimmingCharacters(in: .whitespacesAndNewlines),
                lens: lens.trimmingCharacters(in: .whitespacesAndNewlines),
                loadedAt: loadedAt
            )
        )
        updateRollStatus(rollId: rollId, status: .loaded, changedAt: loadedAt)
    }

    func updateRollStatus(rollId: UUID, status: FilmStatus, changedAt: String) {
        data.statusHistory.append(
            RollStatusHistory(rollId: rollId, status: status, changedAt: changedAt)
        )
        save()
    }

    func addPhotos(rollId: UUID, imageData: [Data]) {
        guard !imageData.isEmpty else { return }
        let addedAt = Self.todayString()
        for item in imageData {
            guard let fileName = saveImageData(item, prefix: "photo") else { continue }
            data.photos.append(PhotoAttachment(rollId: rollId, imageFileName: fileName, addedAt: addedAt))
        }
        save()
    }

    func imageURL(fileName: String?) -> URL? {
        guard let fileName else { return nil }
        return imagesDirectory.appendingPathComponent(fileName)
    }

    private func allRollSummaries() -> [RollSummary] {
        let historyByRoll = Dictionary(grouping: data.statusHistory, by: \.rollId)
        let loadsByRoll = Dictionary(grouping: data.cameraLoads, by: \.rollId)
        let photosByRoll = Dictionary(grouping: data.photos, by: \.rollId)

        return data.stocks.flatMap { stock in
            data.rolls
                .filter { $0.filmStockId == stock.id }
                .sorted { $0.rollNumber < $1.rollNumber }
                .map { roll in
                    let rollHistory = (historyByRoll[roll.id] ?? [])
                        .sorted { lhs, rhs in
                            if lhs.changedAt == rhs.changedAt {
                                return lhs.id.uuidString > rhs.id.uuidString
                            }
                            return lhs.changedAt > rhs.changedAt
                        }
                    let latestLoad = (loadsByRoll[roll.id] ?? [])
                        .max { $0.loadedAt < $1.loadedAt }
                    let photos = (photosByRoll[roll.id] ?? [])
                        .sorted { lhs, rhs in
                            if lhs.addedAt == rhs.addedAt {
                                return lhs.id.uuidString > rhs.id.uuidString
                            }
                            return lhs.addedAt > rhs.addedAt
                        }

                    return RollSummary(
                        stock: stock,
                        roll: roll,
                        currentStatus: rollHistory.first?.status ?? .inStorage,
                        statusHistory: rollHistory,
                        latestLoad: latestLoad,
                        photos: photos
                    )
                }
        }
    }

    private func load() {
        do {
            let url = dataURL
            guard fileManager.fileExists(atPath: url.path) else {
                seedIfEmpty()
                return
            }
            let rawData = try Data(contentsOf: url)
            data = try decoder.decode(FilmLogData.self, from: rawData)
            if data.stocks.isEmpty {
                seedIfEmpty()
            }
        } catch {
            data = FilmLogData()
            seedIfEmpty()
        }
    }

    private func seedIfEmpty() {
        guard data.stocks.isEmpty else { return }

        let stockId = UUID()
        data.stocks = [
            FilmStock(
                id: stockId,
                brand: "Kodak",
                model: "Gold 200",
                iso: 200,
                size: "35mm",
                framesPerRoll: 36,
                numberOfRolls: 3,
                expiryDate: "2027-06-01",
                logoFileName: nil
            )
        ]

        data.rolls = (1...3).map { FilmRoll(filmStockId: stockId, rollNumber: $0) }
        data.statusHistory = data.rolls.map {
            RollStatusHistory(rollId: $0.id, status: .inStorage, changedAt: Self.todayString())
        }

        save()
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let rawData = try encoder.encode(data)
            try rawData.write(to: dataURL, options: .atomic)
        } catch {
            assertionFailure("Could not save film log data: \(error)")
        }
    }

    private func saveImageData(_ imageData: Data?, prefix: String) -> String? {
        guard let imageData else { return nil }
        do {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            let fileName = "\(prefix)-\(UUID().uuidString).jpg"
            let url = imagesDirectory.appendingPathComponent(fileName)
            try imageData.write(to: url, options: .atomic)
            return fileName
        } catch {
            assertionFailure("Could not save image: \(error)")
            return nil
        }
    }

    private var supportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FilmLog", isDirectory: true)
    }

    private var imagesDirectory: URL {
        supportDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    private var dataURL: URL {
        supportDirectory.appendingPathComponent("film-log.json")
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
