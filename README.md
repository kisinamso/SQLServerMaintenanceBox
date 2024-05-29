# Database Management Scripts

This repository contains various T-SQL stored procedures that can be used for database management tasks.

## Contents

1. [Index Maintenance](001_IndexMaintenance.sql)
- [Databases Backup](002_DatabaseBackup.sql)
- [Statistics Update Maintenance](003_StatisticsMaintenance.sql)
- [Shrink All Databases Log Files](004_ShrinkAllLogFiles.sql)
- [Database Integrity Check](005_IntegrityCheck.sql)

## Index Maintenance

This stored procedure performs maintenance on indexes in specified or all databases. It checks index fragmentation and reorganizes or rebuilds indexes as needed.

## Databases Backup

This stored procedure backs up specified or all databases. It offers options for full, differential, and transaction log backups.

## Statistics Update Maintenance

This stored procedure performs maintenance on statistics in specified or all databases.

## Shrink All Databases Log Files

This stored procedure aims to shrink all database log files.

## Database Integrity Check

This stored procedure checks the integrity of a specified database. If not specified, it checks the integrity of all databases.
