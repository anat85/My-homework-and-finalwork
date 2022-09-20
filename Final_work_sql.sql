
1. В каких городах больше одного аэропорта?

SELECT distinct (a.city) -- выводим уникальное значение города 
FROM airports a -- обращаемся к таблице airports
group by a.city -- группируем по городу
having count(*) > 1 -- фильтруем города, значения которых больше 1 

2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select distinct (a1.airport_name) -- выводим уникальные значения имени аэропорта
from (
    select max("range"), aircraft_code -- данным подзапросом выводим самую максимальную дальность полета
	from aircrafts
	group by "range", aircraft_code 
	order by "range" desc
	limit 1) a 
join flights f using (aircraft_code) -- присоединяем табличку flights, так как нет прямой связи с таблицей airports
join airports a1 on f.departure_airport = a1.airport_code   -- присоединяем таблицу airports, так как нам нужна колонка названия аэропорта

	
3. Вывести 10 рейсов с максимальным временем задержки вылета

select flight_id, departure_airport, arrival_airport, aircraft_code, -- выводим необходимые нам строки
(actual_departure - scheduled_departure) as "departure delay time"
from flights f -- смотрим таблицу flights
order by "departure delay time" 
limit 10 -- сортируем от большего к меньшему разницу во времени с лимитом в 10

4. Были ли брони, по которым не были получены посадочные талоны?

select b.book_ref, bp.boarding_no  -- выводим необходимые колонки
from bookings b -- начинаем с таблицы bookings 
left join tickets t using (book_ref) -- делаем левое соединение, чтобы к брони привязать номер билета
left join boarding_passes bp using (ticket_no) -- по номеру билета выходим на посадочные талоны
where bp.boarding_no is null --фильтруем посадочные талоны по значению null

5. Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров 
из каждого аэропорта на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - 
сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.  

select t2.flight_id, t2.occupied_seats, t2.aircraft_code, t2.total_number, round((t2.total_number-t2.occupied_seats)/t2.total_number::numeric*100) as "%_available_seats",
    t2.total_number-t2.occupied_seats as available_seats,t2.actual_departure::date, t2.departure_airport, 
    sum(t2.occupied_seats) over (partition by t2.actual_departure::date, t2.departure_airport order by t2.actual_departure, t2.departure_airport) as every_day_airport
from 
	(select distinct bp.flight_id, count(bp.seat_no) over (partition by f.flight_id)  as occupied_seats, f.aircraft_code, 
	    t.total_number, round(count(bp.seat_no) over (partition by f.flight_id::numeric)/t.total_number::numeric * 100, 1) as percentage_ratio,
	    f.actual_departure, f.departure_airport  
	from flights f--берем данные из таблицы flights
	join boarding_passes bp  using (flight_id)--соединяем данные таблицы, для того, чтобы добавить в таблицу места
	left join (select aircraft_code, count(seat_no) as total_number--здесь мы уже имеем цель соединить места согласно рейсам
	      from seats-- в данном селекте выводим общее количество мест по модели самолета
	      group by aircraft_code 
	      ) t on f.aircraft_code = t.aircraft_code
	order by  bp.flight_id) t2--сортируем по рейсу 
order by 7, 8, 9  --для того, чтобы вывести every_day_airport




6. Найдите процентное соотношение перелетов по типам самолетов от общего количества

select t.model, count(t.qty_all_aircrafts) as qty_all_aircrafts, round((count(t.qty_all_aircrafts)/t.all_flights::numeric)*100, 2) as percent_flights -- здесь выводим %-е соотношение
	from 
		(select a.model, count(aircraft_code) as qty_all_aircrafts, 
		count(f.flight_id) over (order by count(aircraft_code)) as all_flights
		from flights f
		join aircrafts a using (aircraft_code) 
		group by aircraft_code, a.model, f.flight_id) t -- в данном селекте выводим общее количество полетов, 
		-- с соединенными таблицами и нужными выведенными столбцами 
group by t.model, t.qty_all_aircrafts, t.all_flights 	

	
7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with cte1 as (
	select flight_id, array_agg(max_amount::int)  as amount1, array_agg(min_amount::int) as amount, array_agg(fare_conditions order by fare_conditions) as fare_conditions 
--выводим массивы, чтоб в будущем сравнить min ст-ть бизнес с max ст-тью эконом классов
				from (
					select flight_id, fare_conditions, max(amount) as max_amount, min(amount) as min_amount
					from ticket_flights  --в данном селекте отсекаем класс Comfort и выводим максимальные и минимальные стоимости классов
					where fare_conditions != 'Comfort'
					group by flight_id, fare_conditions
					order by flight_id) t
   group by flight_id 	
),  cte2 as (--присоединили таблицу flights 
		select c.flight_id, c.fare_conditions, c.amount, c.amount1, f.departure_airport 
		from cte1 c -- из сте1 выводим необходимые столбцы и джойним с flights, чтобы связать с аэропортом отправления
		left join flights f on c.flight_id = f.flight_id 	 
)
select distinct a.city, c2.amount, c2.amount1, c2.flight_id, c2.fare_conditions
from cte2 c2  
left join airports a on c2.departure_airport = a.airport_code -- джойним, чтоб вывести города
where c2.amount[1] < c2.amount1[2]--условие, где min стоимость бизнесс класса меньше max стоимости эконом класса
group by a.city, c2.flight_id, c2.fare_conditions, c2.amount, c2.amount1
order by c2.flight_id		



8. Между какими городами нет прямых рейсов? 


create view no_flights as
	select concat(t.city,'-', t.city1) as no_flights
	from (
		select a.city, a2.city as city1 
		from airports a --в данном селекте выводим декартово произведение городов без повторов города слева и справа
		cross join airports a2
		where a.city != a2.city) t
	join airports a3 on a3.city = t.city--соединяем с airports, чтобы вывести и привязать код аэропорта к городу
	except --применяем данный оператор, чтобы вычесть из общей пары городов пары городов, между которыми есть перелеты, соответственно остаются те пары, где нет перелетов
	select concat(t2.city2, '-', a4.city) --объединяем город по аэропорту отправления с городом по аэропорту прибытия
	from (
		select f.departure_airport, f.arrival_airport, a1.city  as city2
		from flights f -- в данном селекте выводим эропорты отправления и прибытия, и джойним с airports, чтобы вывести на них города по эропорту отправления
		join airports a1 on f.departure_airport = a1.airport_code ) t2
	join airports a4 on t2.arrival_airport = a4.airport_code--здесь джойним, чтобы вывести города по аэропорту прибытия  


  9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  
в самолетах, обслуживающих эти рейсы

select t.departure_airport, t.arrival_airport, t.aircraft_code, t.distance, a3."range", 
	case 
		when a3."range"/t.distance > 2 then 'short flight'
		else 'long flight'--используем кейс, чтобы сравнить расстояние полета с мах дальностью полета
	end	
from (
	select t.departure_airport, t.arrival_airport, t.aircraft_code,
		acos(sin(RADIANS(t.latitude))*sin(RADIANS(a2.latitude)) + cos(RADIANS(t.latitude))*cos(RADIANS(a2.latitude))*cos(RADIANS(t.longitude-a2.longitude)))*6371 as distance 
	from ( -- в данном селекте выводим расстояние между аэропортами
		select distinct f.departure_airport, f.arrival_airport, f.aircraft_code,  a.longitude, a.latitude
		from flights f --основная цель данного селекта соединить две таблицы, чтоб вывести ширину и долготу в соответствии с уникальной цепочкой аэропорт вылета и прилета
		join airports a on f.departure_airport = a.airport_code 
		order by f.departure_airport) t
	join airports a2 on t.arrival_airport = a2.airport_code ) t 
join aircrafts a3 on t.aircraft_code = a3.aircraft_code --соединяем, чтобы вывести мах дальность в соответствии с моделью самолета



	

	
