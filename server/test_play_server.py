import hashlib
import json
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from play_server import Ledger, Rejected, ThreadingHTTPServer, handler

A = "a" * 32
B = "b" * 32
TOKEN = "play-token-from-sdk"
CONSUMABLE = "gs_crystals_100"
PERMANENT = "gs_starter_v1"


class PlayFixture:
    def __init__(self):
        self.data = {}
        self.calls = []
        self.failure = False

    def purchase(self, _token):
        return self.data

    def finish(self, sku, token):
        self.calls.append((sku, token))
        if self.failure:
            raise Rejected(503, "google_unavailable")
        if sku == CONSUMABLE:
            self.data["productLineItem"][0]["productOfferDetails"]["consumptionState"] = "CONSUMPTION_STATE_CONSUMED"
        else:
            self.data["acknowledgementState"] = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"


class PurchaseDeliveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "orders.sqlite3"
        self.google = PlayFixture()
        self.key = b"fixture-key" * 4
        self.ledger = Ledger(self.path, self.google, self.key, True)
        self.purchase(CONSUMABLE)

    def purchase(self, sku):
        self.google.data = {
            "obfuscatedExternalAccountId": self.ledger.account_id("pilot"),
            "purchaseStateContext": {"purchaseState": "PURCHASED"},
            "productLineItem": [{
                "productId": sku,
                "productOfferDetails": {"quantity": 1, "refundableQuantity": 1,
                                        "consumptionState": "CONSUMPTION_STATE_YET_TO_BE_CONSUMED"},
            }],
            "acknowledgementState": "ACKNOWLEDGEMENT_STATE_PENDING",
            "testPurchaseContext": {"fopType": "TEST"},
        }

    def test_purchased_token_has_one_durable_delivery_and_can_be_consumed_before_client_receives(self):
        first = self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.assertEqual(first["mode"], "deliver")
        self.ledger.finish_once()
        self.assertEqual(self.google.calls, [(CONSUMABLE, TOKEN)])

        reloaded = Ledger(self.path, self.google, self.key, True)
        self.assertEqual(reloaded.outstanding("pilot", A), [first])
        self.assertEqual(reloaded.outstanding("pilot", B), [])
        self.assertEqual(reloaded.verify("pilot", B, CONSUMABLE, TOKEN)["mode"], "other_device")
        reloaded.received("pilot", A, first["delivery_id"])
        reloaded.received("pilot", A, first["delivery_id"])
        self.assertEqual(reloaded.outstanding("pilot", A), [])
        self.assertEqual(reloaded.verify("pilot", B, CONSUMABLE, TOKEN)["mode"], "received")
        reloaded.finish_once()
        self.assertEqual(self.google.calls, [(CONSUMABLE, TOKEN)])

    def test_parallel_validation_assigns_one_installation(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda device: self.ledger.verify("pilot", device, CONSUMABLE, TOKEN), (A, B)))
        self.assertEqual({row["delivery_id"] for row in results}, {hashlib.sha256(TOKEN.encode()).hexdigest()})
        self.assertCountEqual([row["mode"] for row in results], ["deliver", "other_device"])

    def test_acknowledged_nonconsumable_restores_and_finalize_retries(self):
        self.purchase(PERMANENT)
        first = self.ledger.verify("pilot", A, PERMANENT, TOKEN)
        self.ledger.received("pilot", A, first["delivery_id"])
        self.google.failure = True
        self.ledger.finish_once()
        self.google.failure = False
        self.ledger.finish_once()
        self.ledger.finish_once()
        self.assertEqual(self.google.calls, [(PERMANENT, TOKEN)] * 2)
        self.assertEqual(self.ledger.verify("pilot", B, PERMANENT, TOKEN)["mode"], "restore")

    def test_already_consumed_token_has_no_new_currency_on_empty_ledger(self):
        self.google.data["productLineItem"][0]["productOfferDetails"]["consumptionState"] = "CONSUMPTION_STATE_CONSUMED"
        self.assertEqual(self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)["mode"], "received")
        self.assertEqual(self.ledger.outstanding("pilot", A), [])

    def test_invalid_order_is_not_recorded_or_finalized(self):
        with self.assertRaisesRegex(Rejected, "wrong_account"):
            self.ledger.verify("stranger", A, CONSUMABLE, TOKEN)
        with self.assertRaisesRegex(Rejected, "wrong_product"):
            self.ledger.verify("pilot", A, PERMANENT, TOKEN)
        self.google.data["purchaseStateContext"]["purchaseState"] = "PENDING"
        with self.assertRaisesRegex(Rejected, "purchase_not_completed"):
            self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.purchase(CONSUMABLE)
        self.google.data["productLineItem"][0]["productOfferDetails"]["quantity"] = 2
        with self.assertRaisesRegex(Rejected, "unsupported_quantity"):
            self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.purchase(CONSUMABLE)
        del self.google.data["testPurchaseContext"]
        with self.assertRaisesRegex(Rejected, "wrong_purchase_environment"):
            self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.ledger.finish_once()
        self.assertEqual(self.google.calls, [])

    def test_http_session_and_delivery_endpoints_are_bound_to_bearer_and_installation(self):
        secret = "fixture-session-token"
        digest = hashlib.sha256(secret.encode()).hexdigest()
        with ThreadingHTTPServer(("127.0.0.1", 0), handler(self.ledger, {digest: "pilot"})) as server:
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                address = "http://127.0.0.1:%d/v1/play/" % server.server_port

                def send(path, body, token=secret):
                    request = Request(address + path, json.dumps(body).encode(),
                                      {"Authorization": "Bearer " + token, "Content-Type": "application/json"})
                    with urlopen(request, timeout=5) as response:
                        return json.load(response)

                with self.assertRaises(HTTPError) as error:
                    send("session", {}, "invalid")
                self.assertEqual(error.exception.code, 401)
                session = send("session", {})
                self.assertEqual(session["play_mode"], "test")
                self.assertEqual(session["obfuscated_account_id"], self.ledger.account_id("pilot"))
                receipt = send("verify", {"installation": A, "sku": CONSUMABLE, "token": TOKEN})
                with self.assertRaises(HTTPError) as error:
                    send("received", {"installation": B, "delivery_id": receipt["delivery_id"]})
                self.assertEqual(error.exception.code, 404)
                self.assertEqual(send("outstanding", {"installation": A})["orders"][0]["mode"], "deliver")
                self.assertTrue(send("received", {"installation": A, "delivery_id": receipt["delivery_id"]})["ok"])
                self.assertEqual(send("outstanding", {"installation": A})["orders"], [])
            finally:
                server.shutdown()
                thread.join()


if __name__ == "__main__":
    unittest.main()
