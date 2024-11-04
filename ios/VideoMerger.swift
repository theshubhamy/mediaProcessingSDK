import AVFoundation
import React

@objc(VideoMerger)
class VideoMerger: NSObject {

    private var activeExportSession: AVAssetExportSession?

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }

    private func cleanupResources() {
        activeExportSession?.cancelExport()
        activeExportSession = nil
    }

    deinit {
        cleanupResources()
    }

    @objc
    func mergeVideos(_ videoPaths: [String], outputPath: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        // Clean up any existing export session
        cleanupResources()

        guard videoPaths.count >= 2 else {
            rejecter("invalid_argument", "At least two videos are required to merge.", nil)
            return
        }

        // Create composition outside of loop to avoid memory accumulation
        let mixComposition = AVMutableComposition()
        var currentTime = CMTime.zero
        var assets: [AVAsset] = []
        var error: Error?

        // Pre-load assets
        for videoPath in videoPaths {
            autoreleasepool {
                let videoURL = URL(fileURLWithPath: videoPath)
                let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                assets.append(asset)
            }
        }

        // Process each asset
        for (index, asset) in assets.enumerated() {
            autoreleasepool {
                guard error == nil else { return }

                // Load tracks synchronously to catch any issues early
                let semaphore = DispatchSemaphore(value: 0)
                asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                    semaphore.signal()
                }
                semaphore.wait()

                var isReadyForTracks = false
                do {
                    isReadyForTracks = try asset.statusOfValue(forKey: "tracks", error: nil) == .loaded
                } catch let trackError {
                    error = trackError
                    return
                }

                guard isReadyForTracks, !asset.tracks.isEmpty else {
                    error = NSError(domain: "VideoMerger", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Could not load video at index \(index)"])
                    return
                }

                // Handle video track
                if let videoTrack = asset.tracks(withMediaType: .video).first {
                    autoreleasepool {
                        guard let compositionTrack = mixComposition.addMutableTrack(
                            withMediaType: .video,
                            preferredTrackID: kCMPersistentTrackID_Invalid) else {
                            error = NSError(domain: "VideoMerger", code: -1,
                                          userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
                            return
                        }

                        do {
                            try compositionTrack.insertTimeRange(
                                CMTimeRange(start: .zero, duration: asset.duration),
                                of: videoTrack,
                                at: currentTime)
                        } catch let insertError {
                            error = insertError
                            return
                        }
                    }
                }

                // Handle audio track
                if let audioTrack = asset.tracks(withMediaType: .audio).first {
                    autoreleasepool {
                        guard let compositionAudioTrack = mixComposition.addMutableTrack(
                            withMediaType: .audio,
                            preferredTrackID: kCMPersistentTrackID_Invalid) else {
                            error = NSError(domain: "VideoMerger", code: -1,
                                          userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
                            return
                        }

                        do {
                            try compositionAudioTrack.insertTimeRange(
                                CMTimeRange(start: .zero, duration: asset.duration),
                                of: audioTrack,
                                at: currentTime)
                        } catch let insertError {
                            error = insertError
                            return
                        }
                    }
                }

                currentTime = CMTimeAdd(currentTime, asset.duration)
            }
        }

        // Check for errors during processing
        if let error = error {
            rejecter("processing_failed", error.localizedDescription, error)
            return
        }

        let outputURL = URL(fileURLWithPath: outputPath)

        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: mixComposition,
            presetName: AVAssetExportPresetMediumQuality) else {
            rejecter("export_failed", "Failed to create export session", nil)
            return
        }

        // Keep reference to current export session
        self.activeExportSession = exportSession

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // Use background queue for export
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let exportSemaphore = DispatchSemaphore(value: 0)

            exportSession.exportAsynchronously {
                defer {
                    exportSemaphore.signal()
                    self?.cleanupResources()
                }

                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        resolver(outputPath)
                    case .failed:
                        rejecter("merge_failed",
                                "Video merge failed: \(exportSession.error?.localizedDescription ?? "unknown error")",
                                exportSession.error)
                    case .cancelled:
                        rejecter("merge_cancelled", "Video merge was cancelled", nil)
                    default:
                        rejecter("merge_failed", "Video merge failed with unknown error", nil)
                    }
                }
            }

            exportSemaphore.wait()
        }
    }
}
