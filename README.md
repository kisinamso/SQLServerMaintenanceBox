# Database Management Scripts

This repository contains various T-SQL stored procedures that can be used for database management tasks.

# Contents

1. [Index Maintenance](001_IndexMaintenance.sql)
2. [Databases Backup](002_DatabaseBackup.sql)
3. [Statistics Update Maintenance](003_StatisticsMaintenance.sql)
4. [Shrink All Databases Log Files](004_ShrinkAllLogFiles.sql)
5. [Database Integrity Check](005_IntegrityCheck.sql)
6. [Send Job Failure Report E-Mail](006_SendJobFailureReport.sql)
7. [Blocking Check And Send E-Mail](007_BlockingCheckAndSendEmail.sql)
8. [Analyzing Tables For Archiving](008_AnalyzeTablesToBeArchived.sql)

# Guidelines

## Index Maintenance

This stored procedure performs maintenance on indexes in specified or all databases. It checks index fragmentation and reorganizes or rebuilds indexes as needed.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/001_IndexMaintenanceGuideline.md).

## Databases Backup

This stored procedure backs up specified or all databases. It offers options for full, differential, and transaction log backups.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/002_DatabaseBackupGuideline.md).

## Statistics Update Maintenance

This stored procedure performs maintenance on statistics in specified or all databases.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/003_StatisticsMaintenanceGuideline.md).

## Shrink All Databases Log Files

This stored procedure aims to shrink all database log files.
If you eant to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/004_ShrinkAllLogFiles.md).

## Database Integrity Check

This stored procedure checks the integrity of a specified database. If not specified, it checks the integrity of all databases.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/005_IntegrityCheckGuideline.md).

## Send Job Failure Report E-Mail

This stored procedure sending e-mail for failured job.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/006_SendJobFailureReportGuideline.md).

## Blocking Check And Send E-Mail

This stored procedure sending e-mail for blocking session.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/007_BlockingCheckAndSendEmailGuideline.md).

## Analyzing Tables For Archiving

This stored procedure analyzing tables for archiving in specified or all databases.
If you want to view guideline, please click [here](https://github.com/kisinamso/SQLServerMaintenanceBoxGuideline/blob/main/008_AnalyzeTablesToBeArchivedGuideline.md).
