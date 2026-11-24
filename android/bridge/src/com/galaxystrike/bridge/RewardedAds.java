package com.galaxystrike.bridge;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentDebugSettings;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;

final class RewardedAds {
    private static final String SAMPLE_REWARDED = "ca-app-pub-3940256099942544/5224354917";
    private final Activity activity;
    private final GalaxyCommercePlugin bridge;
    private final ConsentInformation consent;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private String activeRequest = "";
    private String activeUnit = "";
    private boolean foreground = true;
    private boolean destroyed;
    private boolean updatingConsent;
    private boolean consentChecked;
    private boolean retryConsent;
    private long nextConsentRetry;
    private boolean initialized;
    private boolean initializing;
    private boolean presenting;

    RewardedAds(Activity activity, GalaxyCommercePlugin bridge) {
        this.activity = activity;
        this.bridge = bridge;
        this.consent = UserMessagingPlatform.getConsentInformation(activity);
    }

    void updateConsent() {
        if (destroyed || !foreground || updatingConsent || (consentChecked && !retryConsent)
                || SystemClock.elapsedRealtime() < nextConsentRetry) return;
        updatingConsent = true;
        bridge.adDiagnostic("", "consent_check");
        consent.requestConsentInfoUpdate(activity, consentParameters(),
            () -> {
                if (destroyed) return;
                if (!foreground) {
                    consentComplete("consent_error");
                    return;
                }
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity,
                    error -> consentComplete(error == null ? "" : "consent_error"));
            },
            error -> consentComplete("consent_error"));
    }

    private ConsentRequestParameters consentParameters() {
        ConsentRequestParameters.Builder request = new ConsentRequestParameters.Builder();
        if (!GalaxyCommercePlugin.debuggable(activity)) return request.build();
        String device = GalaxyCommercePlugin.metadata(activity, "com.galaxystrike.ump_debug_device");
        String region = GalaxyCommercePlugin.metadata(activity, "com.galaxystrike.ump_debug_geography");
        int geography = switch (region) {
            case "eea" -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA;
            case "us" -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_REGULATED_US_STATE;
            case "other" -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_OTHER;
            default -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_DISABLED;
        };
        if (!device.isEmpty() && geography != ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_DISABLED) {
            request.setConsentDebugSettings(new ConsentDebugSettings.Builder(activity)
                .addTestDeviceHashedId(device).setDebugGeography(geography).build());
        }
        return request.build();
    }

    private void consentComplete(String status) {
        if (destroyed) return;
        updatingConsent = false;
        consentChecked = status.isEmpty() || "privacy_saved".equals(status) || consent.canRequestAds();
        retryConsent = "consent_error".equals(status);
        nextConsentRetry = retryConsent ? SystemClock.elapsedRealtime() + 3000 : 0;
        publishPrivacy(status);
        if (!status.isEmpty()) bridge.adDiagnostic("", status);
        bridge.adDiagnostic("", consent.canRequestAds() ? "consent_available" : "consent_blocked");
    }

    void showPrivacy() {
        if (destroyed || !foreground || updatingConsent || !activeRequest.isEmpty() || !privacyRequired()) return;
        updatingConsent = true;
        bridge.adDiagnostic("", "privacy_open");
        UserMessagingPlatform.showPrivacyOptionsForm(activity,
            error -> consentComplete(error == null ? "privacy_saved" : "privacy_error"));
    }

    void onPause() {
        activity.runOnUiThread(() -> {
            foreground = false;
            if (!activeRequest.isEmpty() && !presenting) finish(activeRequest, "background");
        });
    }

    void onResume() {
        activity.runOnUiThread(() -> {
            foreground = true;
            if (destroyed) return;
            publishPrivacy("");
            if (retryConsent) {
                long wait = Math.max(0, nextConsentRetry - SystemClock.elapsedRealtime());
                ui.postDelayed(this::updateConsent, wait);
            } else if (!consentChecked) {
                updateConsent();
            }
        });
    }

    void close() {
        activity.runOnUiThread(() -> {
            destroyed = true;
            activeRequest = "";
            activeUnit = "";
            ui.removeCallbacksAndMessages(null);
        });
    }

    private boolean privacyRequired() {
        return consent.getPrivacyOptionsRequirementStatus()
            == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
    }

    private void publishPrivacy(String state) {
        bridge.privacyChanged(privacyRequired(), state);
    }

    void show(String requestId, String placement) {
        switch (placement) {
            case "double", "revive", "bonus", "boss", "materials" -> {}
            default -> {
                bridge.adResult(requestId, "unavailable");
                return;
            }
        }
        if (!activeRequest.isEmpty()) {
            bridge.adResult(requestId, "busy");
            return;
        }
        if (destroyed || !foreground) {
            bridge.adResult(requestId, "background");
            return;
        }
        if (updatingConsent || !consentChecked || !consent.canRequestAds()) {
            if (!consentChecked || retryConsent) updateConsent();
            bridge.adResult(requestId, "consent");
            return;
        }
        String unit = bridge.testAds() ? SAMPLE_REWARDED
            : GalaxyCommercePlugin.metadata(activity, "com.galaxystrike.rewarded_" + placement);
        if (unit.isEmpty()) {
            bridge.adResult(requestId, "unavailable");
            return;
        }
        activeRequest = requestId;
        activeUnit = unit;
        ui.postDelayed(() -> {
            if (requestId.equals(activeRequest) && !presenting) finish(requestId, "timeout");
        }, 15000);
        ui.postDelayed(() -> {
            if (requestId.equals(activeRequest)) finish(requestId, "timeout");
        }, 175000);
        if (initialized) {
            load(requestId, unit);
        } else if (!initializing) {
            initializing = true;
            bridge.adDiagnostic("", "sdk_initializing");
            new Thread(() -> MobileAds.initialize(activity.getApplicationContext(), status -> ui.post(() -> {
                if (destroyed) return;
                initializing = false;
                initialized = true;
                bridge.adDiagnostic("", "sdk_ready");
                if (!activeRequest.isEmpty()) load(activeRequest, activeUnit);
            })), "galaxy-ad-init").start();
        }
    }

    private void load(String id, String unit) {
        if (!id.equals(activeRequest)) return;
        if (!foreground || updatingConsent || !consent.canRequestAds()) {
            finish(id, !foreground ? "background" : "consent");
            return;
        }
        bridge.adDiagnostic(id, "loading");
        RewardedAd.load(activity, unit, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override
            public void onAdFailedToLoad(LoadAdError error) {
                finish(id, error.getCode() == AdRequest.ERROR_CODE_NETWORK_ERROR ? "network_error" : "unavailable");
            }

            @Override
            public void onAdLoaded(RewardedAd ad) {
                if (!id.equals(activeRequest)) return;
                if (!foreground || activity.isFinishing() || activity.isDestroyed() || updatingConsent || !consent.canRequestAds()) {
                    finish(id, !foreground ? "background" : "unavailable");
                    return;
                }
                bridge.adDiagnostic(id, "ready");
                display(id, ad);
            }
        });
    }

    private void display(String id, RewardedAd ad) {
        presenting = true;
        // Grant on the earned callback and let the flight resume only after the ad closes.
        final class Completion {
            boolean earned;
            boolean closed;
        }
        Completion completion = new Completion();
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override
            public void onAdShowedFullScreenContent() {
                if (id.equals(activeRequest)) bridge.adDiagnostic(id, "showing");
            }

            @Override
            public void onAdDismissedFullScreenContent() {
                if (!id.equals(activeRequest)) return;
                completion.closed = true;
                bridge.adDiagnostic(id, "closed");
                if (completion.earned) finish(id, "rewarded");
                else ui.postDelayed(() -> finish(id, completion.earned ? "rewarded" : "cancelled"), 600);
            }

            @Override
            public void onAdFailedToShowFullScreenContent(AdError error) {
                finish(id, "unavailable");
            }
        });
        ad.show(activity, reward -> {
            if (!id.equals(activeRequest) || completion.earned) return;
            completion.earned = true;
            bridge.adDiagnostic(id, "earned");
            if (completion.closed) finish(id, "rewarded");
        });
    }

    private void finish(String id, String state) {
        if (!id.equals(activeRequest)) return;
        activeRequest = "";
        activeUnit = "";
        presenting = false;
        bridge.adResult(id, state);
    }
}
