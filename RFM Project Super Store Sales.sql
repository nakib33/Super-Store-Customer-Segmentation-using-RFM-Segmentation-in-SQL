-- Step 1: Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS Superstore_Sales;

-- Step 2: Use the Superstore_Sales database
USE Superstore_Sales;

-- Step 3: Create the Superstore_Sales table
CREATE TABLE Superstore_Sales (
    Row_ID INT PRIMARY KEY,
    Order_Priority VARCHAR(50),
    Discount DECIMAL(5,2),
    Unit_Price DECIMAL(10,2),
    Shipping_Cost DECIMAL(10,2),
    Customer_ID INT,
    Customer_Name VARCHAR(100),
    Ship_Mode VARCHAR(50),
    Customer_Segment VARCHAR(50),
    Product_Category VARCHAR(50),
    Product_Sub_Category VARCHAR(50),
    Product_Container VARCHAR(50),
    Product_Name VARCHAR(255),
    Product_Base_Margin DECIMAL(5,2),
    Region VARCHAR(50),
    Manager VARCHAR(50),
    State_or_Province VARCHAR(50),
    City VARCHAR(50),
    Postal_Code INT,
    Order_Date DATE,
    Ship_Date DATE,
    Profit DECIMAL(15,2),
    Quantity_Ordered INT,
    Sales DECIMAL(15,2),
    Order_ID INT,
    Return_Status VARCHAR(50)
);

-- Step 4: Load data into the Superstore_Sales table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Superstore Sales Data.csv'
INTO TABLE Superstore_Sales
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    Row_ID, Order_Priority, Discount, Unit_Price, Shipping_Cost, Customer_ID, Customer_Name, Ship_Mode, 
    Customer_Segment, Product_Category, Product_Sub_Category, Product_Container, Product_Name, @Product_Base_Margin,
    Region, Manager, State_or_Province, City, Postal_Code, @Order_Date, @Ship_Date, Profit, Quantity_Ordered, 
    Sales, Order_ID, Return_Status
)
SET 
    Product_Base_Margin = IFNULL(NULLIF(@Product_Base_Margin, ''), 0),  -- Handle empty values
    Order_Date = DATE_ADD('1899-12-30', INTERVAL @Order_Date DAY),  -- Convert Excel date
    Ship_Date = DATE_ADD('1899-12-30', INTERVAL @Ship_Date DAY);  -- Convert Excel date

-- Step 5: Data retrieval and analysis

-- Retrieve all records from the Superstore_Sales table
SELECT * FROM Superstore_Sales;

-- Get the most recent order date
SELECT MAX(Order_Date) FROM Superstore_Sales;

-- Get the earliest order date
SELECT MIN(Order_Date) FROM Superstore_Sales;

-- Get the current date
SELECT CURDATE();

-- Calculate recency for each customer
SELECT
    Customer_Name,
    MAX(Order_Date) AS LAST_ORDER_DATE,
    DATEDIFF(CURDATE(), MAX(Order_Date)) AS RECENCY
FROM Superstore_Sales
GROUP BY Customer_Name;

-- Step 6: Data cleaning

-- Ensure Order_Date is in the correct format
UPDATE Superstore_Sales
SET Order_Date = STR_TO_DATE(Order_Date, '%Y-%m-%d');

-- Ensure Ship_Date is in the correct format
UPDATE Superstore_Sales 
SET Ship_Date = STR_TO_DATE(Ship_Date, '%Y-%m-%d');

-- Step 7: Exploratory Data Analysis

-- Count total number of orders
SELECT 
    COUNT(*) AS Total_Orders
FROM
    Superstore_Sales;

-- List distinct product categories
SELECT DISTINCT
    Product_Category
FROM
    Superstore_Sales;

-- Count orders by region
SELECT 
    Region, COUNT(*) AS Order_Count
FROM
    Superstore_Sales
GROUP BY Region;

-- Top 10 customers by total sales
SELECT 
    Customer_Name, SUM(Sales) AS Total_Sales
FROM
    Superstore_Sales
GROUP BY Customer_Name
ORDER BY Total_Sales DESC
LIMIT 10;

-- Step 8: RFM Segmentation

-- Create a view for RFM scoring
CREATE OR REPLACE VIEW RFM_SCORE_DATA AS
WITH CUSTOMER_AGGREGATED_DATA AS (
    SELECT 
        Customer_Name,
        DATEDIFF((SELECT MAX(Order_Date) FROM Superstore_Sales), MAX(Order_Date)) AS Recency_Value,
        COUNT(DISTINCT Order_ID) AS Frequency_Value,
        ROUND(SUM(Sales), 0) AS Monetary_Value
    FROM Superstore_Sales
    GROUP BY Customer_Name
),
RFM_SCORE AS (
    SELECT 
        C.*,
        NTILE(4) OVER (ORDER BY Recency_Value DESC) AS R_Score,
        NTILE(4) OVER (ORDER BY Frequency_Value ASC) AS F_Score,
        NTILE(4) OVER (ORDER BY Monetary_Value ASC) AS M_Score
    FROM CUSTOMER_AGGREGATED_DATA AS C
)
SELECT
    R.Customer_Name,
    R.Recency_Value,
    R_Score,
    R.Frequency_Value,
    F_Score,
    R.Monetary_Value,
    M_Score,
    (R_Score + F_Score + M_Score) AS Total_RFM_Score,
    CONCAT_WS('', R_Score, F_Score, M_Score) AS RFM_Score_Combination
FROM RFM_SCORE AS R;

-- Create a view for RFM analysis
CREATE OR REPLACE VIEW RFM_ANALYSIS AS
SELECT 
    RFM_SCORE_DATA.*,
    CASE
        WHEN RFM_Score_Combination IN ('111', '112', '121', '132', '211', '212', '114', '141') THEN 'CHURNED CUSTOMER'
        WHEN RFM_Score_Combination IN ('133', '134', '143', '224', '334', '343', '344', '144') THEN 'SLIPPING AWAY, CANNOT LOSE'
        WHEN RFM_Score_Combination IN ('311', '411', '331') THEN 'NEW CUSTOMERS'
        WHEN RFM_Score_Combination IN ('222', '231', '221', '223', '233', '322') THEN 'POTENTIAL CHURNERS'
        WHEN RFM_Score_Combination IN ('323', '333', '321', '341', '422', '332', '432') THEN 'ACTIVE'
        WHEN RFM_Score_Combination IN ('433', '434', '443', '444') THEN 'LOYAL'
        ELSE 'Other'
    END AS Customer_Segment
FROM RFM_SCORE_DATA;

-- Analyze customer segments
SELECT 
    Customer_Segment,
    COUNT(*) AS Number_of_Customers,
    ROUND(AVG(Monetary_Value), 0) AS Average_Monetary_Value
FROM RFM_ANALYSIS
GROUP BY Customer_Segment
ORDER BY Number_of_Customers DESC;
