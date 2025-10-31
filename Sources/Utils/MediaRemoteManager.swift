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

    /// Отправляет команду паузы медиа-плееру
    public func pause() {
        LogManager.app.info("MediaRemoteManager: Отправка команды паузы...")

        // Отправляем команду паузы
        let success = MRMediaRemoteSendCommand(MRMediaRemoteCommandPause, nil)

        if success {
            didPause = true
            LogManager.app.success("MediaRemoteManager: ✓ Команда паузы отправлена")
        } else {
            didPause = false
            LogManager.app.warning("MediaRemoteManager: Не удалось отправить команду паузы")
        }
    }

    /// Возобновляет воспроизведение, если мы вызывали pause()
    /// - Parameter force: Если true, возобновляет независимо от флага didPause (для Debug кнопок)
    public func resume(force: Bool = false) {
        // Возобновляем только если мы вызывали pause() или force = true
        if didPause || force {
            LogManager.app.info("MediaRemoteManager: Возобновляем воспроизведение\(force ? " (принудительно)" : "")...")

            let success = MRMediaRemoteSendCommand(MRMediaRemoteCommandPlay, nil)

            if success {
                LogManager.app.success("MediaRemoteManager: ✓ Воспроизведение возобновлено")
            } else {
                LogManager.app.warning("MediaRemoteManager: Не удалось возобновить воспроизведение")
            }

            didPause = false
        } else {
            LogManager.app.debug("MediaRemoteManager: Пауза не вызывалась, не возобновляем")
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
