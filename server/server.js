const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8000;
const DATA_FILE = process.env.TRIPS_DATA_FILE || path.join(__dirname, 'data', 'trips.json');

app.use(express.json());
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// ── storage ──────────────────────────────────────────────────────────────────

function loadTrips() {
  if (!fs.existsSync(DATA_FILE)) return [];
  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
}

function saveTrips(trips) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(trips, null, 2), 'utf8');
}

function tripsForDate(date) {
  return loadTrips().filter(t => {
    const d = new Date(t.start);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}` === date;
  });
}

// ── validation ───────────────────────────────────────────────────────────────

function validate(trip) {
  const errors = [];
  if (!trip.id || typeof trip.id !== 'string') errors.push('id required');
  if (!trip.start) errors.push('start required');
  if (!trip.end) errors.push('end required');
  if (typeof trip.amount !== 'number' || trip.amount <= 0) errors.push('amount must be > 0');
  if (!['cash', 'card'].includes(trip.payment)) errors.push("payment must be 'cash' or 'card'");
  if (typeof trip.commission !== 'number' || trip.commission < 0) errors.push('commission must be >= 0');
  if (trip.start && trip.end && new Date(trip.end) <= new Date(trip.start)) {
    errors.push('end must be after start');
  }
  return errors;
}

// ── routes ───────────────────────────────────────────────────────────────────

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

app.get('/trips', (req, res) => {
  const { date } = req.query;
  if (!date || !DATE_RE.test(date)) return res.status(400).json({ detail: 'date must be YYYY-MM-DD' });
  res.json(tripsForDate(date));
});

app.get('/summary', (req, res) => {
  const { date } = req.query;
  if (!date || !DATE_RE.test(date)) return res.status(400).json({ detail: 'date must be YYYY-MM-DD' });
  const trips = tripsForDate(date);
  const total = trips.reduce((s, t) => s + t.amount, 0);
  const commission = trips.reduce((s, t) => s + t.commission, 0);
  const cash = trips.filter(t => t.payment === 'cash').reduce((s, t) => s + t.amount, 0);
  const card = trips.filter(t => t.payment === 'card').reduce((s, t) => s + t.amount, 0);
  res.json({
    date,
    trips_count: trips.length,
    total_amount: total,
    total_commission: commission,
    net_income: total - commission,
    cash,
    card,
  });
});

app.post('/trips', (req, res) => {
  const trip = req.body;
  const errors = validate(trip);
  if (errors.length) return res.status(422).json({ detail: errors });

  const trips = loadTrips();
  if (trips.some(t => t.id === trip.id)) {
    return res.status(409).json({ detail: 'duplicate trip id' });
  }
  trips.push(trip);
  saveTrips(trips);
  res.status(201).json(trip);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
