// App.js
import React from 'react';
import {SafeAreaView} from 'react-native';
import VideoPicker from './src/VideoPicker';
import {StyleSheet} from 'react-native';
import usePermissions from './src/usePermissions';
const App = () => {
  usePermissions();
  return (
    <SafeAreaView style={styles.container}>
      <VideoPicker />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
export default App;
