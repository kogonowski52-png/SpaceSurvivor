package com.galaxystrike.bridge;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
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
            new SignalInfo("ad_diagnostic", String.class, String.class),
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
        return activity == null || "test".equals(playMode()) || debuggable(activity)
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
    public String privacyPolicyUrl() {
        Activity activity = getActivity();
        return activity == null ? "" : metadata(activity, "com.galaxystrike.privacy_policy");
    }

    @UsedByGodot
    public String playMode() {
        Activity activity = getActivity();
        return activity != null && !debuggable(activity)
            && "live".equals(metadata(activity, "com.galaxystrike.play_mode")) ? "live" : "test";
    }

    @UsedByGodot
    public boolean licenseCheckoutEnabled() {
        Activity activity = getActivity();
        return activity != null && !debuggable(activity) && "test".equals(playMode())
            && "enabled".equals(metadata(activity, "com.galaxystrike.license_checkout")) && installedFromPlay(activity);
    }

    @UsedByGodot
    public boolean licenseDraftCatalogEnabled() {
        Activity activity = getActivity();
        return activity != null && licenseCheckoutEnabled()
            && "enabled".equals(metadata(activity, "com.galaxystrike.draft_catalog"));
    }

    private static boolean installedFromPlay(Activity activity) {
        var manager = activity.getPackageManager();
        try {
            String installer = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                ? manager.getInstallSourceInfo(activity.getPackageName()).getInstallingPackageName()
                : manager.getInstallerPackageName(activity.getPackageName());
            return "com.android.vending".equals(installer);
        } catch (PackageManager.NameNotFoundException | SecurityException ignored) {
            return false;
        }
    }

    @UsedByGodot
    public int diagnosticPssKib() {
        Activity activity = getActivity();
        if (activity == null || !"test".equals(playMode())) return 0;
        return (int) Math.min(android.os.Debug.getPss(), Integer.MAX_VALUE);
    }

    static boolean debuggable(Activity activity) {
        return (activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    @UsedByGodot
    public void shareDiagnostics(String report) {
        Activity activity = getActivity();
        if (activity == null || !"test".equals(playMode()) || report.length() > 16384) return;
        activity.runOnUiThread(() -> {
            if (activity.isFinishing()) return;
            Intent share = new Intent(Intent.ACTION_SEND);
            share.setType("text/plain");
            share.putExtra(Intent.EXTRA_TEXT, report);
            activity.startActivity(Intent.createChooser(share, "Raport Galaxy Strike"));
        });
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
        if (!licenseCheckoutEnabled()) {
            billingResult(requestId, "payments_disabled", "[]");
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
        if (ads != null) ads.onResume();
    }

    @Override
    public void onMainPause() {
        if (ads != null) ads.onPause();
    }

    @Override
    public void onMainDestroy() {
        if (billing != null) billing.close();
        if (ads != null) ads.close();
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

    void adDiagnostic(String requestId, String state) {
        emitSignal("ad_diagnostic", requestId, state);
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
