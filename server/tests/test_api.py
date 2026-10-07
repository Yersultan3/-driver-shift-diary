import pytest
from fastapi.testclient import TestClient

import main as m

TRIP_1 = {
    "id": "t1",
    "start": "2026-10-01T08:10:00+05:00",
    "end": "2026-10-01T08:32:00+05:00",
    "amount": 2400,
    "payment": "card",
    "commission": 360,
}
TRIP_2 = {
    "id": "t2",
    "start": "2026-10-01T09:05:00+05:00",
    "end": "2026-10-01T09:20:00+05:00",
    "amount": 1500,
    "payment": "cash",
    "commission": 225,
}


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(m, "DATA_FILE", str(tmp_path / "trips.json"))
    return TestClient(m.app)


class TestSummary:
    def test_empty_day(self, client):
        r = client.get("/summary?date=2026-10-01")
        assert r.status_code == 200
        d = r.json()
        assert d["trips_count"] == 0
        assert d["net_income"] == 0

    def test_calculation(self, client):
        client.post("/trips", json=TRIP_1)
        client.post("/trips", json=TRIP_2)
        d = client.get("/summary?date=2026-10-01").json()
        assert d["trips_count"] == 2
        assert d["total_amount"] == 3900
        assert d["total_commission"] == 585
        assert d["net_income"] == 3315
        assert d["cash"] == 1500
        assert d["card"] == 2400

    def test_isolates_by_date(self, client):
        client.post("/trips", json=TRIP_1)
        d = client.get("/summary?date=2026-10-02").json()
        assert d["trips_count"] == 0


class TestDuplicates:
    def test_first_add_succeeds(self, client):
        r = client.post("/trips", json=TRIP_1)
        assert r.status_code == 201

    def test_same_id_returns_409(self, client):
        client.post("/trips", json=TRIP_1)
        r = client.post("/trips", json=TRIP_1)
        assert r.status_code == 409

    def test_different_id_succeeds(self, client):
        client.post("/trips", json=TRIP_1)
        r = client.post("/trips", json=TRIP_2)
        assert r.status_code == 201


class TestValidation:
    def test_amount_zero(self, client):
        r = client.post("/trips", json={**TRIP_1, "id": "x", "amount": 0})
        assert r.status_code == 422

    def test_amount_negative(self, client):
        r = client.post("/trips", json={**TRIP_1, "id": "x", "amount": -1})
        assert r.status_code == 422

    def test_end_before_start(self, client):
        r = client.post("/trips", json={
            **TRIP_1, "id": "x",
            "start": "2026-10-01T09:00:00+05:00",
            "end": "2026-10-01T08:00:00+05:00",
        })
        assert r.status_code == 422

    def test_invalid_payment(self, client):
        r = client.post("/trips", json={**TRIP_1, "id": "x", "payment": "crypto"})
        assert r.status_code == 422
