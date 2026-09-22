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
