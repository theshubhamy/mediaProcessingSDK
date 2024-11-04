import React, {useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Dimensions,
} from 'react-native';
import {launchImageLibrary} from 'react-native-image-picker';
import Video from 'react-native-video';
import mergeVideos from './VideoMerger';
import RNFS from 'react-native-fs';
const {width, height} = Dimensions.get('window');

const VideoPicker = () => {
  const [videos, setVideos] = useState([]);
  const [mergedVideoPath, setMergedVideoPath] = useState(null);
  const pickVideos = () => {
    const options = {
      mediaType: 'video',
      selectionLimit: 0,
    };

    launchImageLibrary(options, response => {
      if (response.didCancel) {
        console.log('User cancelled video picker');
      } else if (response.error) {
        console.error('VideoPicker Error: ', response.error);
      } else {
        const selectedVideos = response.assets.map(asset => ({
          uri: asset.uri,
          type: asset.type,
          fileName: asset.fileName,
        }));
        setVideos(selectedVideos);
      }
    });
  };
  const mergeSelectedVideos = async () => {
    if (videos.length < 2) {
      return;
    }

    try {
      // Prepare video URIs and output path
      const videoPaths = videos.map(video => decodeURIComponent(video.uri));
      const outputPath = `${RNFS.DocumentDirectoryPath}/mergedVideo.mp4`;

      // Call the native merge function
      const result = await mergeVideos(videoPaths, outputPath);
      setMergedVideoPath(result);
    } catch (error) {
      console.error('Failed to merge videos:', error);
    }
  };

  return (
    <View style={styles.container}>
      {videos?.map((item, index) => {
        return (
          <View key={index}>
            <Video
              source={{uri: item?.uri}}
              style={styles.thumbnail}
              controls
              muted
              resizeMode="cover"
            />
          </View>
        );
      })}
      {videos?.length === 0 ? (
        <TouchableOpacity style={styles.button} onPress={pickVideos}>
          <Text style={styles.buttonText}>Pick Videos</Text>
        </TouchableOpacity>
      ) : (
        <TouchableOpacity style={styles.button} onPress={mergeSelectedVideos}>
          <Text style={styles.buttonText}>Merge Videos</Text>
        </TouchableOpacity>
      )}
      {mergedVideoPath && (
        <View style={styles.resultContainer}>
          <Text>Output Video Path:</Text>
          <Text style={styles.resultPath}>{mergedVideoPath}</Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    width: width,
    height: height,
  },
  videoContainer: {
    marginVertical: 10,
    alignItems: 'center',
  },
  videoText: {
    marginBottom: 5,
  },
  thumbnail: {
    width: width,
    height: height * 0.3,
    borderRadius: 10,
  },
  button: {
    backgroundColor: '#1E90FF',
    padding: 15,
    borderRadius: 10,
    marginVertical: 10,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    textAlign: 'center',
  },
  resultContainer: {
    marginTop: 20,
    alignItems: 'center',
  },
  resultPath: {
    marginTop: 5,
    color: 'blue',
  },
});

export default VideoPicker;
