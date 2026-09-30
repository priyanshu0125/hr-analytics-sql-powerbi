/* =========================================================
   HR ANALYTICS PROJECT — SETUP SCRIPT (SQL Server / SSMS)
   ========================================================= */

-- STEP 1: Create the database
IF DB_ID('HR_Analytics') IS NULL
    CREATE DATABASE HR_Analytics;
GO

USE HR_Analytics;
GO

-- STEP 2: Drop tables if they already exist (safe re-run)
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL DROP TABLE dbo.Employees;
IF OBJECT_ID('dbo.Departments', 'U') IS NOT NULL DROP TABLE dbo.Departments;
GO

-- STEP 3: Create Departments table
CREATE TABLE dbo.Departments (
    DepartmentID   INT PRIMARY KEY,
    DepartmentName VARCHAR(50) NOT NULL
);
GO

-- STEP 4: Create Employees table
CREATE TABLE dbo.Employees (
    EmployeeID     INT IDENTITY(1,1) PRIMARY KEY,
    FirstName      VARCHAR(50),
    LastName       VARCHAR(50),
    Gender         VARCHAR(10),
    Age            INT,
    DepartmentID   INT FOREIGN KEY REFERENCES dbo.Departments(DepartmentID),
    JobRole        VARCHAR(50),
    Salary         DECIMAL(10,2),
    HireDate       DATE,
    TerminationDate DATE NULL,
    AttritionFlag  CHAR(1)   -- 'Y' = left the company, 'N' = still active
);
GO

-- STEP 5: Insert Departments
INSERT INTO dbo.Departments (DepartmentID, DepartmentName) VALUES
(1, 'Sales'),
(2, 'Engineering'),
(3, 'Human Resources'),
(4, 'Finance'),
(5, 'Marketing'),
(6, 'Operations'),
(7, 'Customer Support');
GO

/* STEP 6: Generate ~300 mock employees
   Uses a numbers CTE + randomized values so you get a
   realistic, varied dataset without typing rows by hand. */

;WITH Numbers AS (
    SELECT TOP (300) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
Generated AS (
    SELECT
        n,
        CASE (ABS(CHECKSUM(NEWID())) % 2) WHEN 0 THEN 'Male' ELSE 'Female' END AS Gender,
        20 + ABS(CHECKSUM(NEWID())) % 40 AS Age,                         -- age 20-59
        1 + ABS(CHECKSUM(NEWID())) % 7 AS DeptID,                        -- department 1-7
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1825, GETDATE()) AS HireDate, -- last 5 years
        ABS(CHECKSUM(NEWID())) % 100 AS AttritionRoll                    -- 0-99 for probability
    FROM Numbers
)
INSERT INTO dbo.Employees
    (FirstName, LastName, Gender, Age, DepartmentID, JobRole, Salary, HireDate, TerminationDate, AttritionFlag)
SELECT
    'Emp' + CAST(n AS VARCHAR(10)) AS FirstName,
    'Last' + CAST(n AS VARCHAR(10)) AS LastName,
    Gender,
    Age,
    DeptID,
    CASE DeptID
        WHEN 1 THEN (CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN 'Sales Executive' WHEN 1 THEN 'Sales Manager' ELSE 'Account Rep' END)
        WHEN 2 THEN (CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN 'Software Engineer' WHEN 1 THEN 'QA Engineer' ELSE 'Engineering Manager' END)
        WHEN 3 THEN (CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN 'HR Generalist' ELSE 'HR Manager' END)
        WHEN 4 THEN (CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN 'Financial Analyst' ELSE 'Accountant' END)
        WHEN 5 THEN (CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN 'Marketing Specialist' ELSE 'Marketing Manager' END)
        WHEN 6 THEN (CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN 'Operations Analyst' ELSE 'Operations Manager' END)
        ELSE (CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN 'Support Specialist' ELSE 'Support Lead' END)
    END AS JobRole,
    -- Salary band roughly varies by department
    CASE DeptID
        WHEN 1 THEN 40000 + ABS(CHECKSUM(NEWID())) % 40000
        WHEN 2 THEN 60000 + ABS(CHECKSUM(NEWID())) % 60000
        WHEN 3 THEN 35000 + ABS(CHECKSUM(NEWID())) % 30000
        WHEN 4 THEN 50000 + ABS(CHECKSUM(NEWID())) % 45000
        WHEN 5 THEN 42000 + ABS(CHECKSUM(NEWID())) % 35000
        WHEN 6 THEN 38000 + ABS(CHECKSUM(NEWID())) % 32000
        ELSE 32000 + ABS(CHECKSUM(NEWID())) % 25000
    END AS Salary,
    HireDate,
    CASE WHEN AttritionRoll < 16   -- ~16% attrition rate
         THEN DATEADD(DAY, 30 + ABS(CHECKSUM(NEWID())) % 900, HireDate)
         ELSE NULL END AS TerminationDate,
    CASE WHEN AttritionRoll < 16 THEN 'Y' ELSE 'N' END AS AttritionFlag
FROM Generated;
GO

-- STEP 7: Quick sanity check
SELECT COUNT(*) AS TotalEmployees FROM dbo.Employees;
SELECT AttritionFlag, COUNT(*) AS Cnt FROM dbo.Employees GROUP BY AttritionFlag;
GO


/* =========================================================
   ANALYSIS QUERIES — practice joins, GROUP BY, window functions
   ========================================================= */

-- Q1: Average salary by department
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID) AS HeadCount,
    AVG(e.Salary) AS AvgSalary
FROM dbo.Employees e
JOIN dbo.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
ORDER BY AvgSalary DESC;
GO

-- Q2: Headcount trend by hire year-month (with running total)
SELECT
    FORMAT(HireDate, 'yyyy-MM') AS HireMonth,
    COUNT(*) AS NewHires,
    SUM(COUNT(*)) OVER (ORDER BY FORMAT(HireDate, 'yyyy-MM')) AS RunningHeadcount
FROM dbo.Employees
GROUP BY FORMAT(HireDate, 'yyyy-MM')
ORDER BY HireMonth;
GO

-- Q3: Overall attrition rate
SELECT
    CAST(SUM(CASE WHEN AttritionFlag = 'Y' THEN 1 ELSE 0 END) AS FLOAT)
        / COUNT(*) AS AttritionRate
FROM dbo.Employees;
GO

-- Q4: Attrition rate by department
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID) AS TotalEmployees,
    SUM(CASE WHEN e.AttritionFlag = 'Y' THEN 1 ELSE 0 END) AS AttritionCount,
    CAST(SUM(CASE WHEN e.AttritionFlag = 'Y' THEN 1 ELSE 0 END) AS FLOAT)
        / COUNT(e.EmployeeID) AS AttritionRate
FROM dbo.Employees e
JOIN dbo.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
ORDER BY AttritionRate DESC;
GO

-- Q5: Attrition by tenure bucket (how long people stayed before leaving)
SELECT
    CASE
        WHEN DATEDIFF(DAY, HireDate, TerminationDate) <= 180 THEN '0-6 months'
        WHEN DATEDIFF(DAY, HireDate, TerminationDate) <= 365 THEN '6-12 months'
        WHEN DATEDIFF(DAY, HireDate, TerminationDate) <= 730 THEN '1-2 years'
        ELSE '2+ years'
    END AS TenureBucket,
    COUNT(*) AS EmployeesLeft
FROM dbo.Employees
WHERE AttritionFlag = 'Y'
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, HireDate, TerminationDate) <= 180 THEN '0-6 months'
        WHEN DATEDIFF(DAY, HireDate, TerminationDate) <= 365 THEN '6-12 months'
        WHEN DATEDIFF(DAY, HireDate, TerminationDate) <= 730 THEN '1-2 years'
        ELSE '2+ years'
    END
ORDER BY EmployeesLeft DESC;
GO

-- Q6: Current active headcount by department (for Power BI cards)
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID) AS ActiveEmployees
FROM dbo.Employees e
JOIN dbo.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.AttritionFlag = 'N'
GROUP BY d.DepartmentName
ORDER BY ActiveEmployees DESC;
GO

