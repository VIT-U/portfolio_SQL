-- Накопительная сумма продаж по дням для каждой аптеки
SELECT
-- Чтобы не дублировались дни для аптек пропишем "DISTINCT"
  DISTINCT pharmacy_name
 ,report_date
 ,sum(price*count) OVER(PARTITION by pharmacy_name ORDER by report_date) as accum_sum_sales 
FROM 
  pharma_orders 
ORDER BY
  pharmacy_name
 ,report_date;