-- =====================================================================
-- CRM Analytics Project (Group 5, P1426) - LEAD DASHBOARD SQL
-- Database: crm_full   (built with crm_full_setup.sql)
-- Tables : lead_raw (10,000), account_raw (3,052), opportunity_clean (4,646)
-- =====================================================================
USE crm_full;

-- ---------------------------------------------------------------------
-- 0. CLEAN LEAD VIEW (all dashboard queries read from this view)
--    Fixes: text dates, Lead Source typos, Converted flag, status groups, lead age
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_lead_clean AS
SELECT
    Lead_ID,
    Created_Date,
    DATE_FORMAT(Created_Date, '%Y-%m') AS Created_Month,
    YEAR(Created_Date)                 AS Created_Year,
    Lead_Source,
    CASE WHEN Lead_Source IN ('Inside Sales','Website','Trade Show','Webinar',
                              'Advertisement','Field Sales','Prospecting Journey',
                              'Eblasts','Sales Seminar')
         THEN Lead_Source ELSE 'Other' END AS Lead_Source_Group,
    Status,
    CASE WHEN Status IN ('Untouched','Prospect','Nurturing') THEN 'Early Stage'
         WHEN Status IN ('MQL','SQL','Qualified')            THEN 'Qualified'
         WHEN Status = 'Converted'                           THEN 'Converted'
         WHEN Status = 'Disqualified'                        THEN 'Disqualified'
    END AS Status_Group,
    Industry,
    Is_Converted,
    Converted_Account_ID,
    Converted_Opportunity_ID,
    Lead_Score,
    Pardot_Score,
    Country,
    State_Province,
    CASE WHEN Is_Converted = 0
         THEN TIMESTAMPDIFF(DAY, Created_Date, '2022-01-01 00:00:00')
    END AS Age_Days
FROM (
    SELECT
        `Lead ID` AS Lead_ID,
        STR_TO_DATE(`Created Date`, '%m/%d/%Y %H:%i') AS Created_Date,
        CASE WHEN `Lead Source` IS NULL THEN 'Unknown'
             WHEN `Lead Source` IN ('Advertisment','Advertising') THEN 'Advertisement'
             WHEN `Lead Source` = 'Trades Show' THEN 'Trade Show'
             WHEN `Lead Source` = 'Eblast'      THEN 'Eblasts'
             ELSE `Lead Source` END AS Lead_Source,
        Status,
        COALESCE(Industry, 'Unknown') AS Industry,
        CASE WHEN Converted = 'TRUE' THEN 1 ELSE 0 END AS Is_Converted,
        `Converted Account ID`     AS Converted_Account_ID,
        `Converted Opportunity ID` AS Converted_Opportunity_ID,
        CAST(`Lead Score`   AS DECIMAL(10,2)) AS Lead_Score,
        CAST(`Pardot Score` AS DECIMAL(10,2)) AS Pardot_Score,
        Country,
        `State/Province` AS State_Province
    FROM lead_raw
) x;

-- ---------------------------------------------------------------------
-- 1. EIGHT LEAD KPIs
--    Expected: 10000 | 1033 | 10.33 | 699 | 375 | 65056001.61 | 1.56 | 504.18
--    Note: revenue counts each converted opportunity once (a plain join would double count)
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                           AS total_leads,
    SUM(Is_Converted)                                  AS converted_leads,
    ROUND(SUM(Is_Converted) / COUNT(*) * 100, 2)       AS lead_conversion_rate_pct,
    COUNT(DISTINCT CASE WHEN Is_Converted = 1
                        THEN Converted_Account_ID END) AS converted_accounts,
    COUNT(DISTINCT Converted_Opportunity_ID)           AS converted_opportunities,
    (SELECT ROUND(SUM(o.Amount), 2)
       FROM opportunity_clean o
      WHERE o.Opportunity_ID IN (SELECT Converted_Opportunity_ID
                                   FROM vw_lead_clean
                                  WHERE Converted_Opportunity_ID IS NOT NULL))
                                                       AS expected_revenue_converted,
    ROUND(AVG(Lead_Score), 2)                          AS avg_lead_score,
    ROUND(AVG(Age_Days), 2)                            AS avg_age_open_leads
FROM vw_lead_clean;

-- Optional: Pardot Score alternative (about 17.4 over 9,581 leads)
SELECT ROUND(AVG(Pardot_Score), 1) AS avg_pardot_score, COUNT(Pardot_Score) AS leads_with_score
FROM vw_lead_clean;

-- ---------------------------------------------------------------------
-- 2. YEARLY FIGURES (for the KPI trend arrows: this year vs previous year)
-- ---------------------------------------------------------------------
SELECT Created_Year,
       COUNT(*)                                     AS total_leads,
       SUM(Is_Converted)                            AS converted_leads,
       ROUND(SUM(Is_Converted) / COUNT(*) * 100, 2) AS conversion_rate_pct
FROM vw_lead_clean
GROUP BY Created_Year
ORDER BY Created_Year;

-- ---------------------------------------------------------------------
-- VISUAL 1: Lead Volume Trend - Monthly (36 rows; peak 2021-05 = 1,803)
-- ---------------------------------------------------------------------
SELECT Created_Month,
       COUNT(*)          AS total_leads,
       SUM(Is_Converted) AS converted_leads
FROM vw_lead_clean
GROUP BY Created_Month
ORDER BY Created_Month;

-- ---------------------------------------------------------------------
-- VISUAL 2: Leads by Source (donut)
-- ---------------------------------------------------------------------
SELECT Lead_Source_Group,
       COUNT(*) AS leads,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS pct_share,
       ROUND(AVG(Lead_Score), 2) AS avg_score
FROM vw_lead_clean
GROUP BY Lead_Source_Group
ORDER BY leads DESC;

-- ---------------------------------------------------------------------
-- VISUAL 3: Leads by Stage / Status (horizontal bar, coloured by Status_Group)
-- ---------------------------------------------------------------------
SELECT Status, Status_Group, COUNT(*) AS leads
FROM vw_lead_clean
GROUP BY Status, Status_Group
ORDER BY leads DESC;

-- ---------------------------------------------------------------------
-- VISUAL 4: Conversion Rate by Lead Source (Green >30%, Amber 15-30%, Red <15%)
-- ---------------------------------------------------------------------
SELECT Lead_Source_Group,
       COUNT(*)          AS total_leads,
       SUM(Is_Converted) AS converted_leads,
       ROUND(SUM(Is_Converted) * 100 / COUNT(*), 2) AS conversion_rate_pct,
       CASE WHEN SUM(Is_Converted) * 100 / COUNT(*) > 30  THEN 'Green'
            WHEN SUM(Is_Converted) * 100 / COUNT(*) >= 15 THEN 'Amber'
            ELSE 'Red' END AS colour_band
FROM vw_lead_clean
GROUP BY Lead_Source_Group
ORDER BY conversion_rate_pct DESC;

-- ---------------------------------------------------------------------
-- VISUAL 5: Lead Volume by Industry (Top 5 + All Others)
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT Industry, COUNT(*) AS leads,
           ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn
    FROM vw_lead_clean
    GROUP BY Industry
)
SELECT CASE WHEN rn <= 5 THEN Industry ELSE 'All Others' END AS industry_group,
       SUM(leads) AS leads
FROM ranked
GROUP BY industry_group
ORDER BY MIN(rn);

-- ---------------------------------------------------------------------
-- VISUAL 6: Lead Conversion Summary (table)
-- ---------------------------------------------------------------------
SELECT Lead_Source_Group,
       COUNT(*)          AS total_leads,
       SUM(Is_Converted) AS converted_leads,
       ROUND(SUM(Is_Converted) * 100 / COUNT(*), 2) AS conversion_rate_pct,
       ROUND(AVG(Lead_Score), 2) AS avg_lead_score
FROM vw_lead_clean
GROUP BY Lead_Source_Group
ORDER BY total_leads DESC;

-- ---------------------------------------------------------------------
-- TABLEAU EXTRACT: record-level data (export this result to CSV)
-- ---------------------------------------------------------------------
SELECT * FROM vw_lead_clean;
