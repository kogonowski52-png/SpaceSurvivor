"""Galaxy Strike's reference Play verifier and durable purchase delivery service."""
import hashlib
import hmac
import json
import os
import re
import sqlite3
import threading
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote

PRODUCTS = {
    "gs_starter_v1": "acknowledge",
    "gs_crystals_100": "consume",
    "gs_crystals_350": "consume",
    "gs_crystals_900": "consume",
    "gs_helion_pass_v1": "acknowledge",
}
PACKAGE = "com.galaxystrike.spacesurvivor"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
HEX_ID = re.compile(r"[0-9a-f]{64}")


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
        operation = PRODUCTS[sku]
        body = {} if operation == "acknowledge" else None
        self._request("POST", f"/purchases/products/{sku}/tokens/{quote(token, safe='')}:{operation}", body)


class Ledger:
    def __init__(self, database, play, account_key, test_only):
        self.database = database
        self.play = play
        self.account_key = account_key
        self.test_only = test_only
        with closing(self._open()) as db:
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("""CREATE TABLE IF NOT EXISTS orders (
                id TEXT PRIMARY KEY,
                player TEXT NOT NULL,
                installation TEXT NOT NULL,
                sku TEXT NOT NULL,
                token TEXT NOT NULL,
                received INTEGER NOT NULL DEFAULT 0,
                finalized INTEGER NOT NULL DEFAULT 0
            )""")
            db.commit()

    def _open(self):
        connection = sqlite3.connect(self.database, timeout=8)
        connection.row_factory = sqlite3.Row
        return connection

    def account_id(self, player):
        return hmac.new(self.account_key, player.encode(), hashlib.sha256).hexdigest()

    def _check_purchase(self, purchase, player, sku):
        if purchase.get("obfuscatedExternalAccountId") != self.account_id(player):
            raise Rejected(403, "wrong_account")
        if ("testPurchaseContext" in purchase) != self.test_only:
            raise Rejected(422, "wrong_purchase_environment")
        if purchase.get("purchaseStateContext", {}).get("purchaseState") != "PURCHASED":
            raise Rejected(422, "purchase_not_completed")
        items = purchase.get("productLineItem", [])
        if len(items) != 1 or items[0].get("productId") != sku:
            raise Rejected(422, "wrong_product")
        offer = items[0].get("productOfferDetails", {})
        if offer.get("quantity") != 1 or offer.get("refundableQuantity", 1) != 1:
            raise Rejected(422, "unsupported_quantity")
        if PRODUCTS[sku] == "consume":
            return offer.get("consumptionState") == "CONSUMPTION_STATE_CONSUMED"
        return purchase.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"

    def verify(self, player, installation, sku, token):
        if not isinstance(sku, str) or sku not in PRODUCTS or not isinstance(token, str) or not 8 <= len(token) <= 2048:
            raise Rejected(400, "invalid_request")
        purchase = self.play.purchase(token)
        platform_finished = self._check_purchase(purchase, player, sku)
        delivery = hashlib.sha256(token.encode()).hexdigest()

        with closing(self._open()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM orders WHERE id = ?", (delivery,)).fetchone()
            if row is None:
                # If a Play token was finalized before this ledger saw it, restore permanent
                # rights but never pay its currency again.
                db.execute("INSERT INTO orders VALUES (?, ?, ?, ?, ?, ?, ?)",
                           (delivery, player, installation, sku, token, int(platform_finished), int(platform_finished)))
                row = db.execute("SELECT * FROM orders WHERE id = ?", (delivery,)).fetchone()
            if row["player"] != player or row["sku"] != sku:
                raise Rejected(403, "wrong_account")
            return self._describe(row, installation)

    @staticmethod
    def _describe(row, installation):
        if row["received"]:
            mode = "restore" if PRODUCTS[row["sku"]] == "acknowledge" else "received"
        elif row["installation"] == installation:
            mode = "deliver"
        else:
            mode = "other_device"
        return {"sku": row["sku"], "delivery_id": row["id"], "mode": mode}

    def outstanding(self, player, installation):
        with closing(self._open()) as db:
            rows = db.execute("SELECT * FROM orders WHERE player = ? AND installation = ? AND received = 0",
                              (player, installation)).fetchall()
            return [self._describe(row, installation) for row in rows]

    def received(self, player, installation, delivery):
        if not isinstance(delivery, str) or not HEX_ID.fullmatch(delivery):
            raise Rejected(400, "invalid_request")
        with closing(self._open()) as db, db:
            count = db.execute("UPDATE orders SET received = 1 WHERE id = ? AND player = ? AND installation = ?",
                               (delivery, player, installation)).rowcount
            if not count:
                raise Rejected(404, "unknown_delivery")

    def finish_once(self):
        with closing(self._open()) as db:
            rows = db.execute("SELECT * FROM orders WHERE finalized = 0 ORDER BY rowid").fetchall()
        for row in rows:
            try:
                purchase = self.play.purchase(row["token"])
                if not self._check_purchase(purchase, row["player"], row["sku"]):
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
            if self.path == "/v1/play/session":
                return {"obfuscated_account_id": ledger.account_id(player)}
            install = data.get("installation")
            if not isinstance(install, str) or not re.fullmatch(r"[0-9a-f]{32}", install):
                raise Rejected(400, "invalid_installation")
            if self.path == "/v1/play/verify":
                return ledger.verify(player, install, data.get("sku"), data.get("token"))
            if self.path == "/v1/play/outstanding":
                return {"orders": ledger.outstanding(player, install)}
            if self.path == "/v1/play/received":
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
    ledger = Ledger(os.environ["STRIKE_PLAY_DATABASE"], GooglePlay(credentials), account_key, mode == "test")
    stop = threading.Event()

    def settle_play():
        while not stop.is_set():
            try:
                ledger.finish_once()
            except sqlite3.Error:
                pass
            stop.wait(20)

    worker = threading.Thread(target=settle_play, daemon=True)
    worker.start()
    port = int(os.environ.get("STRIKE_PLAY_PORT", "8080"))
    with ThreadingHTTPServer(("127.0.0.1", port), handler(ledger, sessions)) as server:
        try:
            server.serve_forever()
        finally:
            stop.set()


if __name__ == "__main__":
    main()
