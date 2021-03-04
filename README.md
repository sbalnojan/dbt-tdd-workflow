## DBT TDD Workflow

This repository is a "little workshop" you can
walk through to experience TDD for dbt.

## WIP To Dos

- Fix Batect so that we don't have to replace the "roundX" we want to mount..
- Fix postgres start up (takes some time ...)
- Provide a "rm postgres-data" make, currently you will occasionally have to
  delete the local data folder...
- Add some stuff about the most fun step of TDD: Refactoring!
- Add three TDD rules.

## How this repo works

It's TDD. So we will go in rounds.

1.  Write a test that fails (the minimal failable test).
2.  Fix it.

Turn another round...
If you want to run thing with batect (https://batect.dev/), as you should,
please replace the folder you want to mount (round1-5).

Stuff is mounted, so you can start batect, then edit files locally, and
then run inside the container you already started.

To see the tasks run:

```./batect --list-tasks
...
Dev tasks:
- run_seeded_dbt: Start a shell in the development environment, with seeded data..

Setup tasks:
- seed_dbt: Start the seeding of data into the postgres.

Utility tasks:
- run_dbt: Start a shell in the development environment.
- run_postgres: Start a postgres instance...
```

...

To run a test, you got to load DBT with the database
with data (the "seeded database"), then do a
dbt run and then run the tests like so:

```
./batect run_seeded_dbt

... $ dbt run
... $ dbt test
```

(sometimes you got to run the batect task 3 times,
because the postgres takes some time to load...
haven't fixed that yet.)

## Notes

- We're using "dbt seed" to load raw data. Don't do that in practice! Seeding
  is best for business logic containing things like a mapping table etc.
  (dbt seeds docs)[https://docs.getdbt.com/docs/building-a-dbt-project/seeds]
- You don't have to manually execute dbt test --data all the time
  simply install entr and watch the files => tests will automatically be executed..
- Data is taken from the dbt example project (https://github.com/fishtown-analytics/jaffle_shop)

## Round 1

We're asked to create a simple dashboard containing:

- (1) orders per day
- (2) payments segmented by "type"
- (3) most important customers

Let's start with (1); We will of course follow best practice and create one
model as foundation for the dashboard.

First test... [round1/tdd-jaffle/tests/round1.sql](round1/tdd-jaffle/tests/round1.sql)
e.g. by running

```
./batect run_seeded_dbt

... $ dbt run
... $ dbt test
```

```sql
with result as (select
    *
from {{ ref('dash_orders' )}}),

count as (select case when count(*) > 0 then 1
          else 0
          end res
 from result)
 select * from count group by 1

having (res = 0)
```

Run it...

```shell
[WARNING]: Test 'test.tdd_jaffle.round1' (tests/round1.sql) depends on a node named 'dash_orders' which was not found
```

True, let's create a dummy model...[round2/tdd-jaffle/models/dash_orders.sql](round2/tdd-jaffle/models/dash_orders.sql)

```sql
select "first_order"
```

and run the test again.

```shell
09:31:03 | 1 of 1 START test round1............................................. [RUN]
09:31:03 | 1 of 1 PASS round1................................................... [PASS in 0.09s]
```

Perfect. Now let's iterate on the test. That actually requires some output
oriented thinking...

## Round 2

Now let's write another test. (1) order per day right? So we probably need a table like

- column 1: order_count... int
- column 2: day... date

let's test for that.... [round1/tdd-jaffle/tests/round1.sql](round1/tdd-jaffle/tests/round1.sql)

```sql
-- checks for any order at all
with result as (select
    order_count, date
from {{ ref('dash_orders' )}}),

count as (select case when count(*) > 0 then 1
          else 0
          end res
 from result)
 select * from count group by 1

having (res = 0)
```

now run it...

```shell
Database Error in test round2 (tests/round2.sql)
  column "order_count" does not exist
  LINE 6:     order_count, date
              ^
  compiled SQL at target/compiled/tdd_jaffle/tests/round2.sql
```

Right, the minimal test. Now let's get the columns....

```
09:46:25 | 1 of 2 PASS round1................................................... [PASS in 0.11s]
09:46:25 | 2 of 2 PASS round2................................................... [PASS in 0.09s]
```

## Round 3

Now let's add some actual data, test data. (no not the one we already
seeded, this should usually come form some other EL tool...). We use
the approach in [this article](https://discourse.getdbt.com/t/testing-with-fixed-data-set/564/2)
to use seeds as tests (after all test data contains lots of business
logic.).

The minimal input/output set I got in my mind looks like the round3 set....
[round3/tdd-jaffle/data/test_round3_input.csv](round3/tdd-jaffle/data/test_round3_input.csv)

```
--INPUT
id,user_id,order_date,status
1,1,2018-01-01,completed
2,3,2018-01-02,completed
3,3,2018-01-02,completed
--OUTPUT
order_count,date
1,2018-01-01
2,2018-01-02
```

So our test? of course, with this "input" we want, after model, our expected output...
Let's write that down...

```sql
# schema.yml
version: 2

models:
  - name: dash_orders
    tests:
      - dbt_utils.equality:
          compare_model: ref('test_round3_output')
```

Perfect, we just made a renaming error:

```
  HINT:  There is a column named "date" in table "*SELECT* 1", but it cannot be referenced from this part of the query.
```

Let's fix that, and then fix the rest, once the naming is fixed, our
error looks like this ...

```
Completed with 1 error and 0 warnings:

Failure in test dbt_utils_equality_dash_orders_ref_test_round3_output_ (models/schema.yml)
  Got 4 results, expected 0.
```

So now, we are finally allowed to write some logic, transforming
our fixed input into fixed output data:

```sql
-- Get either test of raw data...
with orders as (
  {% if target.name == 'ci' %}
  select * from {{ ref('test_round3_input') }}

  {% else %}
  select * from {{ ref('raw_orders') }}

  {% endif %}
)

-- now transform the data
select order_date as date, count(id) as order_count from orders
where status='completed' -- let's just take the completed orders... returned doesn't count
group by date
order by date desc --- newest first
```

You can run your tests with the local data using `dbt run/test --target ci`
...

Uh so now we get started...

```
10:54:46 | 2 of 4 PASS round1................................................... [PASS in 0.18s]
10:54:46 | 4 of 4 PASS round3................................................... [PASS in 0.19s]
10:54:46 | 3 of 4 PASS round2................................................... [PASS in 0.20s]
10:54:46 | 1 of 4 PASS dbt_utils_equality_dash_orders_ref_test_round3_output_... [PASS in 0.26s]
```

It's probably also time to take some SQL tool and look at the data, just to make sure...

## Round 4

Remember the requirements? We also need

- (2) payments segmented by "type"
- (3) most important customers

Lots of ways to tackle this, since I'd like to build a larger model and not simply
now repeat the same stuff, I decided enlargen our model a bit...

- column 1: order_count... int
- column 2: day... date
- column 3: payment_type ... string
- column 4: customer_id ... id

and maybe one second model

- column 1: customer id
- column 2: orders_last_30_days
- ...

So let's extend our tests! (Keep in mind, extend them minimally so that they fail)

BY NOW YOU SHOULD KNOW WHERE THEY ARE LOCATED...

```
Database Error in test round4_1 (tests/round4_1.sql)
  column "payment_type" does not exist
  LINE 6:     order_count, date, payment_type, customer_id
                                 ^
  compiled SQL at target/compiled/tdd_jaffle/tests/round4_1.sql
```

(now we just fixed the "only data" tests, dbt test --data)... Let's do a second
iteration and also fix the test data test.

Fun part: If you take a look at the input data I chose, you see you still can
go minimal, you don't have to seed two tables, then join them, you can simply
use the joined table as test data input.

## [WIP] Round 5 - [WIP]

Now let's finally get the customer model to work.. We'll do the
two test fixes in one again, first a test just for the table signature,
then for some transformed data.

## More Testing...

So that is all? Fixed data testing? No of course not! There are two entire
"test pyramids" of which we only tackled one, and only the bottom layer of it.

But it's the most important part. The unit testing part which runs fast,
and often, and makes development so extremely fast & effective.

For the other tests you'll need more tools.

![test pyramid](https://github.com/sbalnojan/dbt-tdd-workflow/blob/main/test_pyramid.jpg)

- for the "value pipeline" you can still utilize dbt and both the schema & data
  tests to a large extend.
- for testing both the ingested raw data as well as possibly the output data
  you might want to employ an additional tool like great-expectations.

## References

Some helpful articles:

- https://itnext.io/how-to-tdd-a-console-application-to-achieve-100-coverage-starting-from-main-test-go-934a617b080f
- https://medium.com/@pierreprinetti/test-driven-development-in-go-baeab5adb468
- https://github.com/quii/learn-go-with-tests
