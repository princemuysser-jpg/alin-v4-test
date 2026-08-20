package com.alin.platform;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String LOCATION_CHANNEL = "com.alin.platform/native_location";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                LOCATION_CHANNEL
        ).setMethodCallHandler(this::handleLocationCall);
    }

    private void handleLocationCall(MethodCall call, MethodChannel.Result result) {
        if (!"getQuickLocation".equals(call.method)) {
            result.notImplemented();
            return;
        }
        getQuickLocation(result);
    }

    private void getQuickLocation(MethodChannel.Result result) {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("location_permission", "Location permission is not granted", null);
            return;
        }

        LocationManager manager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        if (manager == null) {
            result.success(null);
            return;
        }

        Location cached = bestLastKnown(manager);
        if (isGoodCached(cached)) {
            result.success(locationMap(cached));
            return;
        }

        new QuickLocationRequest(manager, result, cached).start();
    }

    private Location bestLastKnown(LocationManager manager) {
        Location best = null;
        String[] providers = new String[]{
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER,
                LocationManager.GPS_PROVIDER
        };
        for (String provider : providers) {
            try {
                if (!manager.getAllProviders().contains(provider)) continue;
                Location value = manager.getLastKnownLocation(provider);
                if (isBetter(value, best)) best = value;
            } catch (SecurityException | IllegalArgumentException ignored) {
            }
        }
        return best;
    }

    private boolean isGoodCached(Location location) {
        if (location == null) return false;
        long ageMs = Math.max(0L, System.currentTimeMillis() - location.getTime());
        float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
        return ageMs <= 5 * 60 * 1000L && accuracy <= 1500f;
    }

    private boolean isBetter(Location candidate, Location current) {
        if (candidate == null) return false;
        if (current == null) return true;
        long timeDelta = candidate.getTime() - current.getTime();
        if (timeDelta > 30_000L) return true;
        if (timeDelta < -30_000L) return false;
        float candidateAccuracy = candidate.hasAccuracy() ? candidate.getAccuracy() : 99999f;
        float currentAccuracy = current.hasAccuracy() ? current.getAccuracy() : 99999f;
        return candidateAccuracy < currentAccuracy;
    }

    private Map<String, Object> locationMap(Location location) {
        Map<String, Object> map = new HashMap<>();
        map.put("latitude", location.getLatitude());
        map.put("longitude", location.getLongitude());
        map.put("accuracy", location.hasAccuracy() ? (double) location.getAccuracy() : 0d);
        map.put("timestamp", location.getTime());
        map.put("provider", location.getProvider());
        return map;
    }

    private final class QuickLocationRequest implements LocationListener {
        private final LocationManager manager;
        private final MethodChannel.Result result;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final AtomicBoolean finished = new AtomicBoolean(false);
        private Location best;

        QuickLocationRequest(LocationManager manager, MethodChannel.Result result, Location initial) {
            this.manager = manager;
            this.result = result;
            this.best = initial;
        }

        void start() {
            boolean requested = false;
            try {
                if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    manager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0L, 0f, this, Looper.getMainLooper());
                    requested = true;
                }
            } catch (SecurityException | IllegalArgumentException ignored) {
            }
            try {
                if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    manager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0L, 0f, this, Looper.getMainLooper());
                    requested = true;
                }
            } catch (SecurityException | IllegalArgumentException ignored) {
            }

            if (!requested) {
                finish(best);
                return;
            }
            handler.postDelayed(() -> finish(isAcceptable(best) ? best : null), 10_000L);
        }

        @Override
        public void onLocationChanged(Location location) {
            if (isBetter(location, best)) best = location;
            if (location == null) return;
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            String provider = location.getProvider();
            if ((LocationManager.NETWORK_PROVIDER.equals(provider) && accuracy <= 1500f) || accuracy <= 500f) {
                finish(location);
            }
        }

        @Override
        public void onStatusChanged(String provider, int status, Bundle extras) {
        }

        @Override
        public void onProviderEnabled(String provider) {
        }

        @Override
        public void onProviderDisabled(String provider) {
        }


        private boolean isAcceptable(Location location) {
            if (location == null) return false;
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            return accuracy <= 2000f;
        }

        private void finish(Location location) {
            if (!finished.compareAndSet(false, true)) return;
            handler.removeCallbacksAndMessages(null);
            try {
                manager.removeUpdates(this);
            } catch (SecurityException ignored) {
            }
            result.success(location == null ? null : locationMap(location));
        }
    }
}
