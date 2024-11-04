//
//  VideoMerger.m
//  mediaProcessingSDK
//
//  Created by shubham kumar on 02/11/24.
//

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(VideoMerger, NSObject)

RCT_EXTERN_METHOD(mergeVideos:(NSArray *)videoPaths
                  outputPath:(NSString *)outputPath
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

@end


