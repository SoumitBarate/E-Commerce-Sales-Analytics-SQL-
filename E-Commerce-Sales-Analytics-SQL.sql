-- Create Table
CREATE TABLE raw_online_retail (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description TEXT,
    Quantity INTEGER,
    InvoiceDate TEXT,
    UnitPrice NUMERIC(10,2),
    CustomerID INTEGER,
    Country VARCHAR(100)
);

-- Verify the Table
SELECT *
FROM raw_online_retail;

-- Remove Table
DROP TABLE raw_online_retail;

-- Verify
SELECT *
FROM raw_online_retail
LIMIT 5;

-- Total Records
SELECT COUNT(*) AS total_records
FROM raw_online_retail;

-- First 10 Rows
SELECT *
FROM raw_online_retail
LIMIT 10;

-- Check for NULL Values
SELECT COUNT(*) AS total_rows,
COUNT(CustomerID) AS customerid_not_null,
COUNT(Description) AS description_not_null,
COUNT(UnitPrice) AS unitprice_not_null
FROM raw_online_retail;

-- Check Missing Customer IDs
SELECT COUNT(*) AS missing_customer_ids
FROM raw_online_retail
WHERE CustomerID IS NULL;

-- Check Negative Quantities
SELECT *
FROM raw_online_retail
WHERE Quantity < 0
LIMIT 20;

-- Check Zero or Negative Prices
SELECT *
FROM raw_online_retail
WHERE UnitPrice <= 0
LIMIT 20;

-- Check Duplicate Rows
SELECT InvoiceNo, StockCode, Quantity, CustomerID, COUNT(*) AS duplicate_count
FROM raw_online_retail
GROUP BY InvoiceNo, StockCode, Quantity, CustomerID
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Check Date Range
SELECT MIN(TO_TIMESTAMP(InvoiceDate, 'MM/DD/YYYY HH24:MI')) AS first_order,
MAX(TO_TIMESTAMP(InvoiceDate, 'MM/DD/YYYY HH24:MI')) AS last_order
FROM raw_online_retail;

-- Create a Clean Table
CREATE TABLE clean_online_retail AS
SELECT InvoiceNo, StockCode, Description, Quantity, TO_TIMESTAMP(InvoiceDate, 'MM/DD/YYYY HH24:MI') AS InvoiceDate,
UnitPrice, CustomerID, Country
FROM raw_online_retail;

-- Verify
SELECT *
FROM clean_online_retail
LIMIT 10;

-- Remove Rows with Missing Customer IDs
DELETE FROM clean_online_retail
WHERE CustomerID IS NULL;

-- Check
SELECT COUNT(*)
FROM clean_online_retail
WHERE CustomerID IS NULL;

-- Remove Rows with Missing Product Description
DELETE FROM clean_online_retail
WHERE Description IS NULL;

-- Remove Invalid Prices
DELETE FROM clean_online_retail
WHERE UnitPrice <= 0;

-- Remove Invalid Quantities
DELETE FROM clean_online_retail
WHERE Quantity <= 0;

-- Remove Duplicate Records
DELETE FROM clean_online_retail
WHERE ctid NOT IN ( SELECT MIN(ctid) FROM clean_online_retail
GROUP BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
);

-- Verify the Cleaned Data - Total Records
SELECT COUNT(*) AS total_records
FROM clean_online_retail;

-- Check for NULL Customer IDs
SELECT COUNT(*)
FROM clean_online_retail
WHERE CustomerID IS NULL;

-- Check for Negative Quantity
SELECT COUNT(*)
FROM clean_online_retail
WHERE Quantity <= 0;

-- Check for Invalid Price
SELECT COUNT(*)
FROM clean_online_retail
WHERE UnitPrice <= 0;

-- Check Date Range
SELECT
    MIN(InvoiceDate),
    MAX(InvoiceDate)
FROM clean_online_retail;

-- Calculate Sales Amount
ALTER TABLE clean_online_retail
ADD COLUMN TotalAmount NUMERIC(12,2);

UPDATE clean_online_retail
SET TotalAmount = Quantity * UnitPrice;

-- Verify
SELECT InvoiceNo, Quantity, UnitPrice, TotalAmount
FROM clean_online_retail
LIMIT 10;

-- Normalize the Data
-- Create Customers Table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    country VARCHAR(100)
);

-- Insert Data
INSERT INTO customers (customer_id, country)
SELECT DISTINCT CustomerID, Country
FROM clean_online_retail
ORDER BY CustomerID;

-- Create Products Table
CREATE TABLE products (
    stock_code VARCHAR(20) PRIMARY KEY,
    description TEXT,
    unit_price NUMERIC(10,2)
);

-- Insert Data
INSERT INTO products (stock_code, description, unit_price)
SELECT StockCode, MAX(Description), MAX(UnitPrice)
FROM clean_online_retail
GROUP BY StockCode;

-- Create Orders Table
CREATE TABLE orders ( invoice_no VARCHAR(20) PRIMARY KEY, customer_id INT, invoice_date TIMESTAMP, CONSTRAINT fk_customer
FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Insert Data
INSERT INTO orders (invoice_no, customer_id, invoice_date)
SELECT InvoiceNo, CustomerID, MIN(InvoiceDate)
FROM clean_online_retail
GROUP BY InvoiceNo, CustomerID;

-- Create Order_Items Table
CREATE TABLE order_items ( order_item_id SERIAL PRIMARY KEY, invoice_no VARCHAR(20), stock_code VARCHAR(20),
quantity INT, unit_price NUMERIC(10,2), total_amount NUMERIC(12,2), CONSTRAINT fk_order
FOREIGN KEY (invoice_no) REFERENCES orders(invoice_no),
CONSTRAINT fk_product
FOREIGN KEY (stock_code) REFERENCES products(stock_code)
);

-- Insert Data
INSERT INTO order_items ( invoice_no, stock_code, quantity, unit_price, total_amount )
SELECT InvoiceNo, StockCode, Quantity, UnitPrice, TotalAmount
FROM clean_online_retail;

-- Verify
SELECT COUNT(*) FROM order_items;

-- Business Analysis
-- Total Revenue
SELECT ROUND(SUM(total_amount), 2) AS total_revenue
FROM order_items;

-- Total Orders
SELECT COUNT(*) AS total_orders
FROM orders;

-- Total Customers
SELECT COUNT(*) AS total_customers
FROM customers;

-- Average Order Value
SELECT ROUND(AVG(order_total), 2) AS average_order_value
FROM ( SELECT invoice_no, SUM(total_amount) AS order_total
FROM order_items
GROUP BY invoice_no
) t;

-- Top 10 Customers by Revenue
SELECT c.customer_id, c.country, ROUND(SUM(oi.total_amount), 2) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.invoice_no = oi.invoice_no
GROUP BY c.customer_id, c.country
ORDER BY revenue DESC
LIMIT 10;

-- Top 10 Selling Products
SELECT p.stock_code, p.description, SUM(oi.quantity) AS total_quantity
FROM products p
JOIN order_items oi
ON p.stock_code = oi.stock_code
GROUP BY p.stock_code, p.description
ORDER BY total_quantity DESC
LIMIT 10;

-- Top Products by Revenue
SELECT p.description, ROUND(SUM(oi.total_amount),2) AS revenue
FROM products p
JOIN order_items oi
ON p.stock_code = oi.stock_code
GROUP BY p.description
ORDER BY revenue DESC
LIMIT 10;

-- Revenue by Country
SELECT c.country, ROUND(SUM(oi.total_amount),2) AS revenue
FROM customers c
JOIN orders o
ON c.customer_id=o.customer_id
JOIN order_items oi
ON o.invoice_no=oi.invoice_no
GROUP BY c.country
ORDER BY revenue DESC;

-- Monthly Sales Trend
SELECT DATE_TRUNC('month', invoice_date) AS month, ROUND(SUM(total_amount),2) AS revenue
FROM orders o
JOIN order_items oi
ON o.invoice_no=oi.invoice_no
GROUP BY month
ORDER BY month;

-- Top 5 Countries by Orders
SELECT c.country, COUNT(DISTINCT o.invoice_no) AS total_orders
FROM customers c
JOIN orders o
ON c.customer_id=o.customer_id
GROUP BY c.country
ORDER BY total_orders DESC
LIMIT 5;

-- Customers Spending More Than ₹5000 
WITH customer_sales AS ( SELECT o.customer_id, SUM(oi.total_amount) AS total_sales
FROM orders o
JOIN order_items oi
ON o.invoice_no = oi.invoice_no
GROUP BY o.customer_id
)
SELECT customer_id, ROUND(total_sales, 2) AS total_sales
FROM customer_sales
WHERE total_sales > 5000
ORDER BY total_sales DESC;

-- Average Revenue per Customer
WITH customer_sales AS ( SELECT o.customer_id, SUM(oi.total_amount) AS total_sales
FROM orders o
JOIN order_items oi
ON o.invoice_no = oi.invoice_no
GROUP BY o.customer_id
)
SELECT ROUND(AVG(total_sales), 2) AS avg_customer_revenue
FROM customer_sales;

-- ROW_NUMBER()
SELECT customer_id, invoice_no, invoice_date,
ROW_NUMBER() OVER ( PARTITION BY customer_id ORDER BY invoice_date ) AS order_number
FROM orders;




