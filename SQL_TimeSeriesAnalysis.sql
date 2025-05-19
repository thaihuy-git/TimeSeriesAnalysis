--============================== SALES OVERVIEW ===========================================
--====================
--====== 01. What are the total sales and the running total sales over months?
--====================

SELECT
	FORMAT(s.SalesDate,'yyyy-MM') as [Month]
	,SUM(s.TotalPrice) as Total_Sales
	,SUM(SUM(s.TotalPrice)) OVER (ORDER BY FORMAT(s.SalesDate,'yyyy-MM')) as Running_Total_Sales --Using Window function to calculate the running total sales
FROM Sales s
GROUP BY FORMAT(s.SalesDate,'yyyy-MM')
ORDER BY FORMAT(s.SalesDate,'yyyy-MM');

---------- Option 2: Using CTE
/*
WITH totalSales AS(
	SELECT
	FORMAT(s.SalesDate,'yyyy-MM') as [Month]
	,SUM(s.TotalPrice) as Total_Sales
FROM Sales s
WHERE s.SalesDate is not NULL
GROUP BY FORMAT(s.SalesDate,'yyyy-MM')
)
SELECT
	t.Month
	,t.Total_Sales
	,SUM(t.Total_Sales) OVER (ORDER BY t.Month) as Running_Total_Sales
FROM totalSales t
ORDER BY t.Month;
*/

--==========================
--====== 02. What is the highest monthly sales?
--==========================

SELECT TOP 1
	FORMAT(s.SalesDate,'yyyy-MM') as [Month]
	,SUM(s.TotalPrice) as Total_Sales
FROM Sales s
GROUP BY FORMAT(s.SalesDate,'yyyy-MM')
ORDER BY Total_Sales DESC;

--==========================
--====== 03. What is the total sales per quarter and the running total sales over time?
--==========================

SELECT
	DATEPART(YEAR, s.SalesDate) as [Year]
	,DATEPART(QUARTER, s.SalesDate) as [Quarter]
	,SUM(s.TotalPrice) as Total_Sales
	,SUM(SUM(s.TotalPrice)) OVER (ORDER BY DATEPART(YEAR, s.SalesDate), DATEPART(QUARTER, s.SalesDate)) as Running_Total_Sales
FROM Sales s
GROUP BY DATEPART(YEAR, s.SalesDate), DATEPART(QUARTER, s.SalesDate)
ORDER BY DATEPART(YEAR, s.SalesDate), DATEPART(QUARTER, s.SalesDate);

--=========================
--====== 04. How is total sales of months comparing the average sales in each year and the previous month?
--=========================

-----------Use CTE to select year, month, and monthly total sales
WITH monthlySales AS(
	SELECT
		YEAR(s.SalesDate) as [Year]
		,FORMAT(s.SalesDate,'yyyy-MM') as [Month]
		,SUM(s.TotalPrice) as Total_Sales
	FROM Sales s
	GROUP BY YEAR(s.SalesDate), FORMAT(s.SalesDate,'yyyy-MM')
)
SELECT
	ms.Year
	,ms.Month
	,ms.Total_Sales as Total_Sales
	,AVG(ms.Total_Sales) OVER (PARTITION BY ms.Year) as Avg_Year_Sales  --AVG windows function to calculate the average monthly sales in the year 
	,ms.Total_Sales - ROUND(AVG(ms.Total_Sales) OVER (PARTITION BY ms.Year),2) as Diff_Avg_Sales
	--Use CASE WHEN to categorize monthly sales into three groups
	,CASE WHEN ms.Total_Sales - ROUND(AVG(ms.Total_Sales) OVER (PARTITION BY ms.Year),2) = 0 THEN 'AVERAGE'
		WHEN ms.Total_Sales - ROUND(AVG(ms.Total_Sales) OVER (PARTITION BY ms.Year),2) < 0 THEN 'BELOW AVERAGE'
		ELSE 'ABOVE AVERAGE'
	END as Group_Name
	,LAG(ms.Total_Sales,1,0) OVER (ORDER BY ms.Month) as Previous_Sales  --LAG windows function to get total sales of the previous month
	,ms.Total_Sales - LAG(ms.Total_Sales,1,0) OVER (ORDER BY ms.Month) as Diff_Previous_Sales
FROM monthlySales ms
GROUP BY ms.Year
	,ms.Month
	,ms.Total_Sales
ORDER BY ms.Month;

--============================
--====== 05. Which common time in a month has the best sales?
--           Assume that a month will be divided into three periods of time 
--           (10 days for the first period, the next 10 days for the second one, and the rest for the last one)
--============================
SELECT TOP 1 --get the period that appears the most times
	sr.Period_Of_Month
	,COUNT(*)
FROM(
SELECT FORMAT(s.SalesDate, 'yyyy-MM') as Year_Month
	--Divid a month into three periods of time
	,CASE WHEN DAY(s.SalesDate) < 11 THEN 'Beginning of the month'
		WHEN DAY(s.SalesDate) < 21 THEN 'Middle of the month' 
		ELSE 'End of the month' END Period_Of_Month  
	,SUM(s.TotalPrice) as Total_Sales
	--Ranking sales for periods of a month in each month
	,RANK() OVER (PARTITION BY FORMAT(s.SalesDate, 'yyyy-MM') ORDER BY SUM(s.TotalPrice) DESC) as Ranking
FROM Sales s
GROUP BY FORMAT(s.SalesDate, 'yyyy-MM')
		,CASE WHEN DAY(s.SalesDate) < 11 THEN 'Beginning of the month'
		WHEN DAY(s.SalesDate) < 21 THEN 'Middle of the month' 
		ELSE 'End of the month' END
) sr
WHERE sr.Ranking = 1  --only get the best sales period each month
GROUP BY sr.Period_Of_Month
ORDER BY COUNT(*) DESC;

--============================== SALES BY COUNTRIES ========================================
--=======================
--====== 06. Total sales by Cities and find the top 5 cities in term of total sales
--=======================

SELECT
	c.CityName
	,SUM(s.TotalPrice) as Total_Sales
	,DENSE_RANK() OVER (ORDER BY SUM(s.TotalPrice) DESC) as City_Ranking --DENSE_RANK for avoiding the gap of ranking sequence 
FROM Sales s
LEFT JOIN Customer c on c.CustomerID = s.CustomerID
WHERE c.CityName is not NULL
GROUP BY c.CityName
ORDER BY City_Ranking;

--=======================
--====== 07. In the top 5 cities, how is the trend  of total sales over months?
--=======================

BEGIN
	-----Get top 5 cities and then create a temporary table to store the result
	SELECT tc.CityName
	INTO #topCity
	FROM (
		SELECT c.CityName
				,DENSE_RANK() OVER (ORDER BY SUM(s.TotalPrice) DESC) as City_Ranking
		FROM Sales s
			LEFT JOIN Customer c on c.CustomerID = s.CustomerID
		WHERE c.CityName is not NULL
		GROUP BY c.CityName) tc
	WHERE tc.City_Ranking <6;

	SELECT
		ct.CityName
		,FORMAT(sl.SalesDate, 'yyyy-MM') as Year_Month
		,SUM(sl.TotalPrice) as Monthly_Total_Sales
	FROM Sales sl
	LEFT JOIN Customer ct on ct.CustomerID = sl.CustomerID
	WHERE exists (Select 1 From #topCity Where #topCity.CityName = ct.CityName) --only get the top 5 cities
	GROUP BY ct.CityName
		,FORMAT(sl.SalesDate, 'yyyy-MM')
	ORDER BY ct.CityName
		,FORMAT(sl.SalesDate, 'yyyy-MM');

	--Delete the temporary table to release the memory
	DROP TABLE #topCity;
END;

--==========================
--====== 08. Find out the top 3 ranking cities over months
--==========================

SELECT cr.Year_Month
		,cr.CityName
		,cr.Total_Sales
		,cr.City_Ranking
FROM
(
	SELECT
		FORMAT(s.SalesDate, 'yyyy-MM') as Year_Month
		,c.CityName
		,SUM(s.TotalPrice) as Total_Sales
		,DENSE_RANK() OVER (PARTITION BY FORMAT(s.SalesDate, 'yyyy-MM') ORDER BY SUM(s.TotalPrice) DESC) as City_Ranking
	FROM Sales s
	LEFT JOIN Customer c on c.CustomerID = s.CustomerID
	WHERE c.CityName is not NULL
	GROUP BY FORMAT(s.SalesDate, 'yyyy-MM')
			,c.CityName
) cr
WHERE cr.City_Ranking < 4  --only get the rank from 1-3
ORDER BY cr.Year_Month, cr.City_Ranking


--============================== SALES BY CUSTOMERS ========================================
--=========================
--====== 09. Find the top 3 customers in each month in term of total sales to give them a voucher
--=========================

------Use CTE to store the customer ranking before JOIN to optimize the query performance
WITH customerRank AS(
	SELECT FORMAT(s.SalesDate, 'yyyy-MM') as Year_Month 
		,s.CustomerID
		,SUM(s.TotalPrice) as Total_Sales
		,RANK() OVER (PARTITION BY FORMAT(s.SalesDate, 'yyyy-MM') ORDER BY SUM(s.TotalPrice) DESC) as Customer_Ranking
	FROM Sales s
	GROUP BY FORMAT(s.SalesDate, 'yyyy-MM')
			,s.CustomerID
)
SELECT csr.Year_Month
	,c.CustomerID
	,(c.LastName + ' ' + c.FirstName) as Full_Name
	,c.Address
	,c.CityName
	,c.Zipcode
	,csr.Total_Sales
	,csr.Customer_Ranking
FROM customerRank csr
LEFT JOIN Customer c ON c.CustomerID = csr.CustomerID
WHERE csr.Customer_Ranking < 4
ORDER BY csr.Year_Month, csr.Customer_Ranking;

--===========================
--====== 10. Ranking the customers based on the buying quantity with discounts to find out the customers who be probably affected by discounts
--===========================

SELECT c.CustomerID
		,(c.LastName + '' + c.FirstName) as Full_Name
		,c.Address
		,c.CityName
		,c.Zipcode
		,c.Segment
		,SUM(s.Quantity) as Total_Quantity
		,DENSE_RANK() OVER (ORDER BY SUM(s.Quantity) DESC) Ranking
FROM Sales s
LEFT JOIN Customer c ON c.CustomerID = s.CustomerID
WHERE s.Discount <> 0
GROUP BY c.CustomerID
		,c.LastName
		,c.FirstName
		,c.Address
		,c.CityName
		,c.Zipcode
		,c.Segment
ORDER BY SUM(s.Quantity) DESC;


--============================== SALES BY PRODUCTS AND CATEGORIES ==========================
--========================
--====== 11. Which categories contribute the most to overall sales?
--========================

SELECT TOP 1 p.CategoryID
		,p.CategoryName
		,SUM(s.TotalPrice) as Total_Sales
FROM Sales s
LEFT JOIN Product p ON p.ProductID = s.ProductID
GROUP BY p.CategoryID
		,p.CategoryName
ORDER BY SUM(s.TotalPrice) DESC;

--=========================
--====== 12. What is sales performance over months by categories?
--=========================

SELECT  p.CategoryID
		,p.CategoryName
		,FORMAT(s.SalesDate, 'yyyy-MM') as Year_Month
		,SUM(s.TotalPrice) as Total_Sales
FROM Sales s
LEFT JOIN Product p ON p.ProductID = s.ProductID
GROUP BY p.CategoryID
		,p.CategoryName
		,FORMAT(s.SalesDate, 'yyyy-MM')
ORDER BY p.CategoryName, FORMAT(s.SalesDate, 'yyyy-MM'), SUM(s.TotalPrice) DESC;

--==========================
--====== 13. Analyze the monthly performance of categories 
--           by comparing each category's sales to both its average sales performance and the previous month's sales
--==========================

-------Use CTE to store the monthly total sales by categories
WITH monthlyCategorySales AS (
	SELECT  p.CategoryID
			,p.CategoryName
			,FORMAT(s.SalesDate, 'yyyy-MM') as Year_Month
			,SUM(s.TotalPrice) as Total_Sales
	FROM Sales s
	LEFT JOIN Product p ON p.ProductID = s.ProductID
	GROUP BY p.CategoryID
			,p.CategoryName
			,FORMAT(s.SalesDate, 'yyyy-MM')
)
SELECT  mcs.CategoryID
		,mcs.CategoryName
		,mcs.Year_Month
		,mcs.Total_Sales
		,ROUND(AVG(mcs.Total_Sales) OVER (PARTITION BY mcs.CategoryID),2) as Avg_Category_Sales  --calculate the average sales of each category
		,mcs.Total_Sales - (AVG(mcs.Total_Sales) OVER (PARTITION BY mcs.CategoryID)) as Diff_Avg_Sales
		,LAG(mcs.Total_Sales,1,0) OVER (PARTITION BY mcs.CategoryID ORDER BY mcs.Year_Month) as Previous_Sales  --get total sales of the previous month
		,mcs.Total_Sales - LAG(mcs.Total_Sales,1,0) OVER (PARTITION BY mcs.CategoryID ORDER BY mcs.Year_Month) as Diff_Previous_Sales
FROM monthlyCategorySales mcs
ORDER BY mcs.CategoryName
		,mcs.Year_Month;

--=========================
--====== 14. Find out the top 10 products in each month in terms of total sales
--=========================

SELECT pr.Year_Month
	,p.ProductID
	,p.ProductName
	,pr.Total_Sales
	,pr.Product_Rank
FROM (
	SELECT FORMAT(s.SalesDate,'yyyy-MM') as Year_Month
			,s.ProductID
			,SUM(s.TotalPrice) as Total_Sales
			,DENSE_RANK() OVER (PARTITION BY FORMAT(s.SalesDate,'yyyy-MM') ORDER BY SUM(s.TotalPrice) DESC) as Product_Rank
	FROM Sales s
	GROUP BY FORMAT(s.SalesDate,'yyyy-MM')
			,s.ProductID
) pr
LEFT JOIN Product p ON p.ProductID = pr.ProductID
WHERE pr.Product_Rank < 11  --only get ranking from 1-10
ORDER BY pr.Year_Month, pr.Product_Rank;

--==========================
--====== 15. Find out the top 5 products that have the least sales in term of quantity
--==========================

SELECT pr.Year_Month
	,p.ProductID
	,p.ProductName
	,pr.Total_Quantity
	,pr.Product_Rank
FROM (
	SELECT FORMAT(s.SalesDate,'yyyy-MM') as Year_Month
			,s.ProductID
			,SUM(s.Quantity) as Total_Quantity
			,DENSE_RANK() OVER (PARTITION BY FORMAT(s.SalesDate,'yyyy-MM') ORDER BY SUM(s.Quantity)) as Product_Rank
	FROM Sales s
	GROUP BY FORMAT(s.SalesDate,'yyyy-MM')
			,s.ProductID
) pr
LEFT JOIN Product p ON p.ProductID = pr.ProductID
WHERE pr.Product_Rank < 6 --only get ranking from 1-5
ORDER BY pr.Year_Month, pr.Product_Rank;

--===========================
--====== 16. Categorize sold products into 3 performance groups ("High performance", "Medium performance", "Low performance") in term of total sales in a period of time
--===========================

------- Declare two variables (fromDate, toDate) to get flexibility in choosing the period of time
DECLARE @fromDate Date = '2018-01-01', @toDate Date = '2018-05-31';
BEGIN
	 
	SELECT p.ProductID
			,p.ProductName
			,p.CategoryName
			,SUM(s.TotalPrice) as Total_Sales
			--Using NTILE to have quartile of three
			,CASE WHEN NTILE(3) OVER (ORDER BY SUM(s.TotalPrice) DESC) = 1 THEN 'High Performance'
				WHEN NTILE(3) OVER (ORDER BY SUM(s.TotalPrice) DESC) = 2 THEN 'Medium Performance'
				ELSE 'Low Performance'
			END as Quartile
	FROM Sales s
	LEFT JOIN Product p ON p.ProductID = s.ProductID
	WHERE s.SalesDate BETWEEN @fromDate AND @toDate  --condition for given period of time
	GROUP BY p.ProductID
			,p.ProductName
			,p.CategoryName;
END;
