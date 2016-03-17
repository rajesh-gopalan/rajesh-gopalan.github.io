-- This file contains the schema of the data related to the SQL project
-- The following data files are needed: jobs.csv, categories.csv and bids.csv
-- Change 'dataDirPath' to the directory where the data files are located.

\set dataDirPath '/Users/rajeshgopalan/Portfolio/rajesh-gopalan.github.io/projects/sqlProject/'
\set jobsFile :dataDirPath jobs.csv
\set categoriesFile :dataDirPath categories.csv
\set bidsFile :dataDirPath bids.csv

----------------------------------- Definitions ------------------------------------------

-- Job : This is a request for services.
		-- First a job (jID) gets 'posted' (pDate).
		-- Once a client (uID) accepts a proposal (bid) from a provider (pID), that job becomes 'booked' (bDate).  Job area (jArea) indicates the job's area of relevance.
-- Bid: This is an provider's response to a job post.
		-- It includes the price the provider (pID) will charge (revCents) and details if the bid is fixed or hourly (bType).  The bid's proposed time (timeHours) is given.
-- Category: This is a user category.
		-- It includes the type of category (uCat) corresponding to each user (uID).

DROP TABLE IF EXISTS jobs, categories, bids;

CREATE TABLE jobs(
  uID VARCHAR NOT NULL,
  jID VARCHAR,
  pDate DATE,
  bDate DATE,
  jArea VARCHAR,
  PRIMARY KEY(jID)
);

COPY jobs FROM :'jobsFile' CSV HEADER;

CREATE TABLE bids(
  jID VARCHAR,
  pID VARCHAR,
  revCents INT,
  timeHours FLOAT,
  bType VARCHAR
);

COPY bids FROM :'bidsFile' CSV HEADER;

CREATE TABLE categories(
  uID VARCHAR NOT NULL,
  uCat VARCHAR,
  PRIMARY KEY(uID)
);

COPY categories FROM :'categoriesFile' CSV HEADER;
