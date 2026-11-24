"""Google Play verification, account balances and refund reconciliation."""
import hashlib
import hmac
import json
import os
import re
import sqlite3
import threading
import time
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, urlencode

PRODUCTS = {
    "gs_starter_v1": "acknowledge",
    "gs_crystals_100": "consume",
    "gs_crystals_350": "consume",
    "gs_crystals_900": "consume",
    "gs_helion_pass_v1": "acknowledge",
}
DRAFT_PRODUCTS = {
    "gs_arsenal_v1": "arsenal_pilot",
    "gs_hangar_supply_v1": "hangar_supply",
    "gs_skin_specter_noctis_v1": "skin_specter_noctis",
    "gs_skin_aurora_vesper_v1": "skin_aurora_vesper",
    "gs_pilot_fx_prism_v1": "pilot_fx_prism",
}
SETTLEMENT = {**PRODUCTS, **{sku: "acknowledge" for sku in DRAFT_PRODUCTS}}
CRYSTAL_GRANTS = {"gs_starter_v1": 120, "gs_crystals_100": 100, "gs_crystals_350": 350, "gs_crystals_900": 900}
PERMANENT_OFFERS = {"gs_starter_v1": "starter", "gs_helion_pass_v1": "season_helion", **DRAFT_PRODUCTS}
LOCAL_DELIVERIES = {"gs_starter_v1", "gs_hangar_supply_v1"}
WALLET_OFFERS = {"skin_ion": 45, "skin_frost": 55, "equipment_signal": 80}
PACKAGE = "com.galaxystrike.spacesurvivor"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
HEX_ID = re.compile(r"[0-9a-f]{64}")
REQUEST_ID = re.compile(r"[0-9a-f]{32}")
DAY_MS = 86_400_000


class Rejected(Exception):
    def __init__(self, status, reason):
        super().__init__(reason)
        self.status = status
        self.reason = reason


class GooglePlay:
    def __init__(self, credentials):
        self.credentials = credentials
        self.base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + PACKAGE

    def _request(self, method, path, body=None):
        from google.auth.exceptions import GoogleAuthError
        from google.auth.transport.requests import AuthorizedSession
        from requests import RequestException

        try:
            with AuthorizedSession(self.credentials) as connection:
                result = connection.request(method, self.base + path, json=body, timeout=12)
        except (GoogleAuthError, RequestException):
            raise Rejected(503, "google_unavailable") from None
        if result.status_code in (400, 404, 410):
            raise Rejected(422, "invalid_purchase")
        if not result.ok:
            raise Rejected(503, "google_unavailable")
        try:
            return result.json() if method == "GET" else None
        except ValueError:
            raise Rejected(503, "google_unavailable") from None

    def purchase(self, token):
        return self._request("GET", "/purchases/productsv2/tokens/" + quote(token, safe=""))

    def finish(self, sku, token):
        operation = SETTLEMENT[sku]
        body = {} if operation == "acknowledge" else None
        self._request("POST", f"/purchases/products/{sku}/tokens/{quote(token, safe='')}:{operation}", body)

    def voided(self, since, until):
        query = {"startTime": since, "endTime": until, "type": 0, "maxResults": 1000,
                 "includeQuantityBasedPartialRefund": "true"}
        seen = set()
        while True:
            page = self._request("GET", "/purchases/voidedpurchases?" + urlencode(query))
            for row in page.get("voidedPurchases", []):
                yield row["purchaseToken"]
            token = page.get("tokenPagination", {}).get("nextPageToken")
            if not token:
                return
            if token in seen:
                raise Rejected(503, "google_unavailable")
            seen.add(token)
            query = {"token": token, "type": 0, "includeQuantityBasedPartialRefund": "true"}


class Ledger:
    def __init__(self, database, play, account_key, test_only, license_checkout=False, draft_checkout=False):
        self.database = database
        self.play = play
        self.account_key = account_key
        self.test_only = test_only
        self.license_checkout = test_only and license_checkout
        self.draft_checkout = self.license_checkout and draft_checkout
        with closing(self._open()) as db:
            db.execute("PRAGMA journal_mode=WAL")
        with closing(self._open()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("CREATE TABLE IF NOT EXISTS wallet_environment (mode TEXT PRIMARY KEY)")
            mode = "test" if test_only else "live"
            prior_mode = db.execute("SELECT mode FROM wallet_environment").fetchone()
            if prior_mode and prior_mode["mode"] != mode:
                raise ValueError("Use separate SQLite databases for live and test Play accounts.")
            if prior_mode is None:
                db.execute("INSERT INTO wallet_environment VALUES (?)", (mode,))
            db.execute("""CREATE TABLE IF NOT EXISTS orders (
                id TEXT PRIMARY KEY,
                player TEXT NOT NULL,
                installation TEXT NOT NULL,
                sku TEXT NOT NULL,
                token TEXT NOT NULL,
                received INTEGER NOT NULL DEFAULT 0,
                finalized INTEGER NOT NULL DEFAULT 0
            )""")
            columns = {row["name"] for row in db.execute("PRAGMA table_info(orders)")}
            for column in ("voided", "local_credit_bonus"):
                if column not in columns:
                    db.execute(f"ALTER TABLE orders ADD COLUMN {column} INTEGER NOT NULL DEFAULT 0")
            db.execute("""CREATE TABLE IF NOT EXISTS wallet_events (
                seq INTEGER PRIMARY KEY,
                event_id TEXT NOT NULL UNIQUE,
                player TEXT NOT NULL,
                amount INTEGER NOT NULL,
                kind TEXT NOT NULL CHECK(kind IN ('purchase', 'spend', 'refund')),
                reference TEXT NOT NULL
            )""")
            db.execute("CREATE INDEX IF NOT EXISTS wallet_events_by_player ON wallet_events(player, seq)")
            db.execute("CREATE INDEX IF NOT EXISTS orders_by_player ON orders(player, voided, sku)")
            db.execute("""CREATE TABLE IF NOT EXISTS wallet_spends (
                player TEXT NOT NULL,
                request_id TEXT NOT NULL,
                offer TEXT NOT NULL,
                PRIMARY KEY(player, request_id),
                UNIQUE(player, offer)
            )""")
            db.execute("CREATE TABLE IF NOT EXISTS voided_tokens (id TEXT PRIMARY KEY)")
            db.execute("CREATE TABLE IF NOT EXISTS refund_cursor (id INTEGER PRIMARY KEY CHECK(id = 1), scanned_until INTEGER NOT NULL)")

    def _open(self):
        connection = sqlite3.connect(self.database, timeout=8)
        connection.row_factory = sqlite3.Row
        return connection

    def account_id(self, player):
        return hmac.new(self.account_key, player.encode(), hashlib.sha256).hexdigest()

    def _check_purchase(self, purchase, player, sku, token):
        if purchase.get("obfuscatedExternalAccountId") != self.account_id(player):
            raise Rejected(403, "wrong_account")
        if ("testPurchaseContext" in purchase) != self.test_only:
            raise Rejected(422, "wrong_purchase_environment")
        items = purchase.get("productLineItem", [])
        if len(items) != 1 or items[0].get("productId") != sku:
            raise Rejected(422, "wrong_product")
        state = purchase.get("purchaseStateContext", {}).get("purchaseState")
        if state == "CANCELLED":
            self.record_void(token)
            raise Rejected(422, "purchase_voided")
        if state != "PURCHASED":
            raise Rejected(422, "purchase_not_completed")
        offer = items[0].get("productOfferDetails", {})
        if offer.get("quantity") != 1 or offer.get("refundableQuantity", 1) != 1:
            raise Rejected(422, "unsupported_quantity")
        if SETTLEMENT[sku] == "consume":
            return offer.get("consumptionState") == "CONSUMPTION_STATE_CONSUMED"
        return purchase.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"

    def verify(self, player, installation, sku, token):
        if not self.test_only:
            raise Rejected(403, "payments_disabled")
        if not isinstance(sku, str) or sku not in SETTLEMENT or not isinstance(token, str) or not 8 <= len(token) <= 2048:
            raise Rejected(400, "invalid_request")
        delivery = hashlib.sha256(token.encode()).hexdigest()
        if sku in DRAFT_PRODUCTS and not self.draft_checkout:
            with closing(self._open()) as db:
                historic = db.execute("SELECT 1 FROM orders WHERE id = ? AND player = ? AND sku = ?",
                                      (delivery, player, sku)).fetchone()
            if not historic:
                raise Rejected(403, "payments_disabled")
        purchase = self.play.purchase(token)
        platform_finished = self._check_purchase(purchase, player, sku, token)

        with closing(self._open()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            if db.execute("SELECT 1 FROM voided_tokens WHERE id = ?", (delivery,)).fetchone():
                raise Rejected(422, "purchase_voided")
            row = db.execute("SELECT * FROM orders WHERE id = ?", (delivery,)).fetchone()
            credited = False
            if row is None:
                # A consumed/acknowledged orphan or a 0.6 row has no safely reconstructible balance.
                already_owned = PERMANENT_OFFERS.get(sku) in self._owned(db, player)
                credited = not platform_finished and not already_owned
                bonus = credited and sku in LOCAL_DELIVERIES
                db.execute("""INSERT INTO orders
                    (id, player, installation, sku, token, received, finalized, local_credit_bonus)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                    (delivery, player, installation, sku, token, int(not bonus), int(platform_finished), int(bonus)))
                self._event(db, "purchase:" + delivery, player, CRYSTAL_GRANTS.get(sku, 0) if credited else 0,
                            "purchase", delivery)
            elif row["player"] != player or row["sku"] != sku:
                raise Rejected(403, "wrong_account")
            return {"sku": sku, "credited": credited, **self._account_data(db, player, installation)}

    @staticmethod
    def _event(db, event_id, player, amount, kind, reference):
        db.execute("INSERT INTO wallet_events (event_id, player, amount, kind, reference) VALUES (?, ?, ?, ?, ?)",
                   (event_id, player, amount, kind, reference))

    @staticmethod
    def _owned(db, player, include_spends=True):
        owned = set()
        if include_spends:
            owned.update(row["offer"] for row in db.execute("SELECT offer FROM wallet_spends WHERE player = ?", (player,)))
        for row in db.execute("SELECT DISTINCT sku FROM orders WHERE player = ? AND voided = 0", (player,)):
            if row["sku"] in PERMANENT_OFFERS:
                owned.add(PERMANENT_OFFERS[row["sku"]])
        return owned

    def _account_data(self, db, player, installation):
        balance, revision = db.execute("SELECT coalesce(sum(amount), 0), coalesce(max(seq), 0) FROM wallet_events WHERE player = ?",
                                       (player,)).fetchone()
        bonuses = db.execute("""SELECT id, sku FROM orders WHERE player = ? AND installation = ?
                                AND received = 0 AND voided = 0 AND local_credit_bonus = 1""",
                             (player, installation)).fetchall()
        return {"wallet": {"crystals": max(0, balance), "debt": max(0, -balance), "revision": revision,
                           "offers": sorted(self._owned(db, player, include_spends=balance >= 0))},
                "credits_deliveries": [row["id"] for row in bonuses if row["sku"] == "gs_starter_v1"],
                "local_deliveries": [{"id": row["id"], "sku": row["sku"]} for row in bonuses if row["sku"] == "gs_hangar_supply_v1"]}

    def wallet(self, player, installation):
        with closing(self._open()) as db:
            db.execute("BEGIN")
            return self._account_data(db, player, installation)

    def spend(self, player, installation, request_id, offer):
        if not isinstance(request_id, str) or not REQUEST_ID.fullmatch(request_id) or not isinstance(offer, str) or offer not in WALLET_OFFERS:
            raise Rejected(400, "invalid_request")
        price = WALLET_OFFERS[offer]
        with closing(self._open()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT offer FROM wallet_spends WHERE player = ? AND request_id = ?",
                                  (player, request_id)).fetchone()
            if existing and existing["offer"] != offer:
                raise Rejected(409, "request_conflict")
            current = self._account_data(db, player, installation)
            owns_skin = offer == "skin_ion" and "starter" in current["wallet"]["offers"]
            if existing or owns_skin or offer in self._owned(db, player):
                return {"spent": False, **current}
            if current["wallet"]["crystals"] < price:
                raise Rejected(409, "insufficient_funds")
            db.execute("INSERT INTO wallet_spends VALUES (?, ?, ?)", (player, request_id, offer))
            self._event(db, f"spend:{self.account_id(player)}:{request_id}", player, -price, "spend", offer)
            return {"spent": True, **self._account_data(db, player, installation)}

    def received(self, player, installation, delivery):
        if not isinstance(delivery, str) or not HEX_ID.fullmatch(delivery):
            raise Rejected(400, "invalid_request")
        with closing(self._open()) as db, db:
            count = db.execute("""UPDATE orders SET received = 1 WHERE id = ? AND player = ? AND installation = ?
                                  AND local_credit_bonus = 1 AND voided = 0""",
                               (delivery, player, installation)).rowcount
            if not count:
                raise Rejected(404, "unknown_delivery")

    def record_void(self, token):
        delivery = hashlib.sha256(token.encode()).hexdigest()
        with closing(self._open()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            if not db.execute("INSERT OR IGNORE INTO voided_tokens VALUES (?)", (delivery,)).rowcount:
                return
            order = db.execute("SELECT player FROM orders WHERE id = ?", (delivery,)).fetchone()
            if order is None:
                return
            credit = db.execute("SELECT amount FROM wallet_events WHERE event_id = ?", ("purchase:" + delivery,)).fetchone()
            db.execute("UPDATE orders SET voided = 1 WHERE id = ?", (delivery,))
            self._event(db, "refund:" + delivery, order["player"], -credit["amount"] if credit else 0, "refund", delivery)

    def reconcile_voids(self, now_ms=None):
        current = int(time.time() * 1000) if now_ms is None else now_ms
        until = current - 60_000
        with closing(self._open()) as db:
            previous = db.execute("SELECT scanned_until FROM refund_cursor WHERE id = 1").fetchone()
        earliest = current - 29 * DAY_MS
        since = max(earliest, previous["scanned_until"] - DAY_MS) if previous else earliest
        for token in self.play.voided(since, until):
            self.record_void(token)
        with closing(self._open()) as db, db:
            db.execute("""INSERT INTO refund_cursor VALUES (1, ?)
                          ON CONFLICT(id) DO UPDATE SET scanned_until = max(scanned_until, excluded.scanned_until)""", (until,))

    def finish_once(self):
        with closing(self._open()) as db:
            rows = db.execute("SELECT * FROM orders WHERE finalized = 0 AND voided = 0 ORDER BY rowid").fetchall()
        for row in rows:
            try:
                purchase = self.play.purchase(row["token"])
                if not self._check_purchase(purchase, row["player"], row["sku"], row["token"]):
                    self.play.finish(row["sku"], row["token"])
            except Rejected:
                # Keep the row for retry, including after process restart.
                continue
            with closing(self._open()) as db, db:
                db.execute("UPDATE orders SET finalized = 1 WHERE id = ?", (row["id"],))


def handler(ledger, sessions):
    class PlayHandler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            return

        def do_POST(self):
            try:
                auth_type, _, secret = self.headers.get("Authorization", "").partition(" ")
                digest = hashlib.sha256(secret.encode()).hexdigest()
                player = sessions.get(digest) if auth_type == "Bearer" else None
                if not player:
                    raise Rejected(401, "session_required")
                length = int(self.headers.get("Content-Length", 0))
                if not 0 < length <= 8192:
                    raise Rejected(400, "invalid_request")
                data = json.loads(self.rfile.read(length))
                if not isinstance(data, dict):
                    raise Rejected(400, "invalid_request")
                payload = self._route(player, data)
                self._reply(200, {"ok": True, "play_mode": "test" if ledger.test_only else "live", **payload})
            except Rejected as error:
                self._reply(error.status, {"ok": False, "error": error.reason})
            except (TypeError, ValueError):
                self._reply(400, {"ok": False, "error": "invalid_request"})
            except Exception:
                self._reply(503, {"ok": False, "error": "server_unavailable"})

        def _route(self, player, data):
            if self.path == "/v2/play/session":
                return {"obfuscated_account_id": ledger.account_id(player), "license_checkout": ledger.license_checkout,
                        "draft_checkout": ledger.draft_checkout}
            install = data.get("installation")
            if not isinstance(install, str) or not re.fullmatch(r"[0-9a-f]{32}", install):
                raise Rejected(400, "invalid_installation")
            if self.path == "/v2/play/verify":
                return ledger.verify(player, install, data.get("sku"), data.get("token"))
            if self.path == "/v2/play/wallet":
                return ledger.wallet(player, install)
            if self.path == "/v2/play/spend":
                return ledger.spend(player, install, data.get("request_id"), data.get("offer"))
            if self.path == "/v2/play/received":
                ledger.received(player, install, data.get("delivery_id"))
                return {}
            raise Rejected(404, "not_found")

        def _reply(self, status, payload):
            response = json.dumps(payload, separators=(",", ":")).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)

    return PlayHandler


def main():
    import google.auth

    os.umask(0o077)
    sessions = json.loads(os.environ["STRIKE_SESSION_DIGESTS"])
    if not sessions or any(not HEX_ID.fullmatch(key) or not isinstance(value, str) or not value
                           for key, value in sessions.items()):
        raise SystemExit("Configure SHA-256 session token digests and stable account names.")
    account_key = bytes.fromhex(os.environ["STRIKE_ACCOUNT_BINDING_KEY"])
    if len(account_key) < 32:
        raise SystemExit("Configure an account binding key of at least 32 bytes.")
    mode = os.environ.get("STRIKE_PLAY_MODE", "test")
    if mode not in ("test", "live"):
        raise SystemExit("Set STRIKE_PLAY_MODE to test or live.")
    credentials, _ = google.auth.default(scopes=SCOPES)
    ledger = Ledger(os.environ["STRIKE_PLAY_DATABASE"], GooglePlay(credentials), account_key, mode == "test",
                    os.environ.get("STRIKE_ENABLE_LICENSE_CHECKOUT") == "1",
                    os.environ.get("STRIKE_ENABLE_DRAFT_CATALOG") == "1")
    stop = threading.Event()

    def settle_play():
        while not stop.is_set():
            try:
                ledger.finish_once()
            except sqlite3.Error:
                pass
            stop.wait(20)

    def refund_worker():
        while not stop.is_set():
            try:
                ledger.reconcile_voids()
            except (sqlite3.Error, Rejected, KeyError, TypeError):
                # Keep the same scan window on a failed API page.
                print("Play refund reconciliation will retry", flush=True)
            stop.wait(300)

    worker = threading.Thread(target=settle_play, daemon=True)
    worker.start()
    threading.Thread(target=refund_worker, daemon=True).start()
    port = int(os.environ.get("STRIKE_PLAY_PORT", "8080"))
    with ThreadingHTTPServer(("127.0.0.1", port), handler(ledger, sessions)) as server:
        try:
            server.serve_forever()
        finally:
            stop.set()


if __name__ == "__main__":
    main()
