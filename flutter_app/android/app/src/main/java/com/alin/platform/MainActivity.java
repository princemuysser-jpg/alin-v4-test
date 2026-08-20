package com.alin.platform;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;
import android.webkit.GeolocationPermissions;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.tasks.CancellationTokenSource;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String LOCATION_CHANNEL = "com.alin.platform/native_location";
    private static final String FUSED_PROVIDER = "fused";
    private static final String WEB_LOCATION_URL = "https://dgaikazhbtyjmswpyvrl.supabase.co/functions/v1/flutter-location-bridge";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                LOCATION_CHANNEL
        ).setMethodCallHandler(this::handleLocationCall);
    }

    private void handleLocationCall(MethodCall call, MethodChannel.Result result) {
        if ("getGoogleFusedLocation".equals(call.method)) {
            getGoogleFusedLocation(result);
            return;
        }
        if ("getQuickLocation".equals(call.method)) {
            getQuickLocation(result);
            return;
        }
        if ("getWebLocation".equals(call.method)) {
            getHiddenWebLocation(result);
            return;
        }
        result.notImplemented();
    }

    private boolean hasLocationPermission() {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private void getGoogleFusedLocation(MethodChannel.Result result) {
        if (!hasLocationPermission()) {
            result.error("location_permission", "Location permission is not granted", null);
            return;
        }

        int availability = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this);
        if (availability != ConnectionResult.SUCCESS) {
            result.success(null);
            return;
        }

        runOnUiThread(() -> new GoogleFusedLocationRequest(result).start());
    }

    private void getQuickLocation(MethodChannel.Result result) {
        if (!hasLocationPermission()) {
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

    private void getHiddenWebLocation(MethodChannel.Result result) {
        if (!hasLocationPermission()) {
            result.error("location_permission", "Location permission is not granted", null);
            return;
        }
        runOnUiThread(() -> new HiddenWebLocationRequest(result).start());
    }

    private String[] preferredProviders() {
        return new String[]{
                FUSED_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.GPS_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
        };
    }

    private Location bestLastKnown(LocationManager manager) {
        Location best = null;
        List<String> available = manager.getAllProviders();
        for (String provider : preferredProviders()) {
            try {
                if (!available.contains(provider)) continue;
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
        return ageMs <= 30_000L && accuracy <= 2000f;
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

    private final class GoogleFusedLocationRequest {
        private final MethodChannel.Result result;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final AtomicBoolean finished = new AtomicBoolean(false);
        private final CancellationTokenSource balancedToken = new CancellationTokenSource();
        private final CancellationTokenSource highAccuracyToken = new CancellationTokenSource();
        private final FusedLocationProviderClient client = LocationServices.getFusedLocationProviderClient(MainActivity.this);
        private Location best;
        private int currentRequestsFinished = 0;

        GoogleFusedLocationRequest(MethodChannel.Result result) {
            this.result = result;
        }

        void start() {
            try {
                client.getLastLocation()
                        .addOnSuccessListener(location -> {
                            if (location != null && isFreshEnough(location, 2 * 60 * 1000L, 3000f)) {
                                best = location;
                                finish(location);
                            } else if (isBetter(location, best)) {
                                best = location;
                            }
                        })
                        .addOnFailureListener(error -> { });

                requestCurrent(Priority.PRIORITY_BALANCED_POWER_ACCURACY, balancedToken);
                requestCurrent(Priority.PRIORITY_HIGH_ACCURACY, highAccuracyToken);
                handler.postDelayed(() -> finish(isAcceptableGoogle(best) ? best : null), 12_000L);
            } catch (RuntimeException error) {
                finish(null);
            }
        }

        private void requestCurrent(int priority, CancellationTokenSource token) {
            try {
                client.getCurrentLocation(priority, token.getToken())
                        .addOnSuccessListener(location -> {
                            if (location != null && isBetter(location, best)) best = location;
                            if (location != null && isAcceptableGoogle(location)) {
                                finish(location);
                                return;
                            }
                            markCurrentFinished();
                        })
                        .addOnFailureListener(error -> markCurrentFinished());
            } catch (RuntimeException error) {
                markCurrentFinished();
            }
        }

        private void markCurrentFinished() {
            currentRequestsFinished++;
            if (currentRequestsFinished >= 2 && isAcceptableGoogle(best)) finish(best);
        }

        private boolean isFreshEnough(Location location, long maxAgeMs, float maxAccuracy) {
            if (location == null) return false;
            long ageMs = Math.max(0L, System.currentTimeMillis() - location.getTime());
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            return ageMs <= maxAgeMs && accuracy <= maxAccuracy;
        }

        private boolean isAcceptableGoogle(Location location) {
            if (location == null) return false;
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            return accuracy <= 3000f;
        }

        private void finish(Location location) {
            if (!finished.compareAndSet(false, true)) return;
            handler.removeCallbacksAndMessages(null);
            try { balancedToken.cancel(); } catch (Exception ignored) { }
            try { highAccuracyToken.cancel(); } catch (Exception ignored) { }
            result.success(location == null ? null : locationMap(location));
        }
    }

    private final class QuickLocationRequest implements LocationListener {
        private final LocationManager manager;
        private final MethodChannel.Result result;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final AtomicBoolean finished = new AtomicBoolean(false);
        private final List<CancellationSignal> cancellationSignals = new ArrayList<>();
        private Location best;

        QuickLocationRequest(LocationManager manager, MethodChannel.Result result, Location initial) {
            this.manager = manager;
            this.result = result;
            this.best = initial;
        }

        void start() {
            boolean requested = false;
            List<String> available = manager.getAllProviders();
            for (String provider : preferredProviders()) {
                if (LocationManager.PASSIVE_PROVIDER.equals(provider)) continue;
                if (!available.contains(provider)) continue;

                try {
                    if (!manager.isProviderEnabled(provider)) continue;

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        CancellationSignal signal = new CancellationSignal();
                        cancellationSignals.add(signal);
                        manager.getCurrentLocation(
                                provider,
                                signal,
                                MainActivity.this.getMainExecutor(),
                                this::acceptLocation
                        );
                    }

                    manager.requestLocationUpdates(provider, 0L, 0f, this, Looper.getMainLooper());
                    requested = true;
                } catch (SecurityException | IllegalArgumentException ignored) {
                }
            }

            if (!requested) {
                finish(isAcceptable(best) ? best : null);
                return;
            }
            handler.postDelayed(() -> finish(isAcceptable(best) ? best : null), 15_000L);
        }

        private void acceptLocation(Location location) {
            if (finished.get() || location == null) return;
            if (isBetter(location, best)) best = location;
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            String provider = location.getProvider();
            if (FUSED_PROVIDER.equals(provider) && accuracy <= 2000f) {
                finish(location);
                return;
            }
            if (LocationManager.NETWORK_PROVIDER.equals(provider) && accuracy <= 2000f) {
                finish(location);
                return;
            }
            if (accuracy <= 700f) finish(location);
        }

        @Override
        public void onLocationChanged(Location location) {
            acceptLocation(location);
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
            return accuracy <= 2500f;
        }

        private void finish(Location location) {
            if (!finished.compareAndSet(false, true)) return;
            handler.removeCallbacksAndMessages(null);
            for (CancellationSignal signal : cancellationSignals) {
                try {
                    signal.cancel();
                } catch (Exception ignored) {
                }
            }
            cancellationSignals.clear();
            try {
                manager.removeUpdates(this);
            } catch (SecurityException ignored) {
            }
            result.success(location == null ? null : locationMap(location));
        }
    }

    private final class HiddenWebLocationRequest {
        private final MethodChannel.Result result;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final AtomicBoolean finished = new AtomicBoolean(false);
        private final String state = UUID.randomUUID().toString().replace("-", "");
        private WebView webView;

        HiddenWebLocationRequest(MethodChannel.Result result) {
            this.result = result;
        }

        void start() {
            webView = new WebView(MainActivity.this);
            WebSettings settings = webView.getSettings();
            settings.setJavaScriptEnabled(true);
            settings.setGeolocationEnabled(true);
            settings.setDomStorageEnabled(false);

            webView.setWebChromeClient(new WebChromeClient() {
                @Override
                public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                    callback.invoke(origin, hasLocationPermission(), false);
                }
            });

            webView.setWebViewClient(new WebViewClient() {
                @Override
                public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                    return handleReturnUri(request.getUrl());
                }

                @Override
                @SuppressWarnings("deprecation")
                public boolean shouldOverrideUrlLoading(WebView view, String url) {
                    return handleReturnUri(Uri.parse(url));
                }
            });

            webView.setAlpha(0.01f);
            webView.setTranslationX(-2000f);
            webView.setTranslationY(-2000f);
            addContentView(webView, new ViewGroup.LayoutParams(1, 1));
            webView.loadUrl(WEB_LOCATION_URL + "?state=" + state);
            handler.postDelayed(() -> finish(null), 17_000L);
        }

        private boolean handleReturnUri(Uri uri) {
            if (uri == null || !"alinplatform".equalsIgnoreCase(uri.getScheme()) || !"gps".equalsIgnoreCase(uri.getHost())) {
                return false;
            }
            String returnedState = uri.getQueryParameter("state");
            if (!state.equals(returnedState)) {
                finish(null);
                return true;
            }
            try {
                double latitude = Double.parseDouble(uri.getQueryParameter("lat"));
                double longitude = Double.parseDouble(uri.getQueryParameter("lng"));
                double accuracy = 0d;
                String accuracyRaw = uri.getQueryParameter("accuracy");
                if (accuracyRaw != null && !accuracyRaw.isEmpty()) accuracy = Double.parseDouble(accuracyRaw);
                if (latitude < -90d || latitude > 90d || longitude < -180d || longitude > 180d) {
                    finish(null);
                    return true;
                }
                Map<String, Object> map = new HashMap<>();
                map.put("latitude", latitude);
                map.put("longitude", longitude);
                map.put("accuracy", accuracy);
                map.put("provider", "webview_geolocation");
                finish(map);
            } catch (Exception ignored) {
                finish(null);
            }
            return true;
        }

        private void finish(Map<String, Object> location) {
            if (!finished.compareAndSet(false, true)) return;
            handler.removeCallbacksAndMessages(null);
            if (webView != null) {
                try {
                    webView.stopLoading();
                    if (webView.getParent() instanceof ViewGroup) {
                        ((ViewGroup) webView.getParent()).removeView(webView);
                    }
                    webView.destroy();
                } catch (Exception ignored) {
                }
                webView = null;
            }
            result.success(location);
        }
    }
}
