/* =====================================================================
   Pornimaa's Banking Database Build Script
   - Creates database + tables + relationships + constraints
   - Loads CSV files from the MySQL Server "Uploads" directory
   - Uses small staging tables to clean messy CSV column names
   ===================================================================== */

-- ------------------------------------------------------------
-- 0) Reference Tables
-- ------------------------------------------------------------
/* 
  Tip for followers:
  - "DROP DATABASE" deletes everything in that database.
  - Run this script only if you’re okay rebuilding from scratch.
*/
-- DROP DATABASE IF EXISTS banking;
-- Drop DATABASE if exists Capstone;
CREATE DATABASE Capstone
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE Capstone;
-- Recommended: make sure FK checks are enforced during normal use
SET sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET time_zone = '-06:00';


/* =====================================================================
   1) DIMENSION TABLES (Reference / lookup tables)
   ===================================================================== */

-- ------------------------------------------------------------
-- 1.1 Regions
-- Source file: Regions.csv
-- ------------------------------------------------------------
CREATE TABLE regions (
  region_id        CHAR(3)      NOT NULL,              -- e.g., R01
  region_name      VARCHAR(100) NOT NULL,              -- e.g., "Midwest"
  hub_city         VARCHAR(100) NOT NULL,              -- e.g., "Chicago"
  CONSTRAINT pk_regions PRIMARY KEY (region_id),
  CONSTRAINT uq_regions_name UNIQUE (region_name)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 1.2 Region ↔ State mapping
-- Source file: RegionsStates.csv
-- ------------------------------------------------------------
CREATE TABLE region_states (
  state_code  CHAR(2) NOT NULL,     -- e.g., IL
  region_id   CHAR(3) NOT NULL,     -- must exist in regions
  CONSTRAINT pk_region_states PRIMARY KEY (state_code),
  CONSTRAINT fk_region_states_region
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 1.3 Branches
-- Source file: Branches.csv
-- Notes:
--  - CSV uses "Location_id" as the branch code (e.g., B001).
-- ------------------------------------------------------------
CREATE TABLE branches (
  location_id             CHAR(7)      NOT NULL,  -- CSV: HomeOffice (e.g., B001)
  street_address          VARCHAR(150) NOT NULL,
  city                    VARCHAR(80)  NOT NULL,
  state_code              CHAR(2)      NOT NULL,
  zip_code                CHAR(10)     NOT NULL,
  phone                   VARCHAR(25)  NULL,
  fax                     VARCHAR(25)  NULL,
  date_opened             VARCHAR(10)  NULL,      -- CSV is text like 2/6/2001 (no cleaning)
  branch_manager_employee_id INT  	NULL,   -- may be blank/NaN in CSV
  region_id               CHAR(3)      NOT NULL,

  CONSTRAINT pk_branches PRIMARY KEY (location_id),

  -- Enforce valid region
  CONSTRAINT fk_branches_region
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  -- Enforce state exists in region_states (simple state validity)
  CONSTRAINT fk_branches_state
    FOREIGN KEY (state_code) REFERENCES region_states(state_code)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  INDEX idx_branches_location_id (location_id)
) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 1.4 Departments
-- Source file: Departments.csv
-- ------------------------------------------------------------
CREATE TABLE departments (
  department_id                   CHAR(4)       NOT NULL,  -- D001...
  dept_name                 VARCHAR(120)  NOT NULL,
  department_manager_employee_id  INT          NOT NULL,  -- references employees later

  CONSTRAINT pk_departments PRIMARY KEY (department_id),
  CONSTRAINT uq_departments_name UNIQUE (dept_name)
) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 1.5 Employees
-- Source file: Employees.csv
-- Notes:
--  - CSV column name includes a space: "Hire Date"
-- ------------------------------------------------------------
CREATE TABLE employees (
  employee_id   INT NOT NULL,
  full_name     VARCHAR(120) NOT NULL,
  employee_type VARCHAR(40)  NOT NULL,
  job_title     VARCHAR(120) NOT NULL,

  department_id CHAR(4)      NOT NULL,
  hire_date     VARCHAR(20)  NULL,      -- no cleaning
  home_office    CHAR(7)        NOT NULL,  -- HomeOffice/branc_id

  CONSTRAINT pk_employees PRIMARY KEY (employee_id),

  CONSTRAINT fk_employees_department
    FOREIGN KEY (department_id)
    REFERENCES departments(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_employees_branch
    FOREIGN KEY (home_office)
    REFERENCES branches(location_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;


-- /* Add circular manager constraint AFTER employees exist */
-- ALTER TABLE departments
--   ADD CONSTRAINT fk_departments_manager
--   FOREIGN KEY (department_manager_employee_id)
--   REFERENCES employees(employee_id)
--   ON UPDATE CASCADE
--   ON DELETE RESTRICT;

-- ALTER TABLE branches
--   ADD CONSTRAINT fk_branches_manager
--   FOREIGN KEY (branch_manager_employee_id)
--   REFERENCES employees(employee_id)
--   ON UPDATE CASCADE
--   ON DELETE SET NULL;



-- ------------------------------------------------------------
-- 1.6 Cost Centers
-- Source file: CostCenters.csv
-- ------------------------------------------------------------
CREATE TABLE cost_centers (
  cost_center_code  VARCHAR(20)  NOT NULL,   -- e.g., CC-B001
  cost_center_name  VARCHAR(140) NOT NULL,
  cost_center_type  VARCHAR(30)  NOT NULL,   -- e.g., "Branch", "HQ"
  department_id     CHAR(4)      NOT NULL,
  branch_id         CHAR(7)      NULL,       -- branch cost centers have a branch, HQ might be NULL

  CONSTRAINT pk_cost_centers PRIMARY KEY (cost_center_code),

  CONSTRAINT fk_cost_centers_department
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_cost_centers_branch
    FOREIGN KEY (branch_id) REFERENCES branches(location_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;




-- ------------------------------------------------------------
-- 1.7 Budget Categories
-- Source file: BudgetCategories.csv
-- ------------------------------------------------------------
CREATE TABLE budget_categories (
  category_id       CHAR(4)       NOT NULL,  -- C001...
  category_name     VARCHAR(140)  NOT NULL,
  category_group    VARCHAR(80)   NOT NULL,
  gl_account_code   INT           NOT NULL,
  usage_rule        VARCHAR(255)  NULL,

  CONSTRAINT pk_budget_categories PRIMARY KEY (category_id),
  CONSTRAINT uq_budget_categories_name UNIQUE (category_name)
) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 1.8 Customers
-- Source file: customers.csv
-- Notes:
--  - CSV headers are messy (spaces, punctuation).
--  - We stage raw columns then insert into a clean table.
-- ------------------------------------------------------------
CREATE TABLE customers (
  first_name      VARCHAR(60)   NOT NULL,
  last_name       VARCHAR(80)   NOT NULL,
  suffix          VARCHAR(10)   NULL,
  social             CHAR(9)       NULL,       -- stored as digits only (best practice: treat as sensitive)
  credit_card_no__customer_id  VARCHAR(25)        NULL,       -- 16-digit fits in BIGINT
  house			   BIGINT	NULL,
  street_name     VARCHAR(120)  NULL,
  cust_city            VARCHAR(80)   NULL,
  cust_state      CHAR(2)       NULL,
  country         VARCHAR(80)   NULL,
  zip_code        VARCHAR(10)   NULL,
  phone           VARCHAR(25)   NULL,
  customer_id     CHAR(5)       NOT NULL,   -- C0001...

  CONSTRAINT pk_customers PRIMARY KEY (customer_id),
  CONSTRAINT uq_customers_credit_card UNIQUE (credit_card_no__customer_id),
  INDEX idx_customers_state (cust_state)
) ENGINE=InnoDB;


/* =====================================================================
   2) FACT TABLES (Transactional / event tables)
   ===================================================================== */

-- ------------------------------------------------------------
-- 2.1 Budgets (annual budget amounts)
-- Source file: Budgets.csv
-- ------------------------------------------------------------
CREATE TABLE budgets (
  budget_id        VARCHAR(20) NOT NULL,  -- BG0000123...
  fiscal_year      YEAR        NOT NULL,
  cost_center_code VARCHAR(20) NOT NULL,
  category_id      CHAR(4)     NOT NULL,
  annual_budget    DECIMAL(12,2) NOT NULL,

  CONSTRAINT pk_budgets PRIMARY KEY (budget_id),

  CONSTRAINT fk_budgets_cost_center
    FOREIGN KEY (cost_center_code) REFERENCES cost_centers(cost_center_code)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_budgets_category
    FOREIGN KEY (category_id) REFERENCES budget_categories(category_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 2.2 Expenditures (spend against budgets)
-- Source file: Expenditures.csv
-- ------------------------------------------------------------
CREATE TABLE expenditures (
  expense_id           VARCHAR(20)   NOT NULL,
  expense_date         VARCHAR(20)   NOT NULL,
  fiscal_year          YEAR          NOT NULL,
  fiscal_month         VARCHAR(20)    NOT NULL,        -- 2024-01
  cost_center_code     VARCHAR(20)   NOT NULL,
  department_id        CHAR(4)       NOT NULL,
  branch_id         CHAR(7)        NOT NULL,
  category_id          CHAR(4)       NOT NULL,
  vendor               VARCHAR(140)  NOT NULL,
  invoice_number       VARCHAR(60)   NULL,
  description          VARCHAR(255)  NULL,
  amount               DECIMAL(12,2) NOT NULL,

  approval_status      VARCHAR(30)   NOT NULL,
  requester_employee_id INT         NOT NULL,
  approver_employee_id  INT         NULL,

  payment_status       VARCHAR(30)   NOT NULL,
  approved_date        VARCHAR(20)   NULL,
  payment_date         VARCHAR(20)   NULL,
  delay_reason         VARCHAR(255)  NULL,

  CONSTRAINT pk_expenditures PRIMARY KEY (expense_id),

  CONSTRAINT fk_expenditures_cost_center
    FOREIGN KEY (cost_center_code) REFERENCES cost_centers(cost_center_code)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_expenditures_department
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_expenditures_category
    FOREIGN KEY (category_id) REFERENCES budget_categories(category_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_expenditures_requester
    FOREIGN KEY (requester_employee_id) REFERENCES employees(employee_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_expenditures_approver
    FOREIGN KEY (approver_employee_id) REFERENCES employees(employee_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,

  INDEX idx_expenditures_fy (fiscal_year),
  INDEX idx_expenditures_vendor (vendor),
  INDEX idx_expenditures_cc_cat (cost_center_code, category_id)
) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 2.3 Customer Transactions
-- Source file: transactions.csv
-- Notes:
--  - CSV stores date as DAY/MONTH/YEAR columns + a Time column.
--  - CSV includes redundant mapping columns; we only keep clean fields.
-- ------------------------------------------------------------
CREATE TABLE transactions (
  transaction_id     INT UNSIGNED NOT NULL,

  day   TINYINT UNSIGNED NOT NULL,
  month TINYINT UNSIGNED NOT NULL,
  year  SMALLINT UNSIGNED NOT NULL,
 
  credit_card_no__customer_id  VARCHAR(25)  NOT NULL,
  customer_id        CHAR(5) NOT NULL,
  
  transaction_type   VARCHAR(40) NOT NULL,
  transaction_amount DECIMAL(12,2) NOT NULL,

  merchant_category  VARCHAR(80) NULL,
  merchant_location  VARCHAR(120) NULL,

  payment_method     VARCHAR(40) NULL,
  is_online          TINYINT(1) NOT NULL,
  fraudulent         TINYINT(1) NOT NULL,

  time   CHAR(8) NULL,

  CONSTRAINT pk_transactions PRIMARY KEY (transaction_id),

  CONSTRAINT fk_transactions_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers(customer_id)
 ) ENGINE=InnoDB;


-- ------------------------------------------------------------
-- 2.4 Loan Applications
-- Source file: loanapplications.csv
-- ------------------------------------------------------------
CREATE TABLE loan_applications (
  application_id      VARCHAR(20)  NOT NULL,
  gender              VARCHAR(20)  NULL,
  married             VARCHAR(10)  NULL,
  dependents          VARCHAR(10)  NULL,
  education           VARCHAR(30)  NULL,
  self_employed       VARCHAR(10)  NULL,
  credit_history      TINYINT      NULL,      -- represents whether or not there is record of good credit
  property_area       VARCHAR(30)  NULL,
  income              VARCHAR(20) NULL,
  application_status  VARCHAR(30)  NOT NULL,
  customer_id         CHAR(5)      NOT NULL,

  CONSTRAINT pk_loan_applications PRIMARY KEY (application_id),

  CONSTRAINT fk_loan_applications_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

/* =====================================================================
   4) LOAD DATA (from MySQL Server Uploads directory)
   IMPORTANT:
   - These paths are read by the MySQL SERVER, not your local machine.
   - Your files should exist in:
     C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/
   ===================================================================== */

-- Helpful option if your CSVs use Windows line endings
-- SET SESSION local_infile = 1;

-- 1) regions (Regions.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Regions.csv'
INTO TABLE regions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(region_id, region_name, hub_city);
-- 2) region_states (RegionsStates.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/RegionsStates.csv'
INTO TABLE region_states
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(state_code, region_id);

-- 3) branches (Branches.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Branches.csv'
INTO TABLE branches
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(location_id, street_address, city, state_code, zip_code, phone, fax, date_opened, branch_manager_employee_id, region_id);

-- 4) departments (Departments.csv)
-- NOTE: If departments has an FK to employees (manager), load may require adding that FK AFTER employees are loaded.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Departments.csv'
INTO TABLE departments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(department_id, dept_name, department_manager_employee_id);

-- 5) employees (Employees.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Employees.csv'
INTO TABLE employees
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(employee_id, full_name, employee_type, job_title, department_id, hire_date, home_office);

-- 6) customers (customers.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(first_name, last_name, suffix, social, credit_card_no__customer_id, house, street_name,
 cust_city, cust_state, country, zip_code, phone, customer_id);

-- 7) budget_categories (BudgetCategories.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/BudgetCategories.csv'
INTO TABLE budget_categories
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(category_id, category_name, category_group, gl_account_code, usage_rule);

-- 8) cost_centers (CostCenters.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/CostCenters.csv'
INTO TABLE cost_centers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(cost_center_code, cost_center_name, cost_center_type, department_id, branch_id);

-- 9) budgets (Budgets.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Budgets.csv'
INTO TABLE budgets
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(budget_id, fiscal_year, cost_center_code, category_id, annual_budget);

-- 10) expenditures (Expenditures.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Expenditures.csv'
INTO TABLE expenditures
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(expense_id, expense_date, fiscal_year, fiscal_month, cost_center_code, department_id, branch_id, category_id,
 vendor, invoice_number, description, amount, approval_status, requester_employee_id, approver_employee_id,
 payment_status, approved_date, payment_date, delay_reason);

-- 11) transactions (transactions.csv)
-- This CSV has more columns than the simplified table, so we discard the extra mapping columns into variables.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  transaction_id,             -- TRANSACTION_ID
  day,                        -- DAY
  month,                      -- MONTH
  year,                       -- YEAR
  credit_card_no__customer_id,  -- CREDIT_CARD_NO--customer_id 
  customer_id,                -- customer_id
  transaction_type,           -- TRANSACTION_TYPE
  transaction_amount,         -- Transaction_Amount
  merchant_category,          -- Merchant_Category
  merchant_location,          -- Merchant_Location
  payment_method,             -- Payment_Method
  is_online,                  -- Is_Online
  fraudulent,                 -- Fraudulent
 time            -- Time
);

-- 12) loan_applications (loanapplications.csv)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/loanapplications.csv'
INTO TABLE loan_applications
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(application_id, gender, married, dependents, education, self_employed, credit_history,
 property_area, income, application_status, customer_id);



-- Quick sanity check.... Screenshot this to make sure that your numbers match your DSU teams numbers.  
SELECT 'regions'            AS table_name, COUNT(*) AS row_count FROM regions
UNION ALL
SELECT 'region_states',     COUNT(*) FROM region_states
UNION ALL
SELECT 'branches',          COUNT(*) FROM branches
UNION ALL
SELECT 'departments',       COUNT(*) FROM departments
UNION ALL
SELECT 'employees',         COUNT(*) FROM employees
UNION ALL
SELECT 'customers',         COUNT(*) FROM customers
UNION ALL
SELECT 'budget_categories', COUNT(*) FROM budget_categories
UNION ALL
SELECT 'cost_centers',      COUNT(*) FROM cost_centers
UNION ALL
SELECT 'budgets',           COUNT(*) FROM budgets
UNION ALL
SELECT 'expenditures',      COUNT(*) FROM expenditures
UNION ALL
SELECT 'transactions',      COUNT(*) FROM transactions
UNION ALL
SELECT 'loan_applications', COUNT(*) FROM loan_applications;


