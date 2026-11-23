package com.galaxystrike.bridge;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class PlayPurchases {
    private record Product(ProductDetails details, ProductDetails.OneTimePurchaseOfferDetails offer) {}

    private final Activity activity;
    private final GalaxyCommercePlugin bridge;
    private final BillingClient client;
    private final List<QueryProductDetailsParams.Product> requests = new ArrayList<>();
    private final Map<String, Product> products = new LinkedHashMap<>();
    private final Handler ui = new Handler(Looper.getMainLooper());
    private String activeRequest = "";
    private boolean connecting;
    private boolean queryingDetails;

    PlayPurchases(Activity activity, GalaxyCommercePlugin bridge, String skuJson) {
        this.activity = activity;
        this.bridge = bridge;
        try {
            JSONArray skus = new JSONArray(skuJson);
            for (int i = 0; i < skus.length(); i++) {
                requests.add(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(skus.getString(i)).setProductType(BillingClient.ProductType.INAPP).build());
            }
        } catch (JSONException ignored) {
            requests.clear();
        }
        client = BillingClient.newBuilder(activity)
            .setListener((result, purchases) -> ui.post(() -> purchaseUpdated(result, purchases)))
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection().build();
    }

    void connect() {
        if (client.isReady() || connecting) return;
        connecting = true;
        client.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(BillingResult result) {
                ui.post(() -> {
                    connecting = false;
                    if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        refreshProducts();
                        bridge.inventoryChanged();
                    }
                });
            }

            @Override
            public void onBillingServiceDisconnected() {
                ui.post(() -> connecting = false);
            }
        });
    }

    void onResume() {
        if (!client.isReady()) {
            connect();
        } else if (activeRequest.isEmpty()) {
            refreshProducts();
            bridge.inventoryChanged();
        }
    }

    void refreshProducts() {
        if (queryingDetails || requests.isEmpty()) return;
        if (!client.isReady()) {
            connect();
            return;
        }
        queryingDetails = true;
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(requests).build(),
            (result, details) -> ui.post(() -> {
                queryingDetails = false;
                products.clear();
                JSONArray data = new JSONArray();
                if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    for (ProductDetails item : details.getProductDetailsList()) {
                        var offer = basePurchase(item);
                        if (offer == null) continue;
                        products.put(item.getProductId(), new Product(item, offer));
                        JSONObject row = new JSONObject();
                        put(row, "sku", item.getProductId());
                        put(row, "title", item.getName());
                        put(row, "price", offer.getFormattedPrice());
                        data.put(row);
                    }
                }
                bridge.billingCatalog(data.toString());
            }));
    }

    private ProductDetails.OneTimePurchaseOfferDetails basePurchase(ProductDetails item) {
        var offers = item.getOneTimePurchaseOfferDetailsList();
        if (offers != null) {
            for (var offer : offers) {
                if (TextUtils.isEmpty(offer.getOfferId()) && offer.getRentalDetails() == null
                    && offer.getPreorderDetails() == null && !offer.getFormattedPrice().isEmpty()) return offer;
            }
        }
        return null;
    }

    void buy(String id, String sku, String account) {
        if (!activeRequest.isEmpty()) {
            bridge.billingResult(id, "busy", "[]");
            return;
        }
        Product item = products.get(sku);
        if (!client.isReady() || item == null || !account.matches("[a-f0-9]{64}")) {
            refreshProducts();
            bridge.billingResult(id, "unavailable", "[]");
            return;
        }
        var product = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(item.details);
        if (!TextUtils.isEmpty(item.offer.getOfferToken())) product.setOfferToken(item.offer.getOfferToken());
        var params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(Arrays.asList(product.build())).setObfuscatedAccountId(account).build();
        activeRequest = id;
        BillingResult result = client.launchBillingFlow(activity, params);
        if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
            activeRequest = "";
            bridge.billingResult(id, state(result), "[]");
        } else {
            ui.postDelayed(() -> {
                if (!id.equals(activeRequest)) return;
                activeRequest = "";
                bridge.billingResult(id, "network_error", "[]");
                bridge.inventoryChanged();
            }, 175000);
        }
    }

    void query(String id) {
        if (!client.isReady()) {
            connect();
            bridge.billingResult(id, "unavailable", "[]");
            return;
        }
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP).build(),
            (result, purchases) -> ui.post(() -> bridge.billingResult(id,
                result.getResponseCode() == BillingClient.BillingResponseCode.OK ? "restored" : state(result),
                rows(purchases).toString())));
    }

    private void purchaseUpdated(BillingResult result, List<Purchase> items) {
        String id = activeRequest;
        activeRequest = "";
        boolean success = result.getResponseCode() == BillingClient.BillingResponseCode.OK;
        if (!id.isEmpty()) bridge.billingResult(id, success ? "success" : state(result), rows(items).toString());
        if ((success && id.isEmpty()) || result.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            bridge.inventoryChanged();
        }
    }

    private static JSONArray rows(List<Purchase> items) {
        JSONArray result = new JSONArray();
        if (items == null) return result;
        for (Purchase item : items) {
            int state = item.getPurchaseState();
            if (state != Purchase.PurchaseState.PURCHASED && state != Purchase.PurchaseState.PENDING) continue;
            for (String sku : item.getProducts()) {
                JSONObject row = new JSONObject();
                put(row, "sku", sku);
                put(row, "token", item.getPurchaseToken());
                put(row, "stage", state == Purchase.PurchaseState.PENDING ? "pending" : "purchased");
                result.put(row);
            }
        }
        return result;
    }

    private static String state(BillingResult result) {
        return switch (result.getResponseCode()) {
            case BillingClient.BillingResponseCode.USER_CANCELED -> "cancelled";
            case BillingClient.BillingResponseCode.NETWORK_ERROR, BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
                 BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE -> "network_error";
            case BillingClient.BillingResponseCode.ITEM_UNAVAILABLE, BillingClient.BillingResponseCode.BILLING_UNAVAILABLE,
                 BillingClient.BillingResponseCode.FEATURE_NOT_SUPPORTED -> "unavailable";
            case BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> "owned_on_play";
            default -> "error";
        };
    }

    private static void put(JSONObject value, String key, String data) {
        try {
            value.put(key, data);
        } catch (JSONException e) {
            throw new IllegalArgumentException(e);
        }
    }

    void close() {
        client.endConnection();
    }
}
