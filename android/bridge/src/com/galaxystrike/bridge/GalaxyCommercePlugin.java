package com.galaxystrike.bridge;

import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.content.pm.ApplicationInfo;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Set;
import java.util.Arrays;
import java.util.HashSet;

public final class GalaxyCommercePlugin extends GodotPlugin {
    static final String SAMPLE_APP_ID = "ca-app-pub-3940256099942544~3347511713";
    private RewardedAds ads;
    private PlayPurchases billing;

    public GalaxyCommercePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "GalaxyCommerce";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("ad_result", String.class, String.class),
            new SignalInfo("ad_privacy", Boolean.class, String.class),
            new SignalInfo("billing_result", String.class, String.class, String.class),
            new SignalInfo("billing_catalog", String.class),
            new SignalInfo("billing_inventory_changed")
        ));
    }

    @UsedByGodot
    public void initAds() {
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            if (ads == null) ads = new RewardedAds(activity, this);
            ads.updateConsent();
        });
    }

    @UsedByGodot
    public boolean testAds() {
        Activity activity = getActivity();
        return activity == null || debuggable(activity)
            || SAMPLE_APP_ID.equals(metadata(activity, "com.google.android.gms.ads.APPLICATION_ID"));
    }

    @UsedByGodot
    public void showRewarded(String requestId, String placement) {
        Activity activity = getActivity();
        if (activity == null) {
            adResult(requestId, "unavailable");
            return;
        }
        activity.runOnUiThread(() -> {
            if (ads == null) adResult(requestId, "unavailable");
            else ads.show(requestId, placement);
        });
    }

    @UsedByGodot
    public void showAdPrivacy() {
        Activity activity = getActivity();
        if (activity != null) activity.runOnUiThread(() -> {
            if (ads != null) ads.showPrivacy();
        });
    }

    @UsedByGodot
    public String billingEndpoint() {
        Activity activity = getActivity();
        return activity == null ? "" : metadata(activity, "com.galaxystrike.purchase_server");
    }

    @UsedByGodot
    public String playMode() {
        Activity activity = getActivity();
        return activity != null && !debuggable(activity)
            && "live".equals(metadata(activity, "com.galaxystrike.play_mode")) ? "live" : "test";
    }

    private static boolean debuggable(Activity activity) {
        return (activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    @UsedByGodot
    public void initBilling(String skusJson) {
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            if (billing == null) billing = new PlayPurchases(activity, this, skusJson);
            billing.connect();
        });
    }

    @UsedByGodot
    public void queryProducts() {
        Activity activity = getActivity();
        if (activity != null) activity.runOnUiThread(() -> {
            if (billing != null) billing.refreshProducts();
        });
    }

    @UsedByGodot
    public void startPurchase(String requestId, String sku, String accountId) {
        Activity activity = getActivity();
        if (activity == null) {
            billingResult(requestId, "unavailable", "[]");
            return;
        }
        activity.runOnUiThread(() -> {
            if (billing == null) billingResult(requestId, "unavailable", "[]");
            else billing.buy(requestId, sku, accountId);
        });
    }

    @UsedByGodot
    public void queryPurchases(String requestId) {
        Activity activity = getActivity();
        if (activity == null) {
            billingResult(requestId, "unavailable", "[]");
            return;
        }
        activity.runOnUiThread(() -> {
            if (billing == null) billingResult(requestId, "unavailable", "[]");
            else billing.query(requestId);
        });
    }

    @Override
    public void onMainResume() {
        if (billing != null) billing.onResume();
    }

    @Override
    public void onMainDestroy() {
        if (billing != null) billing.close();
    }

    static String metadata(Activity activity, String key) {
        try {
            Bundle entries = activity.getPackageManager().getApplicationInfo(
                activity.getPackageName(), PackageManager.GET_META_DATA).metaData;
            return entries == null ? "" : entries.getString(key, "");
        } catch (PackageManager.NameNotFoundException ignored) {
            return "";
        }
    }

    void adResult(String requestId, String status) {
        emitSignal("ad_result", requestId, status);
    }

    void privacyChanged(boolean required, String status) {
        emitSignal("ad_privacy", required, status);
    }

    void billingResult(String requestId, String status, String receipts) {
        emitSignal("billing_result", requestId, status, receipts);
    }

    void billingCatalog(String catalog) {
        emitSignal("billing_catalog", catalog);
    }

    void inventoryChanged() {
        emitSignal("billing_inventory_changed");
    }
}
