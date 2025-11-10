import Foundation

/// Локализуемые строки приложения
/// Централизованное хранение всех текстовых строк с поддержкой локализации
public enum Strings {
    /// Bundle для локализации (main bundle, где находится .app)
    private static let bundle = Bundle.main
    // MARK: - Application

    public enum App {
        public static let name = NSLocalizedString("app.name", bundle: bundle, comment: "Application name")
        public static let settings = NSLocalizedString("app.settings", bundle: bundle, comment: "Settings menu item")
        public static let quit = NSLocalizedString("app.quit", bundle: bundle, comment: "Quit menu item")
        public static let about = NSLocalizedString("app.about", bundle: bundle, comment: "About menu item")
    }

    // MARK: - Menu Bar

    public enum MenuBar {
        public static let recording = NSLocalizedString("menubar.recording", bundle: bundle, comment: "Recording status")
        public static let ready = NSLocalizedString("menubar.ready", bundle: bundle, comment: "Ready status")
        public static let processing = NSLocalizedString("menubar.processing", bundle: bundle, comment: "Processing status")
        public static let error = NSLocalizedString("menubar.error", bundle: bundle, comment: "Error status")
        public static let settings = NSLocalizedString("menubar.settings", bundle: bundle, comment: "Settings menu item")
        public static let audioDevice = NSLocalizedString("menubar.audioDevice", bundle: bundle, comment: "Audio device menu")
        public static let noDevicesAvailable = NSLocalizedString("menubar.noDevicesAvailable", bundle: bundle, comment: "No devices available message")
        public static let refreshList = NSLocalizedString("menubar.refreshList", bundle: bundle, comment: "Refresh list menu item")
        public static let quit = NSLocalizedString("menubar.quit", bundle: bundle, comment: "Quit menu item")
        public static let deviceChanged = NSLocalizedString("menubar.deviceChanged", bundle: bundle, comment: "Device changed notification")
        public static let selectedDevice = NSLocalizedString("menubar.selectedDevice", bundle: bundle, comment: "Selected device prefix")
        public static let listRefreshed = NSLocalizedString("menubar.listRefreshed", bundle: bundle, comment: "List refreshed notification")
        public static let devicesFound = NSLocalizedString("menubar.devicesFound", bundle: bundle, comment: "Devices found prefix")
    }

    // MARK: - Settings Sections

    public enum SettingsSections {
        public static let debug = NSLocalizedString("sections.debug", bundle: bundle, comment: "Debug section")
        public static let general = NSLocalizedString("sections.general", bundle: bundle, comment: "General section")
        public static let models = NSLocalizedString("sections.models", bundle: bundle, comment: "Models section")
        public static let hotkeys = NSLocalizedString("sections.hotkeys", bundle: bundle, comment: "Hotkeys section")
        public static let vocabulary = NSLocalizedString("sections.vocabulary", bundle: bundle, comment: "Vocabulary section")
        public static let audio = NSLocalizedString("sections.audio", bundle: bundle, comment: "Audio section")
        public static let history = NSLocalizedString("sections.history", bundle: bundle, comment: "History section")
    }

    // MARK: - General Settings

    public enum General {
        public static let title = NSLocalizedString("general.title", bundle: bundle, comment: "General settings title")
        public static let stopWords = NSLocalizedString("general.stopWords", bundle: bundle, comment: "Stop words label")
        public static let stopWordsTitle = NSLocalizedString("general.stopWordsTitle", bundle: bundle, comment: "Stop Words card title")
        public static let recordingSettings = NSLocalizedString("general.recordingSettings", bundle: bundle, comment: "Recording Settings card title")
        public static let stopWordsDescription = NSLocalizedString("general.stopWordsDescription", bundle: bundle, comment: "Stop words description")
        public static let addStopWord = NSLocalizedString("general.addStopWord", bundle: bundle, comment: "Add stop word button")
        public static let maxRecordingDuration = NSLocalizedString("general.maxRecordingDuration", bundle: bundle, comment: "Max recording duration label")
        public static let maxRecordingDescription = NSLocalizedString("general.maxRecordingDescription", bundle: bundle, comment: "Max recording duration description")
        public static let seconds = NSLocalizedString("general.seconds", bundle: bundle, comment: "Seconds unit")
    }

    // MARK: - Model Settings

    public enum Models {
        public static let title = NSLocalizedString("models.title", bundle: bundle, comment: "Model settings title")
        public static let currentModel = NSLocalizedString("models.currentModel", bundle: bundle, comment: "Current model label")
        public static let availableModels = NSLocalizedString("models.availableModels", bundle: bundle, comment: "Available models label")
        public static let downloadModel = NSLocalizedString("models.downloadModel", bundle: bundle, comment: "Download model button")
        public static let deleteModel = NSLocalizedString("models.deleteModel", bundle: bundle, comment: "Delete model button")
        public static let modelSize = NSLocalizedString("models.modelSize", bundle: bundle, comment: "Model size label")
        public static let modelStatus = NSLocalizedString("models.modelStatus", bundle: bundle, comment: "Model status label")
        public static let downloaded = NSLocalizedString("models.downloaded", bundle: bundle, comment: "Downloaded status")
        public static let notDownloaded = NSLocalizedString("models.notDownloaded", bundle: bundle, comment: "Not downloaded status")
        public static let downloading = NSLocalizedString("models.downloading", bundle: bundle, comment: "Downloading status")
        public static let deleteConfirmation = NSLocalizedString("models.deleteConfirmation", bundle: bundle, comment: "Delete model confirmation message")
        public static let deleteTitle = NSLocalizedString("models.deleteTitle", bundle: bundle, comment: "Delete model dialog title")
        public static let cancel = NSLocalizedString("models.cancel", bundle: bundle, comment: "Cancel button")
        public static let delete = NSLocalizedString("models.delete", bundle: bundle, comment: "Delete button")
    }

    // MARK: - Hotkey Settings

    public enum Hotkeys {
        public static let title = NSLocalizedString("hotkeys.title", bundle: bundle, comment: "Hotkey settings title")
        public static let hotkeySelection = NSLocalizedString("hotkeys.hotkeySelection", bundle: bundle, comment: "Hotkey Selection card title")
        public static let activeHotkey = NSLocalizedString("hotkeys.activeHotkey", bundle: bundle, comment: "Active Hotkey label")
        public static let hotkey = NSLocalizedString("hotkeys.hotkey", bundle: bundle, comment: "Hotkey picker label")
        public static let currentHotkey = NSLocalizedString("hotkeys.currentHotkey", bundle: bundle, comment: "Current hotkey label")
        public static let recordNewHotkey = NSLocalizedString("hotkeys.recordNewHotkey", bundle: bundle, comment: "Record new hotkey button")
        public static let pressHotkey = NSLocalizedString("hotkeys.pressHotkey", bundle: bundle, comment: "Press hotkey instruction")
        public static let functionKeys = NSLocalizedString("hotkeys.functionKeys", bundle: bundle, comment: "Function keys label")
        public static let modifiers = NSLocalizedString("hotkeys.modifiers", bundle: bundle, comment: "Modifiers label")
        public static let noModifier = NSLocalizedString("hotkeys.noModifier", bundle: bundle, comment: "No modifier option")
    }

    // MARK: - Vocabulary Settings

    public enum Vocabulary {
        public static let title = NSLocalizedString("vocabulary.title", bundle: bundle, comment: "Vocabulary settings title")
        public static let addNewVocabulary = NSLocalizedString("vocabulary.addNewVocabulary", bundle: bundle, comment: "Add New Vocabulary card title")
        public static let customPrompt = NSLocalizedString("vocabulary.customPrompt", bundle: bundle, comment: "Custom prompt label")
        public static let customPromptDescription = NSLocalizedString("vocabulary.customPromptDescription", bundle: bundle, comment: "Custom prompt description")
        public static let programmingPrompt = NSLocalizedString("vocabulary.programmingPrompt", bundle: bundle, comment: "Programming prompt label")
        public static let programmingPromptDescription = NSLocalizedString("vocabulary.programmingPromptDescription", bundle: bundle, comment: "Programming prompt description")
        public static let vocabularies = NSLocalizedString("vocabulary.vocabularies", bundle: bundle, comment: "Vocabularies label")
        public static let addVocabulary = NSLocalizedString("vocabulary.addVocabulary", bundle: bundle, comment: "Add vocabulary button")
        public static let vocabularyName = NSLocalizedString("vocabulary.vocabularyName", bundle: bundle, comment: "Vocabulary name label")
        public static let words = NSLocalizedString("vocabulary.words", bundle: bundle, comment: "Words label")
        public static let wordsPlaceholder = NSLocalizedString("vocabulary.wordsPlaceholder", bundle: bundle, comment: "Words placeholder")
        public static let enabled = NSLocalizedString("vocabulary.enabled", bundle: bundle, comment: "Enabled status")
        public static let disabled = NSLocalizedString("vocabulary.disabled", bundle: bundle, comment: "Disabled status")
        public static let language = NSLocalizedString("vocabulary.language", bundle: bundle, comment: "Language label")
        public static let languageDescription = NSLocalizedString("vocabulary.languageDescription", bundle: bundle, comment: "Language description")
        public static let russian = NSLocalizedString("vocabulary.russian", bundle: bundle, comment: "Russian language")
        public static let english = NSLocalizedString("vocabulary.english", bundle: bundle, comment: "English language")
    }

    // MARK: - Audio Settings

    public enum Audio {
        public static let title = NSLocalizedString("audio.title", bundle: bundle, comment: "Audio settings title")
        public static let audioInput = NSLocalizedString("audio.audioInput", bundle: bundle, comment: "Audio Input card title")
        public static let audioSettings = NSLocalizedString("audio.audioSettings", bundle: bundle, comment: "Audio Settings card title")
        public static let inputDevice = NSLocalizedString("audio.inputDevice", bundle: bundle, comment: "Input device label")
        public static let inputDeviceDescription = NSLocalizedString("audio.inputDeviceDescription", bundle: bundle, comment: "Input device description")
        public static let defaultDevice = NSLocalizedString("audio.defaultDevice", bundle: bundle, comment: "Default device option")
        public static let testRecording = NSLocalizedString("audio.testRecording", bundle: bundle, comment: "Test recording button")
        public static let stopTest = NSLocalizedString("audio.stopTest", bundle: bundle, comment: "Stop test button")
        public static let soundEffects = NSLocalizedString("audio.soundEffects", bundle: bundle, comment: "Sound effects label")
        public static let soundEffectsDescription = NSLocalizedString("audio.soundEffectsDescription", bundle: bundle, comment: "Sound effects description")
        public static let audioDucking = NSLocalizedString("audio.audioDucking", bundle: bundle, comment: "Audio ducking label")
        public static let audioDuckingDescription = NSLocalizedString("audio.audioDuckingDescription", bundle: bundle, comment: "Audio ducking description")
        public static let microphoneVolume = NSLocalizedString("audio.microphoneVolume", bundle: bundle, comment: "Microphone volume label")
        public static let volumeBoost = NSLocalizedString("audio.volumeBoost", bundle: bundle, comment: "Volume boost label")
    }

    // MARK: - History Settings

    public enum History {
        public static let title = NSLocalizedString("history.title", bundle: bundle, comment: "History title")
        public static let testRecording = NSLocalizedString("history.testRecording", bundle: bundle, comment: "Test Recording card title")
        public static let noTranscriptions = NSLocalizedString("history.noTranscriptions", bundle: bundle, comment: "No transcriptions yet message")
        public static let pressHotkeyToRecord = NSLocalizedString("history.pressHotkeyToRecord", bundle: bundle, comment: "Press hotkey instruction")
        public static let recording = NSLocalizedString("history.recording", bundle: bundle, comment: "Recording status")
        public static let total = NSLocalizedString("history.total", bundle: bundle, comment: "Total label")
        public static let words = NSLocalizedString("history.words", bundle: bundle, comment: "Words label")
        public static let avgTime = NSLocalizedString("history.avgTime", bundle: bundle, comment: "Avg Time label")
        public static let copy = NSLocalizedString("history.copy", bundle: bundle, comment: "Copy button")
        public static let export = NSLocalizedString("history.export", bundle: bundle, comment: "Export button")
        public static let clearAll = NSLocalizedString("history.clearAll", bundle: bundle, comment: "Clear All button")
        public static let noEntries = NSLocalizedString("history.noEntries", bundle: bundle, comment: "No entries message")
        public static let entries = NSLocalizedString("history.entries", bundle: bundle, comment: "Entries label")
        public static let copyToClipboard = NSLocalizedString("history.copyToClipboard", bundle: bundle, comment: "Copy to clipboard button")
        public static let deleteEntry = NSLocalizedString("history.deleteEntry", bundle: bundle, comment: "Delete entry button")
        public static let clearHistory = NSLocalizedString("history.clearHistory", bundle: bundle, comment: "Clear history button")
        public static let clearConfirmation = NSLocalizedString("history.clearConfirmation", bundle: bundle, comment: "Clear history confirmation")
        public static let clearTitle = NSLocalizedString("history.clearTitle", bundle: bundle, comment: "Clear history dialog title")
        public static let exportHistory = NSLocalizedString("history.exportHistory", bundle: bundle, comment: "Export history button")
        public static let exportSuccess = NSLocalizedString("history.exportSuccess", bundle: bundle, comment: "Export success title")
        public static let exportSuccessMessage = NSLocalizedString("history.exportSuccessMessage", bundle: bundle, comment: "Export success message")
        public static let ok = NSLocalizedString("history.ok", bundle: bundle, comment: "OK button")
    }

    // MARK: - Debug Settings

    public enum Debug {
        public static let title = NSLocalizedString("debug.title", bundle: bundle, comment: "Debug settings title")
        public static let viewLogs = NSLocalizedString("debug.viewLogs", bundle: bundle, comment: "View logs button")
        public static let openLogFolder = NSLocalizedString("debug.openLogFolder", bundle: bundle, comment: "Open log folder button")
        public static let clearLogs = NSLocalizedString("debug.clearLogs", bundle: bundle, comment: "Clear logs button")
        public static let enableDebugMode = NSLocalizedString("debug.enableDebugMode", bundle: bundle, comment: "Enable debug mode label")
        public static let debugModeDescription = NSLocalizedString("debug.debugModeDescription", bundle: bundle, comment: "Debug mode description")
        public static let performanceMetrics = NSLocalizedString("debug.performanceMetrics", bundle: bundle, comment: "Performance metrics label")
        public static let showMetrics = NSLocalizedString("debug.showMetrics", bundle: bundle, comment: "Show metrics button")
        public static let realTimeFactor = NSLocalizedString("debug.realTimeFactor", bundle: bundle, comment: "Real-time factor label")
        public static let transcriptionSpeed = NSLocalizedString("debug.transcriptionSpeed", bundle: bundle, comment: "Transcription speed label")

        // MediaRemote controls
        public static let mediaRemoteControls = NSLocalizedString("debug.mediaRemoteControls", bundle: bundle, comment: "MediaRemote controls section")
        public static let pause = NSLocalizedString("debug.pause", bundle: bundle, comment: "Pause button")
        public static let resume = NSLocalizedString("debug.resume", bundle: bundle, comment: "Resume button")
        public static let togglePlayPause = NSLocalizedString("debug.togglePlayPause", bundle: bundle, comment: "Toggle play/pause button")
        public static let getNowPlayingInfo = NSLocalizedString("debug.getNowPlayingInfo", bundle: bundle, comment: "Get now playing info button")

        // Audio ducking
        public static let audioDucking = NSLocalizedString("debug.audioDucking", bundle: bundle, comment: "Audio ducking section")
        public static let duck = NSLocalizedString("debug.duck", bundle: bundle, comment: "Duck button")
        public static let unduck = NSLocalizedString("debug.unduck", bundle: bundle, comment: "Unduck button")

        // Microphone volume
        public static let microphoneVolume = NSLocalizedString("debug.microphoneVolume", bundle: bundle, comment: "Microphone volume section")
        public static let boost = NSLocalizedString("debug.boost", bundle: bundle, comment: "Boost button")
        public static let restore = NSLocalizedString("debug.restore", bundle: bundle, comment: "Restore button")

        // Logs
        public static let logs = NSLocalizedString("debug.logs", bundle: bundle, comment: "Logs section")
        public static let copyCommand = NSLocalizedString("debug.copyCommand", bundle: bundle, comment: "Copy command button")
    }

    // MARK: - File Transcription

    public enum FileTranscription {
        public static let title = NSLocalizedString("fileTranscription.title", bundle: bundle, comment: "File transcription title")
        public static let mode = NSLocalizedString("fileTranscription.mode", bundle: bundle, comment: "Transcription mode label")
        public static let vadMode = NSLocalizedString("fileTranscription.vadMode", bundle: bundle, comment: "VAD mode label")
        public static let vadModeDescription = NSLocalizedString("fileTranscription.vadModeDescription", bundle: bundle, comment: "VAD mode description")
        public static let batchMode = NSLocalizedString("fileTranscription.batchMode", bundle: bundle, comment: "Batch mode label")
        public static let batchModeDescription = NSLocalizedString("fileTranscription.batchModeDescription", bundle: bundle, comment: "Batch mode description")
        public static let vadAlgorithm = NSLocalizedString("fileTranscription.vadAlgorithm", bundle: bundle, comment: "VAD algorithm label")
        public static let selectFile = NSLocalizedString("fileTranscription.selectFile", bundle: bundle, comment: "Select file button")
        public static let startTranscription = NSLocalizedString("fileTranscription.startTranscription", bundle: bundle, comment: "Start transcription button")
        public static let stopTranscription = NSLocalizedString("fileTranscription.stopTranscription", bundle: bundle, comment: "Stop transcription button")
        public static let progress = NSLocalizedString("fileTranscription.progress", bundle: bundle, comment: "Progress label")
        public static let transcribing = NSLocalizedString("fileTranscription.transcribing", bundle: bundle, comment: "Transcribing status")
    }

    // MARK: - Permissions

    public enum Permissions {
        public static let microphoneRequired = NSLocalizedString("permissions.microphoneRequired", bundle: bundle, comment: "Microphone permission required")
        public static let microphoneDescription = NSLocalizedString("permissions.microphoneDescription", bundle: bundle, comment: "Microphone permission description")
        public static let openSettings = NSLocalizedString("permissions.openSettings", bundle: bundle, comment: "Open settings button")
        public static let permissionDenied = NSLocalizedString("permissions.permissionDenied", bundle: bundle, comment: "Permission denied title")
    }

    // MARK: - Errors

    public enum Errors {
        public static let title = NSLocalizedString("errors.title", bundle: bundle, comment: "Error dialog title")
        public static let modelLoadFailed = NSLocalizedString("errors.modelLoadFailed", bundle: bundle, comment: "Model load failed error")
        public static let modelNotSupported = NSLocalizedString("errors.modelNotSupported", bundle: bundle, comment: "Model not supported error")
        public static let modelDownloadFailed = NSLocalizedString("errors.modelDownloadFailed", bundle: bundle, comment: "Model download failed error")
        public static let modelDeleteFailed = NSLocalizedString("errors.modelDeleteFailed", bundle: bundle, comment: "Model delete failed error")
        public static let recordingFailed = NSLocalizedString("errors.recordingFailed", bundle: bundle, comment: "Recording failed error")
        public static let transcriptionFailed = NSLocalizedString("errors.transcriptionFailed", bundle: bundle, comment: "Transcription failed error")
        public static let audioDeviceError = NSLocalizedString("errors.audioDeviceError", bundle: bundle, comment: "Audio device error")
        public static let unknownError = NSLocalizedString("errors.unknownError", bundle: bundle, comment: "Unknown error")
        public static let tryAgain = NSLocalizedString("errors.tryAgain", bundle: bundle, comment: "Try again button")
        public static let dismiss = NSLocalizedString("errors.dismiss", bundle: bundle, comment: "Dismiss button")
    }

    // MARK: - Status Messages

    public enum Status {
        public static let ready = NSLocalizedString("status.ready", bundle: bundle, comment: "Ready status")
        public static let recording = NSLocalizedString("status.recording", bundle: bundle, comment: "Recording status")
        public static let processing = NSLocalizedString("status.processing", bundle: bundle, comment: "Processing status")
        public static let transcribing = NSLocalizedString("status.transcribing", bundle: bundle, comment: "Transcribing status")
        public static let completed = NSLocalizedString("status.completed", bundle: bundle, comment: "Completed status")
        public static let cancelled = NSLocalizedString("status.cancelled", bundle: bundle, comment: "Cancelled status")
        public static let modelLoading = NSLocalizedString("status.modelLoading", bundle: bundle, comment: "Model loading status")
        public static let modelLoaded = NSLocalizedString("status.modelLoaded", bundle: bundle, comment: "Model loaded status")
    }

    // MARK: - Buttons

    public enum Buttons {
        public static let ok = NSLocalizedString("buttons.ok", bundle: bundle, comment: "OK button")
        public static let cancel = NSLocalizedString("buttons.cancel", bundle: bundle, comment: "Cancel button")
        public static let delete = NSLocalizedString("buttons.delete", bundle: bundle, comment: "Delete button")
        public static let save = NSLocalizedString("buttons.save", bundle: bundle, comment: "Save button")
        public static let apply = NSLocalizedString("buttons.apply", bundle: bundle, comment: "Apply button")
        public static let close = NSLocalizedString("buttons.close", bundle: bundle, comment: "Close button")
        public static let done = NSLocalizedString("buttons.done", bundle: bundle, comment: "Done button")
        public static let add = NSLocalizedString("buttons.add", bundle: bundle, comment: "Add button")
        public static let remove = NSLocalizedString("buttons.remove", bundle: bundle, comment: "Remove button")
        public static let edit = NSLocalizedString("buttons.edit", bundle: bundle, comment: "Edit button")
        public static let export = NSLocalizedString("buttons.export", bundle: bundle, comment: "Export button")
        public static let `import` = NSLocalizedString("buttons.import", bundle: bundle, comment: "Import button")
    }

    // MARK: - Units

    public enum Units {
        public static let seconds = NSLocalizedString("units.seconds", bundle: bundle, comment: "Seconds unit")
        public static let minutes = NSLocalizedString("units.minutes", bundle: bundle, comment: "Minutes unit")
        public static let hours = NSLocalizedString("units.hours", bundle: bundle, comment: "Hours unit")
        public static let kilobytes = NSLocalizedString("units.kilobytes", bundle: bundle, comment: "Kilobytes unit")
        public static let megabytes = NSLocalizedString("units.megabytes", bundle: bundle, comment: "Megabytes unit")
        public static let gigabytes = NSLocalizedString("units.gigabytes", bundle: bundle, comment: "Gigabytes unit")
    }

    // MARK: - Quality Enhancement

    public enum Quality {
        public static let title = NSLocalizedString("quality.title", bundle: bundle, comment: "Quality enhancement title")
        public static let enabled = NSLocalizedString("quality.enabled", bundle: bundle, comment: "Enable quality enhancement")
        public static let enabledDescription = NSLocalizedString("quality.enabledDescription", bundle: bundle, comment: "Quality enhancement description")
        public static let temperatureFallback = NSLocalizedString("quality.temperatureFallback", bundle: bundle, comment: "Temperature fallback label")
        public static let temperatureFallbackDescription = NSLocalizedString("quality.temperatureFallbackDescription", bundle: bundle, comment: "Temperature fallback description")
        public static let compressionRatio = NSLocalizedString("quality.compressionRatio", bundle: bundle, comment: "Compression ratio label")
        public static let compressionRatioDescription = NSLocalizedString("quality.compressionRatioDescription", bundle: bundle, comment: "Compression ratio description")
        public static let logProbThreshold = NSLocalizedString("quality.logProbThreshold", bundle: bundle, comment: "Log probability threshold label")
        public static let logProbThresholdDescription = NSLocalizedString("quality.logProbThresholdDescription", bundle: bundle, comment: "Log probability threshold description")
    }

    // MARK: - VAD Algorithms

    public enum VADAlgorithms {
        public static let spectralTelephone = NSLocalizedString("vadAlgorithms.spectralTelephone", bundle: bundle, comment: "Spectral VAD - Telephone")
        public static let spectralTelephoneDescription = NSLocalizedString("vadAlgorithms.spectralTelephoneDescription", bundle: bundle, comment: "Spectral VAD - Telephone description")
        public static let spectralWideband = NSLocalizedString("vadAlgorithms.spectralWideband", bundle: bundle, comment: "Spectral VAD - Wideband")
        public static let spectralWidebandDescription = NSLocalizedString("vadAlgorithms.spectralWidebandDescription", bundle: bundle, comment: "Spectral VAD - Wideband description")
        public static let spectralDefault = NSLocalizedString("vadAlgorithms.spectralDefault", bundle: bundle, comment: "Spectral VAD - Default")
        public static let spectralDefaultDescription = NSLocalizedString("vadAlgorithms.spectralDefaultDescription", bundle: bundle, comment: "Spectral VAD - Default description")
        public static let adaptiveLowQuality = NSLocalizedString("vadAlgorithms.adaptiveLowQuality", bundle: bundle, comment: "Adaptive VAD - Low Quality")
        public static let adaptiveLowQualityDescription = NSLocalizedString("vadAlgorithms.adaptiveLowQualityDescription", bundle: bundle, comment: "Adaptive VAD - Low Quality description")
        public static let adaptiveAggressive = NSLocalizedString("vadAlgorithms.adaptiveAggressive", bundle: bundle, comment: "Adaptive VAD - Aggressive")
        public static let adaptiveAggressiveDescription = NSLocalizedString("vadAlgorithms.adaptiveAggressiveDescription", bundle: bundle, comment: "Adaptive VAD - Aggressive description")
        public static let standardLowQuality = NSLocalizedString("vadAlgorithms.standardLowQuality", bundle: bundle, comment: "Standard VAD - Low Quality")
        public static let standardLowQualityDescription = NSLocalizedString("vadAlgorithms.standardLowQualityDescription", bundle: bundle, comment: "Standard VAD - Low Quality description")
        public static let standardHighQuality = NSLocalizedString("vadAlgorithms.standardHighQuality", bundle: bundle, comment: "Standard VAD - High Quality")
        public static let standardHighQualityDescription = NSLocalizedString("vadAlgorithms.standardHighQualityDescription", bundle: bundle, comment: "Standard VAD - High Quality description")
    }

    // MARK: - Notifications

    public enum Notifications {
        public static let recordingStarted = NSLocalizedString("notifications.recordingStarted", bundle: bundle, comment: "Recording started notification")
        public static let recordingStopped = NSLocalizedString("notifications.recordingStopped", bundle: bundle, comment: "Recording stopped notification")
        public static let transcriptionCompleted = NSLocalizedString("notifications.transcriptionCompleted", bundle: bundle, comment: "Transcription completed notification")
        public static let modelChanged = NSLocalizedString("notifications.modelChanged", bundle: bundle, comment: "Model changed notification")
        public static let modelDownloaded = NSLocalizedString("notifications.modelDownloaded", bundle: bundle, comment: "Model downloaded notification")
        public static let modelDeleted = NSLocalizedString("notifications.modelDeleted", bundle: bundle, comment: "Model deleted notification")
    }
}
