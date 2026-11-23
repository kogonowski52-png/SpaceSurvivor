package com.galaxystrike.bridge;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;

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
    private boolean updatingConsent;
    private boolean consentChecked;
    private boolean initialized;

    RewardedAds(Activity activity, GalaxyCommercePlugin bridge) {
        this.activity = activity;
        this.bridge = bridge;
        this.consent = UserMessagingPlatform.getConsentInformation(activity);
    }

    void updateConsent() {
        if (updatingConsent || consentChecked) return;
        updatingConsent = true;
        consent.requestConsentInfoUpdate(activity, consentParameters(),
            () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity,
                error -> consentComplete(error == null ? "" : "consent_error")),
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
        updatingConsent = false;
        consentChecked = status.isEmpty() || "privacy_saved".equals(status) || consent.canRequestAds();
        publishPrivacy(status);
    }

    void showPrivacy() {
        if (updatingConsent || !activeRequest.isEmpty() || !privacyRequired()) return;
        updatingConsent = true;
        UserMessagingPlatform.showPrivacyOptionsForm(activity,
            error -> consentComplete(error == null ? "privacy_saved" : "privacy_error"));
    }

    private boolean privacyRequired() {
        return consent.getPrivacyOptionsRequirementStatus()
            == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
    }

    private void publishPrivacy(String state) {
        bridge.privacyChanged(privacyRequired(), state);
    }

    void show(String requestId, String placement) {
        if (!activeRequest.isEmpty()) {
            bridge.adResult(requestId, "busy");
            return;
        }
        if (updatingConsent || !consentChecked || !consent.canRequestAds()) {
            if (!consentChecked) updateConsent();
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
        ui.postDelayed(() -> {
            if (requestId.equals(activeRequest)) finish(requestId, "timeout");
        }, 175000);
        if (initialized) {
            load(requestId, unit);
        } else {
            new Thread(() -> MobileAds.initialize(activity.getApplicationContext(), status -> ui.post(() -> {
                initialized = true;
                load(requestId, unit);
            })), "galaxy-ad-init").start();
        }
    }

    private void load(String id, String unit) {
        if (!id.equals(activeRequest)) return;
        RewardedAd.load(activity, unit, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override
            public void onAdFailedToLoad(LoadAdError error) {
                finish(id, error.getCode() == AdRequest.ERROR_CODE_NETWORK_ERROR ? "network_error" : "unavailable");
            }

            @Override
            public void onAdLoaded(RewardedAd ad) {
                if (!id.equals(activeRequest)) return;
                if (activity.isFinishing() || !consent.canRequestAds()) {
                    finish(id, "unavailable");
                    return;
                }
                display(id, ad);
            }
        });
    }

    private void display(String id, RewardedAd ad) {
        // Grant on the earned callback and let the flight resume only after the ad closes.
        final class Completion {
            boolean earned;
            boolean closed;
        }
        Completion completion = new Completion();
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override
            public void onAdDismissedFullScreenContent() {
                completion.closed = true;
                if (completion.earned) finish(id, "rewarded");
                else ui.postDelayed(() -> finish(id, completion.earned ? "rewarded" : "cancelled"), 600);
            }

            @Override
            public void onAdFailedToShowFullScreenContent(AdError error) {
                finish(id, "unavailable");
            }
        });
        ad.show(activity, reward -> {
            completion.earned = true;
            if (completion.closed) finish(id, "rewarded");
        });
    }

    private void finish(String id, String state) {
        if (!id.equals(activeRequest)) return;
        activeRequest = "";
        bridge.adResult(id, state);
    }
}
