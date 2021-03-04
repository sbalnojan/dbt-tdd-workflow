-- Get either test of raw data...
with orders as (
  {% if target.name == 'ci' %}
  select * from {{ ref('test_round3_input') }}

  {% else %}
  select status,order_date,raw_orders.id as id,
  raw_payments.payment_method
   from {{ ref('raw_orders') }} join {{ ref('raw_payments') }}
  on raw_orders.id = raw_payments.id

  {% endif %}
)

-- now transform the data

/* the fix for the "just data test"
select order_date as date, count(id) as order_count,
'giftcard' as payment_type, 1 as customer_id
*/

select order_date as date, count(id) as order_count,
payment_method as payment_type

 from orders
where status='completed' -- let's just take the completed orders... returned doesn't count
group by date, payment_type
order by date desc --- newest first
