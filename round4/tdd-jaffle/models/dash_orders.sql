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
