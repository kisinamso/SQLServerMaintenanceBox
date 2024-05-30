USE [DB_NAME]
GO
CREATE PROCEDURE dbo.BlockingCheckAndSendEmail
AS
-- ============================@kisinamso===========================
-- == Variables Declaration                                       ==
-- == 1. Declare a table variable @Blockings to store blocking    ==
-- ==    session details.                                         ==
-- ============================@kisinamso===========================
-- == Fetching Blocking Sessions                                  ==
-- == 1. Run a query to find blocking sessions and insert the     ==
-- ==    results into the @Blockings table.                       ==
-- == 2. Select relevant details such as blocking session ID,     ==
-- ==    blocked session ID, wait type, wait time, wait resource, ==
-- ==    database name, and blocked query.                        ==
-- ============================@kisinamso===========================
-- == Checking for Blocking Sessions                              ==
-- == 1. Check if there are any rows in the @Blockings table.     ==
-- == 2. If there are blocking sessions, proceed to send an email.==
-- ============================@kisinamso===========================
-- == Constructing the Email Body                                 ==
-- == 1. Initialize the HTML body for the email with a table      ==
-- ==    structure to display blocking session details.           ==
-- ============================@kisinamso===========================
-- == Populating the Email Body                                   ==
-- == 1. Declare variables to hold individual blocking session    ==
-- ==    details.                                                 ==
-- == 2. Use a cursor to iterate over the rows in the @Blockings  ==
-- ==    table.                                                   ==
-- == 3. For each row, append a table row to the email body with  ==
-- ==    the blocking session details.                            ==
-- ============================@kisinamso===========================
-- == Finalizing the Email Body                                   ==
-- == 1. Close the HTML table and body tags.                      ==
-- == 2. Execute the sp_send_dbmail stored procedure to send the  ==
-- ==    email with the constructed HTML body.                    ==
-- ============================@kisinamso===========================

BEGIN
    DECLARE @Blockings TABLE (
        BlockingSessionID INT,
        BlockedSessionID INT,
        wait_type NVARCHAR(60),
        wait_time INT,
        wait_resource NVARCHAR(256),
        DatabaseName NVARCHAR(128),
        BlockedQuery NVARCHAR(MAX)
    );

    -- Run the blocking query and insert results into the temporary table
    INSERT INTO @Blockings
    SELECT 
        blocking_session_id AS BlockingSessionID,
        session_id AS BlockedSessionID,
        wait_type,
        wait_time,
        wait_resource,
        DB_NAME(database_id) AS DatabaseName,
        (SELECT TEXT FROM sys.dm_exec_sql_text(sql_handle)) AS BlockedQuery
    FROM 
        sys.dm_exec_requests
    WHERE 
        blocking_session_id <> 0;

    -- If there are any blockings, send the results via email
    IF EXISTS (SELECT 1 FROM @Blockings)
    BEGIN
        DECLARE @EmailBody NVARCHAR(MAX);
        SET @EmailBody = 
        N'<html>
            <head>
                <style>
                    table {
                        width: 100%;
                        border-collapse: collapse;
                    }
                    th, td {
                        border: 1px solid black;
                        padding: 8px;
                        text-align: left;
                    }
                    th {
                        background-color: #f2f2f2;
                    }
                </style>
            </head>
            <body>
                <h2>Blocking Situations Detected</h2>
                <table>
                    <tr>
                        <th>Blocking Session ID</th>
                        <th>Blocked Session ID</th>
                        <th>Wait Type</th>
                        <th>Wait Time</th>
                        <th>Wait Resource</th>
                        <th>Database Name</th>
                        <th>Blocked Query</th>
                    </tr>';

        DECLARE @BlockingSessionID NVARCHAR(MAX), @BlockedSessionID NVARCHAR(MAX), @WaitType NVARCHAR(MAX);
        DECLARE @WaitTime NVARCHAR(MAX), @WaitResource NVARCHAR(MAX), @DatabaseName NVARCHAR(MAX), @BlockedQuery NVARCHAR(MAX);

        DECLARE BlockingsCursor CURSOR FOR
        SELECT 
            BlockingSessionID,
            BlockedSessionID,
            wait_type,
            wait_time,
            wait_resource,
            DatabaseName,
            BlockedQuery
        FROM @Blockings;

        OPEN BlockingsCursor;
        FETCH NEXT FROM BlockingsCursor INTO @BlockingSessionID, @BlockedSessionID, @WaitType, @WaitTime, @WaitResource, @DatabaseName, @BlockedQuery;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @EmailBody = @EmailBody + 
            '<tr>
                <td>' + @BlockingSessionID + '</td>
                <td>' + @BlockedSessionID + '</td>
                <td>' + @WaitType + '</td>
                <td>' + @WaitTime + '</td>
                <td>' + @WaitResource + '</td>
                <td>' + @DatabaseName + '</td>
                <td>' + @BlockedQuery + '</td>
            </tr>';

            FETCH NEXT FROM BlockingsCursor INTO @BlockingSessionID, @BlockedSessionID, @WaitType, @WaitTime, @WaitResource, @DatabaseName, @BlockedQuery;
        END;

        CLOSE BlockingsCursor;
        DEALLOCATE BlockingsCursor;

        SET @EmailBody = @EmailBody + 
                '</table>
            </body>
        </html>';

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'YourMailProfile', -- Your mail profile name here
            @recipients = 'recipient@example.com', -- Recipient email address
            @subject = 'SQL Server Blocking Report',
            @body = @EmailBody,
            @body_format = 'HTML';
    END
END;
