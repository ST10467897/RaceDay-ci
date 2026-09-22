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
