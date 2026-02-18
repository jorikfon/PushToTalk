import Foundation
import CoreFoundation
import PrivateMediaRemote

/// Менеджер для управления системными медиа-плеерами через MediaRemote Private API
/// Работает с Spotify, Apple Music, YouTube, VLC и другими плеерами
/// Использует SPM пакет PrivateFrameworks/MediaRemote
public class MediaRemoteManager {
    public static let shared = MediaRemoteManager()

    private var didPause: Bool = false

    private init() {
        LogManager.app.success("MediaRemoteManager: Инициализирован с SPM пакетом MediaRemote")
    }

    /// Проверяет, воспроизводится ли что-то в данный момент
    public func isPlaying(completion: @escaping (Bool) -> Void) {
        let queue = DispatchQueue.global(qos: .userInitiated)

        MRMediaRemoteGetNowPlayingInfo(queue) { info in
            guard let info = info as? [String: Any] else {
                completion(false)
                return
            }

            // Проверяем статус воспроизведения
            // kMRMediaRemoteNowPlayingInfoPlaybackRate: 1.0 = играет, 0.0 = пауза
            if let playbackRate = info[kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double {
                let isPlaying = playbackRate > 0.0
                LogManager.app.debug("MediaRemoteManager: Playback rate = \(playbackRate) (playing: \(isPlaying))")
                completion(isPlaying)
            } else {
                LogManager.app.debug("MediaRemoteManager: Нет информации о воспроизведении")
                completion(false)
            }
        }
    }

    /// Отправляет команду паузы медиа-плееру через TogglePlayPause
    /// Проверяет, воспроизводится ли что-то — если нет, не ставит на паузу
    /// Использует Toggle вместо прямой команды Pause — совместимо со Spotify и другими плеерами
    public func pause() {
        LogManager.app.info("MediaRemoteManager: Проверяем состояние воспроизведения перед паузой...")

        isPlaying { [weak self] playing in
            guard let self = self else { return }

            guard playing else {
                self.didPause = false
                LogManager.app.debug("MediaRemoteManager: Ничего не воспроизводится, пауза не нужна")
                return
            }

            let success = MRMediaRemoteSendCommand(MRMediaRemoteCommandTogglePlayPause, nil)

            if success {
                self.didPause = true
                LogManager.app.success("MediaRemoteManager: ✓ Пауза через toggle отправлена")
            } else {
                self.didPause = false
                LogManager.app.warning("MediaRemoteManager: Не удалось отправить команду паузы")
            }
        }
    }

    /// Возобновляет воспроизведение, если мы вызывали pause()
    /// - Parameter force: Если true, возобновляет независимо от флага didPause (для Debug кнопок)
    /// Использует Toggle вместо прямой команды Play — совместимо со Spotify и другими плеерами
    /// Проверяет isPlaying() перед toggle, чтобы не поставить на паузу уже играющий плеер
    public func resume(force: Bool = false) {
        guard didPause || force else {
            LogManager.app.debug("MediaRemoteManager: Пауза не вызывалась, не возобновляем")
            return
        }

        didPause = false

        // Проверяем, не играет ли уже (пользователь мог возобновить вручную)
        isPlaying { [weak self] playing in
            guard self != nil else { return }

            if playing {
                LogManager.app.debug("MediaRemoteManager: Уже воспроизводится, toggle не нужен")
                return
            }

            LogManager.app.info("MediaRemoteManager: Возобновляем воспроизведение через toggle\(force ? " (принудительно)" : "")...")

            let success = MRMediaRemoteSendCommand(MRMediaRemoteCommandTogglePlayPause, nil)

            if success {
                LogManager.app.success("MediaRemoteManager: ✓ Воспроизведение возобновлено через toggle")
            } else {
                LogManager.app.warning("MediaRemoteManager: Не удалось возобновить воспроизведение")
            }
        }
    }

    /// Переключает воспроизведение (play/pause)
    public func togglePlayPause() {
        let success = MRMediaRemoteSendCommand(MRMediaRemoteCommandTogglePlayPause, nil)

        if success {
            LogManager.app.info("MediaRemoteManager: ✓ Toggle play/pause выполнен")
        } else {
            LogManager.app.warning("MediaRemoteManager: Не удалось выполнить toggle play/pause")
        }
    }

    /// Получает информацию о текущем треке
    public func getNowPlayingInfo(completion: @escaping ([String: Any]?) -> Void) {
        let queue = DispatchQueue.global(qos: .userInitiated)

        MRMediaRemoteGetNowPlayingInfo(queue) { info in
            completion(info as? [String: Any])
        }
    }
}
