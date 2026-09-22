# RaceDay

RaceDay is an event management and participant tracking system for running, walking and cycling events in South Africa. Organisers publish events with one or more distance categories, participants enrol online and receive a bib number, and after race day organisers capture results that feed a public leaderboard and each participant's personal history.

This repository contains **Part 1** of the PROG6212 project: the database design, the API endpoint plan, the SQL script and the CI pipeline. No application code is included in Part 1; the ASP.NET Core Web API (Part 2) and the deployed web front end (Part 3) will be built on top of this design.

---

## System description

RaceDay solves a common problem for community sports events: entries are collected on spreadsheets, bib numbers are handed out by hand, and results are posted as a PDF days later. RaceDay replaces that with one system where:

- **Organisers** create events (a marathon, a cycle tour, a coastal walk), define the categories for each event (42.2 km, 21.1 km, 10 km and so on, each with its own entry fee, participant limit and minimum age), see who has enrolled, and capture results after the event.
- **Participants** register, browse upcoming events by type, province or date, enrol in a category, view their upcoming enrolments and see their result history once results are captured.
- **Anyone** (no login) can browse published events and view the public leaderboard for a completed event.

Each event stores its venue coordinates so that Part 2 can display live weather for the event location, and a route image URL that will point to Azure Blob Storage in Part 3.

## User roles

| Role | Can do | Cannot do |
|---|---|---|
| **Organiser** | Create, edit and delete their own events and categories. View enrolments for their events. Record and correct results. | Enrol in events. Edit events created by another organiser. |
| **Participant** | Register and log in. Maintain their profile. Enrol in a category and cancel their own enrolment. View their enrolments and results. | Create events or categories. Record results. Cancel another participant's enrolment. |

Public registration always creates a **Participant**. Organiser accounts are seeded through the SQL script so that nobody can self-register as an organiser. See the [API endpoint plan](docs/api-endpoint-plan.md) for the full authorisation rules.

## Entity Relationship Diagram

![RaceDay ERD](docs/erd.png)

Also available as [erd.pdf](docs/erd.pdf). The source is [erd.dbml](docs/erd.dbml), which can be pasted into [dbdiagram.io](https://dbdiagram.io) to view or re-export the diagram.

### Entities (7)

| Entity | Purpose | Key columns |
|---|---|---|
| **Roles** | Lookup: `Organiser`, `Participant` | `RoleId` PK, `Name` UNIQUE |
| **Users** | Every account in the system | `UserId` PK, `RoleId` FK, `Email` UNIQUE, `PasswordHash` |
| **EventTypes** | Lookup: `Running`, `Walking`, `Cycling` | `EventTypeId` PK, `Name` UNIQUE |
| **Events** | An event on a date at a venue, owned by one organiser | `EventId` PK, `OrganiserId` FK → Users, `EventTypeId` FK, `Latitude`, `Longitude`, `RouteImageUrl`, `Status` |
| **Categories** | A distance within an event, with fee, limit and minimum age | `CategoryId` PK, `EventId` FK (cascade), `DistanceKm`, `EntryFee`, `MaxParticipants`, `MinAge` |
| **Enrolments** | Junction table: a participant's entry into one category | `EnrolmentId` PK, `UserId` FK, `CategoryId` FK, `BibNumber`, UNIQUE (`UserId`, `CategoryId`) |
| **Results** | Outcome for one enrolment: finish time, positions, or DNF/DNS | `ResultId` PK, `EnrolmentId` FK UNIQUE, `RecordedById` FK → Users |

### Relationships

| Relationship | Cardinality | How it is enforced |
|---|---|---|
| Roles → Users | 1 : many | `FK_Users_Roles` |
| Users (organiser) → Events | 1 : many | `FK_Events_Users` |
| EventTypes → Events | 1 : many | `FK_Events_EventTypes` |
| Events → Categories | 1 : many | `FK_Categories_Events` with `ON DELETE CASCADE` |
| **Users ↔ Categories** | **many : many**, resolved through **Enrolments** | `FK_Enrolments_Users`, `FK_Enrolments_Categories`, `UQ_Enrolments_User_Category` |
| Enrolments → Results | 1 : 0..1 | `FK_Results_Enrolments` plus `UQ_Results_EnrolmentId` |
| Users (organiser) → Results | 1 : many (who recorded it) | `FK_Results_Users` |

The many-to-many relationship between Users and Categories is the heart of the design: a participant enrols in many categories over time, and a category has many participants. `Enrolments` resolves it and carries the attributes that belong to the pairing (bib number, status, enrolment date). `Results` hangs off `Enrolments` rather than off `Users` and `Categories` separately, so a result can never be attached to a participant who was not enrolled.
