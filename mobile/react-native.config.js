module.exports = {
  // Makes `npx react-native-asset` copy .tflite files into Android assets folder
  assets: ['./assets/models/'],
  dependencies: {
    'react-native-vector-icons': {
      platforms: {
        ios: null, // Android only in this project
      },
    },
  },
};
