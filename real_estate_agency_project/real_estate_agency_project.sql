-- Задача 1: Время активности объявлений.

-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Определим аномальные значения (выбросы) по значению перцентилей.
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы.
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Разделяю данные на категории и вывожу характеристики, которые могут заинтересовать заказчика.
categories AS (
	SELECT 
-- Разделяю объявления на регионы.
		CASE 
		  WHEN city='Санкт-Петербург'
		    THEN 'Санкт-Петербург'
		  ELSE 'Ленинградская область'
		END AS region,
-- Разделяю объявления по времени продажи.
		CASE 
		  WHEN days_exposition BETWEEN 1 AND 30
		    THEN 'до месяца'
		  WHEN days_exposition BETWEEN 31 AND 90
		    THEN 'от 1 до 3 месяцев'
		  WHEN days_exposition BETWEEN 91 AND 180
		    THEN 'от 3 до 6 месяцев'
		  WHEN days_exposition > 180
		    THEN 'от 6 месяцев и более'
		END AS sales_period,
		last_price::numeric/total_area AS cost_per_square_meter,
		a.id,
		total_area,
		rooms,
		ceiling_height,
		floors_total,
		floor,
		is_apartment,
		open_plan,
		balcony,
		parks_around3000,
		ponds_around3000
	FROM real_estate.flats AS f
	INNER JOIN real_estate.advertisement AS a ON f.id=a.id
	LEFT JOIN real_estate.city AS c ON f.city_id=c.city_id
	LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
	WHERE a.id IN (SELECT * FROM filtered_id)
-- Оставляю в выборке только объявления из городов.
	  AND t.type = 'город'
-- Исключаю объявления, которые еще в продаже.
	  AND days_exposition IS NOT NULL 
),
-- Расчитываю моду по количеству комнат, чтобы увидеть какие квартиры больше покупают.
calculate_mode AS (
	SELECT sales_period,
		   region,
		   rooms AS mode_rooms,
		   COUNT(rooms) AS count_rooms,
		   ROW_NUMBER() OVER(PARTITION BY sales_period, region ORDER BY COUNT(rooms) DESC) AS rank_rooms
	FROM categories
	GROUP BY sales_period, region, rooms
	ORDER BY sales_period
)
-- В итоговом запросе группирую полученную выборку по регионам и периодам продаж.
-- Усредняю и подсчитываю наиболее значимые характеристики.
SELECT c.sales_period,
	   c.region,
	   COUNT(id) AS count_advert,
	   ROUND(COUNT(id)::NUMERIC/(SELECT COUNT(id) FROM categories), 2) AS share_advert,
	   ROUND(AVG(cost_per_square_meter)) AS avg_cost_per_square_meter,
	   ROUND(AVG(total_area)) AS avg_total_area,
-- В подзапросе присоединяю расчитанную ранее моду количества комнат.
	   (SELECT mode_rooms
	    FROM calculate_mode
	    WHERE sales_period=c.sales_period AND region=c.region AND rank_rooms=1
	   ) AS mode_rooms,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors_total,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS median_parks_around3000,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS median_ponds_around3000,
	   ROUND(SUM(is_apartment)::NUMERIC/(SELECT SUM(is_apartment) FROM categories), 2) AS share_is_apartment,
	   ROUND(SUM(open_plan)::NUMERIC/(SELECT SUM(open_plan) FROM categories), 2) AS share_open_plan
FROM categories AS c
GROUP BY c.sales_period, c.region 
ORDER BY c.sales_period;


-- Задача 2: Сезонность объявлений.

-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Определим аномальные значения (выбросы) по значению перцентилей.
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы.
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Делаю выборку из объявлений которые были опубликованы и группирую их по номеру месяца.
posting_advert AS ( 
	SELECT EXTRACT ('month' FROM first_day_exposition) AS number_month,
    	   COUNT(a.id) AS count_advert,
    	   ROUND(AVG(last_price::numeric/total_area)) AS avg_cost_per_square_meter,
    	   ROUND(AVG(total_area)) AS avg_total_area,
-- Ранжирую сгруппированные месяцы по количеству объявлений.
    	   ROW_NUMBER() OVER(ORDER BY COUNT(a.id) DESC) AS rank_month
	FROM real_estate.advertisement AS a
	INNER JOIN real_estate.flats AS f ON a.id=f.id
	LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
	WHERE a.id IN (SELECT * FROM filtered_id)
-- Оставляю только города.
	  AND t.type = 'город'
-- Оставляю только те годы, которые целиком представлены в датасете, чтобы статистика не искажалась.
	  AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
	GROUP BY EXTRACT ('month' FROM first_day_exposition)
	ORDER BY number_month
),
-- Добавляю расчет доли количества объявлений в каждом месяце от всех объявлений.
posting_advert_dop AS (
	SELECT 'продавцы',
		   number_month,
		   count_advert,
		   ROUND(count_advert::NUMERIC/(SELECT SUM(count_advert) FROM posting_advert), 2) AS share_advert,
		   avg_cost_per_square_meter,
		   avg_total_area,
		   rank_month
    FROM posting_advert
    ORDER BY number_month
),
-- Делаю выборку из объявлений которые были сняты с публикации и группирую их по номеру месяца.
removal_advert AS (
	SELECT EXTRACT ('month' FROM first_day_exposition + days_exposition::int) AS number_month,
    	   COUNT(a.id) AS count_advert,
    	   ROUND(AVG(last_price::numeric/total_area)) AS avg_cost_per_square_meter,
    	   ROUND(AVG(total_area)) AS avg_total_area,
-- Ранжирую сгруппированные месяцы по количеству объявлений.
    	   ROW_NUMBER() OVER(ORDER BY COUNT(a.id) DESC) AS rank_month
	FROM real_estate.advertisement AS a
	INNER JOIN real_estate.flats AS f ON a.id=f.id
	LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
	WHERE a.id IN (SELECT * FROM filtered_id)
	  AND days_exposition IS NOT NULL
-- Оставляю только города.
	  AND t.type = 'город'
-- Оставляю только те годы, которые целиком представлены в датасете, чтобы статистика не искажалась.
	  AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
	GROUP BY EXTRACT ('month' FROM first_day_exposition + days_exposition::int)
	ORDER BY number_month
),
-- Добавляю расчет доли количества объявлений в каждом месяце от всех объявлений.
removal_advert_dop AS (
	SELECT 'покупатели',
		   number_month,
		   count_advert,
		   ROUND(count_advert::NUMERIC/(SELECT SUM(count_advert) FROM removal_advert), 2) AS share_advert,
		   avg_cost_per_square_meter,
		   avg_total_area,
		   rank_month
    FROM posting_advert
    ORDER BY number_month
)
-- В итоговом запросе соединяю вместе полученные выборки.
SELECT  *
FROM posting_advert_dop AS pa
FULL JOIN removal_advert_dop AS ra ON pa.number_month=ra.number_month;

-- Задача 3: Анализ рынка недвижимости Ленобласти.

-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы.
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Делаю выборку объявлений из Ленинградской области с параметрами, которые могут заинтересовать заказчика.
len_obl AS (
	SELECT 
	    city,
	    a.id,
		last_price::numeric/total_area AS cost_per_square_meter,
		total_area,
		is_apartment,
		open_plan,
		days_exposition
	FROM real_estate.flats AS f
	INNER JOIN real_estate.advertisement AS a ON f.id=a.id
	LEFT JOIN real_estate.city AS c ON f.city_id=c.city_id
	WHERE a.id IN (SELECT * FROM filtered_id)
	  AND city != 'Санкт-Петербург'
)
-- В итоговом запросе группирую полученную выборку по населенным пунктам Ленинградской области.
-- Расчитываю и усредняю необходимые характеристики.
SELECT city,
	   COUNT(id) AS count_advert,
	   COUNT(days_exposition) AS removal_advert,
	   ROUND(COUNT(days_exposition)::NUMERIC/COUNT(id), 2) AS share_removal_advert,
	   ROUND(AVG(cost_per_square_meter)) AS avg_cost_per_square_meter,
	   ROUND(AVG(total_area)) AS avg_total_area,
	   ROUND(SUM(is_apartment)::NUMERIC/(SELECT SUM(is_apartment) FROM len_obl), 2) AS share_is_apartment,
	   ROUND(SUM(open_plan)::NUMERIC/(SELECT SUM(open_plan) FROM len_obl), 2) AS share_open_plan,
	   ROUND(AVG(days_exposition)::numeric, 2) AS avg_days_exposition,
-- По усредненому значению категоризирую выборку по периоду продаж.
	   CASE 
		  WHEN AVG(days_exposition) BETWEEN 1 AND 30
		    THEN 'до месяца'
		  WHEN AVG(days_exposition) BETWEEN 31 AND 90
		    THEN 'от 1 до 3 месяцев'
		  WHEN AVG(days_exposition) BETWEEN 91 AND 180
		    THEN 'от 3 до 6 месяцев'
		  WHEN AVG(days_exposition) > 180
		    THEN 'от 6 месяцев и более'
		  ELSE 'в продаже'
		END AS sales_period
FROM len_obl
GROUP BY city
-- Оставляю населенные пункты, где количество объявлений 20 штук и более.
-- Такая выборка будет содержать 80% от всех объявлений Ленинградской области.
-- В такой диапозон попадут населенные пункты, где количество объявлений немного по сравнению с топ-3,
-- но недвижимость продается там быстрее.
HAVING COUNT(id) >= 20
ORDER BY count_advert DESC;



