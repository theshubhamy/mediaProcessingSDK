import {useEffect, useState} from 'react';
import {Platform, Alert} from 'react-native';
import {
  checkMultiple,
  requestMultiple,
  RESULTS,
  PERMISSIONS,
} from 'react-native-permissions';

const usePermissions = () => {
  const [permissionsGranted, setPermissionsGranted] = useState({
    storage: false,
  });

  useEffect(() => {
    const requestPermissions = async () => {
      try {
        if (Platform.OS === 'ios') {
          const statuses = await checkMultiple([
            PERMISSIONS.IOS.PHOTO_LIBRARY,
            PERMISSIONS.IOS.PHOTO_LIBRARY_ADD_ONLY,
            PERMISSIONS.IOS.MEDIA_LIBRARY,
          ]);

          const storageGranted =
            statuses[PERMISSIONS.IOS.PHOTO_LIBRARY] === RESULTS.GRANTED;
          const storageAddGranted =
            statuses[PERMISSIONS.IOS.PHOTO_LIBRARY_ADD_ONLY] ===
            RESULTS.GRANTED;
          const storageMediaGranted =
            statuses[PERMISSIONS.IOS.MEDIA_LIBRARY] === RESULTS.GRANTED;

          if (!storageGranted || !storageAddGranted || !storageMediaGranted) {
            const newStatuses = await requestMultiple([
              PERMISSIONS.IOS.PHOTO_LIBRARY,
              PERMISSIONS.IOS.PHOTO_LIBRARY_ADD_ONLY,
              PERMISSIONS.IOS.MEDIA_LIBRARY,
            ]);

            setPermissionsGranted({
              storage:
                newStatuses[PERMISSIONS.IOS.PHOTO_LIBRARY] === RESULTS.GRANTED,
            });
          } else {
            setPermissionsGranted({
              storage: storageGranted,
            });
          }
        }
      } catch (err) {
        console.error('Permission Error:', err);

        Alert.alert(
          'Permission Error',
          'Failed to check or request permissions.',
          [
            {
              text: 'Cancel',
              onPress: () => console.log('Cancel Pressed'),
              style: 'cancel',
            },
          ],
          {
            cancelable: true,
            onDismiss: () => console.log('Cancel Pressed'),
          },
        );
      }
    };

    requestPermissions();
  }, []);

  return permissionsGranted;
};

export default usePermissions;
