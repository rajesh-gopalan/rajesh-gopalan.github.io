-- The following postgreSQL queries were run on psql (Version 9.5.1.0) on a MacBook Pro (15-inch, non-retina Mid 2012, 16 GB DDR3 RAM) running OS X El Capitan (Version 10.11.3)

-- Change 'exerciseDirPath' to the directory where the schema SQL file is located.
\set exerciseDirPath '/Users/rajeshgopalan/Portfolio/rajesh-gopalan.github.io/projects/sqlProject/'
\i :exerciseDirPath'loadData.sql'

-- Change 'answerDirPath' to the directory you would like the results to be saved in.
\set answerDirPath :exerciseDirPath 'answers/'
\set answer1_1DirPath :answerDirPath 'kpiQueriesJobs_1.csv'
\set answer1_2DirPath :answerDirPath 'kpiQueriesJobs_2.csv'
\set answer2_1DirPath :answerDirPath 'analysisQueries_jobs+category_1.csv'
\set answer2_2DirPath :answerDirPath 'analysisQueries_jobs+category_2.csv'
\set answer2_3DirPath :answerDirPath 'analysisQueries_jobs+category_3.csv'
\set answer2_4DirPath :answerDirPath 'analysisQueries_jobs+category_4.csv'
\set answer3_1DirPath :answerDirPath 'advancedSQLQueries_bid_1.csv'
\set answer3_2DirPath :answerDirPath 'advancedSQLQueries_bid_2.csv'
\set answer3_3DirPath :answerDirPath 'advancedSQLQueries_bid_3.csv'

-------------------------------- KPI Queries (jobs)---------------------------------------

-- 1)	How many jobs were posted, and how many jobs were booked each month?

-- Answer:
-- Create sub-queries to define two new relations P1 and B1:
		-- P1 provides a count of the number of jobs posted, grouped by month.
		-- B1 provides a count of the number of jobs booked, grouped by month.
-- Two instances of 'P1 inner join B1' (using month as the key) are utilized.
		-- The first instance provides the count of posted and booked jobs grouped by month.
		-- The second instance provides the column total for posted and booked jobs).

COPY (
	WITH P1 AS (
		SELECT TO_CHAR(jobs.pDate, 'FMMonth') AS postedMonth,
					 COUNT(jobs.jID) AS numJobsPosted
		FROM jobs
		WHERE jobs.pDate IS NOT NULL
		GROUP BY DATE_PART('month', jobs.pDate),
						 TO_CHAR(jobs.pDate, 'FMMonth')
		ORDER BY DATE_PART('month', jobs.pDate) ASC
	), B1 AS (
		SELECT TO_CHAR(jobs.bDate, 'FMMonth') AS bookedMonth,
					 COUNT(jobs.jID) AS numJobsBooked
		FROM jobs
		WHERE jobs.bDate IS NOT NULL
		GROUP BY DATE_PART('month', jobs.bDate),
						 TO_CHAR(jobs.bDate, 'FMMonth')
		ORDER BY DATE_PART('month', jobs.bDate) ASC
	)
	(
		SELECT B1.bookedMonth AS "Month",
					 P1.numJobsPosted AS "Jobs Posted",
					 B1.numJobsBooked AS "Jobs Booked"
		FROM P1, B1
		WHERE P1.postedMonth = B1.bookedMonth
	)
	UNION ALL
	(
		SELECT 'Total',
					 SUM(P1.numJobsPosted),
					 SUM(B1.numJobsBooked)
		FROM P1, B1
		WHERE P1.postedMonth = B1.bookedMonth
	)
) TO :'answer1_1DirPath' WITH CSV HEADER;

-- 2)	How many new customers each month, versus how many repeat customers each month?
-- A new customer booked their first transaction this month
-- A repeat customer had booked their first transaction in a previous month?
-- A customer can only be counted once per month.

-- Answer:
-- Create a new relation that gives customer IDs and Non-NULL booking dates.
-- For new customers:
	-- Compare the customer ID from an existing month of booking with previous months of booking.
	-- If there are no matching customer IDs in the previous months of booking, then that customer ID is a new customer.  [A caveat is that all customers in the first month of the given data set are considered new customers.]
	-- Filter out the duplicates of customer IDs.
	-- Count the number of customer IDs to get new customers each month.
-- For repeat customers:
	-- Compare the customer ID from an existing month of booking with future months of booking.
	-- If there are matching customer IDs in the future months of booking, then that customer ID is a repeat customer.
	-- Filter out the duplicates of customer IDs.
	-- Count the number of customer IDs to get repeat customers each month.

COPY (
	WITH B AS (
		SELECT jobs.uID,
					 jobs.bDate
		FROM jobs
		WHERE jobs.bDate IS NOT NULL
	)
	SELECT V1.monthVal as "Month",
				 V1.new_customers AS "New customers",
				 V2.repeat_customers AS "Repeat customers"
	FROM (
		SELECT TO_CHAR(B1.bDate, 'FMMonth') AS monthVal,
					 COUNT(DISTINCT B1.uID) AS new_customers
		FROM B B1
		WHERE NOT EXISTS(
			SELECT B2.uID
			FROM B B2
			WHERE B1.uID = B2.uID AND
						DATE_PART('month', B1.bDate) > DATE_PART('month', B2.bDate)
		)
		GROUP BY DATE_PART('month', B1.bDate),
						 TO_CHAR(B1.bDate, 'FMMonth')
		ORDER BY DATE_PART('month', B1.bDate) ASC
	) AS V1 LEFT JOIN (
		SELECT TO_CHAR(B1.bDate, 'FMMonth') AS monthVal,
					 COUNT(DISTINCT B1.uID) AS repeat_customers
		FROM B B1
		WHERE EXISTS(
			SELECT B2.uID
			FROM B B2
			WHERE B1.uID = B2.uID AND
						DATE_PART('month', B1.bDate) > DATE_PART('month', B2.bDate)
		)
		GROUP BY DATE_PART('month', B1.bDate),
						 TO_CHAR(B1.bDate, 'FMMonth')
		ORDER BY DATE_PART('month', B1.bDate) ASC
	) AS V2
	ON V1.monthVal = V2.monthVal
) TO :'answer1_2DirPath' WITH CSV HEADER;

---------------------- Analysis Queries (jobs + categories)----------------------------

-- 1)	Out of the jobs posted each month, how many of them are currently booked?  How many of them were booked within 5 days of being posted?

-- Answer:
-- Create a new relation that gives job IDs, posted dates and Non-NULL booking dates.
-- Then, count the number of jobs that in that relation, grouped by posting month, to obtain the total number of posted jobs that are currently booked in that month.
-- To get the number of jobs that were booked within five days of being posted, check for a difference of five days between the job posting date and the job booking date, in the newly created relation.
-- PS: The format functions are for cosmetic purposes, and hence useful only if the result is to be displayed in a terminal window.

COPY (
	SELECT format('%9s', A1.monthVal) AS "Month",
				 format('%4s', A1.curr_postedJobs) AS "Posted",
				 format('%4s', A2.currJobs) AS "Booked",
				 format('%8s', ROUND((100.0 * A2.currJobs / A1.curr_postedJobs), 2) || ' %') AS "% Booked",
				 format('%8s', A2.jobs_5d) AS "Booked (5-day)",
				 format('%12s', ROUND((100.0 * A2.jobs_5d / A1.curr_postedJobs), 2) || ' %') AS "% Booked (5-day)"
	FROM (
		SELECT TO_CHAR(jobs.pDate, 'FMMonth') AS monthVal,
					 COUNT(jID) AS curr_postedJobs
		FROM jobs
		GROUP BY DATE_PART('month', jobs.pDate),
						 TO_CHAR(jobs.pDate, 'FMMonth')
		ORDER BY DATE_PART('month', jobs.pDate) ASC
	) AS A1 JOIN (
		WITH B AS (
			SELECT jobs.jID,
						 jobs.pDate,
						 jobs.bDate
			FROM jobs
			WHERE jobs.bDate IS NOT NULL
		)
		SELECT C1.monthVal,
					 C1.currJobs,
					 C2.jobs_5d
		FROM (
			SELECT TO_CHAR(B.pDate, 'FMMonth') AS monthVal,
						 COUNT(B.jID) AS currJobs
			FROM B
			GROUP BY DATE_PART('month', B.pDate),
							 TO_CHAR(B.pDate, 'FMMonth')
			ORDER BY DATE_PART('month', B.pDate) ASC
		) AS C1 JOIN (
			SELECT TO_CHAR(B.pDate, 'FMMonth') AS monthVal,
						 COUNT(B.jID) AS jobs_5d
			FROM B
			WHERE B.bDate - B.pDate <= 5
			GROUP BY DATE_PART('month', B.pDate),
							 TO_CHAR(B.pDate, 'FMMonth')
			ORDER BY DATE_PART('month', B.pDate) ASC
		) AS C2
		ON C1.monthVal = C2.monthVal
	) AS A2
	ON A1.monthVal = A2.monthVal
) TO :'answer2_1DirPath' WITH CSV HEADER;

-- 2)	Which job area has the best booking rate?

-- Answer:
-- Create a new relation that gives job areas, posted Jobs and booked jobs.
-- Then, count the number of posted and booked jobs in that relation, grouped by job area.
-- To get the booking rate, divide the number of booked jobs by the number of posted jobs, for each job area, sorted by descending order of booking rate.

COPY (
	WITH A1 AS (
		SELECT B1.jArea,
					 B1.pJobs
		FROM (
			SELECT jobs.jArea,
						 COUNT(jobs.jID) AS pJobs
			FROM jobs
			GROUP BY jobs.jArea
		) AS B1
		ORDER BY B1.pJobs DESC
	), A2 AS (
		SELECT B1.jArea,
					 B1.bJobs
		FROM (
			SELECT jobs.jArea,
						 COUNT(jobs.jID) AS bJobs
			FROM jobs
			WHERE jobs.bDate IS NOT NULL
			GROUP BY jobs.jArea
		) AS B1
		ORDER BY B1.bJobs DESC
	)
	(
		SELECT A1.jArea as "Job Area",
					 format('%7s', A1.pJobs) AS "Posted Jobs",
					 format('%7s', A2.bJobs) AS "Booked Jobs",
					 format('%10s', ROUND((100.0 * A2.bJobs / A1.pJobs), 2) || ' %') AS "Booking Rate"
		FROM A1 LEFT JOIN A2
		ON A1.jArea = A2.jArea
		ORDER BY ROUND((100.0 * A2.bJobs / A1.pJobs), 2) DESC NULLS LAST,
						 A1.pJobs,
						 A2.bJobs,
						 A1.jArea
	)
	UNION ALL
	(
		SELECT format('%24s', 'Total'),
					 format('%7s', SUM(A1.pJobs)),
					 format('%7s', SUM(A2.bJobs)),
					 format('%10s', ROUND((100.0 * SUM(A2.bJobs) / SUM(A1.pJobs)), 2) || ' %')
		FROM A1 LEFT JOIN A2
		ON A1.jArea = A2.jArea
	)
) TO :'answer2_2DirPath' WITH CSV HEADER;

-- 3)	Understanding the channel users come from is extremely important.  Using the categories dataset, which uCat (channel) has the best booking rate?

-- Answer:
-- The answer to the previous question has a structure similar to the answer that is required for this question.
  -- So, create a new relation that gives job IDs, posted jobs, booked jobs and categories by joining jobs and categories.  Create two other relations that provide a count of posted jobs and booked jobs, respectively, grouped by categories.
-- To get the booking rate, divide the number of booked jobs by the number of posted jobs, for each of the categories, sorted by descending order of booking rate.

COPY (
	WITH U1 AS (
			SELECT jobs.jID,
						 jobs.pDate,
						 jobs.bDate,
						 categories.uCat
			FROM jobs JOIN categories
			ON jobs.uID = categories.uID
	), A1 AS (
		SELECT B1.uCat,
					 B1.pJobs
		FROM (
			SELECT U1.uCat,
						 COUNT(U1.jID) AS pJobs
			FROM U1
			GROUP BY U1.uCat
		) AS B1
		ORDER BY B1.pJobs DESC
	), A2 AS (
		SELECT B1.uCat,
					 B1.bJobs
		FROM (
			SELECT U1.uCat,
						 COUNT(U1.jID) AS bJobs
			FROM U1
			WHERE U1.bDate IS NOT NULL
			GROUP BY U1.uCat
		) AS B1
		ORDER BY B1.bJobs DESC
	)
	(
		SELECT A1.uCat as "User Category",
					 format('%7s', A1.pJobs) AS "Posted Jobs",
					 format('%7s', A2.bJobs) AS "Booked Jobs",
					 format('%10s', ROUND((100.0 * A2.bJobs / A1.pJobs), 2) || ' %') AS "Booking Rate"
		FROM A1 LEFT JOIN A2
		ON A1.uCat = A2.uCat
		ORDER BY ROUND((100.0 * A2.bJobs / A1.pJobs), 2) DESC NULLS LAST,
						 A1.pJobs,
						 A2.bJobs,
						 A1.uCat
	)
	UNION ALL
	(
		SELECT format('%24s', 'Total'),
					 format('%7s', SUM(A1.pJobs)),
					 format('%7s', SUM(A2.bJobs)),
					 format('%10s', ROUND((100.0 * SUM(A2.bJobs) / SUM(A1.pJobs)), 2) || ' %')
		FROM A1 LEFT JOIN A2
		ON A1.uCat = A2.uCat
	)
) TO :'answer2_3DirPath' WITH CSV HEADER;

-- 4)	How many users booked only 1 job?

-- Answer:
-- Compare the uID's in one instance of the jobs relation, with those in another instance, and filter out the uID's that are appear in at least one other date.

COPY (
	SELECT format('%13s', COUNT(J1.uID)) AS "Users booking only 1 job"
	FROM jobs J1
	WHERE NOT EXISTS (
		SELECT J2.uID
		FROM jobs J2
		WHERE J1.uID = J2.uID AND
					J1.bDate <> J2.bDate
	) AND
	J1.bDate IS NOT NULL
) TO :'answer2_4DirPath' WITH CSV HEADER;

---------------------------- Advanced SQL Queries (bids)----------------------------------

-- 1)	For every job determine the number of bids, and the average client payment.

-- Answer:
-- From the bids relation, count the number of jID's and the average of the client payment, both grouped by jID's.

COPY (
	SELECT bids.jID AS "Job ID",
				 COUNT(bids.jID) AS "Num bids",
				 format('%10s', '$' || ROUND(AVG(bids.revCents / 100.0), 2)) AS "Avg. Payment"
	FROM bids
	GROUP BY bids.jID
	ORDER BY AVG(bids.revCents) DESC
) TO :'answer3_1DirPath' WITH CSV HEADER;

-- 2)	For every job determine the most expensive bid, and who the provider was for that bid.

-- Answer:
-- From the bids relation, create a new relation that contains the maximum bid for each jID.
-- Join the new relation with the bids relation and determine the pID corresponding to each maximum bid.  [Caveat: There could be more than one maximum bid for a jID.]

COPY (
	SELECT B1.jID AS "Job ID",
				 format('%10s', '$' || ROUND((B1.max_bid / 100.0), 2) )AS "Max Bid",
				 B2.pID as "Provider ID"
	FROM (
		SELECT bids.jID,
					 MAX(bids.revCents) AS max_bid
		FROM bids
		GROUP BY bids.jID
	) AS B1 JOIN bids B2
	ON B1.jID = B2.jID AND
		 B1.max_bid = B2.revCents
	ORDER BY B1.jID
) TO :'answer3_2DirPath' WITH CSV HEADER;

-- 3)	Create a histogram showing the number of bids by job.  For example how many jobs have 1 bid, 2 bids, 3 bids?

-- Answer:
-- From the bids relation, create a new relation that contains a bin, i.e. a count of the jID's for each bid.
-- In that new relation, count the number of jID's for each of the newly created bins.

COPY (
	SELECT format('%3s bid(s)', B2.bid_count) AS "Bid bin number",
				 format('%5s', COUNT(B2.jID)) AS "Num. Jobs"
	FROM (
		SELECT B1.jID,
					 COUNT(B1.jID) AS bid_count
		FROM bids B1
		GROUP BY B1.jID
	) AS B2
	GROUP BY B2.bid_count
	ORDER BY B2.bid_count
) TO :'answer3_3DirPath' WITH CSV HEADER;
