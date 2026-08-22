package com.alin.platform;

import android.Manifest;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
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
import com.google.android.gms.common.api.ResolvableApiException;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationSettingsRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.tasks.CancellationTokenSource;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String LOCATION_CHANNEL = "com.alin.platform/native_location";
    private static final String NOTIFICATION_CHANNEL = "com.alin.platform/native_notifications";
    private static final String NOTIFICATION_CHANNEL_ID = "alin_general";
    private static final int NOTIFICATION_PERMISSION_REQUEST_CODE = 4301;
    private static final String FUSED_PROVIDER = "fused";
    private static final String WEB_LOCATION_URL = "https://dgaikazhbtyjmswpyvrl.supabase.co/functions/v1/flutter-location-bridge";
    private static final int LOCATION_SETTINGS_REQUEST_CODE = 4201;
    private GoogleFusedLocationRequest pendingGoogleLocationRequest;
    private MethodChannel.Result pendingNotificationPermissionResult;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                LOCATION_CHANNEL
        ).setMethodCallHandler(this::handleLocationCall);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                NOTIFICATION_CHANNEL
        ).setMethodCallHandler(this::handleNotificationCall);
        ensureNotificationChannel();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return;
        MethodChannel.Result pending = pendingNotificationPermissionResult;
        pendingNotificationPermissionResult = null;
        if (pending == null) return;
        boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
        pending.success(granted);
        if (!granted
                && Build.VERSION.SDK_INT >= 33
                && !shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
            // If Android no longer offers the runtime dialog, immediately give the
            // user a working path to enable notifications for Alin.
            openNotificationSettings();
        }
    }

    private void handleNotificationCall(MethodCall call, MethodChannel.Result result) {
        if ("permissionGranted".equals(call.method)) {
            result.success(notificationPermissionGranted());
            return;
        }
        if ("requestPermission".equals(call.method)) {
            requestNotificationPermission(result);
            return;
        }
        if ("showNotification".equals(call.method)) {
            String title = call.argument("title");
            String message = call.argument("message");
            showNativeNotification(title, message);
            result.success(true);
            return;
        }
        result.notImplemented();
    }

    private boolean notificationPermissionGranted() {
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        boolean appNotificationsEnabled = manager == null || Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled();
        if (!appNotificationsEnabled) return false;
        if (Build.VERSION.SDK_INT < 33) return true;
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
    }

    private void openNotificationSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            intent.putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName());
            startActivity(intent);
        } catch (Exception ignored) {
            try {
                Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                intent.setData(Uri.parse("package:" + getPackageName()));
                startActivity(intent);
            } catch (Exception ignoredAgain) {
            }
        }
    }

    private void requestNotificationPermission(MethodChannel.Result result) {
        ensureNotificationChannel();
        if (notificationPermissionGranted()) {
            result.success(true);
            return;
        }

        if (Build.VERSION.SDK_INT < 33) {
            openNotificationSettings();
            result.success(false);
            return;
        }

        if (pendingNotificationPermissionResult != null) {
            result.success(false);
            return;
        }

        SharedPreferences prefs = getSharedPreferences("alin_notification_permission", Context.MODE_PRIVATE);
        boolean requestedBefore = prefs.getBoolean("requested_once", false);
        boolean canShowRuntimePrompt = !requestedBefore || shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS);

        if (!canShowRuntimePrompt) {
            // Android can stop showing the runtime dialog after repeated denial.
            // In that state the only reliable path is the app notification settings page.
            openNotificationSettings();
            result.success(false);
            return;
        }

        prefs.edit().putBoolean("requested_once", true).apply();
        pendingNotificationPermissionResult = result;
        requestPermissions(
                new String[]{Manifest.permission.POST_NOTIFICATIONS},
                NOTIFICATION_PERMISSION_REQUEST_CODE
        );
    }

    private void ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null || manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return;
        NotificationChannel channel = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "منصة آلين",
                NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription("إعلانات وتنبيهات منصة آلين");
        channel.enableVibration(true);
        channel.enableLights(true);
        channel.setLightColor(Color.BLUE);
        manager.createNotificationChannel(channel);
    }

    private void showNativeNotification(String title, String message) {
        if (message == null || message.trim().isEmpty()) return;
        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return;

        ensureNotificationChannel();
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent contentIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                : new Notification.Builder(this);
        builder.setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title == null || title.trim().isEmpty() ? "منصة آلين" : title.trim())
                .setContentText(message.trim())
                .setStyle(new Notification.BigTextStyle().bigText(message.trim()))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setDefaults(Notification.DEFAULT_ALL);

        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager != null) {
            manager.notify((int) (System.currentTimeMillis() & 0x7fffffff), builder.build());
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != LOCATION_SETTINGS_REQUEST_CODE) return;
        GoogleFusedLocationRequest pending = pendingGoogleLocationRequest;
        pendingGoogleLocationRequest = null;
        if (pending == null) return;
        if (resultCode == Activity.RESULT_OK) {
            pending.resumeAfterSettings();
        } else {
            pending.cancelFromSettings();
        }
    }

    private void handleLocationCall(MethodCall call, MethodChannel.Result result) {
        if ("getGoogleFusedLocation".equals(call.method)) {
            getGoogleFusedLocation(result);
            return;
        }
        if ("getLocationDiagnostics".equals(call.method)) {
            getLocationDiagnostics(result);
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

    private void getLocationDiagnostics(MethodChannel.Result result) {
        Map<String, Object> map = new HashMap<>();
        map.put("manufacturer", Build.MANUFACTURER);
        map.put("model", Build.MODEL);
        map.put("sdk", Build.VERSION.SDK_INT);
        map.put("fine", checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED);
        map.put("coarse", checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED);
        map.put("gms", GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this));

        LocationManager manager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        if (manager != null) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    map.put("location_enabled", manager.isLocationEnabled());
                }
                List<String> providerStates = new ArrayList<>();
                for (String provider : manager.getAllProviders()) {
                    boolean enabled = false;
                    try { enabled = manager.isProviderEnabled(provider); } catch (Exception ignored) { }
                    providerStates.add(provider + ":" + (enabled ? "on" : "off"));
                }
                map.put("providers", providerStates.toString());
            } catch (Exception ignored) {
            }
        }

        try {
            LocationServices.getSettingsClient(this)
                    .isGoogleLocationAccuracyEnabled()
                    .addOnSuccessListener(enabled -> {
                        map.put("google_accuracy", enabled);
                        result.success(map);
                    })
                    .addOnFailureListener(error -> {
                        map.put("google_accuracy", "unknown");
                        result.success(map);
                    });
        } catch (RuntimeException error) {
            map.put("google_accuracy", "unavailable");
            result.success(map);
        }
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
        private final LocationRequest liveRequest = new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
                .setMinUpdateIntervalMillis(500L)
                .setWaitForAccurateLocation(false)
                .setDurationMillis(22_000L)
                .setMaxUpdates(12)
                .build();
        private final LocationCallback liveCallback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                if (finished.get() || locationResult == null) return;
                for (Location location : locationResult.getLocations()) {
                    acceptLocation(location, true);
                    if (finished.get()) return;
                }
            }
        };
        private Location best;
        private boolean flowStarted = false;

        GoogleFusedLocationRequest(MethodChannel.Result result) {
            this.result = result;
        }

        void start() {
            // HONOR/Android can report "location enabled" while the network/high-accuracy
            // settings required by Google Fused are still disabled. Ask Android to verify
            // the exact settings for this request and show the native one-tap resolution
            // dialog when required. No browser/page is opened.
            LocationSettingsRequest settingsRequest = new LocationSettingsRequest.Builder()
                    .addLocationRequest(liveRequest)
                    .setAlwaysShow(true)
                    .build();

            LocationServices.getSettingsClient(MainActivity.this)
                    .checkLocationSettings(settingsRequest)
                    .addOnSuccessListener(response -> beginLocationFlow())
                    .addOnFailureListener(error -> {
                        if (finished.get()) return;
                        if (error instanceof ResolvableApiException) {
                            try {
                                if (pendingGoogleLocationRequest != null && pendingGoogleLocationRequest != this) {
                                    pendingGoogleLocationRequest.finish(null);
                                }
                                pendingGoogleLocationRequest = this;
                                ((ResolvableApiException) error).startResolutionForResult(
                                        MainActivity.this,
                                        LOCATION_SETTINGS_REQUEST_CODE
                                );
                                // Never leave the MethodChannel hanging if the OEM does not
                                // return an activity result. Try the live request anyway.
                                handler.postDelayed(() -> {
                                    if (!finished.get() && pendingGoogleLocationRequest == this) {
                                        pendingGoogleLocationRequest = null;
                                        beginLocationFlow();
                                    }
                                }, 12_000L);
                                return;
                            } catch (Exception ignored) {
                            }
                        }
                        // Some OEM builds do not expose a resolvable settings dialog. The
                        // live fused request can still succeed, so continue instead of fail.
                        beginLocationFlow();
                    });
        }

        void resumeAfterSettings() {
            beginLocationFlow();
        }

        void cancelFromSettings() {
            finish(null);
        }

        private void beginLocationFlow() {
            if (finished.get() || flowStarted) return;
            flowStarted = true;

            // Cached fix: useful when Maps/browser obtained a location moments ago.
            try {
                client.getLastLocation()
                        .addOnSuccessListener(location -> {
                            if (location != null && isFreshEnough(location, 5 * 60 * 1000L, 5000f)) {
                                acceptLocation(location, false);
                            } else if (isBetter(location, best)) {
                                best = location;
                            }
                        })
                        .addOnFailureListener(error -> { });
            } catch (RuntimeException ignored) {
            }

            // Single-fix APIs can legally return null. Keep them for speed, but do not
            // depend on them as the only Google Fused path.
            requestCurrent(Priority.PRIORITY_BALANCED_POWER_ACCURACY, balancedToken);
            requestCurrent(Priority.PRIORITY_HIGH_ACCURACY, highAccuracyToken);

            // Critical path for HONOR Pad X9: actively subscribe to fresh fused updates.
            // This can produce a fix even when getCurrentLocation() returned null.
            try {
                client.requestLocationUpdates(liveRequest, liveCallback, Looper.getMainLooper())
                        .addOnFailureListener(error -> { });
            } catch (RuntimeException ignored) {
            }

            handler.postDelayed(() -> finish(isAcceptableGoogle(best) ? best : null), 22_000L);
        }

        private void requestCurrent(int priority, CancellationTokenSource token) {
            try {
                client.getCurrentLocation(priority, token.getToken())
                        .addOnSuccessListener(location -> acceptLocation(location, false))
                        .addOnFailureListener(error -> { });
            } catch (RuntimeException ignored) {
            }
        }

        private void acceptLocation(Location location, boolean live) {
            if (finished.get() || location == null) return;
            if (isBetter(location, best)) best = location;

            long maxAge = live ? 2 * 60 * 1000L : 5 * 60 * 1000L;
            float maxAccuracy = live ? 5000f : 5000f;
            if (isFreshEnough(location, maxAge, maxAccuracy)) {
                finish(location);
            }
        }

        private boolean isFreshEnough(Location location, long maxAgeMs, float maxAccuracy) {
            if (location == null) return false;
            long ageMs = Math.max(0L, System.currentTimeMillis() - location.getTime());
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            return ageMs <= maxAgeMs && accuracy <= maxAccuracy;
        }

        private boolean isAcceptableGoogle(Location location) {
            if (location == null) return false;
            long ageMs = Math.max(0L, System.currentTimeMillis() - location.getTime());
            float accuracy = location.hasAccuracy() ? location.getAccuracy() : 99999f;
            return ageMs <= 10 * 60 * 1000L && accuracy <= 5000f;
        }

        private void finish(Location location) {
            if (!finished.compareAndSet(false, true)) return;
            handler.removeCallbacksAndMessages(null);
            if (pendingGoogleLocationRequest == this) pendingGoogleLocationRequest = null;
            try { balancedToken.cancel(); } catch (Exception ignored) { }
            try { highAccuracyToken.cancel(); } catch (Exception ignored) { }
            try { client.removeLocationUpdates(liveCallback); } catch (Exception ignored) { }
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
