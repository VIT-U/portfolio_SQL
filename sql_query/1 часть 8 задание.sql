-- Находим лучших клиентов по количеству заказов в аптеках 'Горздрав' и 'Здравсити'
with 
-- Находим ТОП-10 клиентов по количеству заказов в аптеке 'Горздрав'
top_client_gorzdrav as(
  SELECT
    pharmacy_name
   ,po.customer_id
   ,CONCAT(first_name, ' ', last_name, ' ', second_name) as full_name
   ,count(distinct order_id) as count_order
  FROM 
    pharma_orders po
  join 
    customers c ON po.customer_id=c.customer_id
  where pharmacy_name = 'Горздрав'
  GROUP BY
    pharmacy_name
   ,po.customer_id
   ,CONCAT(first_name, ' ', last_name, ' ', second_name)
  ORDER BY
    count_order DESC
  LIMIT 10
),
-- Находим ТОП-10 клиентов по количеству заказов в аптеке 'Здравсити'
top_client_zdravcity as(
  SELECT
    pharmacy_name
   ,po.customer_id
   ,CONCAT(first_name, ' ', last_name, ' ', second_name) as full_name
   ,count(distinct order_id) as count_order
  FROM 
    pharma_orders po
  join 
    customers c ON po.customer_id=c.customer_id
  where pharmacy_name = 'Здравсити'
  GROUP BY
    pharmacy_name
   ,po.customer_id
   ,CONCAT(first_name, ' ', last_name, ' ', second_name)
  ORDER BY
    count_order DESC
  LIMIT 10
)
-- Объединяем лучших клиентов из двух аптек в один запрос
SELECT *
from 
  top_client_gorzdrav
union
SELECT *
from 
  top_client_zdravcity
ORDER BY
  pharmacy_name
 ,count_order DESC
;