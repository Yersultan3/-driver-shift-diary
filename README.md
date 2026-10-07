# Дневник смен водителя

Flutter mobile app + Python FastAPI backend for tracking driver shift trips and earnings.

## Architecture

```
arqa_project/
├── server/               # Python FastAPI backend
│   ├── main.py           # API endpoints
│   ├── requirements.txt
│   ├── data/trips.json   # persistent JSON storage (sample data included)
│   └── tests/
│       └── test_api.py   # pytest — summary calc + duplicate protection
└── lib/                  # Flutter mobile app
    ├── main.dart
    ├── models/trip.dart          # Trip + DaySummary models
    ├── services/api_service.dart # HTTP client wrapper
    └── screens/
        ├── home_screen.dart      # daily summary + trip list + day nav
        └── add_trip_screen.dart  # add trip form
```

## Running the server

Requires Python 3.10+ and pip.

```bash
cd server
pip install -r requirements.txt
python -m uvicorn main:app --reload --port 8000
# API available at http://localhost:8000
# Interactive docs: http://localhost:8000/docs
```

### API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/trips?date=YYYY-MM-DD` | List trips for a day |
| GET | `/summary?date=YYYY-MM-DD` | Daily summary (count, revenue, commission, net, cash/card) |
| POST | `/trips` | Add a trip (validates amount > 0, end > start, no duplicate id) |

### Backend tests

```bash
cd server
pytest -v
```

Covers: summary calculation, date isolation, duplicate 409, validation (amount ≤ 0, end ≤ start, bad payment type).

## Running the Flutter app

```bash
flutter pub get
flutter run
```

> **Android emulator**: change `localhost` to `10.0.2.2` in `lib/services/api_service.dart`.  
> **Real Android device**: forward the port via ADB before running:  
> ```bash
> adb reverse tcp:8000 tcp:8000
> ```

The app shows today's trips by default. Use `<` / `>` to switch days. Tap `+` to add a trip — commission is auto-set to 15% of the amount and is editable.

### Flutter tests

```bash
flutter test
```

Covers: `DaySummary.fromTrips` calculation (count, total, commission, net income, cash/card split) and duplicate-protection logic via a mock HTTP client.

## What was built

- Server stores trips in a local JSON file; the date filter correctly handles timezone-aware ISO 8601 timestamps (e.g. `+05:00`)
- `POST /trips` returns 409 on duplicate `id`; client shows a snackbar
- Form auto-calculates 15% commission and validates on the client before sending
- Russian locale for date labels and number formatting (thousands separator)

## AI usage

Claude was used to scaffold all files (FastAPI structure, Flutter screens, test skeletons). Fixes applied manually / after review:

- Pydantic v2 cross-field validation requires `@model_validator(mode="after")` — the initial `@validator` skeleton was outdated v1 syntax.
- `initializeDateFormatting('ru', null)` must be awaited in `main()` before `DateFormat(..., 'ru')` is used — the AI omitted the `await`.
- `DATA_FILE` path made absolute via `os.path.abspath(__file__)` so the server works from any working directory, not just `server/`.
- Flutter `_MockClient` used `request.finalize().bytesToString()` initially; simplified to `(request as http.Request).body` which is synchronous and avoids the stream complexity.
