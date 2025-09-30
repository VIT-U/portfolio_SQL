-- Анализируем продажи по лекарствам в названии которых присутствует слово "аква"
WITH
-- Находим нужные лекарства, их объемы продаж в каждой аптеке и ранжируем их по продажам
drug_akva_in_pharmacy as(
  SELECT
    pharmacy_name
   ,drug
   ,total_sales_pharmacy
   ,sum(price*count) as total_sales_drug
   ,ROW_NUMBER() OVER(PARTITION by pharmacy_name ORDER by sum(price*count) DESC) rank_drug_in_pharmacy
  from 
    pharma_orders
-- Присоединяем данные с общими объемами продаж по каждой аптеке  
  JOIN
    (select pharmacy_name, sum(price*count) as total_sales_pharmacy
     from pharma_orders
     GROUP by pharmacy_name) USING(pharmacy_name)
  WHERE
    LOWER(drug) LIKE '%аква%'
  GROUP BY
    pharmacy_name
   ,drug
   ,total_sales_pharmacy
-- Выводим полученные данные и расчитываем долю наших лекарст от общих продаж в каждой аптеке
)
SELECT
  pharmacy_name
 ,drug
 ,rank_drug_in_pharmacy
 ,total_sales_drug
 ,ROUND(total_sales_drug::NUMERIC/total_sales_pharmacy*100, 1) as percent_of_total_sales
from 
  drug_akva_in_pharmacy
ORDER BY
  pharmacy_name
 ,rank_drug_in_pharmacy 
;

/* Общая доля продаж таких лекарств в каждой аптеке составляет как минимум четверть от всех продаж.
Можно сделать вывод, что такие лекарства пользуются спросом во всех аптеках. Можно отметить, что лекарство 
"Аква-нормикс", среди схожих лекарств, в трех аптеках занимает последнюю позицию по продажам, что 
говорит о меньшей популярности среди покупателей. Остальные препараты пользуются разной популярностью в 
зависимости от аптек. Чтобы выявить явного лидера по продажам потребуются дополнительные расчеты.
*/