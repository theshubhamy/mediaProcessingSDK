// src/VideoMerger.js
import {NativeModules} from 'react-native';
const {VideoMerger} = NativeModules;
console.log(NativeModules.VideoMerger);
const mergeVideos = async (videoPaths, outputPath) => {
  try {
    const result = await VideoMerger.mergeVideos(videoPaths, outputPath);
    return result;
  } catch (error) {
    console.error('Video merge failed:', error);
    throw error;
  }
};

export default mergeVideos;
