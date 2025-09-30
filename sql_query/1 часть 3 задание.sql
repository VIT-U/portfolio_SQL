-- Выводим аптеки имеющие более 1,800,000 у.е. торгового оборота за все время
SELECT
  pharmacy_name
 ,sum(price*count) as sales_volume 
FROM 
  pharma_orders 
GROUP by 
  pharmacy_name
HAVING
  sum(price*count) > 1800000
ORDER BY
  sales_volume DESC;