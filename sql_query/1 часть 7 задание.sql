-- Накопительная сумма по дням для каждого клиента за все время
SELECT
  c.customer_id
 ,CONCAT(first_name, ' ', last_name, ' ', second_name) as full_name
 ,report_date
 ,sum(price*count) OVER(PARTITION by c.customer_id ORDER by report_date) as accum_sum_sales
FROM 
  customers c
LEFT join 
  pharma_orders po ON po.customer_id=c.customer_id
ORDER BY
  c.customer_id
 ,report_date;