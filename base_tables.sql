--Creating table_columns View

CREATE VIEW table_columns AS
SELECT table_name AS table,
	   STRING_AGG(column_name, ', ')
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name;

-- Most represented Sports in terms of athletes number
SELECT sport,
       COUNT(distinct(athlete_id)) AS athletes
FROM summer_games
GROUP BY sport
ORDER BY athletes DESC
LIMIT 3;

/*************************************************************************/
-- Athletes vs events by sport
SELECT sport,
       COUNT(DISTINCT(event)) AS events,
       COUNT(DISTINCT(athlete_id)) AS athletes
FROM summer_games
GROUP BY sport;

/*************************************************************************/
-- Select the age of the oldest athlete for each region
SELECT region,
    MAX(age) AS age_of_oldest_athlete
FROM athletes AS a
JOIN summer_games AS s
ON a.id = s.athlete_id
JOIN countries AS c
ON s.country_id = c.id
GROUP BY region;

/************************************************************************/
-- Number of events in each sport
SELECT sport,
    COUNT(DISTINCT event) AS events
FROM summer_games
GROUP BY sport
UNION

SELECT sport,
    COUNT(DISTINCT event) AS events
FROM winter_games
GROUP BY sport
ORDER BY events DESC;
/**************************************************************************/

-- Report 1: Most decorated summer athletes (with more than 3 Golden Medals)
SELECT a.name AS athlete_name,
	   SUM(s.gold) AS gold_medal_won
FROM athletes AS a
JOIN summer_games AS s
	ON s.athlete_id = a.id
GROUP BY athlete_name
HAVING SUM(s.gold)> 2
ORDER BY gold_medal_won DESC;
/**********************************************************************/

-- Report 2: Gold Medals Won By Demographic Group for Countried in
-- 'Western Europe' considering both Summer and Winter games.
WITH seasons AS(
		 SELECT 'Summer' AS season,
		 				country_id,
						athlete_id,
						gold
		FROM summer_games AS sg
		UNION ALL
		SELECT 'Winter' AS season,
					 country_id,
					 athlete_id,
					 gold
		FROM winter_games AS wg
								),
	  demographics AS(
			SELECT id,
						CASE
							WHEN gender = 'F' AND age BETWEEN 13 AND 25 THEN 'Femal Age 13-25'
							WHEN gender = 'F' AND age >= 26 THEN 'Female Age 26+'
							WHEN gender = 'M' AND age BETWEEN 13 AND 25 THEN 'Male Age 13-25'
							WHEN gender = 'M' AND age >= 26 THEN 'Male Age 26+'
						END AS demographic_group
			FROM athletes
									)

SELECT s.season,
			 d.demographic_group,
			 SUM(s.gold) AS gold_medal_won

FROM seasons AS s
JOIN demographics AS d
	ON s.athlete_id = d.id
JOIN countries AS c
	ON c.id = s.country_id
WHERE region = 'WESTERN EUROPE'
GROUP BY s.season, d.demographic_group
ORDER BY SUM(s.gold) DESC;

/***********************************************************************/
-- Report 3: Top athletes in nobel-prized countries

SELECT
    event,
    CASE WHEN event LIKE '%Women%' THEN 'female'
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM summer_games
-- Only include countries that won a nobel prize
WHERE country_id IN
	(SELECT country_id
    FROM country_stats
    WHERE nobel_prize_winners > 0)
GROUP BY event
UNION
SELECT
    event,
    CASE WHEN event LIKE '%Women%' THEN 'female'
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM winter_games
WHERE country_id IN
	(SELECT country_id
    FROM country_stats
    WHERE nobel_prize_winners > 0)
GROUP BY event
ORDER BY athletes DESC
LIMIT 10;

/*****************************************************************/
-- Report 3: Countries with high medal rates
SELECT 
    LEFT(REPLACE(UPPER(TRIM(c.country)), '.', ''), 3) AS 
		country_code,
		pop_in_millions,
  	SUM(COALESCE(bronze,0) + COALESCE(silver,0) + 
		COALESCE(gold,0)) AS medals,
		SUM(COALESCE(bronze,0) + COALESCE(silver,0) + 
		COALESCE(gold,0)) / CAST(cs.pop_in_millions AS float) AS medals_per_million
FROM summer_games AS s
JOIN countries AS c 
ON s.country_id = c.id
-- Update the newest join statement to remove duplication
JOIN country_stats AS cs 
ON s.country_id = cs.country_id AND s.year = CAST(cs.year AS date)
-- Filter out null populations
WHERE cs.pop_in_millions IS NOT NULL
GROUP BY c.country, pop_in_millions
-- Keep only the top 25 medals_per_million rows
ORDER BY medals_per_million DESC
LIMIT 25;

/**************************************************************/
-- Report 4: Tallest athletes and % GDP by region
SELECT
	-- Pull in region and calculate avg tallest height
    region,
    AVG(height) AS avg_tallest,
    -- Calculate region's percent of world gdp
    SUM(gdp)/SUM(SUM(gdp)) OVER () AS perc_world_gdp    
FROM countries AS c
JOIN
    (SELECT 
     	-- Pull in country_id and height
        country_id, 
        height, 
        -- Number the height of each country's athletes
        ROW_NUMBER() OVER (PARTITION BY country_id ORDER BY height DESC) AS row_num
    FROM winter_games AS w 
    JOIN athletes AS a ON w.athlete_id = a.id
    GROUP BY country_id, height
    -- Alias as subquery
    ORDER BY country_id, height DESC) AS subquery
ON c.id = subquery.country_id
-- Join to country_stats
JOIN country_stats AS cs 
ON cs.country_id = c.id
-- Only include the tallest height for each country
WHERE row_num = 1
