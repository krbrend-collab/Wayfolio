import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

struct CharacterProfileImage: Codable, Equatable {
    let characterID: String
    let localMediaReference: String
    var cropCenterX: Double
    var cropCenterY: Double
    var zoomScale: Double
    var rotation: Double
    var updatedAt: Date
}

@MainActor
final class CharacterImageStore: ObservableObject {
    @Published private(set) var profiles: [String: CharacterProfileImage] = [:]
    @Published private(set) var removedCharacterIDs: Set<String> = []

    private let metadataKey = "wayfolio.character-images.metadata.v1"
    private let removedKey = "wayfolio.character-images.removed.v1"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: metadataKey),
           let decoded = try? JSONDecoder().decode([String: CharacterProfileImage].self, from: data) {
            profiles = decoded
        }
        removedCharacterIDs = Set(defaults.stringArray(forKey: removedKey) ?? [])
    }

    func profile(for characterID: String) -> CharacterProfileImage? {
        profiles[characterID]
    }

    func customImage(for characterID: String) -> UIImage? {
        guard let profile = profiles[characterID],
              let data = try? Data(contentsOf: imageDirectory.appendingPathComponent(profile.localMediaReference)) else {
            return nil
        }
        return UIImage(data: data)
    }

    func customImageData(for characterID: String) -> Data? {
        guard let profile = profiles[characterID] else { return nil }
        return try? Data(contentsOf: imageDirectory.appendingPathComponent(profile.localMediaReference))
    }

    func usesBundledPortrait(for characterID: String) -> Bool {
        profiles[characterID] == nil && !removedCharacterIDs.contains(characterID) && characterID == "renn"
    }

    func save(
        sourceData: Data,
        characterID: String,
        cropCenterX: Double,
        cropCenterY: Double,
        zoomScale: Double
    ) throws {
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let filename = "\(sanitized(characterID))-portrait.jpg"
        let destination = imageDirectory.appendingPathComponent(filename)
        let displayData = downsampledJPEG(from: sourceData, maximumPixelSize: 2400) ?? sourceData
        try displayData.write(to: destination, options: .atomic)
        profiles[characterID] = CharacterProfileImage(
            characterID: characterID,
            localMediaReference: filename,
            cropCenterX: cropCenterX,
            cropCenterY: cropCenterY,
            zoomScale: zoomScale,
            rotation: 0,
            updatedAt: Date()
        )
        removedCharacterIDs.remove(characterID)
        persist()
    }

    func updateCrop(characterID: String, cropCenterX: Double, cropCenterY: Double, zoomScale: Double) {
        guard var profile = profiles[characterID] else { return }
        profile.cropCenterX = cropCenterX
        profile.cropCenterY = cropCenterY
        profile.zoomScale = zoomScale
        profile.updatedAt = Date()
        profiles[characterID] = profile
        persist()
    }

    func remove(characterID: String) {
        if let profile = profiles.removeValue(forKey: characterID) {
            try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(profile.localMediaReference))
        }
        removedCharacterIDs.insert(characterID)
        persist()
    }

    private var imageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Wayfolio/CharacterImages", isDirectory: true)
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(profiles) { defaults.set(data, forKey: metadataKey) }
        defaults.set(Array(removedCharacterIDs).sorted(), forKey: removedKey)
    }

    private func sanitized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private func downsampledJPEG(from data: Data, maximumPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.9)
    }
}

struct CharacterPortraitView: View {
    @EnvironmentObject private var imageStore: CharacterImageStore
    @State private var manifestImage: UIImage?
    let characterID: String
    let characterName: String
    var size: CGFloat = 72

    var body: some View {
        GeometryReader { proxy in
            portrait(in: proxy.size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(WayfolioPalette.brassBright, lineWidth: 1.3))
        .shadow(color: WayfolioPalette.cyan.opacity(0.3), radius: 8)
        .accessibilityLabel("\(characterName) portrait")
        .task(id: characterID) {
            manifestImage = await WayfolioManifestImage.load(
                subjectID: WayfolioManifestImage.characterSubject(for: characterID),
                subjectType: characterID == "hinosuke" ? "CREATURE" : "CHARACTER",
                role: "LOGIN_PORTRAIT"
            )
        }
    }

    @ViewBuilder
    private func portrait(in size: CGSize) -> some View {
        if let image = imageStore.customImage(for: characterID) {
            rendered(image: image, profile: imageStore.profile(for: characterID), size: size)
        } else if let manifestImage {
            rendered(image: manifestImage, profile: nil, size: size)
        } else if imageStore.usesBundledPortrait(for: characterID), let image = UIImage(named: "renn_hazel_login_official") {
            rendered(image: image, profile: nil, size: size)
        } else {
            ZStack {
                WayfolioPalette.navy.opacity(0.92)
                WayfolioApprovedIcon(.character, size: min(size.width, size.height) * 0.62)
            }
        }
    }

    private func rendered(image: UIImage, profile: CharacterProfileImage?, size: CGSize) -> some View {
        let zoom = CGFloat(profile?.zoomScale ?? 1)
        let centerX = CGFloat(profile?.cropCenterX ?? 0.5)
        let centerY = CGFloat(profile?.cropCenterY ?? 0.5)
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(zoom)
            .offset(x: (0.5 - centerX) * size.width * zoom, y: (0.5 - centerY) * size.height * zoom)
            .clipped()
    }
}

/// The Character root's primary artwork. Unlike `CharacterPortraitView`, this
/// intentionally has no medallion, border, or circular crop: the transparent
/// character manifestation is allowed to lead the page and is cropped only
/// below the waist when its source is taller than the available stage.
struct CharacterManifestationView: View {
    @EnvironmentObject private var imageStore: CharacterImageStore
    @State private var manifestImage: UIImage?
    let characterID: String
    let characterName: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                RadialGradient(
                    colors: [WayfolioPalette.cyan.opacity(0.20), WayfolioPalette.violet.opacity(0.10), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: min(proxy.size.width, proxy.size.height) * 0.68
                )
                .accessibilityHidden(true)

                artwork(in: proxy.size)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
        }
        .accessibilityLabel("\(characterName) character manifestation")
        .task(id: characterID) {
            manifestImage = await WayfolioManifestImage.load(
                subjectID: WayfolioManifestImage.characterSubject(for: characterID),
                subjectType: characterID == "hinosuke" ? "CREATURE" : "CHARACTER",
                role: "LOGIN_PORTRAIT"
            )
        }
    }

    @ViewBuilder
    private func artwork(in size: CGSize) -> some View {
        if let image = imageStore.customImage(for: characterID) {
            rendered(image: image, profile: imageStore.profile(for: characterID), size: size)
        } else if let manifestImage {
            rendered(image: manifestImage, profile: nil, size: size)
        } else if imageStore.usesBundledPortrait(for: characterID), let image = UIImage(named: "renn_hazel_login_official") {
            rendered(image: image, profile: nil, size: size)
        } else {
            VStack(spacing: 8) {
                WayfolioApprovedIcon(.character, size: min(size.width, size.height) * 0.42)
                Text("Character art unavailable")
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.62))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func rendered(image: UIImage, profile: CharacterProfileImage?, size: CGSize) -> some View {
        let zoom = CGFloat(profile?.zoomScale ?? 1)
        let centerX = CGFloat(profile?.cropCenterX ?? 0.5)
        let centerY = CGFloat(profile?.cropCenterY ?? 0.36)
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height * 1.55, alignment: .top)
            .scaleEffect(zoom, anchor: .top)
            .offset(
                x: (0.5 - centerX) * size.width * zoom,
                y: (0.36 - centerY) * size.height * zoom
            )
    }
}

enum WayfolioManifestImage {
    private struct Resolution: Decodable { let state: String; let url: String? }

    static func characterSubject(for id: String) -> String {
        switch id.lowercased() {
        case "renn": return "CHARACTER_RENN_HAZEL"
        case "yugen", "yu-gen": return "CHARACTER_YUGEN"
        case "soren": return "CHARACTER_SOREN_HAZEL"
        case "lupin": return "CHARACTER_LUPIN"
        case "lark": return "CHARACTER_LARK"
        case "emrys": return "CHARACTER_EMRYS"
        case "hinosuke": return "CREATURE_HINOSUKE"
        default: return "CHARACTER_\(id.uppercased().replacingOccurrences(of: "-", with: "_"))"
        }
    }

    static func creatureSubject(for id: String) -> String {
        "CREATURE_\(id.uppercased().replacingOccurrences(of: "-", with: "_"))"
    }

    static func load(subjectID: String, subjectType: String, role: String) async -> UIImage? {
        guard !subjectID.isEmpty else { return nil }
        let stored = UserDefaults.standard.string(forKey: "wayfolio.session.host") ?? ""
        guard !stored.isEmpty else { return nil }
        let candidate = stored.contains("://") ? stored : "http://\(stored)"
        guard var base = URLComponents(string: candidate) else { return nil }
        base.scheme = "http"
        if base.port == nil { base.port = 8787 }
        base.path = "/api/assets/resolve"
        base.queryItems = [
            .init(name: "subject_id", value: subjectID), .init(name: "subject_type", value: subjectType),
            .init(name: "asset_role", value: role), .init(name: "audience", value: "player"),
            .init(name: "knowledge_scope", value: "assigned_character_only"),
            .init(name: "fallback", value: "approved_native_reference")
        ]
        guard let endpoint = base.url else { return nil }
        do {
            let (resolutionData, response) = try await URLSession.shared.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let resolution = try JSONDecoder().decode(Resolution.self, from: resolutionData)
            guard ["ready", "last_known_good"].contains(resolution.state), let path = resolution.url,
                  let imageURL = URL(string: path, relativeTo: endpoint)?.absoluteURL else { return nil }
            let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            guard let imageHTTP = imageResponse as? HTTPURLResponse, (200..<300).contains(imageHTTP.statusCode) else { return nil }
            return UIImage(data: imageData)
        } catch { return nil }
    }
}

struct CharacterImageEditor: View {
    @EnvironmentObject private var imageStore: CharacterImageStore
    @Environment(\.dismiss) private var dismiss

    let characterID: String
    let characterName: String

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var sourceData: Data?
    @State private var sourceImage: UIImage?
    @State private var cropCenterX: CGFloat = 0.5
    @State private var cropCenterY: CGFloat = 0.5
    @State private var zoomScale: CGFloat = 1.0
    @State private var dragStart: CGPoint?
    @State private var zoomStart: CGFloat?
    @State private var isShowingFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    cropWindow

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(sourceImage == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(WayfolioPalette.brass)

                        Button { isShowingFilePicker = true } label: {
                            Label("Choose File", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                    }

                    if sourceImage != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Zoom", systemImage: "magnifyingglass")
                            Slider(value: $zoomScale, in: 1...4)
                                .tint(WayfolioPalette.cyan)
                            Button("Reset Crop") {
                                cropCenterX = 0.5
                                cropCenterY = 0.5
                                zoomScale = 1
                            }
                        }
                        .padding(16)
                        .projectionPane(.info)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(WayfolioTypography.caption)
                            .foregroundStyle(WayfolioPalette.danger)
                    }

                    if imageStore.profile(for: characterID) != nil || imageStore.usesBundledPortrait(for: characterID) {
                        Button(role: .destructive) {
                            imageStore.remove(characterID: characterID)
                            dismiss()
                        } label: {
                            Label("Remove Image", systemImage: "trash")
                        }
                        .accessibilityLabel("Remove \(characterName) profile image")
                    }
                }
                .padding(20)
            }
            .background(WayfolioPalette.midnight)
            .foregroundStyle(WayfolioPalette.parchment)
            .navigationTitle("Edit \(characterName) Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(sourceImage == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: loadExistingImage)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { accept(data) }
                }
            }
        }
        .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                accept(try Data(contentsOf: url))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var cropWindow: some View {
        GeometryReader { proxy in
            ZStack {
                WayfolioPalette.navy
                if let sourceImage {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(zoomScale)
                        .offset(
                            x: (0.5 - cropCenterX) * proxy.size.width * zoomScale,
                            y: (0.5 - cropCenterY) * proxy.size.height * zoomScale
                        )
                } else {
                    VStack(spacing: 10) {
                        WayfolioApprovedIcon(.character, size: 88)
                        Text("Choose an image to begin")
                    }
                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.75))
                }
            }
            .clipShape(Circle())
            .overlay(Circle().stroke(WayfolioPalette.cyan, lineWidth: 2))
            .shadow(color: WayfolioPalette.cyan.opacity(0.4), radius: 14)
            .contentShape(Circle())
            .gesture(panGesture(size: proxy.size).simultaneously(with: zoomGesture))
        }
        .frame(height: 290)
        .accessibilityLabel("Portrait crop preview. Use the zoom slider and drag the image to reposition it.")
    }

    private func panGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil { dragStart = CGPoint(x: cropCenterX, y: cropCenterY) }
                guard let start = dragStart else { return }
                cropCenterX = min(1, max(0, start.x - value.translation.width / max(size.width * zoomScale, 1)))
                cropCenterY = min(1, max(0, start.y - value.translation.height / max(size.height * zoomScale, 1)))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomStart == nil { zoomStart = zoomScale }
                zoomScale = min(4, max(1, (zoomStart ?? 1) * value))
            }
            .onEnded { _ in zoomStart = nil }
    }

    private func loadExistingImage() {
        if let data = imageStore.customImageData(for: characterID), let image = UIImage(data: data) {
            sourceData = data
            sourceImage = image
            if let profile = imageStore.profile(for: characterID) {
                cropCenterX = CGFloat(profile.cropCenterX)
                cropCenterY = CGFloat(profile.cropCenterY)
                zoomScale = CGFloat(profile.zoomScale)
            }
        }
    }

    private func accept(_ data: Data) {
        guard let image = UIImage(data: data) else {
            errorMessage = "That file could not be read as an image."
            return
        }
        sourceData = data
        sourceImage = image
        cropCenterX = 0.5
        cropCenterY = 0.5
        zoomScale = 1
        errorMessage = nil
    }

    private func save() {
        do {
            if let sourceData {
                try imageStore.save(
                    sourceData: sourceData,
                    characterID: characterID,
                    cropCenterX: Double(cropCenterX),
                    cropCenterY: Double(cropCenterY),
                    zoomScale: Double(zoomScale)
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
