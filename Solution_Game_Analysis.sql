Create Schema game_analysis;

use game_analysis;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;

alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
alter table level_details2 add primary key(P_ID,Dev_id,start_datetime);

-- pd (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- ld (P_ID,Dev_ID,start_time,stages_crossed,level,difficulty,kill_count,
-- headshots_count,score,lives_earned)


SELECT 
    *
FROM
    player_details;

SELECT 
    *
FROM
    level_details2;

-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0

SELECT 
    P_ID, Dev_ID, PName, Difficulty, Level
FROM
    level_details2
        INNER JOIN
    player_details USING (P_ID)
WHERE
    Level = 0;


SELECT 
    pd.P_ID,
    ld2.Dev_ID,
    pd.PName,
    ld2.difficulty AS Difficulty_level
FROM
    player_details pd
        JOIN
    level_details2 ld2 ON pd.P_ID = ld2.P_ID
WHERE
    ld2.level = 0;

-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed


SELECT 
    pd.L1_code, AVG(ld2.kill_count) AS Avg_Kill_Count
FROM
    player_details pd
        JOIN
    level_details2 ld2 ON pd.P_ID = ld2.P_ID
WHERE
    ld2.lives_earned = 2
        AND ld2.stages_crossed >= 3
GROUP BY pd.L1_code;


-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decreasing order of total number of stages crossed.

SELECT 
    ld2.difficulty AS Difficulty_level,
    SUM(ld2.stages_crossed) AS Total_Stages_Crossed
FROM
    level_details2 ld2
        JOIN
    player_details pd ON ld2.P_ID = pd.P_ID
WHERE
    ld2.level = 2 AND ld2.Dev_ID LIKE 'zm_%'
GROUP BY ld2.difficulty
ORDER BY Total_Stages_Crossed DESC;


-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.

SELECT 
    P_ID,
    COUNT(DISTINCT DATE(start_datetime)) AS Unique_Play_Days
FROM
    level_details2
GROUP BY P_ID
HAVING Unique_Play_Days > 1;


-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.


WITH Average_Kills AS (
    SELECT AVG(Kill_Count) AS Avg_Kill
    FROM level_details2
    WHERE Difficulty = 'Medium'
)
SELECT P_ID, Level, SUM(Kill_Count) AS Total_Kills
FROM level_details2, Average_Kills
WHERE Kill_Count > Avg_Kill
GROUP BY P_ID, Level;




-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.


SELECT 
    ld2.level AS Level,
    pd.L2_code AS Level_Code,
    SUM(ld2.lives_earned) AS Total_Lives_Earned
FROM
    level_details2 ld2
        JOIN
    player_details pd ON ld2.P_ID = pd.P_ID
WHERE
    ld2.level <> 0
GROUP BY ld2.level , pd.L2_code
ORDER BY ld2.level ASC;


-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 

WITH RankedScores AS (
    SELECT
        Dev_ID,
        difficulty,
        score,
        ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY score DESC) AS score_rank
    FROM
        level_details2
)
SELECT
    Dev_ID,
    difficulty,
    score,
    score_rank
FROM
    RankedScores
WHERE
    score_rank <= 3
ORDER BY
    Dev_ID ASC,
    score_rank ASC;
    
    
-- Q8) Find first_login datetime for each device id

SELECT 
    Dev_ID, MIN(start_datetime) AS First_Login
FROM
    level_details2
GROUP BY Dev_ID;


-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.


WITH RankedScores AS (
    SELECT
        Dev_ID,
        difficulty,
        score,
        RANK() OVER (PARTITION BY difficulty ORDER BY score DESC) AS score_rank
    FROM
        level_details2
)
SELECT
    Dev_ID,
    difficulty,
    score,
    score_rank
FROM
    RankedScores
WHERE
    score_rank <= 5
ORDER BY
    difficulty ASC,
    score_rank ASC;
    
	

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.


SELECT 
    ld2.P_ID,
    ld2.Dev_ID,
    ld2.start_datetime AS first_login_datetime
FROM
    level_details2 ld2
        INNER JOIN
    (SELECT 
        P_ID, MIN(start_datetime) AS first_login_time
    FROM
        level_details2
    GROUP BY P_ID) AS first_login ON ld2.P_ID = first_login.P_ID
        AND ld2.start_datetime = first_login.first_login_time;


-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
-- a) window function


SELECT 
    P_ID,
    start_datetime,
    SUM(kill_count) OVER (PARTITION BY P_ID ORDER BY start_datetime ROWS UNBOUNDED PRECEDING) AS killsSoFar
FROM 
    level_details2
ORDER BY 
    P_ID ASC, start_datetime ASC;



-- b) without window function


SELECT 
    ld2.P_ID,
    ld2.start_datetime,
    (SELECT 
            SUM(ld2_inner.kill_count)
        FROM
            level_details2 ld2_inner
        WHERE
            ld2_inner.P_ID = ld2.P_ID
                AND ld2_inner.start_datetime <= ld2.start_datetime) AS KillsSoFar
FROM
    level_details2 ld2
ORDER BY ld2.P_ID ASC , ld2.start_datetime ASC;


-- Q12) Find the cumulative sum of stages crossed over a start_datetime 


SELECT
    P_ID,
    start_datetime,
    stages_crossed,
    SUM(stages_crossed) OVER (PARTITION BY P_ID ORDER BY start_datetime) AS cumulative_stages_crossed
FROM
    level_details2
ORDER BY
    P_ID ASC, start_datetime ASC;


-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime

WITH CumulativeSum AS (
    SELECT
        P_ID,
        start_datetime,
        Stages_Crossed,
        SUM(Stages_Crossed) OVER (PARTITION BY P_ID ORDER BY start_datetime ASC ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS CumulativeStages
    FROM level_details2
)
SELECT
    P_ID,
    start_datetime,
    Stages_Crossed,
    CumulativeStages
FROM CumulativeSum
ORDER BY P_ID Asc, start_datetime ASC;



-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id

WITH DeviceTopScores AS (
    SELECT
        ld2.Dev_ID,
        ld2.P_ID,
        SUM(ld2.score) AS total_score,
        ROW_NUMBER() OVER (PARTITION BY ld2.Dev_ID ORDER BY SUM(ld2.score) DESC) AS score_rank
    FROM
        level_details2 ld2
    GROUP BY
        ld2.Dev_ID,
        ld2.P_ID
)
SELECT
    Dev_ID,
    P_ID,
    total_score
FROM
    DeviceTopScores
WHERE
    score_rank <= 3
ORDER BY
    Dev_ID,
    score_rank;


-- Q15) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id


WITH PlayerAvgScores AS (
    SELECT
        P_ID,
        AVG(score) AS avg_score
    FROM
        level_details2
    GROUP BY
        P_ID
),
PlayerTotalScores AS (
    SELECT
        P_ID,
        SUM(score) AS total_score
    FROM
        level_details2
    GROUP BY
        P_ID
)
SELECT
    pts.P_ID,
    pts.total_score,
    pas.avg_score
FROM
    PlayerTotalScores pts
INNER JOIN
    PlayerAvgScores pas ON pts.P_ID = pas.P_ID
WHERE
    pts.total_score > 0.5 * pas.avg_score;
    
    

-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.

DELIMITER //

CREATE PROCEDURE GetTopNHeadshotsCountByDevID(IN TopN INT)
BEGIN
    WITH RankedHeadshots AS (
        SELECT
            Dev_ID,
            difficulty,
            headshots_count,
            ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count ASC) AS headshots_rank
        FROM
            level_details2
    )
    SELECT
        Dev_ID,
        difficulty,
        headshots_count,
        headshots_rank
    FROM
        RankedHeadshots
    WHERE
        headshots_rank <= TopN
    ORDER BY
        Dev_ID,
        headshots_rank;
END//

DELIMITER ;


CALL GetTopNHeadshotsCountByDevID(5);


-- Q17) Create a function to return sum of Score for a given player_id.

DELIMITER //

DROP FUNCTION IF EXISTS GetTotalScoreForPlayer;

CREATE FUNCTION GetTotalScoreForPlayer(PlayerID VARCHAR(50)) RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE TotalScore INT;
    
    SELECT SUM(score) INTO TotalScore
    FROM level_details2
    WHERE P_ID = PlayerID;
    
    RETURN TotalScore;
END //

DELIMITER ;

SELECT DISTINCT
    p_id
FROM
    level_details2;

SELECT GETTOTALSCOREFORPLAYER(224);