/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок.
 * 
 * Автор: Уляшев Виталий
 * Дата: 14.12.2024-19.12.2024
*/

-- ЧАСТЬ 1. Исследовательский анализ данных.

-- Задача 1. Исследование доли платящих игроков.

-- 1.1. Доля платящих пользователей по всем данным.
SELECT COUNT(id) AS total_users,
       SUM(payer) AS count_payer,
       AVG(payer) AS share_payer_users
FROM fantasy.users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа.
SELECT race,
	   COUNT(id) AS total_users,
	   SUM(payer) AS payer_users,
	   ROUND(AVG(payer),2) AS share_payer_users
FROM fantasy.users	AS u 
-- Присоединяю таблицу с расами, чтобы вывести названия рас.
JOIN fantasy.race r ON u.race_id=r.race_id
GROUP BY race
-- Добавил сортировку.
ORDER BY total_users DESC;

-- Задача 2. Исследование внутриигровых покупок.

-- 2.1. Статистические показатели по полю amount.
-- Вывожу статистику по полю amount.
-- Считаю медиану с помощью функции PERCENTILE_CONT, так как в таблице четное количество строк.
SELECT COUNT(*) AS count_amount,
       SUM(amount) AS sum_amount,
       MAX(amount) AS max_amount,
       MIN(amount) AS min_amount,
       ROUND(AVG(amount)::numeric,2) AS avg_amount,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)::numeric,2) AS median_amount,
       ROUND(STDDEV(amount)::numeric,2) AS stddev_amount
FROM fantasy.events; 

-- 2.2. Аномальные нулевые покупки.
SELECT COUNT(amount) AS zero_amount,
       ROUND(COUNT(amount)::numeric/(SELECT COUNT(amount) FROM fantasy.events),5) AS share_zero_amount
FROM fantasy.events 
WHERE amount=0; 

-- 2.3. Сравнительный анализ активности платящих и неплатящих игроков.
-- В основном запросе даю названия категориям игроков.
SELECT CASE 
	     WHEN payer=0
	       THEN 'неплатящий игрок'
	     WHEN payer=1
	       THEN 'платящий игрок'
       END AS payer,
       COUNT(DISTINCT u.id) AS count_users,
-- Считаю среднее количество покупок и среднюю сумму покупок на одного игрока.
       ROUND(COUNT(amount)::numeric/COUNT(DISTINCT u.id),2) AS avg_count_per_user,
       ROUND(SUM(amount)::numeric/COUNT(DISTINCT u.id),2) AS avg_sum_per_user
FROM fantasy.users u
JOIN fantasy.events e ON u.id=e.id
WHERE amount>0
GROUP BY payer;

-- 2.4. Популярные эпические предметы.
-- В табличном выражении нахожу количество покупок по каждому предмету и их долю от всех покупок,
-- количество уникальных пользователей купивших предмет и их долю от всех активных игроков.
WITH
stat_items AS (
	SELECT item_code,
	       COUNT(amount) AS count_pay,
	       COUNT(amount)::numeric/(SELECT COUNT(amount) FROM fantasy.events WHERE amount>0) AS share_per_item,
	       COUNT(DISTINCT id) AS count_id,
	       COUNT(DISTINCT id)::numeric/(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount>0) AS share_users_pay_item
	FROM fantasy.events
-- Применяю фильтрацию, чтобы учитывать только ненулевые покупки.
	WHERE amount>0
	GROUP BY item_code
	ORDER BY count_pay DESC
)
-- В основном запросе показываю количество покупок для каждого предмета,
-- долю продажи каждого предмета от всех продаж и долю уникальных игроков покупавших предметы от всех игроков.
-- Округление не применяю, так как присутствует много значений с тремя и более нулями после запятой.
-- Для предметов, которые не покупались, поля с долями оставил без значений, а поле с количеством покупок заменил на значение "0".
SELECT game_items,
	   COALESCE(count_pay,0) AS count_pay,
	   share_per_item,
       share_users_pay_item
-- Полученные результаты присоединяю к таблице со всеми предметами,
-- чтобы видеть названия предметов и понимать какие предметы совсем не пользуются спросом.	   
FROM fantasy.items AS i
LEFT JOIN stat_items AS si ON i.item_code=si.item_code
ORDER BY count_pay DESC;

-- ЧАСТЬ 2. Решение ad hoc-задач.

-- Задача 1. Зависимость активности игроков от расы персонажа.
-- В табличном выражении нахожу количество пользователей по расам, сначала общее количество из всех зарегистрированных игроков.
WITH
count_users AS (
	SELECT DISTINCT u.race_id,
	       COUNT(u.id) OVER(PARTITION BY u.race_id) AS count_total_id,
	       count_payer_users,
	       count_users_buy_item
	FROM fantasy.users AS u
-- Присоединяю количество платящих пользователей для каждой расы.
	JOIN (SELECT race_id,
	             COUNT(DISTINCT e.id) AS count_payer_users
	      FROM fantasy.users AS u
	      JOIN fantasy.events AS e ON u.id=e.id
	      WHERE payer=1 AND amount>0
	      GROUP BY race_id) AS p ON u.race_id=p.race_id
-- Присоединяю количество пользователей, которые совершили внутриигровые покупки.
	JOIN (SELECT race_id,
	             COUNT(DISTINCT e.id) AS count_users_buy_item
	      FROM fantasy.users AS u
	      LEFT JOIN fantasy.events AS e ON u.id=e.id
	      WHERE amount>0
	      GROUP BY race_id) AS b ON u.race_id=b.race_id     
),
-- Во втором табличном выражении нахожу количество покупок и их сумму в разрезе каждой расы.
stat_race AS (
	SELECT DISTINCT race_id,
	       COUNT(amount) OVER(PARTITION BY race_id) AS count_buy,
	       SUM(amount) OVER(PARTITION BY race_id) sum_buy
	FROM fantasy.users AS u
	LEFT JOIN fantasy.events AS e ON u.id=e.id
-- Применяю фильтр, чтобы учитывать только ненулевые покупки.
	WHERE amount>0
)
-- В основном запросе соединяю полученные табличные выражения и произвожу расчеты для каждой расы.
SELECT race,
       count_total_id,
       count_users_buy_item,
-- Доля игроков сделавших внутриигровую покупку от всех игроков.
       ROUND(count_users_buy_item::numeric/count_total_id,2) AS share_users_buy_item,
-- Доля платящих игроков от всех игроков сделавших покупку.
       ROUND(count_payer_users::numeric/count_users_buy_item,2) AS share_payer_users,
-- Среднее количество покупок на одного игрока.
       ROUND(count_buy::numeric/count_users_buy_item,2) AS avg_count_buy_per_user,
-- Средняя сумма покупок на одного игрока.
       ROUND(sum_buy::numeric/count_users_buy_item,2) AS avg_sum_buy_per_user,
-- Средняя цена одной покупки.
       ROUND(sum_buy::NUMERIC/count_buy,2) AS avg_price_item_per_user
FROM count_users AS cu
JOIN stat_race AS sr ON cu.race_id=sr.race_id
-- Присоединяю таблицу с расами, чтобы вывести названия рас.
JOIN fantasy.race AS r ON cu.race_id=r.race_id;

-- Задача 2. Частота покупок.
-- В первом табличном выражении нахожу промежуток в днях между покупками у каждого пользователя.
WITH
count_day_between_buy AS (
	SELECT *,
	       date::date-LAG(date::date) OVER(PARTITION BY id ORDER BY date::date) AS count_day
	FROM fantasy.events
-- С помощью фильтра исключаю покупки с нулевой стоимостью.
	WHERE amount>0
),
-- Во втором табличном выражении для каждого пользователя нахожу количество покупок, средний интервал в днях между этими покупками.
count_amount_and_rank AS (
	SELECT id,
	       COUNT(amount) AS count_amount,
	       AVG(count_day) AS avg_count_day,
-- Делю полученные данные на три группы.
	       NTILE(3) OVER(ORDER BY AVG(count_day)) AS rank_day
	FROM count_day_between_buy
	GROUP BY id
-- Исключаю игроков, которые совершили менее 25 покупок.
	HAVING COUNT(amount)>=25
),
-- Добавляю к предыдущему результату поле 'payer' из другой таблицы, чтобы видеть кто из игроков является платящим пользователем.
count_amount_and_rank_and_payer_users AS (
	SELECT caar.id,
	       count_amount,
	       avg_count_day,
	       rank_day,
	       payer
	FROM count_amount_and_rank AS caar
	LEFT JOIN (SELECT payer,
	                  id
	      FROM fantasy.users AS u) AS u ON caar.id=u.id
)
-- В основном запросе даю названия группам по частоте покупок и для каждой группы нахожу необходимые значения.
SELECT CASE 
	     WHEN rank_day=1
	       THEN 'высокая частота'
	     WHEN rank_day=2
	       THEN 'умеренная частота'
	     WHEN rank_day=3
	       THEN 'низкая частота'
       END AS rank_day,
-- Общее количество пользователей в группе.
       COUNT(id) AS count_id,
-- Количество платящих пользователей.
       SUM(payer) AS count_payer_users,
-- Доля платящих пользователей от всех пользователей в группе.
       ROUND(SUM(payer)::numeric/COUNT(id),2) AS share_payer_users,
-- Среднее количество покупок на одного игрока.
       ROUND(AVG(count_amount)::NUMERIC,2) AS avg_count_amount_per_user,
-- Среднее количество дней между покупками для одного игрока.
       ROUND(AVG(avg_count_day)::NUMERIC,2) AS avg_count_day_per_user
FROM count_amount_and_rank_and_payer_users
GROUP BY rank_day;

