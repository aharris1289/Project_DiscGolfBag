## Creating a backup of the data before cleaning
CREATE TABLE discs AS
	SELECT *
    FROM discs_raw
    ;

## Removing extra text from the DiscType, Stability, and Skill columns
#Removing "Primary Use: " from the DiscType column
SELECT LENGTH('Primary Use: ')
;

UPDATE discs
	SET DiscType = SUBSTRING(DiscType, 14)
;

#Removing "Stability: " from the Stability column
SELECT LENGTH('Stability: ')
;

UPDATE discs
	SET Stability = SUBSTRING(Stability, 12)
;

#Removing "Recommended Skill Level: " from the skill column
SELECT LENGTH('Recommended Skill Level: ')
;

UPDATE discs
	SET Skill = SUBSTRING(Skill, 26)
;

##Removing the text from the NumReviews column to leave only the numbers
##Data in the reviews are formatted as '(# Reviews)' with the number ranging from 1 to 3 intergers
#Start by removing the "(" at the beginning of the string
UPDATE discs
SET NumReviews = SUBSTRING(NumReviews, 2)
;
#Extract the substring before the ' ' between the number and 'Reviews)'
UPDATE discs
SET NumReviews = SUBSTRING_INDEX(NumReviews, ' ', 1)
;
#Changing the data type from String to Interger
ALTER TABLE discs
MODIFY COLUMN NumReviews INT
;

##Separating the flight numbers
#Checking that the extraction works
SELECT 
    SUBSTRING_INDEX(MFNum, '/', 1) AS MSpeed,
    SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 2), '/', -1) AS MGlide,
    SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 3), '/', -1) AS MTurn,
    SUBSTRING_INDEX(MFNum, '/', -1) AS MFade
FROM discs;
#Adding new columns to the table
ALTER TABLE discs
	ADD COLUMN MSpeed DECIMAL(4,1),
	ADD COLUMN MGlide DECIMAL(4,1),
	ADD COLUMN MTurn DECIMAL(4,1),
	ADD COLUMN MFade DECIMAL(4,1)
    ;
#Populating the new columns
#There are some discs that have not been distributed yet so the flightnumbers are unknown. InfiniteDiscs populates these fields with ? on their website
UPDATE discs
SET
	MSpeed = CASE
				WHEN SUBSTRING_INDEX(MFNum, '/', 1) = '?' THEN NULL 
				ELSE CAST(SUBSTRING_INDEX(MFNum, '/', 1) AS DECIMAL(4,1))
			END,
    MGlide = CASE
				WHEN SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 2), '/', -1) = '?' THEN NULL
				ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 2), '/', -1) AS DECIMAL(4,1))
			END,
    MTurn = CASE
				WHEN SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 3), '/', -1) = '?' THEN NULL
				ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 3), '/', -1) AS DECIMAL(4,1))
			END,
    MFade = CASE
				WHEN SUBSTRING_INDEX(MFNum, '/', -1) = '?' THEN NULL
				ELSE CAST(SUBSTRING_INDEX(MFNum, '/', -1) AS DECIMAL(4,1))
			END
;
#Now doing the same thing with the reviewer flight numbers (RFNum)
ALTER TABLE discs
	ADD COLUMN RSpeed DECIMAL(4,1),
	ADD COLUMN RGlide DECIMAL(4,1),
	ADD COLUMN RTurn DECIMAL(4,1),
	ADD COLUMN RFade DECIMAL(4,1)
    ;
#Ran into an issue trying to populate the reviewer flight number columns.
#The data scraper pulled incorrect data for three discs. 
#Manually updating the data.

UPDATE discs
SET
	RFNum = CASE
				WHEN `Name` = 'Max' AND `Manufacturer` = 'Innova' THEN '10.9/3.1/0/5'
                WHEN `Name` = 'Boss' AND `Manufacturer` = 'Innova' THEN '13/5/-0.6/3'
                WHEN `Name` = 'Meteor Hammer' AND `Manufacturer` = 'Yikun' THEN '2.1/3.1/-0.1/0'
                WHEN `Name` = 'Inner Core' AND `Manufacturer` = 'Trash Panda Disc Golf' THEN '2.1/4.1/-0.5/0'
                ELSE RFNum
			END;

#Populating the new columns
UPDATE discs
SET
	RSpeed = CASE
				#In this query I am replacing all the rows where there are no customer reviews. 
                #Infinite discs populates those numbers to match the manufacturer flight numbers. 
                #This will also catch all of the '?/?/?/?' values. 
                WHEN NumReviews = 0 THEN NULL 
				ELSE CAST(SUBSTRING_INDEX(RFNum, '/', 1) AS DECIMAL(4,1))
			END,
    RGlide = CASE
				WHEN NumReviews = 0 THEN NULL
				ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(RFNum, '/', 2), '/', -1) AS DECIMAL(4,1))
			END,
    RTurn = CASE
				WHEN NumReviews = 0 THEN NULL
				ELSE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(RFNum, '/', 3), '/', -1) AS DECIMAL(4,1))
			END,
    RFade = CASE
				WHEN NumReviews = 0 THEN NULL
				ELSE CAST(SUBSTRING_INDEX(RFNum, '/', -1) AS DECIMAL(4,1))
			END
;

#I want to see the difference between reviewer and manufacturer flight numbers.
SELECT `Name`, 
		Manufacturer,
        MSpeed - RSpeed AS SpeedDifference,
        MGlide - RGlide AS GlideDifference,
        MTurn - RTurn AS TurnDifference,
        MFade - RFade AS FadeDifference,
        Rating,
        NumReviews
FROM discs
WHERE NumReviews > 5 #I want to filter out those discs that maybe had one passionately dissatisfied reviewer
;
#Results showed that very few discs had a difference score > |1|. 
#At my skill level, this shouldn't make a big difference so I am going to focus on the manufacturer flight numbers for my visuals

#For the visuals that I want to create, I need to calculate a new stability variable
#Turn and Fade in the flight numbers combined represent whether the disc will go right or left when thrown flat. 
#Creating a new column for the new stability number
ALTER TABLE discs
ADD COLUMN Stab DECIMAL(4,1);

#Populate the new column
UPDATE discs
SET Stab = MFade + MTurn;

#There are a number of missing values in the Skill column. I am designating those as missing
UPDATE discs
	SET Skill = CASE
		WHEN Skill = '' THEN NULL 
        ELSE Skill
	END;
#I also wanted to update the Skill column for the data to be more useful. 
#The Skill column contains 'Beginner' 'Intermediate' 'Advanced' 'Everyone' and various combinations (n=13) of all of those values
#I am reducing this variable to six total categories that will be useful for me - Beginner, Beginner-Intermediate, Intermediate, Intermediate-Advanced, Advanced, and Everyone
UPDATE discs
	SET Skill = CASE
		WHEN Skill = 'Advanced, Everyone' THEN 'Advanced'
        WHEN Skill = 'Beginner, Everyone' THEN 'Beginner'
        WHEN Skill = 'Beginner, Intermediate' THEN 'Beginner-Intermediate'
        WHEN Skill = 'Beginner, Intermediate, Advanced' THEN 'Everyone'
        WHEN Skill = 'Beginner, Intermediate, Advanced, Everyone' THEN 'Everyone'
        WHEN Skill = 'Beginner, Intermediate, Everyone' THEN 'Beginner-Intermediate'
        WHEN Skill = 'Intermediate, Advanced' THEN 'Intermediate-Advanced'
        WHEN Skill = 'Intermediate, Advanced, Everyone' THEN 'Intermediate-Advanced'
        WHEN Skill = 'Intermediate, Everyone' THEN 'Intermediate'
        ELSE Skill
	END;

#If there are no reviews, the Rating is automatically designated as 0. 
#Changing to NULL as that is more appropriate.
UPDATE discs
	SET Rating = CASE
		WHEN Rating = 0 THEN NULL
        ELSE Rating
	END;
#Kastaplast is a Sweedish manufacturer. Two of their disc's names have special characters that didn't populate correctly during scraping. 
#Fixing those names
UPDATE discs
	SET `Name` = CASE
		WHEN `Name` = 'Ã„lva' THEN 'Älva'
        WHEN `Name` = 'JÃ¤rn' THEN 'Järn'
        ELSE `Name`
	END;

#Adding a column to designate discs that I already own/use
ALTER TABLE discs
	ADD COLUMN Owned BOOLEAN DEFAULT FALSE;
#Designating those discs that are in my bag
UPDATE discs
	SET Owned = CASE
		WHEN `Name` = 'Sting' THEN 1
        WHEN `Name` = 'Valkyrie' THEN 1
        WHEN `Name` = 'Raptor' THEN 1
        WHEN `Name` = 'Diamond' THEN 1
        WHEN `Name` = 'Fuse' THEN 1
        WHEN `Name` = 'M4' THEN 1
        WHEN `Name` = 'MX-3' THEN 1
        WHEN `Name` = 'PA-3' THEN 1
        WHEN `Name` = 'Aviar' THEN 1
		ELSE 0
	END;

