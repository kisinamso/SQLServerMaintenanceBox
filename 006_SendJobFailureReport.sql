CREATE PROCEDURE dbo.SendJobFailureReport
AS
-- ============================@kisinamso===========================
-- == Variables Declaration                                       ==
-- == 1. Declare variables for email body, subject, profile name, ==
-- ==    and recipients.                                          ==
-- == 2. Set default values for @ProfileName and @Recipients.     ==
-- ============================@kisinamso===========================
-- == Fetching Failed Jobs in the Last 1 Day                      ==
-- == 1. Use a CTE (Common Table Expression) to fetch details of  ==
-- ==    failed jobs within the last 1 day from sysjobhistory and ==
-- ==    sysjobs tables.                                          ==
-- == 2. Select job name, step ID, step name, error message, run  ==
-- ==    date, and run time for failed jobs.                      ==
-- ============================@kisinamso===========================
-- == Constructing the HTML Body                                  ==
-- == 1. Use HTML and CSS to format the email body.               ==
-- == 2. Create a table to display the job failure details.       ==
-- == 3. Populate the table rows with data from the JobFailures   ==
-- ==    CTE.                                                     ==
-- ============================@kisinamso===========================
-- == Setting the Email Subject                                   ==
-- == 1. Set the email subject to include the current date and    ==
-- ==    time.                                                    ==
-- ============================@kisinamso===========================
-- == Sending the Email                                           ==
-- == 1. Use sp_send_dbmail to send the email with the constructed==
-- ==    HTML body and subject.                                   ==
-- ============================@kisinamso===========================

BEGIN
    -- Variables
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @Subject NVARCHAR(255);
    DECLARE @ProfileName NVARCHAR(255) = 'YourMailProfile'; -- Replace with your actual mail profile
    DECLARE @Recipients NVARCHAR(255) = 'recipient@example.com'; -- Replace with your actual recipients

    -- Fetching failed jobs in the last 1 day
    WITH JobFailures AS (
        SELECT 
            j.name AS JobName,
            h.step_id AS StepID,
            h.step_name AS StepName,
            h.message AS ErrorMessage,
            h.run_date AS RunDate,
            h.run_time AS RunTime
        FROM 
            msdb.dbo.sysjobhistory h
        INNER JOIN 
            msdb.dbo.sysjobs j ON h.job_id = j.job_id
        WHERE 
            h.run_status = 0 -- 0 = Failed
            AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR, GETDATE()-1, 112)) -- Last 1 day
    )

    -- Constructing the HTML body
    SELECT @Body = 
        '<html>
        <head>
            <style>
                body { font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; color: #333; }
                table { font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; border-collapse: collapse; width: 100%; }
                th { background-color: #E60000; color: #fff; text-align: left; padding: 12px; }
                td { border: 1px solid #ddd; padding: 12px; }
                tr:nth-child(even) { background-color: #f2f2f2; }
                tr:hover { background-color: #ddd; }
                .header { font-size: 24px; font-weight: bold; }
                .subheader { font-size: 16px; color: #555; }
                .logo { float: right; width: 100px; }
            </style>
        </head>
        <body>
            <h2 class="header">SQL Server Job Failure Report <img src="https://camo.githubusercontent.com/9cbaabc30ff420add039d1dffb740c064845a8846fb88e9cfd37678f51877113/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f2d4d5353514c2d3333333333333f7374796c653d666c6174266c6f676f3d6d6963726f736f667473716c736572766572" alt="Logo" class="logo"></h2>
            <p class="subheader">The following jobs have failed in the last 1 day:</p>
            <table>
                <tr>
                    <th>Job Name</th>
                    <th>Step ID</th>
                    <th>Step Name</th>
                    <th>Error Message</th>
                    <th>Run Date</th>
                    <th>Run Time</th>
                </tr>' +
                CAST((
                    SELECT 
                        td = JobName, '',
                        td = StepID, '',
                        td = StepName, '',
                        td = ErrorMessage, '',
                        td = FORMAT(CAST(RunDate AS DATE), 'yyyy-MM-dd'), '',
                        td = FORMAT(CAST(RunTime AS TIME), 'HH:mm:ss')
                    FROM JobFailures
                    FOR XML PATH('tr'), TYPE
                ) AS NVARCHAR(MAX)) +
            '</table>
        </body>
        </html>';

    -- Setting the email subject
    SET @Subject = 'SQL Server Job Failure Report - ' + CONVERT(VARCHAR, GETDATE(), 120);

    -- Sending the email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = @ProfileName,
        @recipients = @Recipients,
        @subject = @Subject,
        @body = @Body,
        @body_format = 'HTML';
END;
GO
