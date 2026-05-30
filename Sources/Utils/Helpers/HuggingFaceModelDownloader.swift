//
//  HuggingFaceModelDownloader.swift
//  PushToTalk
//
//  Загрузчик моделей WhisperKit из произвольного репозитория Hugging Face.
//
//  Зачем нужен: штатный механизм WhisperKit ищет веса в подпапке вида
//  `*<variant>/*` внутри репозитория (argmaxinc/whisperkit-coreml). Некоторые
//  сторонние модели (например smkrv/whisper-podlodka-turbo-coreml) выкладывают
//  скомпилированные `.mlmodelc` прямо в корень репозитория — такую "плоскую"
//  структуру WhisperKit.download(variant:) не находит. Поэтому мы скачиваем
//  файлы сами и затем открываем модель через `WhisperKit(modelFolder:)`.
//
//  Прогресс считается по объёму скачанных байт. Скачивание идёт во временную
//  папку с суффиксом `.partial`, которая атомарно переименовывается в финальную
//  только после успешного завершения — это исключает ситуацию, когда наполовину
//  скачанная модель ошибочно считается доступной.
//

import Foundation

/// Загрузчик "плоского" репозитория Hugging Face в локальную папку.
public final class HuggingFaceModelDownloader: NSObject, @unchecked Sendable {

    // MARK: - Types

    /// Файл в репозитории Hugging Face.
    public struct RemoteFile {
        public let path: String
        public let size: Int
    }

    /// Ошибки загрузки.
    public enum DownloadError: Error, LocalizedError {
        case invalidURL(String)
        case listingFailed(status: Int)
        case fileFailed(path: String, status: Int)
        case emptyRepository

        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Некорректный URL: \(url)"
            case .listingFailed(let status):
                return "Не удалось получить список файлов модели (HTTP \(status))"
            case .fileFailed(let path, let status):
                return "Не удалось скачать файл \(path) (HTTP \(status))"
            case .emptyRepository:
                return "Репозиторий модели не содержит файлов"
            }
        }
    }

    // MARK: - Private Properties

    private let repo: String
    private let host = "https://huggingface.co"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60  // 1 час на большой файл
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Состояние текущей (последовательной) загрузки одного файла.
    private var continuation: CheckedContinuation<Void, Error>?
    private var currentDestination: URL?
    private var moveError: Error?
    private var baseBytes: Int = 0      // байт скачано в предыдущих файлах
    private var totalBytes: Int = 1     // общий объём (минимум 1, чтобы не делить на 0)
    private var progressHandler: ((Double) -> Void)?

    // MARK: - Init

    /// - Parameter repo: идентификатор репозитория, например `smkrv/whisper-podlodka-turbo-coreml`.
    public init(repo: String) {
        self.repo = repo
        super.init()
    }

    // MARK: - Public API

    /// Список файлов репозитория (рекурсивно, только файлы — без папок).
    public func listFiles() async throws -> [RemoteFile] {
        let urlString = "\(host)/api/models/\(repo)/tree/main?recursive=true"
        guard let url = URL(string: urlString) else { throw DownloadError.invalidURL(urlString) }

        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else { throw DownloadError.listingFailed(status: status) }

        let entries = try JSONDecoder().decode([TreeEntry].self, from: data)
        return entries
            .filter { $0.type == "file" }
            .map { RemoteFile(path: $0.path, size: $0.size ?? 0) }
    }

    /// Скачивает весь репозиторий в `destination`, сохраняя структуру подпапок.
    ///
    /// Загрузка ведётся во временную папку `<destination>.partial`, которая
    /// переименовывается в `destination` только после полного успеха.
    ///
    /// - Parameters:
    ///   - destination: финальная папка модели (будет перезаписана при наличии).
    ///   - progress: вызывается с дробью `0...1` по мере скачивания.
    public func download(to destination: URL, progress: @escaping (Double) -> Void) async throws {
        let files = try await listFiles()
        guard !files.isEmpty else { throw DownloadError.emptyRepository }

        self.progressHandler = progress
        self.totalBytes = max(1, files.reduce(0) { $0 + $1.size })
        self.baseBytes = 0

        let fm = FileManager.default
        let tempDir = destination.deletingLastPathComponent()
            .appendingPathComponent(destination.lastPathComponent + ".partial", isDirectory: true)

        // Чистим возможный остаток от прошлой неудачной попытки.
        try? fm.removeItem(at: tempDir)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for file in files {
            let dest = tempDir.appendingPathComponent(file.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await downloadFile(path: file.path, to: dest)
            baseBytes += file.size
            progress(min(1.0, Double(baseBytes) / Double(totalBytes)))
        }

        // Атомарная замена финальной папки.
        try? fm.removeItem(at: destination)
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: tempDir, to: destination)
        progress(1.0)
    }

    // MARK: - Private

    private func resolveURL(for path: String) -> URL? {
        let encoded = path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        return URL(string: "\(host)/\(repo)/resolve/main/\(encoded)")
    }

    private func downloadFile(path: String, to dest: URL) async throws {
        guard let url = resolveURL(for: path) else {
            throw DownloadError.invalidURL(path)
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            self.currentDestination = dest
            self.moveError = nil
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    private struct TreeEntry: Decodable {
        let type: String
        let path: String
        let size: Int?
    }
}

// MARK: - URLSessionDownloadDelegate

extension HuggingFaceModelDownloader: URLSessionDownloadDelegate {

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let global = Double(baseBytes + Int(totalBytesWritten)) / Double(totalBytes)
        progressHandler?(min(1.0, global))
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Переместить файл нужно синхронно: временный файл удаляется после выхода.
        guard let dest = currentDestination else { return }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.moveItem(at: location, to: dest)
        } catch {
            moveError = error
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let cont = continuation
        continuation = nil

        if let error = error {
            cont?.resume(throwing: error)
            return
        }
        if let http = task.response as? HTTPURLResponse, http.statusCode != 200 {
            let path = currentDestination?.lastPathComponent ?? ""
            cont?.resume(throwing: DownloadError.fileFailed(path: path, status: http.statusCode))
            return
        }
        if let moveError = moveError {
            self.moveError = nil
            cont?.resume(throwing: moveError)
            return
        }
        cont?.resume(returning: ())
    }
}
