# Building a Disc Golf Bag

## Table of Contents
- [Project Overview](#project-overview)
- [Data Sources](#data-sources)
- [Data Cleaning](#data-cleaning)
- [Dashboard](#dashboard)
- [References](#references)
  
### Project Overview

[Back to Top](#building-a-disc-golf-bag)

After learning the basics of SQL and Tableau, I wanted to practice these skills. I love disc golf and recently purchased a larger bag so I decided to use my new skills to help me find some potential discs to fill out my disc golf bag. I started by **scraping data** from the [Infinite Discs](infinitediscs.com) website. Next I **merged and cleaned my datasets** before creating an **interactive dashboard** that I could use to explore new disc options. 

### Data Sources

[Back to Top](#building-a-disc-golf-bag)

Tools used: [WebScraper.io](webscraper.io)

I gathered data for this project from Infinite Discs, one of the largest disc golf retailers online. In addition to selling discs, the Infinite Discs website also allows users to leave reviews on discs and keep track of the rounds they play. I started by selecting 27 of the 77 different disc golf manufacturers listed on their website. The 27 I chose were brands that I had heard positive things about and felt comfortable adding to a list of potential discs to purchase. The Infinite Discs website is organized by manufacturer, so I used a web scraping tool to create a data set for each. I scraped the following data for each disc made by these manufacturers. 

- Disc Name
- Manufacturer
- Disc Type
- Stability
- Recommended Skill Level
- Manufacturer Flight Numbers
- Reviewer Flight Numbers
- Number of Reviews
- Rating

*You can view the data sets in this repository.*

### Data Cleaning

[Back to Top](#building-a-disc-golf-bag)

Tools used: [SQL Server](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)

To clean the data I started by unioning all 27 manufacturer tables together. Since all the tables were created using the same web scraping tool, I didn't think that I needed to do any data cleaning before unioning.

```SQL
CREATE TABLE discs_raw AS
  SELECT *
  FROM discgolf.axiom
UNION ALL
  SELECT *
  FROM discgolf.birdie
UNION ALL
  SELECT *
  FROM discgolf.dga
;
# Continue for all 27 manufacturers
```
#### **Lesson Learned**: I should have done a simple Exploratory Data Analysis (EDA) of the 27 manufacturer tables before the union. There were 4 instances of bad data from the web scraper that I could have caught more easily before unioning all 900+ rows of data together. 

Overall the webscraper produced a clean data set but in addition to correcting the 4 instances of bad data, I did the following to prepare the data for creating my dashboard:

**Create a copy of the data set before cleaning**
```SQL
CREATE TABLE discs AS
  SELECT *
  FROM discs_raw
;
```
**Remove leading and trailing text from some variables**
```SQL
#Removing "Primary Use: " from the DiscType column
SELECT LENGTH('Primary Use: ')
;
UPDATE discs
	SET DiscType = SUBSTRING(DiscType, 14)
;
```
**Break up columns formatted as '7/5/0/2' into four individual columns**
```SQL
##Separating the flight numbers
#Checking that the extraction works
SELECT
  SUBSTRING_INDEX(MFNum, '/', 1) AS MSpeed,
  SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 2), '/', -1) AS MGlide,
  SUBSTRING_INDEX(SUBSTRING_INDEX(MFNum, '/', 3), '/', -1) AS MTurn,
  SUBSTRING_INDEX(MFNum, '/', -1) AS MFade
FROM discs
;
#Adding new columns to the table
ALTER TABLE discs
  ADD COLUMN MSpeed DECIMAL(4,1),
	ADD COLUMN MGlide DECIMAL(4,1),
	ADD COLUMN MTurn DECIMAL(4,1),
	ADD COLUMN MFade DECIMAL(4,1)
;
#Populating the new columns
#There are some discs that have not been released yet so the flightnumbers are unknown.
#InfiniteDiscs populates these fields with ? on their website
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
```
**Calculate a new variable**
```SQL
#For the visuals that I want to create, I need to calculate a new stability variable
#Turn and Fade in the flight numbers combined represent whether the disc will go right or left when thrown flat. 
#Creating a new column for the new stability number
ALTER TABLE discs
  ADD COLUMN Stab DECIMAL(4,1)
;
#Populate the new column
UPDATE discs
  SET Stab = MFade + MTurn
;
```

**Replace missing values**

```SQL
#There are a number of missing values in the Skill column. I am designating those as missing
UPDATE discs
  SET Skill = CASE
    WHEN Skill = '' THEN NULL
    ELSE Skill
  END
;
```
*You can view my entire data cleaning process in this repository.*

### Dashboard

[Back to Top](#building-a-disc-golf-bag)

Tools used: [Tableau Public](https://public.tableau.com/app/discover)

When designing a dashboard, I wanted to create a more interactive version of a tool I have used on [dgputtheads.com](https://flightcharts.dgputtheads.com/mybag.html). Their bag tool allows you to select your discs and shows you where you have spots that you might want to fill. With the data I scraped, I created an **interactive dashboard** that would allow me to see all the possible discs that I could consider when filling out my bag. 

![Dashboard](images/Dashboard.png)

In the center of the dashboard is a flight map. The Y axis represents the potential distance of a disc and the x axis corresponds to how far right or left a disc will land when thrown level. Each point is a disc in the table and the red circles are discs that are in my bag. The six shaded areas represent different zones where you might want to throw a disc. Discs outside of these zones are either beyond my skill level or are specialty discs for throwing trick shots. This tool is designed to help me find discs to cover these colored areas.

The dashboard has the following interactive features:

- Searching for a specific disc in the table on the right of the Flight Chart using a text box.
- Selecting a specific disc from the list on the right will highlight it on the Flight Chart.
- Selecting an area on the Flight Chart will filter the tables on either side of the Flight Chart.
- Selecting a manufacturer from the list on the left will filter the Flight Chart and other tables.
- Selecting a category in the Skill Level and Disc Type tables will highlight those discs on the Flight Chart.

The feature that I see as the most helpful is the ability to select an area on the Flight Chart and have it filter the other tables. This will be especially helpful in finding discs to cover any missing areas in my bag. You can try this dashboard out [here](https://public.tableau.com/views/AndysDiscGolfDashboard/AndysDiscGolfDashboard?:language=en-US&:sid=&:display_count=n&:origin=viz_share_link)

### References

[Back to Top](#building-a-disc-golf-bag)

I learned the basics of SQL and Tableau from Alex on [AnalystBuilder.com](https://www.analystbuilder.com/)
- [MySQL for Data Analytics](https://www.analystbuilder.com/courses/mysql-for-data-analytics)
- [Tableau for Data Visualization](https://www.analystbuilder.com/courses/tableau-for-data-visualization)

I also used ChatGPT as a resource to help trouble shoot some of my code.
- [ChatGPT](https://chatgpt.com/)

Finally, I received some help from a Tableau Discord Community that I found on Reddit.
- [r/Tableau](https://www.reddit.com/r/tableau/comments/eal8z1/rtableau_discord/?rdt=58088)
