/* =============================================================================
   RaceDay - Database Schema and Seed Data
   PROG6212 Part 1

   Target:  Microsoft SQL Server 2019+ (tested on SQL Server 2022)
   Usage:   Open in SSMS and execute (F5), or:
            sqlcmd -S localhost -U sa -P <password> -i raceday_schema.sql

   The script is fully re-runnable. It drops and recreates the RaceDay
   database, creates all tables in dependency order, loads seed data and
   finishes with verification queries.

   Table order (dependency order):
     1. Roles
     2. EventTypes
     3. Users        -> Roles
     4. Events       -> Users (organiser), EventTypes
     5. Categories   -> Events
     6. Enrolments   -> Users, Categories      (resolves Users M:M Categories)
     7. Results      -> Enrolments, Users (recorded by)
   ============================================================================= */

SET NOCOUNT ON;
GO

/* -----------------------------------------------------------------------------
   0. Database setup
   ----------------------------------------------------------------------------- */
USE master;
GO

IF DB_ID('RaceDay') IS NOT NULL
BEGIN
    ALTER DATABASE RaceDay SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RaceDay;
END
GO

CREATE DATABASE RaceDay;
GO

USE RaceDay;
GO

/* -----------------------------------------------------------------------------
   1. Roles (lookup)
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.Roles
(
    RoleId      INT           NOT NULL IDENTITY(1,1),
    Name        NVARCHAR(50)  NOT NULL,

    CONSTRAINT PK_Roles      PRIMARY KEY CLUSTERED (RoleId),
    CONSTRAINT UQ_Roles_Name UNIQUE (Name)
);
GO

/* -----------------------------------------------------------------------------
   2. EventTypes (lookup)
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.EventTypes
(
    EventTypeId INT           NOT NULL IDENTITY(1,1),
    Name        NVARCHAR(50)  NOT NULL,

    CONSTRAINT PK_EventTypes      PRIMARY KEY CLUSTERED (EventTypeId),
    CONSTRAINT UQ_EventTypes_Name UNIQUE (Name)
);
GO

/* -----------------------------------------------------------------------------
   3. Users
   A custom Users table (rather than ASP.NET Identity) keeps the ERD and the
   JWT auth in Part 2 aligned. PasswordHash stores a salted hash, never the
   plain-text password.
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.Users
(
    UserId        INT            NOT NULL IDENTITY(1,1),
    RoleId        INT            NOT NULL,
    FirstName     NVARCHAR(100)  NOT NULL,
    LastName      NVARCHAR(100)  NOT NULL,
    Email         NVARCHAR(256)  NOT NULL,
    PasswordHash  NVARCHAR(255)  NOT NULL,
    Phone         NVARCHAR(20)   NULL,
    DateOfBirth   DATE           NOT NULL,
    City          NVARCHAR(100)  NULL,
    CreatedAt     DATETIME2(0)   NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Users            PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT UQ_Users_Email      UNIQUE (Email),
    CONSTRAINT FK_Users_Roles      FOREIGN KEY (RoleId)
        REFERENCES dbo.Roles (RoleId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Users_Email      CHECK (Email LIKE '%_@_%.__%'),
    CONSTRAINT CK_Users_DateOfBirth CHECK (DateOfBirth > '1900-01-01')
);
GO

/* -----------------------------------------------------------------------------
   4. Events
   Latitude/Longitude support the live weather feature (Part 2).
   RouteImageUrl will hold the Azure Blob Storage link (Part 3).
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.Events
(
    EventId        INT             NOT NULL IDENTITY(1,1),
    OrganiserId    INT             NOT NULL,
    EventTypeId    INT             NOT NULL,
    Name           NVARCHAR(150)   NOT NULL,
    Description    NVARCHAR(2000)  NULL,
    EventDate      DATE            NOT NULL,
    StartTime      TIME(0)         NOT NULL,
    Venue          NVARCHAR(150)   NOT NULL,
    City           NVARCHAR(100)   NOT NULL,
    Province       NVARCHAR(100)   NOT NULL,
    Latitude       DECIMAL(9,6)    NULL,
    Longitude      DECIMAL(9,6)    NULL,
    RouteImageUrl  NVARCHAR(500)   NULL,
    Status         NVARCHAR(20)    NOT NULL CONSTRAINT DF_Events_Status DEFAULT ('Published'),
    CreatedAt      DATETIME2(0)    NOT NULL CONSTRAINT DF_Events_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Events              PRIMARY KEY CLUSTERED (EventId),
    CONSTRAINT FK_Events_Users        FOREIGN KEY (OrganiserId)
        REFERENCES dbo.Users (UserId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Events_EventTypes   FOREIGN KEY (EventTypeId)
        REFERENCES dbo.EventTypes (EventTypeId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Events_Status       CHECK (Status IN ('Draft', 'Published', 'Cancelled', 'Completed')),
    CONSTRAINT CK_Events_Latitude     CHECK (Latitude  IS NULL OR Latitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_Events_Longitude    CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180)
);
GO

CREATE INDEX IX_Events_EventDate ON dbo.Events (EventDate);
CREATE INDEX IX_Events_OrganiserId ON dbo.Events (OrganiserId);
GO

/* -----------------------------------------------------------------------------
   5. Categories
   Each event has one or more categories (e.g. 42.2km, 21.1km, 10km).
   ON DELETE CASCADE here only: deleting an event removes its categories.
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.Categories
(
    CategoryId       INT            NOT NULL IDENTITY(1,1),
    EventId          INT            NOT NULL,
    Name             NVARCHAR(100)  NOT NULL,
    DistanceKm       DECIMAL(6,2)   NOT NULL,
    EntryFee         DECIMAL(10,2)  NOT NULL,
    MaxParticipants  INT            NOT NULL,
    MinAge           INT            NOT NULL CONSTRAINT DF_Categories_MinAge DEFAULT (0),

    CONSTRAINT PK_Categories                 PRIMARY KEY CLUSTERED (CategoryId),
    CONSTRAINT UQ_Categories_Event_Name      UNIQUE (EventId, Name),
    CONSTRAINT FK_Categories_Events          FOREIGN KEY (EventId)
        REFERENCES dbo.Events (EventId)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT CK_Categories_DistanceKm      CHECK (DistanceKm > 0),
    CONSTRAINT CK_Categories_EntryFee        CHECK (EntryFee >= 0),
    CONSTRAINT CK_Categories_MaxParticipants CHECK (MaxParticipants > 0),
    CONSTRAINT CK_Categories_MinAge          CHECK (MinAge BETWEEN 0 AND 120)
);
GO

/* -----------------------------------------------------------------------------
   6. Enrolments (junction table)
   Resolves the many-to-many relationship between Users and Categories.
   A participant may enrol in one category only once (UQ on UserId, CategoryId)
   and bib numbers are unique within a category.
   Both FKs use NO ACTION so SQL Server does not see multiple cascade paths.
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.Enrolments
(
    EnrolmentId  INT           NOT NULL IDENTITY(1,1),
    UserId       INT           NOT NULL,
    CategoryId   INT           NOT NULL,
    BibNumber    INT           NOT NULL,
    Status       NVARCHAR(20)  NOT NULL CONSTRAINT DF_Enrolments_Status DEFAULT ('Active'),
    EnrolledAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_Enrolments_EnrolledAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Enrolments                PRIMARY KEY CLUSTERED (EnrolmentId),
    CONSTRAINT UQ_Enrolments_User_Category  UNIQUE (UserId, CategoryId),
    CONSTRAINT UQ_Enrolments_Category_Bib   UNIQUE (CategoryId, BibNumber),
    CONSTRAINT FK_Enrolments_Users          FOREIGN KEY (UserId)
        REFERENCES dbo.Users (UserId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Enrolments_Categories     FOREIGN KEY (CategoryId)
        REFERENCES dbo.Categories (CategoryId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Enrolments_Status         CHECK (Status IN ('Active', 'Cancelled')),
    CONSTRAINT CK_Enrolments_BibNumber      CHECK (BibNumber > 0)
);
GO

CREATE INDEX IX_Enrolments_CategoryId ON dbo.Enrolments (CategoryId);
GO

/* -----------------------------------------------------------------------------
   7. Results
   One enrolment has at most one result (1 to 0..1), enforced by UQ on
   EnrolmentId. ElapsedSeconds and positions are only present for finishers.
   ----------------------------------------------------------------------------- */
CREATE TABLE dbo.Results
(
    ResultId          INT           NOT NULL IDENTITY(1,1),
    EnrolmentId       INT           NOT NULL,
    ElapsedSeconds    INT           NULL,
    OverallPosition   INT           NULL,
    CategoryPosition  INT           NULL,
    Status            NVARCHAR(20)  NOT NULL,
    RecordedById      INT           NOT NULL,
    RecordedAt        DATETIME2(0)  NOT NULL CONSTRAINT DF_Results_RecordedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Results               PRIMARY KEY CLUSTERED (ResultId),
    CONSTRAINT UQ_Results_EnrolmentId   UNIQUE (EnrolmentId),
    CONSTRAINT FK_Results_Enrolments    FOREIGN KEY (EnrolmentId)
        REFERENCES dbo.Enrolments (EnrolmentId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Results_Users         FOREIGN KEY (RecordedById)
        REFERENCES dbo.Users (UserId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Results_Status        CHECK (Status IN ('Finished', 'DNF', 'DNS')),
    CONSTRAINT CK_Results_ElapsedSeconds CHECK (ElapsedSeconds IS NULL OR ElapsedSeconds > 0),
    CONSTRAINT CK_Results_Positions     CHECK (
        (OverallPosition  IS NULL OR OverallPosition  > 0) AND
        (CategoryPosition IS NULL OR CategoryPosition > 0)
    ),
    -- Finishers must have a time; DNF/DNS must not.
    CONSTRAINT CK_Results_Finished_HasTime CHECK (
        (Status =  'Finished' AND ElapsedSeconds IS NOT NULL) OR
        (Status <> 'Finished' AND ElapsedSeconds IS NULL AND OverallPosition IS NULL AND CategoryPosition IS NULL)
    )
);
GO

/* =============================================================================
   SEED DATA
   ============================================================================= */

/* -----------------------------------------------------------------------------
   Roles and EventTypes
   ----------------------------------------------------------------------------- */
INSERT INTO dbo.Roles (Name) VALUES
    ('Organiser'),      -- RoleId 1
    ('Participant');    -- RoleId 2

INSERT INTO dbo.EventTypes (Name) VALUES
    ('Running'),        -- EventTypeId 1
    ('Walking'),        -- EventTypeId 2
    ('Cycling');        -- EventTypeId 3
GO

/* -----------------------------------------------------------------------------
   Users
   PasswordHash values are BCrypt hashes of "Password123!" (work factor 11).
   Organisers are seeded here; the public register endpoint only creates
   Participants.
   ----------------------------------------------------------------------------- */
INSERT INTO dbo.Users (RoleId, FirstName, LastName, Email, PasswordHash, Phone, DateOfBirth, City) VALUES
    -- Organisers (UserId 1-2)
    (1, 'Thandiwe', 'Mokoena',  'thandiwe.mokoena@raceday.co.za',  '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', '0821234567', '1985-04-12', 'Johannesburg'),
    (1, 'Pieter',   'van Wyk',  'pieter.vanwyk@raceday.co.za',     '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', '0837654321', '1979-11-03', 'Cape Town'),
    -- Participants (UserId 3-7)
    (2, 'Sipho',    'Dlamini',  'sipho.dlamini@gmail.com',          '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', '0729876543', '1996-02-27', 'Soweto'),
    (2, 'Aisha',    'Naidoo',   'aisha.naidoo@outlook.com',         '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', '0761122334', '1992-08-15', 'Durban'),
    (2, 'Johan',    'Botha',    'johan.botha@gmail.com',            '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', '0845566778', '1988-06-30', 'Pretoria'),
    (2, 'Lerato',   'Khumalo',  'lerato.khumalo@yahoo.com',         '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', '0713344556', '2001-12-09', 'Johannesburg'),
    (2, 'Megan',    'Pillay',   'megan.pillay@gmail.com',           '$2a$11$Q9hZ3yG5kq1W0pWnZ8uK5uEo7c1dYfN1bqXk0O9gHkq1JkH2eTzAq', NULL,         '1999-03-21', 'Cape Town');
GO

/* -----------------------------------------------------------------------------
   Events
   ----------------------------------------------------------------------------- */
INSERT INTO dbo.Events (OrganiserId, EventTypeId, Name, Description, EventDate, StartTime, Venue, City, Province, Latitude, Longitude, RouteImageUrl, Status) VALUES
    -- EventId 1: upcoming marathon (Running), organised by Thandiwe
    (1, 1, 'Soweto Heritage Marathon',
     'A full and half marathon through the streets of Soweto, passing Vilakazi Street and the Orlando Towers. Includes a 10km fun run.',
     '2026-11-01', '06:00:00', 'FNB Stadium', 'Johannesburg', 'Gauteng',
     -26.234700, 27.982400, NULL, 'Published'),

    -- EventId 2: upcoming cycle tour (Cycling), organised by Pieter
    (2, 3, 'Cape Peninsula Cycle Tour',
     'The classic peninsula loop around Chapman''s Peak and Cape Point, with a shorter 42km option for newer riders.',
     '2027-03-14', '06:15:00', 'Green Point Common', 'Cape Town', 'Western Cape',
     -33.905200, 18.410400, NULL, 'Published'),

    -- EventId 3: upcoming coastal walk (Walking), organised by Thandiwe
    (1, 2, 'Durban Golden Mile Coastal Walk',
     'A relaxed 10km promenade walk from uShaka Marine World to Blue Lagoon and back, with a 5km family option.',
     '2026-10-18', '07:30:00', 'uShaka Marine World', 'Durban', 'KwaZulu-Natal',
     -29.867700, 31.045700, NULL, 'Published'),

    -- EventId 4: past event with results (Running), organised by Pieter
    (2, 1, 'Pretoria Jacaranda Half Marathon',
     'Half marathon and 10km through the jacaranda-lined streets of Pretoria, starting and finishing at the Union Buildings.',
     '2026-08-16', '06:30:00', 'Union Buildings', 'Pretoria', 'Gauteng',
     -25.740600, 28.211800, NULL, 'Completed');
GO

/* -----------------------------------------------------------------------------
   Categories
   ----------------------------------------------------------------------------- */
INSERT INTO dbo.Categories (EventId, Name, DistanceKm, EntryFee, MaxParticipants, MinAge) VALUES
    -- Soweto Heritage Marathon (CategoryId 1-3)
    (1, '42.2km Marathon',       42.20, 450.00, 5000, 18),
    (1, '21.1km Half Marathon',  21.10, 300.00, 8000, 16),
    (1, '10km Fun Run',          10.00, 150.00, 10000, 12),

    -- Cape Peninsula Cycle Tour (CategoryId 4-5)
    (2, '109km Full Tour',      109.00, 650.00, 30000, 18),
    (2, '42km Short Tour',       42.00, 350.00, 5000, 14),

    -- Durban Golden Mile Coastal Walk (CategoryId 6-7)
    (3, '10km Promenade Walk',   10.00, 120.00, 2000, 0),
    (3, '5km Family Walk',        5.00,  80.00, 3000, 0),

    -- Pretoria Jacaranda Half Marathon (CategoryId 8-9)
    (4, '21.1km Half Marathon',  21.10, 280.00, 4000, 16),
    (4, '10km Road Race',        10.00, 140.00, 6000, 12);
GO
