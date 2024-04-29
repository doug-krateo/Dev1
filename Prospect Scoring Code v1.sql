USE DATABASE MARKETSMASHER;
USE WAREHOUSE SCORING_WH;

/* Scoring Code for 100 point scaled score and decile for all prospects based on the sessions data */

CREATE OR REPLACE DYNAMIC TABLE MARKETSMASHER.PUBLIC.PROSPECT_SCORES
  TARGET_LAG = '180 minutes'
  WAREHOUSE = SCORING_WH
  AS
  WITH UserActivity AS (
    SELECT
        email,
        organization_id,
        MAX(duration) AS Max_Duration,
        COUNT(email) AS Visits,
        SUM(total_page_views) AS Page_Count,
        -- Adjust recency_points to be maximum for first 7 days, then decay to 0 at 57 days
        GREATEST(0, LEAST(57 - DATEDIFF(day, MAX(last_visit_date), CURRENT_DATE()),50)) AS recency_points,
        CASE
            WHEN MAX(duration) <= 60 THEN 0
            WHEN MAX(duration) BETWEEN 61 AND 160 THEN 10
            WHEN MAX(duration) > 160 THEN 20
            ELSE -1
        END AS duration_points,
        CASE
            WHEN COUNT(email) = 1 THEN 0
            WHEN COUNT(email) = 2 THEN 7.5
            WHEN COUNT(email) > 2 THEN 15
            ELSE -1
        END AS visits_points,
        CASE
            WHEN SUM(total_page_views) / COUNT(email) = 1 THEN 0
            WHEN SUM(total_page_views) / COUNT(email) BETWEEN 1 AND 2 THEN 7.5
            WHEN SUM(total_page_views) / COUNT(email) > 2 THEN 15
            ELSE -1
        END AS pages_points
    FROM SESSION
    WHERE last_visit_date >= DATEADD(day, -90, CURRENT_DATE()) -- Only consider sessions/visits with last visit dates within the last 90 days
    GROUP BY email, organization_id
)
SELECT
    email,
    organization_id,
    recency_points,
    duration_points,
    visits_points,
    pages_points,
    recency_points + duration_points + visits_points + pages_points AS engagement_score,
    10-(Trunc((recency_points + duration_points + visits_points + pages_points)/10)) AS engagement_decile
FROM UserActivity;