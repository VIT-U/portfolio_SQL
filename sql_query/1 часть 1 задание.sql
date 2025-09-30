-- Находим ТОП-3 аптек по объемам продаж
SELECT
  pharmacy_name
 ,sum(price*count) as sales_volume 
FROM 
  pharma_orders 
GROUP by 
  pharmacy_name
ORDER BY
  sales_volume DESC
LIMIT 3;