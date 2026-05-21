import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: FilmLogStore
    @State private var selectedPage: WorkflowPage = .unloaded
    @State private var showAddFilm = false
    @State private var loadingRoll: RollSummary?
    @State private var finishingRoll: RollSummary?
    @State private var processingRoll: RollSummary?
    @State private var deletingRoll: RollSummary?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $selectedPage) {
                    ForEach(WorkflowPage.allCases) { page in
                        WorkflowList(
                            page: page,
                            loadingRoll: $loadingRoll,
                            finishingRoll: $finishingRoll,
                            processingRoll: $processingRoll,
                            deletingRoll: $deletingRoll
                        )
                        .tag(page)
                        .tabItem {
                            Label(page.tabTitle, systemImage: iconName(for: page))
                        }
                        .badge(store.count(for: page))
                    }
                }

                Button {
                    showAddFilm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(radius: 10, y: 4)
                }
                .accessibilityLabel("Add film stock")
                .padding(.trailing, 22)
                .padding(.bottom, 64)
            }
            .navigationTitle("Film Log")
        }
        .sheet(isPresented: $showAddFilm) {
            AddFilmSheet()
                .environmentObject(store)
        }
        .sheet(item: $loadingRoll) { summary in
            LoadRollSheet(summary: summary)
                .environmentObject(store)
        }
        .sheet(item: $finishingRoll) { summary in
            FinishRollSheet(summary: summary)
                .environmentObject(store)
        }
        .sheet(item: $processingRoll) { summary in
            ProcessingSheet(summary: summary)
                .environmentObject(store)
        }
        .alert(item: $deletingRoll) { summary in
            Alert(
                title: Text("Delete roll \(summary.roll.rollNumber)?"),
                message: Text("This removes only this \(summary.stock.brand) \(summary.stock.model) roll and its status history, camera loads, and attached photos."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteRoll(summary.roll.id, stockId: summary.stock.id)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func iconName(for page: WorkflowPage) -> String {
        switch page {
        case .unloaded:
            "tray"
        case .loaded:
            "camera"
        case .finished:
            "checkmark.seal"
        }
    }
}

private struct WorkflowList: View {
    @EnvironmentObject private var store: FilmLogStore
    let page: WorkflowPage
    @Binding var loadingRoll: RollSummary?
    @Binding var finishingRoll: RollSummary?
    @Binding var processingRoll: RollSummary?
    @Binding var deletingRoll: RollSummary?

    var body: some View {
        let rolls = store.rollSummaries(for: page)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HeaderCard(page: page, stockCount: store.stockCount)

                if store.stockCount == 0 {
                    EmptyStateCard()
                } else {
                    Text(page.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    if rolls.isEmpty {
                        PageEmptyStateCard(page: page)
                    } else {
                        ForEach(rolls) { summary in
                            RollCard(
                                page: page,
                                summary: summary,
                                onLoad: { loadingRoll = summary },
                                onFinish: { finishingRoll = summary },
                                onProcess: { processingRoll = summary },
                                onDelete: { deletingRoll = summary }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct HeaderCard: View {
    let page: WorkflowPage
    let stockCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(page.title)
                    .font(.title2.weight(.semibold))
                Text("\(stockCount) film stock(s) tracked across the workflow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                SummaryBadge(label: "Page", value: page.title)
                SummaryBadge(label: "Stocks", value: "\(stockCount)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SummaryBadge: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No film logged yet")
                .font(.title3.weight(.semibold))
            Text("Add your first stock to create rolls automatically and start tracking each one through unloaded, loaded, and finished pages.")
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PageEmptyStateCard: View {
    let page: WorkflowPage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(page.emptyTitle)
                .font(.title3.weight(.semibold))
            Text(page.emptyMessage)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RollCard: View {
    @EnvironmentObject private var store: FilmLogStore
    let page: WorkflowPage
    let summary: RollSummary
    let onLoad: () -> Void
    let onFinish: () -> Void
    let onProcess: () -> Void
    let onDelete: () -> Void
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                FileBackedImage(
                    url: store.imageURL(fileName: summary.stock.logoFileName),
                    fallback: String(summary.stock.brand.prefix(1))
                )
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.stock.brand) \(summary.stock.model)")
                        .font(.title3.weight(.semibold))
                    Text("Roll \(summary.roll.rollNumber) • ISO \(summary.stock.iso) • \(summary.stock.size)")
                        .font(.subheadline)
                    Text("\(summary.stock.framesPerRoll) frames • Expires \(summary.stock.expiryDate)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(summary.currentStatus.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
            }

            WorkflowDetail(page: page, summary: summary)

            Text(historyText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    switch page {
                    case .unloaded:
                        Button("Load roll", action: onLoad)
                            .buttonStyle(.borderedProminent)
                    case .loaded:
                        Button("Mark finished", action: onFinish)
                            .buttonStyle(.borderedProminent)
                    case .finished:
                        Button("Update status", action: onProcess)
                            .buttonStyle(.borderedProminent)
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: 30,
                            matching: .images
                        ) {
                            Text("Add photos")
                        }
                        .buttonStyle(.bordered)
                        .disabled(summary.currentStatus != .developed)
                    }

                    Button("Delete roll", role: .destructive, action: onDelete)
                        .buttonStyle(.bordered)
                }
            }

            if page == .finished && summary.currentStatus != .developed {
                Text("Photo import unlocks after you mark the roll as developed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !summary.photos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(summary.photos.count) photo(s) attached")
                        .font(.subheadline.weight(.medium))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(summary.photos.prefix(6)) { photo in
                                FileBackedImage(url: store.imageURL(fileName: photo.imageFileName), fallback: "F")
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: photoItems) { _, newItems in
            Task {
                var imageData: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        imageData.append(data)
                    }
                }
                await MainActor.run {
                    store.addPhotos(rollId: summary.roll.id, imageData: imageData)
                    photoItems = []
                }
            }
        }
    }

    private var historyText: String {
        let items = summary.statusHistory.prefix(3).map {
            "\($0.changedAt) \($0.status.displayName)"
        }
        return "Recent history: \(items.joined(separator: " • "))"
    }
}

private struct WorkflowDetail: View {
    let page: WorkflowPage
    let summary: RollSummary

    var body: some View {
        switch page {
        case .unloaded:
            Text("Ready to load into a camera. Once loaded, this roll moves to the loaded page.")
                .font(.body)
        case .loaded:
            Text(loadedDetail)
                .font(.body)
        case .finished:
            VStack(alignment: .leading, spacing: 8) {
                Text(finishedDetail)
                    .font(.body)
                if let latestLoad = summary.latestLoad {
                    Text("Last camera load: \(latestLoad.cameraBody) with \(latestLoad.lens) on \(latestLoad.loadedAt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var loadedDetail: String {
        guard let latestLoad = summary.latestLoad else {
            return "Marked loaded, but no camera load details were saved."
        }
        return "Loaded in \(latestLoad.cameraBody) with \(latestLoad.lens) on \(latestLoad.loadedAt)."
    }

    private var finishedDetail: String {
        switch summary.currentStatus {
        case .finished:
            "This roll is shot and ready to be sent for development."
        case .inDevelopment:
            "This roll is currently in development."
        case .developed:
            "Development is complete. You can attach photos from this roll."
        default:
            summary.currentStatus.displayName
        }
    }
}

private struct AddFilmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    @State private var brand = ""
    @State private var model = ""
    @State private var iso = "400"
    @State private var size = "35mm"
    @State private var framesPerRoll = "36"
    @State private var numberOfRolls = "1"
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()).map(Self.dateString) ?? FilmLogStore.todayString()
    @State private var logoItem: PhotosPickerItem?
    @State private var logoData: Data?

    private let filmSizeOptions = ["35mm", "120"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                    TextField("ISO", text: $iso)
                        .keyboardType(.numberPad)
                    Picker("Film size", selection: $size) {
                        ForEach(filmSizeOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Frames per roll", text: $framesPerRoll)
                        .keyboardType(.numberPad)
                    TextField("Number of rolls", text: $numberOfRolls)
                        .keyboardType(.numberPad)
                    TextField("Expiry date (YYYY-MM-DD)", text: $expiryDate)
                }

                Section {
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        HStack {
                            Text(logoData == nil ? "Pick logo" : "Logo selected")
                            Spacer()
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let logoData, let image = UIImage(data: logoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .navigationTitle("Add film stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
            .onChange(of: logoItem) { _, item in
                Task {
                    let data = try? await item?.loadTransferable(type: Data.self)
                    await MainActor.run {
                        logoData = data
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        guard
            !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let parsedIso = Int(iso),
            let parsedFrames = Int(framesPerRoll),
            let parsedRolls = Int(numberOfRolls)
        else {
            return false
        }
        return parsedIso > 0 && parsedFrames > 0 && parsedRolls > 0
    }

    private func save() {
        guard
            let parsedIso = Int(iso),
            let parsedFrames = Int(framesPerRoll),
            let parsedRolls = Int(numberOfRolls)
        else { return }

        store.addFilmStock(
            NewFilmStockInput(
                brand: brand,
                model: model,
                iso: parsedIso,
                size: size,
                framesPerRoll: parsedFrames,
                numberOfRolls: parsedRolls,
                expiryDate: expiryDate,
                logoData: logoData
            )
        )
        dismiss()
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct LoadRollSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    let summary: RollSummary
    @State private var cameraBody = ""
    @State private var lens = ""
    @State private var loadedAt = FilmLogStore.todayString()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Record which camera body and lens this unloaded roll is going into.")
                        .foregroundStyle(.secondary)
                    TextField("Camera body", text: $cameraBody)
                    TextField("Lens", text: $lens)
                    TextField("Loaded date (YYYY-MM-DD)", text: $loadedAt)
                }
            }
            .navigationTitle("Load \(summary.stock.brand) \(summary.stock.model) roll \(summary.roll.rollNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        store.recordLoad(
                            rollId: summary.roll.id,
                            cameraBody: cameraBody,
                            lens: lens,
                            loadedAt: loadedAt
                        )
                        dismiss()
                    }
                    .disabled(cameraBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lens.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct FinishRollSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    let summary: RollSummary
    @State private var finishedAt = FilmLogStore.todayString()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This moves the roll from the loaded page to the finished page.")
                        .foregroundStyle(.secondary)
                    TextField("Finished date (YYYY-MM-DD)", text: $finishedAt)
                }
            }
            .navigationTitle("Finish roll \(summary.roll.rollNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move to finished") {
                        store.updateRollStatus(rollId: summary.roll.id, status: .finished, changedAt: finishedAt)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ProcessingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    let summary: RollSummary
    @State private var selectedStatus: FilmStatus
    @State private var changedAt = FilmLogStore.todayString()

    private let availableStatuses: [FilmStatus] = [.finished, .inDevelopment, .developed]

    init(summary: RollSummary) {
        self.summary = summary
        let initialStatus = [.finished, .inDevelopment, .developed].contains(summary.currentStatus) ? summary.currentStatus : .finished
        _selectedStatus = State(initialValue: initialStatus)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Current status: \(summary.currentStatus.displayName)")
                    TextField("Change date (YYYY-MM-DD)", text: $changedAt)
                }

                Section {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(availableStatuses) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Process roll \(summary.roll.rollNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateRollStatus(rollId: summary.roll.id, status: selectedStatus, changedAt: changedAt)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FileBackedImage: View {
    let url: URL?
    let fallback: String

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                    Text(fallback.isEmpty ? "F" : fallback)
                        .font(.title2.weight(.bold))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    ContentView()
        .environmentObject(FilmLogStore())
}
