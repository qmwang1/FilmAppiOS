import Foundation

enum FilmStatus: String, Codable, CaseIterable, Identifiable {
    case inStorage = "IN_STORAGE"
    case loaded = "LOADED"
    case finished = "FINISHED"
    case inDevelopment = "IN_DEVELOPMENT"
    case developed = "DEVELOPED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inStorage:
            "In storage"
        case .loaded:
            "Loaded"
        case .finished:
            "Finished"
        case .inDevelopment:
            "In development"
        case .developed:
            "Developed"
        }
    }
}

enum WorkflowPage: String, CaseIterable, Hashable, Identifiable {
    case unloaded
    case loaded
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unloaded:
            "Unloaded film"
        case .loaded:
            "Loaded film"
        case .finished:
            "Finished film"
        }
    }

    var tabTitle: String {
        switch self {
        case .unloaded:
            "Unloaded"
        case .loaded:
            "Loaded"
        case .finished:
            "Finished"
        }
    }

    var subtitle: String {
        switch self {
        case .unloaded:
            "Rolls waiting to be loaded into a camera."
        case .loaded:
            "Rolls currently loaded in a camera body."
        case .finished:
            "Move shot rolls through finished, in development, and developed."
        }
    }

    var emptyTitle: String {
        switch self {
        case .unloaded:
            "No unloaded film"
        case .loaded:
            "No loaded film"
        case .finished:
            "No finished film"
        }
    }

    var emptyMessage: String {
        switch self {
        case .unloaded:
            "All available rolls have already moved into later stages."
        case .loaded:
            "Record a camera load from the unloaded page when a roll goes into a camera."
        case .finished:
            "Loaded rolls will show up here once you mark them finished."
        }
    }
}

struct FilmStock: Identifiable, Codable, Equatable {
    var id = UUID()
    var brand: String
    var model: String
    var iso: Int
    var size: String
    var framesPerRoll: Int
    var numberOfRolls: Int
    var expiryDate: String
    var logoFileName: String?
}

struct FilmRoll: Identifiable, Codable, Equatable {
    var id = UUID()
    var filmStockId: UUID
    var rollNumber: Int
}

struct RollStatusHistory: Identifiable, Codable, Equatable {
    var id = UUID()
    var rollId: UUID
    var status: FilmStatus
    var changedAt: String
}

struct CameraLoad: Identifiable, Codable, Equatable {
    var id = UUID()
    var rollId: UUID
    var cameraBody: String
    var lens: String
    var loadedAt: String
}

struct PhotoAttachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var rollId: UUID
    var imageFileName: String
    var addedAt: String
}

struct FilmLogData: Codable, Equatable {
    var stocks: [FilmStock] = []
    var rolls: [FilmRoll] = []
    var statusHistory: [RollStatusHistory] = []
    var cameraLoads: [CameraLoad] = []
    var photos: [PhotoAttachment] = []
}

struct RollSummary: Identifiable, Equatable {
    var id: UUID { roll.id }
    var stock: FilmStock
    var roll: FilmRoll
    var currentStatus: FilmStatus
    var statusHistory: [RollStatusHistory]
    var latestLoad: CameraLoad?
    var photos: [PhotoAttachment]
}

struct NewFilmStockInput {
    var brand: String
    var model: String
    var iso: Int
    var size: String
    var framesPerRoll: Int
    var numberOfRolls: Int
    var expiryDate: String
    var logoData: Data?
}
