//
//  VideoMerger.swift
//  mediaProcessingSDK
//
//  Created by shubham kumar on 02/11/24.
//

import AVFoundation
import React

@objc(VideoMerger)
class VideoMerger: NSObject {

  @objc
  func mergeVideos(_ videoPaths: [String], outputPath: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
      guard videoPaths.count >= 2 else {
          rejecter("invalid_argument", "At least two videos are required to merge.", nil)
          return
      }

      let mixComposition = AVMutableComposition()
      var currentTime = CMTime.zero

      for videoPath in videoPaths {
          autoreleasepool {
              let videoURL = URL(fileURLWithPath: videoPath)
              let asset = AVAsset(url: videoURL)

              guard !asset.tracks.isEmpty else {
                  rejecter("invalid_video", "Could not load video at path \(videoPath)", nil)
                  return
              }

              guard let compositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                  rejecter("insert_failed", "Failed to create video track", nil)
                  return
              }

              do {
                  try compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: asset.tracks(withMediaType: .video)[0], at: currentTime)
              } catch {
                  rejecter("insert_failed", "Failed to insert video track: \(error.localizedDescription)", nil)
                  return
              }

              if let audioTrackAsset = asset.tracks(withMediaType: .audio).first {
                  guard let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                      rejecter("insert_failed", "Failed to create audio track", nil)
                      return
                  }
                  do {
                      try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrackAsset, at: currentTime)
                  } catch {
                      rejecter("insert_failed", "Failed to insert audio track: \(error.localizedDescription)", nil)
                      return
                  }
              }

              currentTime = currentTime + asset.duration
          }
      }

      let outputURL = URL(fileURLWithPath: outputPath)
      guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
          rejecter("export_failed", "Failed to create export session", nil)
          return
      }

      exportSession.outputURL = outputURL
      exportSession.outputFileType = .mp4

      DispatchQueue.global(qos: .background).async {
          exportSession.exportAsynchronously {
              DispatchQueue.main.async {
                  switch exportSession.status {
                  case .completed:
                      resolver(outputPath)
                  case .failed:
                      rejecter("merge_failed", "Video merge failed: \(exportSession.error?.localizedDescription ?? "unknown error")", nil)
                  case .cancelled:
                      rejecter("merge_cancelled", "Video merge was cancelled", nil)
                  default:
                      rejecter("merge_failed", "Video merge failed with unknown error", nil)
                  }
              }
          }
      }
  }

}
