import csv
import os
import threading
import time
from datetime import datetime, timezone

from azure.containerregistry import ContainerRegistryClient
from azure.identity import DefaultAzureCredential
from flask import Flask, jsonify

app = Flask(__name__)

ACR_URL = os.environ["ACR_URL"]  # e.g. https://hsunacr.azurecr.io
LOG_PATH = "/log/log.csv"

credential = DefaultAzureCredential()


def _list_repositories() -> list[str]:
    client = ContainerRegistryClient(ACR_URL, credential)
    return list(client.list_repository_names())


@app.route("/healthz")
def healthz():
    try:
        repos = _list_repositories()
        return jsonify({"repositories": repos}), 200
    except Exception as exc:
        # Surface the upstream status code and body from the Azure SDK response
        response = getattr(exc, "response", None)
        status = getattr(response, "status_code", 500)
        return jsonify({"error": str(exc)}), status


def _log_loop() -> None:
    while True:
        ts = datetime.now(timezone.utc).isoformat()
        with open(LOG_PATH, "a", newline="") as f:
            csv.writer(f).writerow([ts, "Hello"])
        time.sleep(20)


if __name__ == "__main__":
    t = threading.Thread(target=_log_loop, daemon=True)
    t.start()
    app.run(host="0.0.0.0", port=8080)
