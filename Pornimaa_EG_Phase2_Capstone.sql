use capstone;
-- =====================================================================================
-- 				PHASE 2 - Data Quality Investigation & Analytical Queries 
-- =====================================================================================

-- 			1.Database Structure

--  Answer --> go to navigator pane -->right click on the database"Capstone" 
-- -->click schema inspector --> the information will popup in a new query Tab
-- Or We can use commands like show, describe
show databases;
show tables;

-- =====================================================================================
-- 			2.Tables’ Structure/Column Information

--  Answer --> go to navigator pane -->right click on the database"Capstone" 
-- -->click schema inspector --> the information will popup in a new query Tab
-- You can select the tabs under to explore Tables and columns

-- describe table_name;
describe budgets;
show columns from budgets;

-- =====================================================================================
-- 			3.How many budget categories are there?
-- Things to consider: Do you see any natural division in the categories? 
--  How many are branch based?  How many are corporate wide?
-- Explore the table -- 
select * from budget_categories;
-- Answer/Query
select
	category_group,
    count(*) as category_count
from budget_categories
group by category_group;


-- =====================================================================================
--  		4.How many cost centers are there?
-- Things to consider: How are cost centers related to departments and budgets and branches?
-- Explore the table -- 
select * from cost_centers;
-- Answer 
select count(cost_center_code) as Number_of_cost_Centers 
from cost_centers;

-- =====================================================================================
-- 			5.List all customer transactions over $1,000 and 
-- 			show the transaction ID, customer ID, customer Name, amount, transaction date, and merchant category.

select * from transactions;
SELECT 
        t.customer_id,    t.transaction_id,
    #c.first_name,  c.last_name,
    concat(c.first_name, ' ',   c.last_name) as Customer_name,
       SUM(t.transaction_amount) AS total_amount,
    t.transaction_amount,
    t.merchant_category,
    # create date column (convert string to date)
    STR_TO_DATE(CONCAT(t.year, '-', t.month, '-', t.day), '%Y-%m-%d') 
    AS transaction_date
FROM
    transactions t JOIN customers c 
    on t.customer_id = c.customer_id 
WHERE
    t.transaction_amount > 1000
  GROUP BY t.customer_id, t.transaction_id, c.first_name, c.last_name
 order by t.transaction_amount desc;

-- =====================================================================================
-- 			6.Find the top 10 highest expenditures by amount. Show expense ID, vendor, amount, and fiscal year.

select expense_id, vendor,  fiscal_year, amount
from expenditures
order by amount desc limit 10;

-- =====================================================================================
-- 		7.Calculate the total customer transaction amount and transaction count for each merchant category.

select Merchant_category, count(transaction_id) as 'Transaction count',
sum(transaction_amount) as 'transaction Amount'
from transactions
group by merchant_category;

-- =====================================================================================
-- 8.Calculate the average expenditure amount per branch and the number of expenses per branch.  
-- Sort the results from highest to lowest average expenditure.  
-- Output should include BranchID, BranchName, Number of Expenses, Average Expense Amount.
# Answer
-- Branch name is derived from existing columns(street address +city name as "Branch_Name")
-- concat branch location and state to create branch name

select  e.Branch_ID, count(e.Expense_ID) as Number_of_Expenses, 
CONCAT(b.street_address, ', ', b.city) AS Branch_Name, 
round(avg(e.Amount),2) as Average_Expense_Amount
from expenditures e 
join branches b
on e.branch_Id = b.location_ID
group by e.Branch_ID
order by Average_Expense_Amount desc;

-- =====================================================================================
-- List Expenditure vendors that have more than 5 expenses and a total spend greater than $25,000. 
-- Show vendor, number of expenses, and total spend.

select vendor, count(Expense_ID) as Number_of_Expenses, 
sum(amount) as Total_Spend
from expenditures
group by vendor 
-- condition is passed on the aggregated column hence use "having"
having Number_of_Expenses > 5 and Total_spend > 25000;

-- =====================================================================================
-- 10.List all departments whose 2025 total spending exceeds $100,000. 
-- Output should include:  Department_ID, Fiscal Year, Total spending

select department_id , fiscal_year as 'Fiscal Year', sum(amount) as Total_Spending
from expenditures
group by department_id, fiscal_year
having fiscal_year = 2025 and Total_Spending > 100000;

-- =====================================================================================
-- 11.How many states per region?

select region_id , count(state_code) as Number_of_States
from region_states
group by region_id ;

-- =====================================================================================
--		 12.How many branches per region?

select region_id, count(location_id) as Number_of_Branches
from branches
group by region_id;

-- =====================================================================================
-- 13.How many branches are in the same state as their region's hub city? 

-- use regions[hub city] table and branches table
select  r.region_name,
count(*) as branches_matching_Hub_state  # of rows in each aggregated group by
from branches b join regions r on b.region_id = r.region_id
where b.state_code = trim(substring_index(r.hub_city,',', -1))
-- substring_index is used to split using delimiter to look for split, position
-- Trim is removing extra leading and trailing spaces
group by r.region_id,r.region_name
order by branches_matching_Hub_state,r.region_name;

-- =====================================================================================
-- 14 What is the total expenditure per department?

select d.department_id, d.dept_name, sum(e.amount) as Total_Expenditure 
from departments d join expenditures e
on d.department_id = e.department_id
group by d.department_id ;

-- =====================================================================================
-- 15 Top 5 employees with the longest employment and which branch they work at?

-- HINT: Branch number is not an informative piece of information for your audience
-- There is another “thought” challenge here.  Use your best judgment.

-- To check the stored date format 
SELECT hire_date FROM employees LIMIT 5;
-- convert/cast the date from string and to curdate() format 
-- concat branch location and state to create branch name
SELECT 
    e.full_name AS Employee_Name, 
    CONCAT(b.street_address, ', ', b.city) AS Branch_Name, 
    STR_TO_DATE(e.hire_date, '%m/%d/%Y') AS converted_date,
    DATEDIFF(CURDATE(), STR_TO_DATE(e.hire_date, '%m/%d/%Y')) AS Days_employed
FROM employees e 
-- to avoid null values used left join
LEFT JOIN branches b ON e.home_office = b.location_id 
ORDER BY Days_employed DESC
LIMIT 5;


-- =====================================================================================
--   	16.How many customers per region? Sort from the highest number to the lowest number.

-- use regionstates , regions and customers table

select r. region_name,  
count(c.customer_id) as Total_customers
from  customers c join region_states s
on s.state_code = c.cust_state
-- To pull region name join with regions table
join regions r on s.region_id = r.region_id 
group by r.region_name
order by Total_customers desc;

/* =====================================================================================

17.Compare the total number of loan applications and the total number of approved applications between 
applicants with good credit history and those with no credit history.
 (This requires you to really understand what the actual data is telling you and what the fields mean what)
  */
  
 --  Answer
 --  credit_history column has values 1,0
 --  Therefore 1 --> Good and 0 --> Bad
 SELECT 
    CASE WHEN Credit_History = 1 THEN 'Good Credit History' 
         ELSE 'No Credit History' END AS Credit_Group,
    COUNT(*) AS Total_Applications,
    SUM(CASE WHEN Application_Status = 'Y' THEN 1 ELSE 0 END) AS Approved_Applications
FROM loan_applications
WHERE Credit_History IN (1, 0)
GROUP BY Credit_History
ORDER BY Credit_History DESC;

 
-- =====================================================================================
/* 18. Classify each Customer transaction into a size band using a CASE statement:
Small: < $50
Medium: $50- $499.99
Large: ≥ $500
*/
-- Answer
SELECT 
    CASE 
        WHEN Transaction_amount < 50 THEN 'Small'
        WHEN transaction_amount BETWEEN 50 AND 499.99 THEN 'Medium'
        WHEN transaction_amount >= 500 THEN 'Large'
    END AS Transaction_Size_Band,
    COUNT(*) AS Total_Transactions
FROM transactions
group by transaction_Size_Band
ORDER BY Total_Transactions DESC;


-- =====================================================================================
--		 [Additional Queries]
-- 1.Find Top 10 customers name, id based on the purchase/transaction using the credit card 

-- I want to see top 10 transactions from transactions table using credit card
select * from transactions 
where payment_method ='credit card'
group by transaction_id
order by transaction_amount desc limit 10;

-- Then join the tables with customer name
select concat(c.first_name, ' ',   c.last_name) as Customer_name,
 c.customer_id , t.transaction_amount
from transactions t join customers c
on t.customer_id = c.customer_id
where t.payment_method ='credit card'
group by customer_name, c.customer_id , t.transaction_amount
order by t.transaction_amount desc limit 10;


-- ======================================================================================
-- 2.CASE Statement — Flag transaction risk level
-- Categorize risk level based on transaction amount show highest to lowest transaction amount

select 
    Customer_ID,
    transaction_amount,
    Fraudulent,
    CASE 
        WHEN Fraudulent = 1 AND transaction_amount >= 500 THEN 'High Risk'
        WHEN Fraudulent = 1 AND transaction_amount < 500 THEN 'Medium Risk'
        WHEN Fraudulent = 0 AND transaction_amount >= 500 THEN 'Monitor'
        ELSE 'Low Risk'
    END AS Risk_Level
FROM transactions
ORDER BY Fraudulent DESC, transaction_amount DESC;


-- ======================================================================================
-- 3.Which merchants location have been involved in more than 2 fraudulent transactions, and 
-- how many total transactions did they process?

-- Group by + Having  
SELECT 
    merchant_location,
    COUNT(*) AS Total_Transactions,
    SUM(Fraudulent) AS Fraudulent_Transactions
FROM transactions
GROUP BY Merchant_location
HAVING SUM(Fraudulent) > 2
ORDER BY Fraudulent_Transactions DESC;

-- ======================================================================================
-- 4.Which customer transactions exceed the overall average transaction amount, and what payment method did they use?

SELECT 
    Customer_ID,
    merchant_category,
    transaction_amount,
    Payment_Method
FROM transactions
WHERE transaction_amount > 
    (SELECT AVG(transaction_amount) FROM transactions)
ORDER BY transaction_amount DESC;

-- ======================================================================================
-- 5. How does fraud rate and average transaction amount compare between online and in-store transactions?

SELECT 
    CASE WHEN Is_Online = 1 THEN 'Online'  -- converts 1 to readable label
         ELSE 'In-Store'                    -- converts 0 to readable label
    END AS Purchase_Type,
    COUNT(*) AS Total_Transactions,                              -- counts all rows per group
    ROUND(AVG(transaction_amount), 2) AS Avg_Transaction_Amount, -- average spend, rounded to 2 decimals
    SUM(Fraudulent) AS Total_Fraud,                              -- adds up all fraud cases (1s)
    ROUND(SUM(Fraudulent) / COUNT(*) * 100, 2) AS Fraud_Rate_Percentage -- fraud as % of total
FROM transactions
GROUP BY Is_Online          -- groups results into Online vs In-Store
ORDER BY Fraud_Rate_Percentage DESC;  -- highest fraud rate shown first
