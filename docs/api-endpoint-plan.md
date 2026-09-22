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

## 5. Enrolments

| Method | Route | Purpose | Role | Request | Responses |
|---|---|---|---|---|---|
| POST | `/api/enrolments` | Enrol the caller in a category (bib number assigned automatically) | Participant | Body:<br>`{ "categoryId": 2 }` | **201** `{ "enrolmentId", "categoryId", "eventName", "categoryName", "bibNumber", "status": "Active", "enrolledAt" }`<br>**400** caller is younger than the category's minAge, or event is not `Published`<br>**401** not logged in<br>**403** caller is an organiser<br>**404** category not found<br>**409** already enrolled in this category, or the category is full |
| GET | `/api/enrolments/me` | List the caller's enrolments (upcoming and past) | Participant | Header only | **200** array of enrolments with event and category details<br>**401** not logged in<br>**403** caller is an organiser |
| DELETE | `/api/enrolments/{id}` | Cancel the caller's own enrolment (sets status to `Cancelled`) | Participant (own only) | Path: `id` (EnrolmentId) | **204** cancelled<br>**401** not logged in<br>**403** enrolment belongs to another user<br>**404** enrolment not found<br>**409** event has already taken place, or a result exists |
| GET | `/api/events/{id}/enrolments` | List all enrolments for an event (organiser's participant list) | Organiser (owner only) | Path: `id` (EventId)<br>Query (optional): `?categoryId=2&status=Active` | **200** `[ { "enrolmentId", "bibNumber", "status", "participant": { "userId", "firstName", "lastName", "email" }, "category": { "categoryId", "name" } } ]`<br>**401** not logged in<br>**403** not the organiser of this event<br>**404** event not found |

---

## 6. Results

| Method | Route | Purpose | Role | Request | Responses |
|---|---|---|---|---|---|
| POST | `/api/enrolments/{id}/result` | Record a result for one enrolment | Organiser (owner of the event) | Path: `id` (EnrolmentId)<br>Body:<br>`{ "status": "Finished", "elapsedSeconds": 5112, "overallPosition": 14, "categoryPosition": 1 }`<br>For DNF/DNS: `{ "status": "DNF" }` | **201** created result (`recordedById` = caller)<br>**400** validation failed (Finished without elapsedSeconds, negative values)<br>**401** not logged in<br>**403** not the organiser of the enrolment's event<br>**404** enrolment not found<br>**409** a result already exists for this enrolment, or the enrolment is `Cancelled` |
| PUT | `/api/results/{id}` | Correct a recorded result | Organiser (owner of the event) | Path: `id` (ResultId)<br>Body: same fields as POST | **200** updated result<br>**400** validation failed<br>**401** not logged in<br>**403** not the organiser of the event<br>**404** result not found |
| GET | `/api/events/{id}/results` | Public leaderboard for an event, grouped by category | None | Path: `id` (EventId)<br>Query (optional): `?categoryId=8` | **200** `[ { "category": "21.1km Half Marathon", "results": [ { "categoryPosition", "overallPosition", "bibNumber", "participant": "Sipho Dlamini", "elapsedSeconds", "status" } ] } ]`<br>**404** event not found |
| GET | `/api/results/me` | The caller's personal results history | Participant | Header only | **200** array of results with event, category, time and positions<br>**401** not logged in<br>**403** caller is an organiser |

---
