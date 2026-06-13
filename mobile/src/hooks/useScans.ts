import {useState, useEffect, useCallback} from 'react';
import {allScans, recentScans, scansInLastDays} from '../services/database';
import {ScanRecord} from '../types/scanRecord';

export function useAllScans(refreshKey?: number) {
  const [scans, setScans] = useState<ScanRecord[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const data = await allScans();
      setScans(data);
    } catch (e) {
      console.error('[useAllScans]', e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh, refreshKey]);

  return {scans, loading, refresh};
}

export function useRecentScans(limit: number, refreshKey?: number) {
  const [scans, setScans] = useState<ScanRecord[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const data = await recentScans(limit);
      setScans(data);
    } finally {
      setLoading(false);
    }
  }, [limit]);

  useEffect(() => {
    refresh();
  }, [refresh, refreshKey]);

  return {scans, loading, refresh};
}

export function useScansLastDays(days: number, refreshKey?: number) {
  const [scans, setScans] = useState<ScanRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    scansInLastDays(days)
      .then(setScans)
      .finally(() => setLoading(false));
  }, [days, refreshKey]);

  return {scans, loading};
}
