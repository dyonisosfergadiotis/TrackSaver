import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

final class ImageLoader: ObservableObject {
    @Published var image: PlatformImage?

    private var url: URL
    private var task: URLSessionDataTask?

    init(url: URL) {
        self.url = url
    }

    func updateURL(_ newURL: URL) {
        guard newURL != url else { return }
        cancel()
        url = newURL
        image = nil
        load()
    }

    func load() {
        if image != nil || task != nil {
            return
        }

        let currentURL = url

        if let cached = ImageCache.shared.image(for: currentURL) {
            image = cached
            return
        }

        task?.cancel()
        var request = URLRequest(url: currentURL)
        request.cachePolicy = .returnCacheDataElseLoad

        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }

            guard let data, let image = PlatformImage(data: data) else {
                DispatchQueue.main.async {
                    if self.url == currentURL {
                        self.task = nil
                    }
                }
                return
            }

            ImageCache.shared.store(image: image, data: data, response: response, for: currentURL)
            DispatchQueue.main.async {
                guard self.url == currentURL else { return }
                self.task = nil
                self.image = image
            }
        }
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

enum ImageCache {
    static let shared = ImageCacheImpl()
}

final class ImageCacheImpl {
    private let decodedImageCache = NSCache<NSURL, PlatformImage>()

    func image(for url: URL) -> PlatformImage? {
        let key = url as NSURL
        if let cachedImage = decodedImageCache.object(forKey: key) {
            return cachedImage
        }

        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = PlatformImage(data: cached.data) {
            decodedImageCache.setObject(image, forKey: key)
            return image
        }
        return nil
    }

    func store(image: PlatformImage, data: Data, response: URLResponse?, for url: URL) {
        decodedImageCache.setObject(image, forKey: url as NSURL)
        guard let response else { return }
        let cached = CachedURLResponse(response: response, data: data)
        let request = URLRequest(url: url)
        URLCache.shared.storeCachedResponse(cached, for: request)
    }
}

struct RemoteImage<Placeholder: View>: View {
    private let url: URL
    private let placeholder: Placeholder

    @StateObject private var loader: ImageLoader

    init(url: URL, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                platformImage(image)
            } else {
                placeholder
            }
        }
        .onAppear { loader.load() }
        .onChange(of: url) { _, newURL in
            loader.updateURL(newURL)
        }
        .onDisappear { loader.cancel() }
    }

    @ViewBuilder
    private func platformImage(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image).resizable()
        #elseif canImport(AppKit)
        Image(nsImage: image).resizable()
        #endif
    }
}
