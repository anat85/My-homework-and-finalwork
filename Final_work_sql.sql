
1. � ����� ������� ������ ������ ���������?

SELECT distinct (a.city) -- ������� ���������� �������� ������ 
FROM airports a -- ���������� � ������� airports
group by a.city -- ���������� �� ������
having count(*) > 1 -- ��������� ������, �������� ������� ������ 1 

2. � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������?

select distinct (a1.airport_name) -- ������� ���������� �������� ����� ���������
from (
    select max("range"), aircraft_code -- ������ ����������� ������� ����� ������������ ��������� ������
	from aircrafts
	group by "range", aircraft_code 
	order by "range" desc
	limit 1) a 
join flights f using (aircraft_code) -- ������������ �������� flights, ��� ��� ��� ������ ����� � �������� airports
join airports a1 on f.departure_airport = a1.airport_code   -- ������������ ������� airports, ��� ��� ��� ����� ������� �������� ���������

	
3. ������� 10 ������ � ������������ �������� �������� ������

select flight_id, departure_airport, arrival_airport, aircraft_code, -- ������� ����������� ��� ������
(actual_departure - scheduled_departure) as "departure delay time"
from flights f -- ������� ������� flights
order by "departure delay time" 
limit 10 -- ��������� �� �������� � �������� ������� �� ������� � ������� � 10

4. ���� �� �����, �� ������� �� ���� �������� ���������� ������?

select b.book_ref, bp.boarding_no  -- ������� ����������� �������
from bookings b -- �������� � ������� bookings 
left join tickets t using (book_ref) -- ������ ����� ����������, ����� � ����� ��������� ����� ������
left join boarding_passes bp using (ticket_no) -- �� ������ ������ ������� �� ���������� ������
where bp.boarding_no is null --��������� ���������� ������ �� �������� null

5. ������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
�������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� 
�� ������� ��������� �� ������ ����. �.�. � ���� ������� ������ ���������� ������������� ����� - 
������� ������� ��� �������� �� ������� ��������� �� ���� ��� ����� ������ ������ � ������� ���.  

select t2.flight_id, t2.occupied_seats, t2.aircraft_code, t2.total_number, round((t2.total_number-t2.occupied_seats)/t2.total_number::numeric*100) as "%_available_seats",
    t2.total_number-t2.occupied_seats as available_seats,t2.actual_departure::date, t2.departure_airport, 
    sum(t2.occupied_seats) over (partition by t2.actual_departure::date, t2.departure_airport order by t2.actual_departure, t2.departure_airport) as every_day_airport
from 
	(select distinct bp.flight_id, count(bp.seat_no) over (partition by f.flight_id)  as occupied_seats, f.aircraft_code, 
	    t.total_number, round(count(bp.seat_no) over (partition by f.flight_id::numeric)/t.total_number::numeric * 100, 1) as percentage_ratio,
	    f.actual_departure, f.departure_airport  
	from flights f--����� ������ �� ������� flights
	join boarding_passes bp  using (flight_id)--��������� ������ �������, ��� ����, ����� �������� � ������� �����
	left join (select aircraft_code, count(seat_no) as total_number--����� �� ��� ����� ���� ��������� ����� �������� ������
	      from seats-- � ������ ������� ������� ����� ���������� ���� �� ������ ��������
	      group by aircraft_code 
	      ) t on f.aircraft_code = t.aircraft_code
	order by  bp.flight_id) t2--��������� �� ����� 
order by 7, 8, 9  --��� ����, ����� ������� every_day_airport




6. ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������

select t.model, count(t.qty_all_aircrafts) as qty_all_aircrafts, round((count(t.qty_all_aircrafts)/t.all_flights::numeric)*100, 2) as percent_flights -- ����� ������� %-� �����������
	from 
		(select a.model, count(aircraft_code) as qty_all_aircrafts, 
		count(f.flight_id) over (order by count(aircraft_code)) as all_flights
		from flights f
		join aircrafts a using (aircraft_code) 
		group by aircraft_code, a.model, f.flight_id) t -- � ������ ������� ������� ����� ���������� �������, 
		-- � ������������ ��������� � ������� ����������� ��������� 
group by t.model, t.qty_all_aircrafts, t.all_flights 	

	
7. ���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������?

with cte1 as (
	select flight_id, array_agg(max_amount::int)  as amount1, array_agg(min_amount::int) as amount, array_agg(fare_conditions order by fare_conditions) as fare_conditions 
--������� �������, ���� � ������� �������� min ��-�� ������ � max ��-��� ������ �������
				from (
					select flight_id, fare_conditions, max(amount) as max_amount, min(amount) as min_amount
					from ticket_flights  --� ������ ������� �������� ����� Comfort � ������� ������������ � ����������� ��������� �������
					where fare_conditions != 'Comfort'
					group by flight_id, fare_conditions
					order by flight_id) t
   group by flight_id 	
),  cte2 as (--������������ ������� flights 
		select c.flight_id, c.fare_conditions, c.amount, c.amount1, f.departure_airport 
		from cte1 c -- �� ���1 ������� ����������� ������� � ������� � flights, ����� ������� � ���������� �����������
		left join flights f on c.flight_id = f.flight_id 	 
)
select distinct a.city, c2.amount, c2.amount1, c2.flight_id, c2.fare_conditions
from cte2 c2  
left join airports a on c2.departure_airport = a.airport_code -- �������, ���� ������� ������
where c2.amount[1] < c2.amount1[2]--�������, ��� min ��������� ������� ������ ������ max ��������� ������ ������
group by a.city, c2.flight_id, c2.fare_conditions, c2.amount, c2.amount1
order by c2.flight_id		



8. ����� ������ �������� ��� ������ ������? 


create view no_flights as
	select concat(t.city,'-', t.city1) as no_flights
	from (
		select a.city, a2.city as city1 
		from airports a --� ������ ������� ������� ��������� ������������ ������� ��� �������� ������ ����� � ������
		cross join airports a2
		where a.city != a2.city) t
	join airports a3 on a3.city = t.city--��������� � airports, ����� ������� � ��������� ��� ��������� � ������
	except --��������� ������ ��������, ����� ������� �� ����� ���� ������� ���� �������, ����� �������� ���� ��������, �������������� �������� �� ����, ��� ��� ���������
	select concat(t2.city2, '-', a4.city) --���������� ����� �� ��������� ����������� � ������� �� ��������� ��������
	from (
		select f.departure_airport, f.arrival_airport, a1.city  as city2
		from flights f -- � ������ ������� ������� �������� ����������� � ��������, � ������� � airports, ����� ������� �� ��� ������ �� �������� �����������
		join airports a1 on f.departure_airport = a1.airport_code ) t2
	join airports a4 on t2.arrival_airport = a4.airport_code--����� �������, ����� ������� ������ �� ��������� ��������  


  9. ��������� ���������� ����� �����������, ���������� ������� �������, �������� � ���������� ������������ ���������� ���������  
� ���������, ������������� ��� �����

select t.departure_airport, t.arrival_airport, t.aircraft_code, t.distance, a3."range", 
	case 
		when a3."range"/t.distance > 2 then 'short flight'
		else 'long flight'--���������� ����, ����� �������� ���������� ������ � ��� ���������� ������
	end	
from (
	select t.departure_airport, t.arrival_airport, t.aircraft_code,
		acos(sin(RADIANS(t.latitude))*sin(RADIANS(a2.latitude)) + cos(RADIANS(t.latitude))*cos(RADIANS(a2.latitude))*cos(RADIANS(t.longitude-a2.longitude)))*6371 as distance 
	from ( -- � ������ ������� ������� ���������� ����� �����������
		select distinct f.departure_airport, f.arrival_airport, f.aircraft_code,  a.longitude, a.latitude
		from flights f --�������� ���� ������� ������� ��������� ��� �������, ���� ������� ������ � ������� � ������������ � ���������� �������� �������� ������ � �������
		join airports a on f.departure_airport = a.airport_code 
		order by f.departure_airport) t
	join airports a2 on t.arrival_airport = a2.airport_code ) t 
join aircrafts a3 on t.aircraft_code = a3.aircraft_code --���������, ����� ������� ��� ��������� � ������������ � ������� ��������



	

	
