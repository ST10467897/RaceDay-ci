# RaceDay – API Endpoint Plan

This document plans the REST API that will be built in Part 2. Every endpoint is described using six columns:

| Column | Meaning |
|---|---|
| **Method** | HTTP verb |
| **Route** | URL relative to the API base (`/api`) |
| **Purpose** | What the endpoint does |
| **Role** | Who may call it: `None` (public), `Any` (any logged-in user), `Participant`, `Organiser` |
| **Request** | Path/query parameters and the JSON request body |
| **Responses** | Success code and body, followed by every failure code and when it is returned |

---

## 1. Authentication

| Method | Route | Purpose | Role | Request | Responses |
|---|---|---|---|---|---|
| POST | `/api/auth/register` | Register a new participant account | None | Body:<br>`{ "firstName": "Sipho", "lastName": "Dlamini", "email": "sipho@example.com", "password": "Password123!", "phone": "0721234567", "dateOfBirth": "1996-02-27", "city": "Soweto" }` | **201** `{ "userId": 8, "email": "...", "role": "Participant" }`<br>**400** validation failed (weak password, invalid email, missing fields)<br>**409** email already registered |
| POST | `/api/auth/login` | Exchange credentials for a JWT | None | Body:<br>`{ "email": "sipho@example.com", "password": "Password123!" }` | **200** `{ "token": "<jwt>", "role": "Participant", "expiresAt": "2026-09-23T10:00:00Z" }`<br>**400** missing email or password<br>**401** invalid email or password (same message for both, to avoid account enumeration) |

---

## 2. Profile

| Method | Route | Purpose | Role | Request | Responses |
|---|---|---|---|---|---|
| GET | `/api/users/me` | Get the logged-in user's profile | Any | Header only | **200** `{ "userId", "firstName", "lastName", "email", "phone", "dateOfBirth", "city", "role", "createdAt" }`<br>**401** not logged in |
| PUT | `/api/users/me` | Update the logged-in user's profile (not email, password or role) | Any | Body:<br>`{ "firstName": "Sipho", "lastName": "Dlamini", "phone": "0721234567", "dateOfBirth": "1996-02-27", "city": "Soweto" }` | **200** updated profile<br>**400** validation failed<br>**401** not logged in |

---

## 3. Events

| Method | Route | Purpose | Role | Request | Responses |
|---|---|---|---|---|---|
| GET | `/api/events` | List published events, optionally filtered | None | Query (all optional):<br>`?type=Running&province=Gauteng&from=2026-10-01` | **200** `[ { "eventId", "name", "eventType", "eventDate", "startTime", "venue", "city", "province", "status" } ]`<br>**400** invalid filter value (e.g. bad date) |
| GET | `/api/events/{id}` | Get one event with its categories | None | Path: `id` (EventId) | **200** event object including `"organiser": { "userId", "firstName", "lastName" }` and `"categories": [ ... ]`<br>**404** event not found |
| GET | `/api/events/mine` | List events created by the logged-in organiser (all statuses) | Organiser | Header only | **200** array of events<br>**401** not logged in<br>**403** caller is a participant |
| POST | `/api/events` | Create a new event owned by the caller | Organiser | Body:<br>`{ "eventTypeId": 1, "name": "Soweto Heritage Marathon", "description": "...", "eventDate": "2026-11-01", "startTime": "06:00", "venue": "FNB Stadium", "city": "Johannesburg", "province": "Gauteng", "latitude": -26.2347, "longitude": 27.9824, "status": "Draft" }` | **201** created event, `Location: /api/events/{id}`<br>**400** validation failed (date in the past, unknown eventTypeId, missing venue)<br>**401** not logged in<br>**403** caller is a participant |
| PUT | `/api/events/{id}` | Update an event the caller owns | Organiser (owner only) | Path: `id`<br>Body: same fields as POST | **200** updated event<br>**400** validation failed<br>**401** not logged in<br>**403** not the organiser of this event<br>**404** event not found |
| DELETE | `/api/events/{id}` | Delete an event the caller owns (categories cascade) | Organiser (owner only) | Path: `id` | **204** deleted<br>**401** not logged in<br>**403** not the organiser of this event<br>**404** event not found<br>**409** event has enrolments; cancel it instead (set status to `Cancelled`) |
| GET | `/api/event-types` | List event types for dropdowns | None | – | **200** `[ { "eventTypeId": 1, "name": "Running" }, ... ]` |

---

## 4. Categories

| Method | Route | Purpose | Role | Request | Responses |
|---|---|---|---|---|---|
| GET | `/api/events/{id}/categories` | List categories for an event, with spaces remaining | None | Path: `id` (EventId) | **200** `[ { "categoryId", "name", "distanceKm", "entryFee", "maxParticipants", "minAge", "enrolledCount" } ]`<br>**404** event not found |
| POST | `/api/events/{id}/categories` | Add a category to an event the caller owns | Organiser (owner only) | Path: `id` (EventId)<br>Body:<br>`{ "name": "21.1km Half Marathon", "distanceKm": 21.1, "entryFee": 300.00, "maxParticipants": 8000, "minAge": 16 }` | **201** created category<br>**400** validation failed (distance ≤ 0, fee < 0, max ≤ 0)<br>**401** not logged in<br>**403** not the organiser of this event<br>**404** event not found<br>**409** a category with this name already exists on the event |
| PUT | `/api/categories/{id}` | Update a category | Organiser (owner of parent event) | Path: `id` (CategoryId)<br>Body: same fields as POST | **200** updated category<br>**400** validation failed (e.g. maxParticipants below current enrolments)<br>**401** not logged in<br>**403** not the organiser of the parent event<br>**404** category not found |
| DELETE | `/api/categories/{id}` | Delete a category | Organiser (owner of parent event) | Path: `id` | **204** deleted<br>**401** not logged in<br>**403** not the organiser of the parent event<br>**404** category not found<br>**409** category has enrolments |

---
