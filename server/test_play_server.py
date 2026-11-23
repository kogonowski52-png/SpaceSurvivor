import hashlib
import json
import sqlite3
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from play_server import DAY_MS, GooglePlay, Ledger, Rejected, ThreadingHTTPServer, handler

A = "a" * 32
B = "b" * 32
TOKEN = "play-token-from-sdk"
CONSUMABLE = "gs_crystals_100"
PERMANENT = "gs_starter_v1"


class PlayFixture:
    def __init__(self):
        self.data = {}
        self.calls = []
        self.voids = []
        self.windows = []
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

    def voided(self, since, until):
        self.windows.append((since, until))
        yield from self.voids
        if self.failure:
            raise Rejected(503, "google_unavailable")


class PurchaseWalletTest(unittest.TestCase):
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

    def test_reinstall_new_installation_and_replayed_consumed_order_share_one_balance(self):
        first = self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.assertTrue(first["credited"])
        self.assertEqual(first["wallet"]["crystals"], 100)
        self.ledger.finish_once()
        reloaded = Ledger(self.path, self.google, self.key, True)
        self.assertEqual(reloaded.wallet("pilot", B)["wallet"], first["wallet"])
        self.assertFalse(reloaded.verify("pilot", B, CONSUMABLE, TOKEN)["credited"])
        self.assertEqual(reloaded.wallet("pilot", A)["wallet"]["crystals"], 100)
        self.assertEqual(reloaded.wallet("stranger", B)["wallet"]["crystals"], 0)
        reloaded.finish_once()
        self.assertEqual(self.google.calls, [(CONSUMABLE, TOKEN)])

    def test_parallel_verification_and_spending_do_not_double_credit_or_overdraw(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda device: self.ledger.verify("pilot", device, CONSUMABLE, TOKEN), (A, B)))
            self.assertCountEqual([row["credited"] for row in results], [True, False])

            def spend(args):
                try:
                    return self.ledger.spend("pilot", *args)["spent"]
                except Rejected as exc:
                    self.assertEqual(exc.reason, "insufficient_funds")
                    return False

            results = list(pool.map(spend, [(A, "1" * 32, "equipment_signal"), (B, "2" * 32, "skin_frost")]))
        self.assertCountEqual(results, [True, False])
        self.assertIn(self.ledger.wallet("pilot", B)["wallet"]["crystals"], [20, 45])

    def test_idempotency_covers_replay_after_installation_loss_and_mismatched_request(self):
        self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        request = "1" * 32
        first = self.ledger.spend("pilot", A, request, "equipment_signal")
        self.assertTrue(first["spent"])
        for key in (request, "2" * 32):
            replay = self.ledger.spend("pilot", B, key, "equipment_signal")
            self.assertFalse(replay["spent"])
            self.assertEqual(replay["wallet"], first["wallet"])
        with self.assertRaisesRegex(Rejected, "request_conflict"):
            self.ledger.spend("pilot", B, request, "skin_ion")
        self.assertEqual(first["wallet"]["crystals"], 20)
        self.assertIn("equipment_signal", self.ledger.wallet("pilot", B)["wallet"]["offers"])

    def test_refund_once_creates_debt_if_spent_and_a_deposit_offsets_debt(self):
        self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.ledger.spend("pilot", A, "1" * 32, "equipment_signal")
        self.google.voids = [TOKEN, TOKEN]
        self.ledger.reconcile_voids(1_800_000_000_000)
        self.ledger.reconcile_voids(1_800_000_300_000)
        wallet = self.ledger.wallet("pilot", B)["wallet"]
        self.assertEqual((wallet["crystals"], wallet["debt"]), (0, 80))
        self.assertEqual(wallet["offers"], [])
        with self.assertRaisesRegex(Rejected, "insufficient_funds"):
            self.ledger.spend("pilot", B, "2" * 32, "skin_ion")
        with self.assertRaisesRegex(Rejected, "purchase_voided"):
            self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        second = self.ledger.verify("pilot", B, CONSUMABLE, TOKEN + "-new")["wallet"]
        self.assertEqual((second["crystals"], second["debt"]), (20, 0))
        self.assertEqual(second["offers"], ["equipment_signal"])

    def test_void_before_verification_and_partial_api_failure_replay_safely(self):
        self.google.voids = [TOKEN]
        self.google.failure = True
        now = 1_800_000_000_000
        with self.assertRaisesRegex(Rejected, "google_unavailable"):
            self.ledger.reconcile_voids(now)
        self.google.failure = False
        self.ledger.reconcile_voids(now)
        self.assertEqual(self.google.windows, [(now - 29 * DAY_MS, now - 60_000)] * 2)
        with self.assertRaisesRegex(Rejected, "purchase_voided"):
            self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)
        self.assertEqual(self.ledger.wallet("pilot", A)["wallet"]["crystals"], 0)

    def test_starter_credits_scope_is_separate_from_account_wallet_and_refunds_revoke_rights(self):
        self.purchase(PERMANENT)
        first = self.ledger.verify("pilot", A, PERMANENT, TOKEN)
        self.assertEqual(first["wallet"]["crystals"], 120)
        self.assertEqual(first["wallet"]["offers"], ["starter"])
        self.assertEqual(len(first["credits_deliveries"]), 1)
        self.assertEqual(self.ledger.wallet("pilot", B)["credits_deliveries"], [])
        delivery = first["credits_deliveries"][0]
        with self.assertRaisesRegex(Rejected, "unknown_delivery"):
            self.ledger.received("pilot", B, delivery)
        self.ledger.received("pilot", A, delivery)
        self.ledger.received("pilot", A, delivery)
        self.google.failure = True
        self.ledger.finish_once()
        self.google.failure = False
        self.ledger.finish_once()
        self.ledger.finish_once()
        self.assertEqual(self.google.calls, [(PERMANENT, TOKEN)] * 2)
        self.ledger.record_void(TOKEN)
        self.assertEqual(self.ledger.wallet("pilot", B)["wallet"]["offers"], [])
        self.assertEqual(self.ledger.wallet("pilot", B)["wallet"]["crystals"], 0)

    def test_consumed_orphan_and_legacy_delivery_do_not_recredit_history(self):
        legacy_path = Path(self.temp.name) / "legacy.sqlite3"
        with sqlite3.connect(legacy_path) as conn:
            conn.execute("""CREATE TABLE orders (id TEXT PRIMARY KEY, player TEXT, installation TEXT, sku TEXT,
                         token TEXT, received INTEGER, finalized INTEGER)""")
            old = hashlib.sha256(TOKEN.encode()).hexdigest()
            conn.execute("INSERT INTO orders VALUES (?, ?, ?, ?, ?, ?, ?)", (old, "pilot", A, CONSUMABLE, TOKEN, 0, 0))
        migrated = Ledger(legacy_path, self.google, self.key, True)
        self.assertFalse(migrated.verify("pilot", B, CONSUMABLE, TOKEN)["credited"])
        self.assertEqual(migrated.wallet("pilot", B)["wallet"]["crystals"], 0)
        self.google.data["productLineItem"][0]["productOfferDetails"]["consumptionState"] = "CONSUMPTION_STATE_CONSUMED"
        self.assertFalse(self.ledger.verify("pilot", A, CONSUMABLE, TOKEN)["credited"])
        self.assertEqual(self.ledger.wallet("pilot", B)["wallet"]["crystals"], 0)

    def test_invalid_order_is_never_charged_or_credited(self):
        with self.assertRaisesRegex(Rejected, "wrong_account"):
            self.ledger.verify("stranger", A, CONSUMABLE, TOKEN)
        with self.assertRaisesRegex(Rejected, "wrong_product"):
            self.ledger.verify("pilot", A, PERMANENT, TOKEN)
        for state in ("PENDING", "CANCELLED"):
            self.google.data["purchaseStateContext"]["purchaseState"] = state
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
        with self.assertRaisesRegex(ValueError, "separate SQLite databases"):
            Ledger(self.path, self.google, self.key, False)
        live = Ledger(Path(self.temp.name) / "live.sqlite3", self.google, self.key, False, license_checkout=True)
        self.assertFalse(live.license_checkout)
        with self.assertRaisesRegex(Rejected, "payments_disabled"):
            live.verify("pilot", A, CONSUMABLE, TOKEN)
        self.ledger.finish_once()
        self.assertEqual(self.google.calls, [])

    def test_voided_responses_follow_google_page_token(self):
        play = GooglePlay(None)
        requests = []
        pages = iter([{"voidedPurchases": [{"purchaseToken": TOKEN}], "tokenPagination": {"nextPageToken": "next"}},
                      {"voidedPurchases": [{"purchaseToken": "another-token"}]}])

        def request(method, path):
            requests.append((method, path))
            return next(pages)

        play._request = request
        self.assertEqual(list(play.voided(10, 20)), [TOKEN, "another-token"])
        self.assertIn("startTime=10", requests[0][1])
        self.assertIn("token=next", requests[1][1])

    def test_http_scope_and_rotated_user_code_restore_after_installation_loss(self):
        tokens = {"fixture-session-token": "pilot", "fixture-recovery-token": "pilot", "fixture-other": "stranger"}
        sessions = {hashlib.sha256(secret.encode()).hexdigest(): name for secret, name in tokens.items()}
        with ThreadingHTTPServer(("127.0.0.1", 0), handler(self.ledger, sessions)) as server:
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                addr = "http://127.0.0.1:%d/v2/play/" % server.server_port

                def send(path, body, token="fixture-session-token"):
                    request = Request(addr + path, json.dumps(body).encode(),
                                      {"Authorization": "Bearer " + token, "Content-Type": "application/json"})
                    with urlopen(request, timeout=5) as response:
                        return json.load(response)

                with self.assertRaises(HTTPError) as error:
                    send("session", {}, "invalid")
                self.assertEqual(error.exception.code, 401)
                session = send("session", {})
                self.assertFalse(session["license_checkout"])
                self.assertEqual(session["obfuscated_account_id"], send("session", {}, "fixture-recovery-token")["obfuscated_account_id"])
                receipt = send("verify", {"installation": A, "sku": CONSUMABLE, "token": TOKEN})
                self.assertEqual(receipt["wallet"]["crystals"], 100)
                restored = send("wallet", {"installation": B}, "fixture-recovery-token")
                self.assertEqual(restored["wallet"], receipt["wallet"])
                isolated = send("wallet", {"installation": B}, "fixture-other")
                self.assertEqual(isolated["wallet"]["crystals"], 0)
                with self.assertRaises(HTTPError) as error:
                    send("spend", {"installation": B, "offer": "unknown", "request_id": "1" * 32})
                self.assertEqual(error.exception.code, 400)
            finally:
                server.shutdown()
                thread.join()


if __name__ == "__main__":
    unittest.main()
