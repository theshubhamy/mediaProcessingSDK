#import "VideoMerger.h"
#import <AVFoundation/AVFoundation.h>

@implementation VideoMerger

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(mergeVideos
                  : (NSArray<NSString *> *)videoPaths outputPath
                  : (NSString *)outputPath resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
  if (videoPaths.count < 2) {
    reject(@"invalid_argument", @"At least two videos are required to merge.",
           nil);
    return;
  }

  // Create a composition to hold the video tracks
  AVMutableComposition *mixComposition = [AVMutableComposition composition];
  CMTime currentTime = kCMTimeZero;

  for (NSString *videoPath in videoPaths) {
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    AVAsset *asset = [AVAsset assetWithURL:videoURL];

    if (asset == nil || asset.tracks.count == 0) {
      reject(@"invalid_video",
             [NSString stringWithFormat:@"Could not load video at path %@",
                                        videoPath],
             nil);
      return;
    }

    // Add video track to composition
    AVMutableCompositionTrack *compositionTrack = [mixComposition
        addMutableTrackWithMediaType:AVMediaTypeVideo
                    preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionTrack
        insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo]
                            firstObject]
                 atTime:currentTime
                  error:nil];

    // Add audio track (optional)
    if ([asset tracksWithMediaType:AVMediaTypeAudio].count > 0) {
      AVMutableCompositionTrack *audioTrack = [mixComposition
          addMutableTrackWithMediaType:AVMediaTypeAudio
                      preferredTrackID:kCMPersistentTrackID_Invalid];
      [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                          ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio]
                                      firstObject]
                           atTime:currentTime
                            error:nil];
    }

    // Update the current time to be at the end of the last inserted video
    currentTime = CMTimeAdd(currentTime, asset.duration);
  }

  // Set up export session
  NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
  AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]
      initWithAsset:mixComposition
         presetName:AVAssetExportPresetHighestQuality];
  exportSession.outputURL = outputURL;
  exportSession.outputFileType = AVFileTypeMPEG4;

  // Export the composition asynchronously
  [exportSession exportAsynchronouslyWithCompletionHandler:^{
    switch ([exportSession status]) {
    case AVAssetExportSessionStatusCompleted:
      resolve(outputPath);
      break;
    case AVAssetExportSessionStatusFailed:
      reject(@"merge_failed", @"Video merge failed", exportSession.error);
      break;
    default:
      reject(@"merge_failed", @"Video merge failed with unknown error", nil);
      break;
    }
  }];
}

@end
