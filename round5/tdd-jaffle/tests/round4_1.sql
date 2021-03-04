-- checks for any order at all
with result as (select
    order_count, date, payment_type
from {{ ref('dash_orders' )}}),

count as (select case when count(*) > 0 then 1
          else 0
          end res
 from result)
 select * from count group by 1

having (res = 0)
