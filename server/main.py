import json
import os
from datetime import datetime
from typing import Annotated

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator, model_validator

_BASE = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.getenv("TRIPS_DATA_FILE", os.path.join(_BASE, "data", "trips.json"))

app = FastAPI(title="Driver Shift Diary API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _load() -> list[dict]:
    if not os.path.exists(DATA_FILE):
        return []
    with open(DATA_FILE, encoding="utf-8") as f:
        return json.load(f)


def _save(trips: list[dict]) -> None:
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(trips, f, ensure_ascii=False, indent=2)


class TripIn(BaseModel):
    id: str
    start: str
    end: str
    amount: float
    payment: str
    commission: float

    @field_validator("amount")
    @classmethod
    def amount_gt_zero(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("amount must be > 0")
        return v

    @field_validator("payment")
    @classmethod
    def payment_valid(cls, v: str) -> str:
        if v not in ("cash", "card"):
            raise ValueError("payment must be 'cash' or 'card'")
        return v

    @model_validator(mode="after")
    def end_after_start(self) -> "TripIn":
        start = datetime.fromisoformat(self.start)
        end = datetime.fromisoformat(self.end)
        if end <= start:
            raise ValueError("end must be after start")
        return self


def _trips_for_date(date: str) -> list[dict]:
    return [
        t for t in _load()
        if datetime.fromisoformat(t["start"]).date().isoformat() == date
    ]


@app.get("/trips")
def list_trips(
    date: Annotated[str, Query(pattern=r"^\d{4}-\d{2}-\d{2}$")]
) -> list[dict]:
    return _trips_for_date(date)


@app.get("/summary")
def get_summary(
    date: Annotated[str, Query(pattern=r"^\d{4}-\d{2}-\d{2}$")]
) -> dict:
    trips = _trips_for_date(date)
    total = sum(t["amount"] for t in trips)
    commission = sum(t["commission"] for t in trips)
    cash = sum(t["amount"] for t in trips if t["payment"] == "cash")
    card = sum(t["amount"] for t in trips if t["payment"] == "card")
    return {
        "date": date,
        "trips_count": len(trips),
        "total_amount": total,
        "total_commission": commission,
        "net_income": total - commission,
        "cash": cash,
        "card": card,
    }


@app.post("/trips", status_code=201)
def add_trip(trip: TripIn) -> dict:
    trips = _load()
    if any(t["id"] == trip.id for t in trips):
        raise HTTPException(status_code=409, detail="duplicate trip id")
    data = trip.model_dump()
    trips.append(data)
    _save(trips)
    return data
