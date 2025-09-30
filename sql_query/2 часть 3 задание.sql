-- Анализируем продажи в зависимости от возрастной группы
WITH
-- Разбиваем клиентов на возрастные группы
customers_groups as(
  SELECT
    customer_id
   ,EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) as age_client
   ,CASE
      WHEN gender = 'муж' and EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) < 30
        THEN 'Мужчины младше 30'
      WHEN gender = 'муж' and EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) <= 45
        THEN 'Мужчины 30-45'
      WHEN gender = 'муж' and EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) > 45
        THEN 'Мужчины 45+'
      WHEN gender = 'жен' and EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) < 30
        THEN 'Женщины младше 30'
      WHEN gender = 'жен' and EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) <= 45
        THEN 'Женщины 30-45'
      WHEN gender = 'жен' and EXTRACT(YEAR FROM AGE(date_of_birth::DATE)) > 45
        THEN 'Женщины 45+'
    end as age_group
  from 
    customers
),
-- Считаем количество клиентов и суммы продаж в каждой возрастной группе 
customers_groups_and_orders as(
  SELECT
    age_group
   ,COUNT(DISTINCT cg.customer_id) as count_clients_in_groups
   ,sum(price*count) as sum_sales_groups
-- В подзапросе считаем весь объем продаж по всем аптекам 
   ,(SELECT sum(price*count) FROM pharma_orders) as total_sales
  FROM
    customers_groups cg
  LEFT JOIN
    pharma_orders po on cg.customer_id=po.customer_id
  GROUP BY
    age_group
-- Выводим полученные данные и расчитываем долю каждой возрастной группы от общих продаж
)
SELECT
  age_group
 ,count_clients_in_groups
 ,sum_sales_groups
 ,ROUND(sum_sales_groups::NUMERIC/total_sales*100, 1) as percent_of_total_sales
from 
  customers_groups_and_orders
ORDER BY
  sum_sales_groups DESC 
;

/* Больше всего на покупки лекарств тратят мужчины и женщины за 45 лет, данные группы 
являются самыми многочисленными по количеству клиентов. Их суммарные покупки составляют
половину продаж по всем аптекам. Относительно самыми здоровыми можно считать женщин младше 30,
они тратят меньше всех на лекарства, их доля покупок составляет 10.8%. А мужчины младше 30
занимают третье место, их доля от общих продаж 13.3%
*/