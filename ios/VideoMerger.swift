import AVFoundation
import React

@objc(VideoMerger)
class VideoMerger: NSObject {
    
    private var activeExportSession: AVAssetExportSession?

    // Indicates whether the module requires setup on the main queue
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }

    // Clean up any active export sessions
    private func cleanupResources() {
        activeExportSession?.cancelExport()
        activeExportSession = nil
    }

    deinit {
        cleanupResources()
    }

    @objc
    func mergeVideos(
        _ videoPaths: [String],
        outputPath: String,
        resolver: @escaping RCTPromiseResolveBlock,
        rejecter: @escaping RCTPromiseRejectBlock
    ) {
        // Clean up any existing export session
        cleanupResources()

        // Ensure there are at least two videos to merge
        guard videoPaths.count >= 2 else {
            rejecter("invalid_argument", "At least two videos are required to merge.", nil)
            return
        }

        let mixComposition = AVMutableComposition()
        var currentTime = CMTime.zero
        var assets: [AVAsset] = []
        var loadingError: Error?

        // Pre-load assets for each video path
        for videoPath in videoPaths {
            autoreleasepool {
                let videoURL = URL(fileURLWithPath: videoPath)
                let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                assets.append(asset)
            }
        }

        // Process each asset to add its tracks to the composition
        for (index, asset) in assets.enumerated() {
            autoreleasepool {
                guard loadingError == nil else { return }
                
                // Load tracks asynchronously and wait for the completion
                let semaphore = DispatchSemaphore(value: 0)
                asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                    semaphore.signal()
                }
                semaphore.wait()

                // Check if tracks are successfully loaded
                var isReadyForTracks = false
                do {
                    isReadyForTracks = try asset.statusOfValue(forKey: "tracks", error: nil) == .loaded
                } catch let trackError {
                    loadingError = trackError
                    return
                }

                guard isReadyForTracks, !asset.tracks.isEmpty else {
                    loadingError = NSError(domain: "VideoMerger", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not load video at index \(index)"
                    ])
                    return
                }

                // Add video track to composition
                if let videoTrack = asset.tracks(withMediaType: .video).first {
                    autoreleasepool {
                        guard let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                            loadingError = NSError(domain: "VideoMerger", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "Failed to create video track"
                            ])
                            return
                        }

                        do {
                            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: currentTime)
                        } catch let insertError {
                            loadingError = insertError
                            return
                        }
                    }
                }

                // Add audio track to composition if it exists
                if let audioTrack = asset.tracks(withMediaType: .audio).first {
                    autoreleasepool {
                        guard let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                            loadingError = NSError(domain: "VideoMerger", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "Failed to create audio track"
                            ])
                            return
                        }

                        do {
                            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: currentTime)
                        } catch let insertError {
                            loadingError = insertError
                            return
                        }
                    }
                }

                // Update current time for the next asset
                currentTime = CMTimeAdd(currentTime, asset.duration)
            }
        }

        // Handle any errors encountered during processing
        if let error = loadingError {
            rejecter("processing_failed", error.localizedDescription, error)
            return
        }

        let outputURL = URL(fileURLWithPath: outputPath)

        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)

        // Initialize export session
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetMediumQuality) else {
            rejecter("export_failed", "Failed to create export session", nil)
            return
        }

        // Configure export session
        self.activeExportSession = exportSession
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // Start export asynchronously on a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let exportSemaphore = DispatchSemaphore(value: 0)

            exportSession.exportAsynchronously {
                defer {
                    exportSemaphore.signal()
                    self?.cleanupResources()
                }

                // Handle export completion on main queue
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        resolver(outputPath)
                    case .failed:
                        if let exportError = exportSession.error {
                            rejecter("export_failed", exportError.localizedDescription, exportError)
                        } else {
                            rejecter("export_failed", "Unknown error occurred during export", nil)
                        }
                    case .cancelled:
                        rejecter("export_cancelled", "Export was cancelled", nil)
                    default:
                        rejecter("export_unknown", "Unknown export status", nil)
                    }
                }
            }

            exportSemaphore.wait()
        }
    }
}
