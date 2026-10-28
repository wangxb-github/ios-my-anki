import Foundation
public import AnkiBackend
public import AnkiProto
import AnkiKit
import Logging

private let logger = Logger(label: "com.ankiapp.media.downloader")

/// Manages media file downloads with batching, retry, and progress tracking
/// Coordinates with Rust backend's syncMedia by wrapping it with retry logic and monitoring MediaSyncStatus
public actor MediaDownloader: Sendable {
    private let backend: AnkiBackend
    private let session: MediaSyncSession

    public init(
        backend: AnkiBackend,
        session: MediaSyncSession
    ) {
        self.backend = backend
        self.session = session
    }

    // MARK: - Public API

    /// Sync media with automatic retry and real-time MediaSyncStatus polling
    public func syncMediaWithRetry(
        auth: Anki_Sync_SyncAuth,
        maxAttempts: Int = 5
    ) async -> AsyncThrowingStream<MediaSyncProgressEvent, any Error> {
        let backendRef = self.backend
        return AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                do {
                    guard let self = self else { return }

                    for attempt in 1...maxAttempts {
                        let delayMs = await self.session.getCurrentDelayMs()

                        if attempt > 1 {
                            try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                        }

                        do {
                            continuation.yield(.connecting)
                            try await self.runAndMonitorBackendSyncMedia(
                                auth: auth,
                                continuation: continuation
                            )
                            continuation.yield(.completed)
                            continuation.finish()
                            return
                        } catch is CancellationError {
                            try? backendRef.callVoid(
                                service: AnkiBackend.Service.sync,
                                method: AnkiBackend.SyncMethod.abortMediaSync
                            )
                            throw CancellationError()
                        } catch let error as BackendError {
                            if error.isSyncAuthError {
                                throw SyncError.authFailed
                            }

                            if error.message.contains("429") {
                                await self.session.handleHTTP429()
                            }

                            if attempt == maxAttempts {
                                throw SyncError(message: error.message)
                            }

                            logger.warning("Media sync attempt \(attempt) failed, will retry: \(error.message)")
                            continuation.yield(.retrying(attempt: attempt, delayMs: delayMs))
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                try? backendRef.callVoid(
                    service: AnkiBackend.Service.sync,
                    method: AnkiBackend.SyncMethod.abortMediaSync
                )
            }
        }
    }

    // MARK: - Private Helpers

    private func runAndMonitorBackendSyncMedia(
        auth: Anki_Sync_SyncAuth,
        continuation: AsyncThrowingStream<MediaSyncProgressEvent, any Error>.Continuation
    ) async throws {
        logger.info("Calling backend syncMedia RPC (spawns background thread in Rust)")

        // 1. Start the background media sync thread in Rust
        try backend.callVoid(
            service: AnkiBackend.Service.sync,
            method: AnkiBackend.SyncMethod.syncMedia,
            request: auth
        )

        var lastReportedAdded = -1
        var lastReportedChecked = -1

        // 2. Poll MediaSyncStatus (method 2) until status.active == false.
        // Note: In Rust, get_media_sync_status joins the thread when finished and throws any inner error.
        while true {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 250_000_000)

            let status: Anki_Sync_MediaSyncStatusResponse = try backend.invoke(
                service: AnkiBackend.Service.sync,
                method: AnkiBackend.SyncMethod.mediaSyncStatus
            )

            if status.hasProgress {
                let addedCount = Self.extractDownloadedCount(from: status.progress.added)
                let checkedCount = Self.extractCheckedCount(from: status.progress.checked)
                if addedCount != lastReportedAdded || checkedCount != lastReportedChecked {
                    lastReportedAdded = addedCount
                    lastReportedChecked = checkedCount
                    continuation.yield(
                        .progress(
                            downloaded: max(0, addedCount),
                            total: max(addedCount, checkedCount)
                        )
                    )
                }
            }

            if !status.active {
                break
            }
        }

        logger.info("Backend syncMedia completed and verified via MediaSyncStatus")
    }

    private nonisolated static func extractDownloadedCount(from addedText: String) -> Int {
        // Anki formats media added progress as:
        // "Added: {up}↑ {down}↓" or "已新增：{up}↑ {down}↓"
        // First integer is uploaded_files ({up}), second integer is downloaded_files ({down}).
        let numbers = addedText.split { !$0.isNumber }.compactMap { Int($0) }
        if numbers.count >= 2 {
            return numbers[1]
        }
        return numbers.last ?? 0
    }

    private nonisolated static func extractCheckedCount(from checkedText: String) -> Int {
        // Format: "Checked {count}" or "已检查：{count}"
        let numbers = checkedText.split { !$0.isNumber }.compactMap { Int($0) }
        return numbers.last ?? 0
    }
}

// MARK: - Progress Event Type

public enum MediaSyncProgressEvent: Sendable {
    case connecting
    case fetchingIndex
    case progress(downloaded: Int, total: Int)
    case retrying(attempt: Int, delayMs: Int)
    case completed
}
