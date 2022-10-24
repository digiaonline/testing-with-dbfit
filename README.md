# Testing with DbFit

Author: jani.hurskainen@digia.com

[DbFit](https://dbfit.github.io/dbfit/) is a database testing framework that supports easy test-driven development of your database code. 

You will find here

* a brief introduction what DbFit is
* what kind of systems are a good fit for DbFit testing
* a complete working example how actual DbFit tests look like

The working example is simple but it contains all the elementary building blocks so it reflects the actual tests of a real production code I have written succesfully several times.

## What is DbFit

DbFit is a database testing tool built on [FitNesse](http://fitnesse.org/) [acceptance testing](https://en.wikipedia.org/wiki/Acceptance_testing) framework so everything you know about FitNesse applies also to DbFit. DbFit brings in database features like queries, inserts, updates and running stored procedures in (mostly) database agnostic manner.

FitNesse is a bit weird (but in a good way) as it is essentially a wiki where most of the pages are also executable tests. The FitNesse mindset is that you have human readable specifications that can be used to verify the correctness of the system under test (SUT).

FitNesse is a stand-alone Java web application. You start it in you local development host and connect to FitNesse with a browser. FitNesse provides a wiki-interface where you can write and execute tests. The server has also REST interface that can be used to control the server from command line e.g. for running tests automatically part of continuous integration.

FitNesse tests (or wiki pages) are human readable and version control friendly text files. In fact I most often modify the pages with my [favorite text editor](https://www.gnu.org/software/emacs/).

The DbFit tests are based on FitNesse table syntax that looks like this:
```
!|Insert|input|
|party    |amount1|amount2|amount3|amount4|id?                 |
|ACME     |     0|      30|      0|      0|>>acme_input_id     |
|FOOBARINC|     0|      40|      0|      0|>>foobarinc_input_id|
|MEGACORP |     0|      50|      0|      0|>>megacorp_input_id |
```

That essentially executes the following SQL under the hood:
```
insert into input(party, amount1, amount2, amount3, amount4) values('ACME', 0, 30, 0, 0);
insert into input(party, amount1, amount2, amount3, amount4) values('FOOBARINC', 0, 40, 0, 0);
insert into input(party, amount1, amount2, amount3, amount4) values('MEGACORP', 0, 50, 0, 0);
```

and returns the database auto-generated primary key (`id`-column) to the `acme_input_id`, `foobarinc_input_id` and `megacorp_input_id` variables that could be used later in the test.

Note that DbFit documentation covers only database features so for everything else one have to refer FitNesse documentation. That's a bit akward and confusing in the beginning but is not a deal breaker as the usage is actually rather simple. Anyway here is the complete list of the relevant documentation:

* DbFit [Getting Started](https://dbfit.github.io/dbfit/docs/getting-started.html)
* How to resolve [Oracle connectivity issue](https://stackoverflow.com/q/74040376/272735) not covered in Getting Started (we're using Oracle in this example)
* DbFit [Reference](https://dbfit.github.io/dbfit/docs/reference.html)
* FitNesse [User Guide](http://fitnesse.org/FitNesse.FullReferenceGuide)

Remember everything mentioned above about FitNesse also applies to DbFit. You can think DbFit as a tailored version of FitNesse.

## Systems Suitable for DbFit Tests

Generally DbFit works fine in cases where you:

* insert data into database table(s)
* run database code (stored procedures)
* verify the state of database table(s)

I have applied DbFit testing with great success in several cases that are essentially a variations of the traditional [ESB](https://en.wikipedia.org/wiki/Enterprise_service_bus) [VETO pattern](https://learn.microsoft.com/en-us/biztalk/esb-toolkit/service-mediation-patterns) described in the diagram below. I'm not saying this should be your target architecture in 2020's but you'll run into this when maintaining legacy (integration) systems.

In the diagram below:

* external data producer (not visible in the diagram) inserts data into `Input data`
* `Execution trigger` starts `Code` that reads new data from `Input data`
* `Configuration` instructs how `Code` should process the data
* processed data is inserted into `Output data` by `Code`
* external data consumer (not visible in the diagram) reads data from `Output data` and processes it for $$$

`Code` and `Configuration` boxes comprises the private parts of the system under test and `Execution trigger`, `Input data` and `Output data` are considered the system's public interface.

There can be any number of input, configuration or output tables and also any number of other fancy database widgets like triggers, views, materialized views and temporary tables depending on the implementation of the system but the pattern remains.

```
                     +------------------+
                     | Input data       |
                     | (database table) |
                     +------------------+
                               ^
                               | 2/4 reads unprocessed data
                               |
+-----------+ 1/4    +---------+----------+ 3/4   +------------------+
| Execution | starts | Code               | reads | Configuration    |
| trigger   +------->| (stored procedure) +------>| (database table) |
+-----------+        +---------+----------+       +------------------+
                               |
                               | 4/4 writes processed data
                               v
                     +------------------+
                     | Output data      |
                     | (database table) |
                     +------------------+
```

## DbFit Command Examples

The examples are from test [OnlyCommissionRecord.wiki](tests/DbFitExampleTestSuite/OnlyCommissionRecord.wiki) (see the link for full test description).

Fake external data producer and insert three carefully selected records into `Input data`:
```
!|Insert|input|
|party    |amount1|amount2|amount3|amount4|id?                 |
|ACME     |     0|      30|      0|      0|>>acme_input_id     |
|FOOBARINC|     0|      40|      0|      0|>>foobarinc_input_id|
|MEGACORP |     0|      50|      0|      0|>>megacorp_input_id |
```

The auto-generated primary key (`id`-column) returned by the database is bind to the `acme_input_id`, `foobarinc_input_id` and `megacorp_input_id` variables that are used later.

Start the execution (`Execution trigger`):
```
!|Execute Procedure|data_processing.process_input|
|p_id                |
|<<acme_input_id     |
|<<foobarinc_input_id|
|<<megacorp_input_id |
```

In this system every record has to be triggered individually hence three procedure calls.

Validate `Output data` is as expected:
```
!2 Validate Output Records

!|Ordered Query|select * from input_meta order by input_id, processed_at|
|input_id            |processing_status|
|<<acme_input_id     |         INSERTED|
|<<acme_input_id     |     PROCESSED_OK|
|<<foobarinc_input_id|         INSERTED|
|<<foobarinc_input_id|     PROCESSED_OK|
|<<megacorp_input_id |         INSERTED|
|<<megacorp_input_id |     PROCESSED_OK|

!|Query|select * from output order by id|
|input_id            |account|amount|
|<<acme_input_id     |   A101|    30|
|<<acme_input_id     |   A102|   1.8|
|<<foobarinc_input_id|   F101|    40|
|<<foobarinc_input_id|   F102|   3.2|
|<<megacorp_input_id |   M101|    50|
|<<megacorp_input_id |   M102|     5|
```

The variables are used to verify the generated output records are based on the correct input record.

## Complete Working Example

The example implements pattern described in chapter _Systems Suitable for DbFit Tests_.

The used DbFit version is [4.0.0](https://github.com/dbfit/dbfit/releases/tag/v4.0.0) released on 23 July 2022.

The used database Oracle 18 XE. The database code uses features that are introduced in Oracle 12.2 and might also use features that are introduced in Oracle 18 (I lost track at some point). So you really might need Oracle 18 or better (sorry - [PostgreSQL](https://www.postgresql.org/) doesn't count here) if you'd like to run the tests. See e.g. [Oracle 18 XE Ubuntu Quick Start Guide for Dummies](https://blog.digia.com/oracle-18-xe-ubuntu-quick-start-guide-for-dummies) for the relative painless way to run Oracle database locally in you development host.

Althought we use here a specific database the DbFit tests are (mostly) database agnostic and the way how DbFit is used and tests are written don't depend on the actual database system. So if you feel adventurous you could implement the system under test with PostgreSQL and see if you can pass all the tests :)

The example consists of two parts that are located in the following directory structure:

* `db` - an imaginary old-school finance record processing system that demonstrates the system under test (SUT) that implements the pattern descibed in chapter _Systems Suitable for DbFit Tests_.
* `tests` - the actual DbFit tests that verifies the correctness of the SUT

Install SUT with [SQLcl](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/) by executing `db/createdb.sql`:
```
sqlcl -noupdates -LOGON <USER>/<PASSWORD>@<DATABASE> @db/create.sql
```

Start DbFit with following command line options:
```
-o -p 8090 -d <PATH> -r tests
```

where <PATH> is the absolute path of this repository in your file system.

Now just point your browser to http://localhost:8090/DbFitExampleTestSuite press `Suite` text in the top row and enjoy the correctness of the system!

Note that the database connection string is hardcoded and have to be changed in:

* `tests/DbFitExampleTestSuite/SetUp.wiki`
* `tests/DbFitExampleTestSuite/SuiteSetUp.wiki`
* `tests/DbFitExampleTestSuite/SuiteTearDown.wiki`

This is not a good practice but convenient and no information is leaked in this case.

There is only two test that both belongs to the same [test suite](http://fitnesse.org/FitNesse.FullReferenceGuide.UserGuide.WritingAcceptanceTests.TestSuites) DbFitExampleTestSuite. When the test suite is run the following steps are executed in order:

* SuiteSetup
 * Executed once in the beginning of test suite. Here we set configuration suitable for the test cases.
* Setup
 * Executed before every test. Here we import the correct database driver and open database connection.
* OnlyCommissionRecord
 * The actual test.
* TearDown
 * Executed after every test. Here we run `Inspect query` DbFit commands that dump the contents of all relevant database tables. This is valuable information when developing the system and/or tests and have helped me several times in troubleshooting.
* Setup
 * The same as before.
* OnlyCommissionRecord
 * The actual test.
* TearDown
 * The same as before.
* SuiteTearDown
 * Executed once in the end of test suite. Here we undo configuration set in SuiteSetup.
