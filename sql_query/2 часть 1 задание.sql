-- Сравниваем продажи между Москвой и Санкт-Петербургом по одинаковым аптекам и месяцам
with 
-- Считаем продажи по месяцам в Москве для каждой аптеки
sales_moscow as(
  SELECT
    pharmacy_name
   ,DATE_TRUNC('month', report_date::DATE)::DATE as month_date
   ,sum(price*count) as sales_in_moscow
  FROM 
    pharma_orders
  where 
    city = 'Москва'
  GROUP BY
    pharmacy_name
   ,DATE_TRUNC('month', report_date::DATE)
  ORDER BY
    pharmacy_name
   ,month_date
),
-- Считаем продажи по месяцам в Санкт-Петербурге для каждой аптеки
sales_st_petersburg as(
  SELECT
    pharmacy_name
   ,DATE_TRUNC('month', report_date::DATE)::DATE as month_date
   ,sum(price*count) as sales_in_petersburg
  FROM 
    pharma_orders
  where 
    city = 'Санкт-Петербург'
  GROUP BY
    pharmacy_name
   ,DATE_TRUNC('month', report_date::DATE)
  ORDER BY
    pharmacy_name
   ,month_date
)
-- Объединяем полученные результаты по аптекам и месяцам и находим разницу в процентах относительно Москвы
SELECT
  sm.pharmacy_name
 ,sm.month_date
 ,sales_in_moscow
 ,sales_in_petersburg
 ,ROUND(((sales_in_petersburg-sales_in_moscow)::NUMERIC
         /NULLIF(sales_in_moscow, 0)*100), 1) as percent_diff_relative_moscow
from 
  sales_moscow sm
join 
  sales_st_petersburg sp on sm.pharmacy_name=sp.pharmacy_name
  						 and sm.month_date=sp.month_date
-- исключаем июнь, так как данные представлены не за весь месяц
WHERE
  sm.month_date != '2024-06-01'
ORDER BY
  sm.pharmacy_name
 ,sm.month_date;
 
 /* Разницу в процентах будем рассматривать относительно Москвы. 
 Для каждой аптеки есть данные за 4 месяца, с февраля по май. 
 
 В аптеках "Столичная" и "Здравсити" в феврале больше продаж в Санкт-Петербурге, 
 но в остальные месяца преобладают продажи в Москве. Так же в аптеке "Горздрав" суммарные продажи
 в трех месяцах из четырех в Санкт-Петербурге меньше, чем в Москве.
 По остальным аптекам процентная разница показывает, что объемы продаж в Санкт-Петербурге
 больше, чем в Москве в большинстве месяцев.