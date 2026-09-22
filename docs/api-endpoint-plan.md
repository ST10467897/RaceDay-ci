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
