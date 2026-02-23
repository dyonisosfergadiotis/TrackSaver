import SwiftUI
import Combine

final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

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
        let currentURL = url

        if let cached = ImageCache.shared.image(for: currentURL) {
            image = cached
            return
        }

        task?.cancel()
        var request = URLRequest(url: currentURL)
        request.cachePolicy = .returnCacheDataElseLoad

        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            ImageCache.shared.store(image: image, data: data, response: response, for: currentURL)
            DispatchQueue.main.async {
                guard self.url == currentURL else { return }
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
    func image(for url: URL) -> UIImage? {
        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request) {
            return UIImage(data: cached.data)
        }
        return nil
    }

    func store(image: UIImage, data: Data, response: URLResponse?, for url: URL) {
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
                Image(uiImage: image).resizable()
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
}
