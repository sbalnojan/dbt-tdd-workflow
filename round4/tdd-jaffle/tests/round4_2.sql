-- checks for any order at all
with result as (select
    customer_id, orders_last_30_days
from {{ ref('dash_customers' )}}),

count as (select case when count(*) > 0 then 1
          else 0
          end res
 from result)
 select * from count group by 1

having (res = 0)
