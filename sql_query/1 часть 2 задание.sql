-- Находим ТОП-3 лекарств по объемам продаж
SELECT
  drug
 ,sum(price*count) as sales_volume 
FROM 
  pharma_orders 
GROUP by 
  drug
ORDER BY
  sales_volume DESC
LIMIT 3;