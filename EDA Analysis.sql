SELECT * FROM dbo.Auto_Sales_data

/*
 Cleaning Data in SQL Queries
*/
------------------------------------------------------------------------------------------

-- Add new columns for Month and Year
ALTER TABLE dbo.Auto_Sales_data
ADD  ORDERMONTH INT;

ALTER TABLE dbo.Auto_Sales_data
ADD  ORDERYEAR INT;


-- Update the new columns with extracted values
UPDATE dbo.Auto_Sales_data
SET 
    ORDERMONTH = MONTH(CONVERT(DATETIME, ORDERDATE, 103)),
    ORDERYEAR = YEAR(CONVERT(DATETIME, ORDERDATE, 103));

-- Drop unwanted column
ALTER TABLE dbo.Auto_Sales_data
DROP COLUMN DAYS_SINCE_LASTORDER;



/*
 Exploratory Analysis 
*/
------------------------------------------------------------------------------------------
-- Inspecting Clean Data
SELECT * FROM dbo.Auto_Sales_data;


-- Check for Unqiue values present in data
SELECT DISTINCT ORDERYEAR FROM dbo.Auto_Sales_data;
SELECT DISTINCT COUNTRY FROM dbo.Auto_Sales_data;-- Plot
SELECT DISTINCT STATUS FROM dbo.Auto_Sales_data;-- Plot
SELECT DISTINCT PRODUCTLINE  FROM dbo.Auto_Sales_data;-- Plot
SELECT DISTINCT DEALSIZE FROM dbo.Auto_Sales_data;-- Plot


---------------------------ANALYSIS LIST---------------------------------------
-- 1. Aggregating Sales Data by Product Line, Order Year, and Deal Size
SELECT PRODUCTLINE, SUM(SALES) AS REVENUE
FROM Auto_Sales_data
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

SELECT ORDERYEAR, SUM(SALES) AS REVENUE
FROM Auto_Sales_data
GROUP BY ORDERYEAR
ORDER BY 2 DESC

SELECT DEALSIZE, SUM(SALES) AS REVENUE
FROM Auto_Sales_data
GROUP BY DEALSIZE
ORDER BY 2 DESC

-- 2. Sales Month within a Designated Year (Revenue Generated for the Year)
SELECT ORDERMONTH , SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY
FROM Auto_Sales_data
WHERE ORDERYEAR = 2019
GROUP BY ORDERMONTH
ORDER BY 2 DESC


--3. Determining the Highest Performing Product Line during the Optimal Sales Month
SELECT ORDERMONTH, PRODUCTLINE , SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY
FROM Auto_Sales_data
WHERE ORDERYEAR = 2019 and ORDERMONTH = 11
GROUP BY ORDERMONTH, PRODUCTLINE
ORDER BY 3 DESC


--4. Identification of the Top-Performing Customer through RFM Analysis

-- Check if the temporary table #rfm exists, and drop it if it does
IF OBJECT_ID('tempdb..#rfm', 'U') IS NOT NULL
    DROP TABLE #rfm;
-- Create a temporary table #rfm
With rfm as
(
	-- Calculate RFM metrics for each customer
	SELECT CUSTOMERNAME, COUNT(ORDERNUMBER) AS FREQUENCY,
	SUM(SALES) AS MONETARYVALUE, MAX(ORDERDATE) AS LAST_ORDER_DATE,
	(SELECT  MAX(ORDERDATE) FROM Auto_Sales_data) MAX_ORDER_DATE,
	DATEDIFF(DD,MAX(ORDERDATE),(SELECT  MAX(ORDERDATE) FROM Auto_Sales_data)) AS RECENCY
FROM Auto_Sales_data
GROUP BY CUSTOMERNAME
),
rfm_calc as
(
SELECT r.*,
	NTILE(4) OVER (ORDER BY RECENCY) rfm_recency,
	NTILE(4) OVER (ORDER BY FREQUENCY) rfm_frequency,
	NTILE(4) OVER (ORDER BY MONETARYVALUE) rfm_monetary
FROM rfm r
)
SELECT c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
CAST(rfm_recency as Varchar) + CAST(rfm_frequency as Varchar) + CAST(rfm_monetary as Varchar) as rfm_cell_string
into #rfm
FROM rfm_calc c;


-- 5. Customers be segmented based on RFM analysis?
SELECT CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,

-- Applying a CASE statement to categorize customers into segments
	CASE
		when rfm_cell_string in (433,434,443,444) then 'Loyal'
		when rfm_cell_string in (323,333,321,422,332,432) then 'Active'
		when rfm_cell_string in (311,411,331) then 'New Customer'
		when rfm_cell_string in (133,134,143,244,334,343,344, 144) then 'Slipping away, Cannot lose'
		when rfm_cell_string in (111,112,121,122,123,132,211,212,114,141) then 'Lost_Customer'
		when rfm_cell_string in (222,333,321,422,332,432) then 'Potential Churners'
	end rfm_segment

FROM #rfm;



--6. Selecting distinct ORDERNUMBER and concatenating associated PRODUCTCODEs for orders
SELECT DISTINCT ORDERNUMBER, stuff(
	(SELECT ',' + PRODUCTCODE
	FROM Auto_Sales_data p
	WHERE ORDERNUMBER IN (
		SELECT ORDERNUMBER
		FROM (
			SELECT ORDERNUMBER, COUNT(*)rn
			FROM Auto_Sales_data
			WHERE STATUS = 'Shipped'
			GROUP BY ORDERNUMBER
		) as n
		WHERE rn = 3
	)
	and p.ORDERNUMBER = s.ORDERNUMBER
	for xml path(''))
	,1,1,'')
FROM Auto_Sales_data s
ORDER BY 1




/*
 
*/
------------------------------------------------------------------------------------------