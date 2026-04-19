-- ============================================================
-- HR Attrition Analysis | IBM HR Analytics Dataset
-- Author: Gabrielle Magalhaes
-- Description: Exploratory analysis of employee attrition patterns
--              using aggregations, CTEs, and window functions.
-- Dataset: WA_Fn-UseC_-HR-Employee-Attrition.csv (Kaggle)
-- Database: SQL Server (SSMS)
-- Note: Attrition and OverTime were imported as integers (0/1)
--       1 = Yes, 0 = No
-- ============================================================


-- ============================================================
-- 0. QUICK CHECK
-- Run this first to confirm data loaded correctly
-- ============================================================

SELECT TOP 10 * FROM hr_employees;
SELECT COUNT(*) AS total_rows FROM hr_employees;


-- ============================================================
-- QUERY 1
-- Attrition rate by department and job level
-- Goal: identify where turnover is most concentrated
-- ============================================================

SELECT
    Department,
    JobLevel,
    COUNT(*)                                                        AS total_employees,
    SUM(CAST(Attrition AS INT))                                                  AS employees_left,
    ROUND(
        100.0 * SUM(CAST(Attrition AS INT)) / COUNT(*), 2
    )                                                               AS attrition_rate_pct
FROM hr_employees
GROUP BY Department, JobLevel
ORDER BY attrition_rate_pct DESC;


-- ============================================================
-- QUERY 2
-- Average monthly income: employees who left vs stayed
-- Goal: understand whether compensation is a driver of attrition
-- ============================================================

SELECT
    Department,
    Attrition,
    ROUND(AVG(CAST(MonthlyIncome AS FLOAT)), 2)    AS avg_monthly_income,
    ROUND(MIN(CAST(MonthlyIncome AS FLOAT)), 2)    AS min_monthly_income,
    ROUND(MAX(CAST(MonthlyIncome AS FLOAT)), 2)    AS max_monthly_income,
    COUNT(*)                                        AS headcount
FROM hr_employees
GROUP BY Department, Attrition
ORDER BY Department, Attrition;


-- ============================================================
-- QUERY 3 — WINDOW FUNCTION
-- Ranking employees by years since last promotion
-- within each department, among those who left
-- Goal: check if stagnation correlates with attrition
-- ============================================================

SELECT
    EmployeeNumber,
    Department,
    JobRole,
    YearsSinceLastPromotion,
    MonthlyIncome,
    RANK() OVER (
        PARTITION BY Department
        ORDER BY YearsSinceLastPromotion DESC
    )                               AS rank_stagnation
FROM hr_employees
WHERE Attrition = 1
ORDER BY Department, rank_stagnation;


-- ============================================================
-- QUERY 4 — CTE
-- Employees with multiple attrition risk factors combined:
--   - Works overtime (OverTime = 1)
--   - Monthly income below department median
--   - Job satisfaction <= 2 (scale 1-4)
--   - Still active (Attrition = 0)
-- Goal: flag current employees at high risk of leaving
-- ============================================================

WITH dept_median_income AS (
    -- Step 1: calculate median income per department
    SELECT DISTINCT
        Department,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY MonthlyIncome)
            OVER (PARTITION BY Department)  AS median_income
    FROM hr_employees
),

risk_flags AS (
    -- Step 2: join employees with department median and apply risk rules
    SELECT
        e.EmployeeNumber,
        e.Department,
        e.JobRole,
        e.MonthlyIncome,
        e.OverTime,
        e.JobSatisfaction,
        e.YearsAtCompany,
        d.median_income,
        CASE WHEN e.OverTime = 1                            THEN 1 ELSE 0 END AS flag_overtime,
        CASE WHEN e.MonthlyIncome < d.median_income         THEN 1 ELSE 0 END AS flag_below_median,
        CASE WHEN e.JobSatisfaction <= 2                    THEN 1 ELSE 0 END AS flag_low_satisfaction
    FROM hr_employees e
    JOIN dept_median_income d ON e.Department = d.Department
    WHERE e.Attrition = 0
),

-- Step 3: filter only employees with 2 or more risk flags
risk_scored AS (
    SELECT
        EmployeeNumber,
        Department,
        JobRole,
        MonthlyIncome,
        ROUND(median_income, 2)     AS dept_median_income,
        OverTime,
        JobSatisfaction,
        YearsAtCompany,
        (flag_overtime + flag_below_median + flag_low_satisfaction) AS total_risk_flags
    FROM risk_flags
)

SELECT *
FROM risk_scored
WHERE total_risk_flags >= 2
ORDER BY total_risk_flags DESC, Department;


-- ============================================================
-- QUERY 5 — COHORT ANALYSIS
-- Attrition rate by tenure cohort (years at company)
-- Goal: identify at which career stage employees are most likely to leave
-- ============================================================

SELECT
    CASE
        WHEN YearsAtCompany = 0              THEN '0 - first year'
        WHEN YearsAtCompany BETWEEN 1 AND 2  THEN '1-2 years'
        WHEN YearsAtCompany BETWEEN 3 AND 5  THEN '3-5 years'
        WHEN YearsAtCompany BETWEEN 6 AND 10 THEN '6-10 years'
        ELSE '10+ years'
    END                                                             AS tenure_cohort,
    COUNT(*)                                                        AS total_employees,
    SUM(CAST(Attrition AS INT))                                                  AS employees_left,
    ROUND(
        100.0 * SUM(CAST(Attrition AS INT)) / COUNT(*), 2
    )                                                               AS attrition_rate_pct
FROM hr_employees
GROUP BY
    CASE
        WHEN YearsAtCompany = 0              THEN '0 - first year'
        WHEN YearsAtCompany BETWEEN 1 AND 2  THEN '1-2 years'
        WHEN YearsAtCompany BETWEEN 3 AND 5  THEN '3-5 years'
        WHEN YearsAtCompany BETWEEN 6 AND 10 THEN '6-10 years'
        ELSE '10+ years'
    END
ORDER BY MIN(YearsAtCompany);


-- ============================================================
-- BONUS QUERY — WINDOW FUNCTION (running total)
-- Cumulative headcount and attrition count ordered by monthly income
-- Goal: understand attrition distribution across income spectrum
-- ============================================================

SELECT
    EmployeeNumber,
    Department,
    MonthlyIncome,
    Attrition,
    COUNT(*) OVER (
        ORDER BY MonthlyIncome
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                               AS cumulative_headcount,
    SUM(CAST(Attrition AS INT)) OVER (
        ORDER BY MonthlyIncome
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                               AS cumulative_attrition
FROM hr_employees
ORDER BY MonthlyIncome;
