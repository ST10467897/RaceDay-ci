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
