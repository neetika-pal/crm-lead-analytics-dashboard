-- CRM Lead Analytics: database and table structure (no data)
-- lead_raw and account_raw hold the raw Salesforce extract as text; opportunity_clean holds cleaned converted-opportunity amounts.
-- The source data was supplied for the ExcelR course and is not included in this repository.
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS crm_full;
USE crm_full;

DROP TABLE IF EXISTS `lead_raw`;
CREATE TABLE `lead_raw` (
  `Lead ID` VARCHAR(18) NOT NULL,
  `Created Date` VARCHAR(25),
  `Lead Source` VARCHAR(60),
  `Status` VARCHAR(40),
  `Status (Simplified)` VARCHAR(40),
  `Industry` VARCHAR(80),
  `Converted` VARCHAR(10),
  `Converted Account ID` VARCHAR(18),
  `Converted Opportunity ID` VARCHAR(18),
  `Lead Score` VARCHAR(20),
  `Pardot Score` VARCHAR(20),
  `Country` VARCHAR(80),
  `State/Province` VARCHAR(80),
  PRIMARY KEY (`Lead ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `account_raw`;
CREATE TABLE `account_raw` (
  `Account ID` VARCHAR(18) NOT NULL,
  `Account Name` VARCHAR(200),
  `Industry` VARCHAR(80),
  `Account Type` VARCHAR(60),
  `Billing Country` VARCHAR(80),
  `Created Date` VARCHAR(25),
  PRIMARY KEY (`Account ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `opportunity_clean`;
CREATE TABLE `opportunity_clean` (
  `Opportunity_ID` VARCHAR(18) NOT NULL,
  `Account_ID` VARCHAR(18),
  `Stage` VARCHAR(60),
  `Stage_Group` VARCHAR(20),
  `Won` TINYINT,
  `Closed` TINYINT,
  `Is_Lost` TINYINT,
  `Amount` DECIMAL(15,2),
  `Expected_Amount` DECIMAL(15,2),
  `Created_Date` DATETIME,
  `Close_Date` DATETIME,
  `Lead_Source` VARCHAR(60),
  `Industry_Clean` VARCHAR(80),
  PRIMARY KEY (`Opportunity_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
