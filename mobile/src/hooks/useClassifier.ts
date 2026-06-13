import {useEffect} from 'react';
import {loadModel, isModelLoaded} from '../services/classifier';
import {useAppStore} from '../store/appStore';

/**
 * Loads the TFLite model on mount and tracks state in Zustand.
 * Call this once at the top of the app (inside App.tsx).
 */
export function useClassifier() {
  const {modelState, setModelState} = useAppStore();

  useEffect(() => {
    if (modelState !== 'idle') return;
    if (isModelLoaded()) {
      setModelState('ready');
      return;
    }

    setModelState('loading');
    loadModel()
      .then(() => setModelState('ready'))
      .catch(err => {
        console.error('[Classifier] Failed to load model:', err);
        setModelState('error', String(err));
      });
  }, [modelState, setModelState]);
}
