import Combine
import Foundation

enum FilmLogBackupError: LocalizedError {
    case iCloudUnavailable
    case invalidBackup
    case noBackupFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            "iCloud Drive is not available. Check that iCloud is enabled for this app and that you are signed in on this device."
        case .invalidBackup:
            "This does not look like a valid Filmist backup file."
        case .noBackupFound:
            "No Filmist iCloud backup was found."
        }
    }
}

struct PortableFilmLogBackup: Codable {
    var version = 1
    var exportedAt: String
    var filmLog: FilmLogData
    var images: [String: Data]
}

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

    var cameras: [CameraProfile] {
        data.cameras.sorted {
            if $0.cameraBody.localizedCaseInsensitiveCompare($1.cameraBody) == .orderedSame {
                return $0.lens.localizedCaseInsensitiveCompare($1.lens) == .orderedAscending
            }
            return $0.cameraBody.localizedCaseInsensitiveCompare($1.cameraBody) == .orderedAscending
        }
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

    func updateFilmStock(stockId: UUID, input: NewFilmStockInput) {
        guard let stockIndex = data.stocks.firstIndex(where: { $0.id == stockId }) else { return }

        let existingLogoFileName = data.stocks[stockIndex].logoFileName
        data.stocks[stockIndex].brand = input.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        data.stocks[stockIndex].model = input.model.trimmingCharacters(in: .whitespacesAndNewlines)
        data.stocks[stockIndex].iso = input.iso
        data.stocks[stockIndex].size = input.size.trimmingCharacters(in: .whitespacesAndNewlines)
        data.stocks[stockIndex].framesPerRoll = input.framesPerRoll
        data.stocks[stockIndex].expiryDate = input.expiryDate.trimmingCharacters(in: .whitespacesAndNewlines)

        if let logoFileName = saveImageData(input.logoData, prefix: "logo") {
            data.stocks[stockIndex].logoFileName = logoFileName
        } else {
            data.stocks[stockIndex].logoFileName = existingLogoFileName
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

    @discardableResult
    func addCamera(cameraBody: String, lens: String) -> CameraProfile? {
        let trimmedBody = cameraBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLens = lens.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty, !trimmedLens.isEmpty else { return nil }

        if let existingCamera = data.cameras.first(where: {
            $0.cameraBody.caseInsensitiveCompare(trimmedBody) == .orderedSame &&
                $0.lens.caseInsensitiveCompare(trimmedLens) == .orderedSame
        }) {
            return existingCamera
        }

        let camera = CameraProfile(cameraBody: trimmedBody, lens: trimmedLens)
        data.cameras.append(camera)
        save()
        return camera
    }

    func deleteCamera(_ cameraId: UUID) {
        data.cameras.removeAll { $0.id == cameraId }
        save()
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

    var isICloudAvailable: Bool {
        fileManager.ubiquityIdentityToken != nil && iCloudBackupDirectory != nil
    }

    var iCloudBackupDate: Date? {
        guard let backupDataURL = iCloudBackupDataURL else { return nil }
        return try? fileManager.attributesOfItem(atPath: backupDataURL.path)[.modificationDate] as? Date
    }

    func backupToICloud() throws {
        guard let backupDirectory = iCloudBackupDirectory else {
            throw FilmLogBackupError.iCloudUnavailable
        }

        let rawData = try makePortableBackupData()
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try rawData.write(to: backupDirectory.appendingPathComponent(iCloudBackupFileName), options: .atomic)
    }

    func restoreFromICloud() throws {
        guard let backupDataURL = iCloudBackupDataURL else {
            throw FilmLogBackupError.iCloudUnavailable
        }
        guard fileManager.fileExists(atPath: backupDataURL.path) else {
            throw FilmLogBackupError.noBackupFound
        }

        try restorePortableBackup(from: Data(contentsOf: backupDataURL))
    }

    func makePortableBackupData() throws -> Data {
        save()
        let backup = PortableFilmLogBackup(
            exportedAt: Self.timestampString(),
            filmLog: data,
            images: try collectImageData()
        )
        return try encoder.encode(backup)
    }

    func restorePortableBackup(from rawData: Data) throws {
        let backup = try decoder.decode(PortableFilmLogBackup.self, from: rawData)
        guard backup.version == 1 else {
            throw FilmLogBackupError.invalidBackup
        }

        if fileManager.fileExists(atPath: imagesDirectory.path) {
            try fileManager.removeItem(at: imagesDirectory)
        }
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        for (fileName, imageData) in backup.images {
            try imageData.write(to: imagesDirectory.appendingPathComponent(fileName), options: .atomic)
        }

        data = backup.filmLog
        save()
    }

    private func allRollSummaries() -> [RollSummary] {
        let indexedHistoryByRoll = Dictionary(grouping: data.statusHistory.enumerated(), by: { $0.element.rollId })
        let indexedLoadsByRoll = Dictionary(grouping: data.cameraLoads.enumerated(), by: { $0.element.rollId })
        let indexedPhotosByRoll = Dictionary(grouping: data.photos.enumerated(), by: { $0.element.rollId })

        return data.stocks.flatMap { stock in
            data.rolls
                .filter { $0.filmStockId == stock.id }
                .sorted { $0.rollNumber < $1.rollNumber }
                .map { roll in
                    let rollHistory = (indexedHistoryByRoll[roll.id] ?? [])
                        .sorted { lhs, rhs in
                            if lhs.element.changedAt == rhs.element.changedAt {
                                return lhs.offset > rhs.offset
                            }
                            return lhs.element.changedAt > rhs.element.changedAt
                        }
                        .map(\.element)
                    let latestLoad = (indexedLoadsByRoll[roll.id] ?? [])
                        .max {
                            if $0.element.loadedAt == $1.element.loadedAt {
                                return $0.offset < $1.offset
                            }
                            return $0.element.loadedAt < $1.element.loadedAt
                        }?
                        .element
                    let photos = (indexedPhotosByRoll[roll.id] ?? [])
                        .sorted { lhs, rhs in
                            if lhs.element.addedAt == rhs.element.addedAt {
                                return lhs.offset > rhs.offset
                            }
                            return lhs.element.addedAt > rhs.element.addedAt
                        }
                        .map(\.element)

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

    private func collectImageData() throws -> [String: Data] {
        guard fileManager.fileExists(atPath: imagesDirectory.path) else {
            return [:]
        }

        let imageURLs = try fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        var images: [String: Data] = [:]
        for url in imageURLs {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            images[url.lastPathComponent] = try Data(contentsOf: url)
        }
        return images
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

    private var iCloudBackupDirectory: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("FilmLog", isDirectory: true)
    }

    private var iCloudBackupDataURL: URL? {
        iCloudBackupDirectory?.appendingPathComponent(iCloudBackupFileName)
    }

    private var iCloudBackupFileName: String {
        "FilmLog-iCloud-Backup.json"
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
