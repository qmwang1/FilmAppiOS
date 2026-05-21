import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum AppTab: Hashable {
    case workflow(WorkflowPage)
    case settings
}

private enum FilmistDates {
    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func date(from string: String) -> Date {
        isoFormatter.date(from: string) ?? Date()
    }

    static func displayString(from dateString: String) -> String {
        guard let date = isoFormatter.date(from: dateString) else {
            return dateString
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func displayString(from date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func displayStringWithTime(from date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: FilmLogStore
    @State private var selectedTab: AppTab = .workflow(.unloaded)
    @State private var showAddMenu = false
    @State private var showAddFilm = false
    @State private var showAddCamera = false
    @State private var loadingRoll: RollSummary?
    @State private var finishingRoll: RollSummary?
    @State private var processingRoll: RollSummary?
    @State private var deletingRoll: RollSummary?
    @State private var editingStock: FilmStock?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $selectedTab) {
                    ForEach(WorkflowPage.allCases) { page in
                        WorkflowList(
                            page: page,
                            loadingRoll: $loadingRoll,
                            finishingRoll: $finishingRoll,
                            processingRoll: $processingRoll,
                            deletingRoll: $deletingRoll,
                            editingStock: $editingStock
                        )
                        .tag(AppTab.workflow(page))
                        .tabItem {
                            Label(page.tabTitle, systemImage: iconName(for: page))
                        }
                        .badge(store.count(for: page))
                    }

                    BackupView()
                        .tag(AppTab.settings)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }

                if showAddMenu {
                    AddMenuBackdrop {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            showAddMenu = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                AddMenu(
                    isPresented: $showAddMenu,
                    onAddFilm: {
                        showAddFilm = true
                    },
                    onAddCamera: {
                        showAddCamera = true
                    }
                )
                .padding(.trailing, 22)
                .padding(.bottom, 64)
                .zIndex(2)
            }
            .navigationTitle("Filmist")
        }
        .sheet(isPresented: $showAddFilm) {
            AddFilmSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddCamera) {
            AddCameraSheet()
                .environmentObject(store)
        }
        .sheet(item: $editingStock) { stock in
            EditFilmSheet(stock: stock)
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

private struct AddMenuBackdrop: View {
    let onDismiss: () -> Void

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.12).ignoresSafeArea())
            .onTapGesture(perform: onDismiss)
    }
}

private struct AddMenu: View {
    @Binding var isPresented: Bool
    let onAddFilm: () -> Void
    let onAddCamera: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isPresented {
                AddMenuAction(
                    title: "Film stock",
                    systemImage: "film",
                    delay: 0.04
                ) {
                    choose(onAddFilm)
                }

                AddMenuAction(
                    title: "Camera",
                    systemImage: "camera",
                    delay: 0.0
                ) {
                    choose(onAddCamera)
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isPresented.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isPresented ? 45 : 0))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(radius: isPresented ? 16 : 10, y: isPresented ? 8 : 4)
            }
            .accessibilityLabel(isPresented ? "Close add menu" : "Add")
        }
    }

    private func choose(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
        }
    }
}

private struct AddMenuAction: View {
    let title: String
    let systemImage: String
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: systemImage)
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.14), in: Circle())
            }
            .foregroundStyle(.primary)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.86, anchor: .bottomTrailing)
        .offset(y: isVisible ? 0 : 14)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78).delay(delay)) {
                isVisible = true
            }
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
    @Binding var editingStock: FilmStock?

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
                                onEdit: { editingStock = summary.stock },
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

private struct BackupView: View {
    @EnvironmentObject private var store: FilmLogStore
    @State private var message = ""
    @State private var backupDocument = FilmLogBackupDocument()
    @State private var isWorking = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showICloudRestoreConfirmation = false

    var body: some View {
        List {
            Section {
                if store.cameras.isEmpty {
                    Text("No saved cameras")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.cameras) { camera in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(camera.cameraBody)
                            Text(camera.lens)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        let cameras = store.cameras
                        for index in indexSet {
                            store.deleteCamera(cameras[index].id)
                        }
                    }
                }
            } header: {
                Text("Cameras")
            } footer: {
                Text("Saved cameras can be selected when loading a roll.")
            }

            Section {
                Label(
                    store.isICloudAvailable ? "iCloud is available" : "iCloud is not available",
                    systemImage: store.isICloudAvailable ? "checkmark.icloud" : "exclamationmark.icloud"
                )
                .foregroundStyle(store.isICloudAvailable ? .primary : .secondary)

                if let backupDate = store.iCloudBackupDate {
                    LabeledContent("Last backup", value: FilmistDates.displayStringWithTime(from: backupDate))
                } else {
                    LabeledContent("Last backup", value: "None")
                }
            } header: {
                Text("iCloud Backup")
            } footer: {
                Text("iCloud backup saves the film log, logos, and attached photos to the app's private iCloud Drive container.")
            }

            Section {
                Button {
                    backUpToICloud()
                } label: {
                    Label("Back Up to iCloud", systemImage: "icloud.and.arrow.up")
                }
                .disabled(isWorking)

                Button {
                    showICloudRestoreConfirmation = true
                } label: {
                    Label("Restore From iCloud", systemImage: "icloud.and.arrow.down")
                }
                .disabled(isWorking)
            }

            Section {
                Button {
                    exportBackup()
                } label: {
                    Label("Export Backup File", systemImage: "square.and.arrow.up")
                }
                .disabled(isWorking)

                Button {
                    showImporter = true
                } label: {
                    Label("Import Backup File", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            } header: {
                Text("File Backup")
            } footer: {
                Text("File backup keeps a portable JSON copy you can save to Files, AirDrop, Google Drive, or another location.")
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Restore iCloud backup?", isPresented: $showICloudRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                restoreFromICloud()
            }
        } message: {
            Text("This replaces the film log currently on this device with the iCloud backup.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "FilmLog-Backup-\(FilmLogStore.todayString()).json"
        ) { result in
            switch result {
            case .success:
                message = "Backup file exported."
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
    }

    private func backUpToICloud() {
        isWorking = true
        do {
            try store.backupToICloud()
            message = "iCloud backup completed."
        } catch {
            message = error.localizedDescription
        }
        isWorking = false
    }

    private func restoreFromICloud() {
        isWorking = true
        do {
            try store.restoreFromICloud()
            message = "iCloud backup restored."
        } catch {
            message = error.localizedDescription
        }
        isWorking = false
    }

    private func exportBackup() {
        isWorking = true
        do {
            backupDocument = FilmLogBackupDocument(data: try store.makePortableBackupData())
            showExporter = true
        } catch {
            message = error.localizedDescription
        }
        isWorking = false
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        isWorking = true
        do {
            guard let url = try result.get().first else {
                isWorking = false
                return
            }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try store.restorePortableBackup(from: Data(contentsOf: url))
            message = "Backup file imported."
        } catch {
            message = error.localizedDescription
        }
        isWorking = false
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
    let onEdit: () -> Void
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
                    Text("\(summary.stock.framesPerRoll) frames • Expires \(FilmistDates.displayString(from: summary.stock.expiryDate))")
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

            if let latestLoad = summary.latestLoad, page != .unloaded {
                Text("Camera: \(latestLoad.cameraBody) + \(latestLoad.lens) • \(FilmistDates.displayString(from: latestLoad.loadedAt))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
                        Button("Edit", action: onEdit)
                            .buttonStyle(.bordered)
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
            "\(FilmistDates.displayString(from: $0.changedAt)) \($0.status.displayName)"
        }
        return "Recent history: \(items.joined(separator: " • "))"
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
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
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
                    DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
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
                expiryDate: FilmistDates.string(from: expiryDate),
                logoData: logoData
            )
        )
        dismiss()
    }
}

private struct EditFilmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    let stock: FilmStock
    @State private var brand: String
    @State private var model: String
    @State private var iso: String
    @State private var size: String
    @State private var framesPerRoll: String
    @State private var expiryDate: Date
    @State private var logoItem: PhotosPickerItem?
    @State private var logoData: Data?

    private let filmSizeOptions = ["35mm", "120"]

    init(stock: FilmStock) {
        self.stock = stock
        _brand = State(initialValue: stock.brand)
        _model = State(initialValue: stock.model)
        _iso = State(initialValue: "\(stock.iso)")
        _size = State(initialValue: stock.size)
        _framesPerRoll = State(initialValue: "\(stock.framesPerRoll)")
        _expiryDate = State(initialValue: FilmistDates.date(from: stock.expiryDate))
    }

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
                    DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
                }

                Section {
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        HStack {
                            Text(logoData == nil ? "Replace logo" : "New logo selected")
                            Spacer()
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit film")
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
            let parsedFrames = Int(framesPerRoll)
        else {
            return false
        }
        return parsedIso > 0 && parsedFrames > 0
    }

    private func save() {
        guard
            let parsedIso = Int(iso),
            let parsedFrames = Int(framesPerRoll)
        else { return }

        store.updateFilmStock(
            stockId: stock.id,
            input: NewFilmStockInput(
                brand: brand,
                model: model,
                iso: parsedIso,
                size: size,
                framesPerRoll: parsedFrames,
                numberOfRolls: stock.numberOfRolls,
                expiryDate: FilmistDates.string(from: expiryDate),
                logoData: logoData
            )
        )
        dismiss()
    }
}

private struct LoadRollSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    let summary: RollSummary
    @State private var selectedCameraId = ""
    @State private var cameraBody = ""
    @State private var lens = ""
    @State private var loadedAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                if !store.cameras.isEmpty {
                    Section {
                        Picker("Saved camera", selection: $selectedCameraId) {
                            Text("Custom").tag("")
                            ForEach(store.cameras) { camera in
                                Text(camera.displayName).tag(camera.id.uuidString)
                            }
                        }
                    }
                }

                Section {
                    Text("Record which camera body and lens this unloaded roll is going into.")
                        .foregroundStyle(.secondary)
                    TextField("Camera body", text: $cameraBody)
                    TextField("Lens", text: $lens)
                    DatePicker("Loaded date", selection: $loadedAt, displayedComponents: .date)

                    Button {
                        if let camera = store.addCamera(cameraBody: cameraBody, lens: lens) {
                            selectedCameraId = camera.id.uuidString
                        }
                    } label: {
                        Label("Save Camera", systemImage: "camera.badge.ellipsis")
                    }
                    .disabled(!canRecord)
                }
            }
            .navigationTitle("Load \(summary.stock.brand) \(summary.stock.model) roll \(summary.roll.rollNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedCameraId) { _, cameraId in
                guard
                    let camera = store.cameras.first(where: { $0.id.uuidString == cameraId })
                else { return }
                cameraBody = camera.cameraBody
                lens = camera.lens
            }
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
                            loadedAt: FilmistDates.string(from: loadedAt)
                        )
                        dismiss()
                    }
                    .disabled(!canRecord)
                }
            }
        }
    }

    private var canRecord: Bool {
        !cameraBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !lens.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AddCameraSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    @State private var cameraBody = ""
    @State private var lens = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Camera body", text: $cameraBody)
                    TextField("Lens", text: $lens)
                }
            }
            .navigationTitle("Add Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addCamera(cameraBody: cameraBody, lens: lens)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !cameraBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !lens.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct FinishRollSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FilmLogStore
    let summary: RollSummary
    @State private var finishedAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This moves the roll from the loaded page to the finished page.")
                        .foregroundStyle(.secondary)
                    DatePicker("Finished date", selection: $finishedAt, displayedComponents: .date)
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
                        store.updateRollStatus(rollId: summary.roll.id, status: .finished, changedAt: FilmistDates.string(from: finishedAt))
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
    @State private var changedAt = Date()

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
                    DatePicker("Change date", selection: $changedAt, displayedComponents: .date)
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
                        store.updateRollStatus(rollId: summary.roll.id, status: selectedStatus, changedAt: FilmistDates.string(from: changedAt))
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
