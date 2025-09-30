-- Находим количество уникальных клиентов в каждой аптеке
SELECT
  pharmacy_name
-- Чтобы посчитать только уникальных клиентов пропишем "DISTINCT"
 ,count(DISTINCT customer_id) as count_clients 
FROM 
  pharma_orders 
GROUP BY  
  pharmacy_name
ORDER BY
  count_clients DESC;