-- Ранжируем клиентов по общей сумме заказов и оставляем 10 самых прибыльных клиентов
SELECT
  po.customer_id
 ,first_name
 ,last_name
 ,second_name
 ,sum(price*count) as total_sales
 ,ROW_NUMBER() OVER(ORDER by sum(price*count) DESC) as rank_client
FROM 
  pharma_orders po
join 
  customers c ON po.customer_id=c.customer_id
GROUP BY  
  po.customer_id
 ,first_name
 ,last_name
 ,second_name
ORDER BY
  rank_client
limit 10;