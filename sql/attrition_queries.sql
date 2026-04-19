-- ============================================================
-- HR Attrition Analysis | IBM HR Analytics Dataset
-- Author: Gabrielle Magalhaes
-- Description: Exploratory analysis of employee attrition patterns
--              using aggregations, CTEs, and window functions.
-- Dataset: WA_Fn-UseC_-HR-Employee-Attrition.csv (Kaggle)
-- ============================================================


-- ============================================================
-- 0. SETUP NOTE
-- These queries assume the CSV was loaded into a table called
-- `hr_employees`. Column names match the original Kaggle dataset.
-- Attrition values: 'Yes' = left the company, 'No' = still active.
-- ============================================================


-- ============================================================
-- QUERY 1
-- Attrition rate by department and job level
-- Goal: identify where turnover is most concentrated
-- ============================================================

SELECT
    Department,
    JobLevel,
    COUNT(*)                                                        AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)            AS employees_left,
    ROUND(
        100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*), 2
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
    ROUND(AVG(MonthlyIncome), 2)    AS avg_monthly_income,
    ROUND(MIN(MonthlyIncome), 2)    AS min_monthly_income,
    ROUND(MAX(MonthlyIncome), 2)    AS max_monthly_income,
    COUNT(*)                        AS headcount
FROM hr_employees
GROUP BY Department, Attrition
ORDER BY Department, Attrition;


-- ============================================================
-- QUERY 3 — WINDOW FUNCTION
-- Ranking employees by years since last promotion
-- within each department, among those who left
-- Goal: check if stagnation (lack of promotion) correlates with attrition
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
WHERE Attrition = 'Yes'
ORDER BY Department, rank_stagnation;


-- ============================================================
-- QUERY 4 — CTE
-- Employees with multiple attrition risk factors combined:
--   - Works overtime
--   - Monthly income below department median
--   - Job satisfaction <= 2 (scale 1–4)
--   - Still active (Attrition = 'No')
-- Goal: flag current employees at high risk of leaving
-- ============================================================

WITH dept_median_income AS (
    -- Step 1: calculate median income per department
    -- Note: standard SQL uses PERCENTILE_CONT; adjust syntax for your DB
    SELECT
        Department,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY MonthlyIncome) AS median_income
    FROM hr_employees
    GROUP BY Department
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
        -- flag each risk factor individually
        CASE WHEN e.OverTime = 'Yes'                        THEN 1 ELSE 0 END AS flag_overtime,
        CASE WHEN e.MonthlyIncome < d.median_income         THEN 1 ELSE 0 END AS flag_below_median,
        CASE WHEN e.JobSatisfaction <= 2                    THEN 1 ELSE 0 END AS flag_low_satisfaction
    FROM hr_employees e
    JOIN dept_median_income d ON e.Department = d.Department
    WHERE e.Attrition = 'No'  -- active employees only
)

-- Step 3: filter only employees with 2 or more risk flags
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
WHERE (flag_overtime + flag_below_median + flag_low_satisfaction) >= 2
ORDER BY total_risk_flags DESC, Department;


-- ============================================================
-- QUERY 5 — COHORT ANALYSIS
-- Attrition rate by tenure cohort (years at company)
-- Goal: identify at which career stage employees are most likely to leave
-- ============================================================

SELECT
    CASE
        WHEN YearsAtCompany = 0            THEN '0 — first year'
        WHEN YearsAtCompany BETWEEN 1 AND 2 THEN '1–2 years'
        WHEN YearsAtCompany BETWEEN 3 AND 5 THEN '3–5 years'
        WHEN YearsAtCompany BETWEEN 6 AND 10 THEN '6–10 years'
        ELSE '10+ years'
    END                                                             AS tenure_cohort,
    COUNT(*)                                                        AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)            AS employees_left,
    ROUND(
        100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*), 2
    )                                                               AS attrition_rate_pct
FROM hr_employees
GROUP BY tenure_cohort
ORDER BY
    MIN(YearsAtCompany);  -- preserves logical chronological order


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
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) OVER (
        ORDER BY MonthlyIncome
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                               AS cumulative_attrition
FROM hr_employees
ORDER BY MonthlyIncome;
