-- Use the `ref` function to select from other models

select 2 as order_count, '2021-01-01'::date as date
--from {{ ref('raw_customers') }}
