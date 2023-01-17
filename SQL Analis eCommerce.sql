--Create Table
create table customers_dataset (
	customer_id varchar,
	customer_unique_id varchar,
	customer_zip_code_prefix varchar,
	customer_city varchar,
	customer_state varchar
);

create table geolocation_dataset (
	geo_zip_code_prefix varchar,
	geo_lat varchar,
	geo_lng varchar,
	geo_city varchar,
	geo_state varchar
);


create table order_items_dataset (
	order_id varchar,
	order_item_id varchar,
	product_id varchar,
	seller_id varchar,
	shipping_limit_date timestamp,
	price float,
	freight_value float
);

create table order_payments_dataset (
	order_id varchar(250),
	payment_sequential int,
	payment_type varchar(250),
	payment_installment int,
	payment_value float
);


create table order_reviews_dataset (
	review_id varchar,
	order_id varchar,
	review_score int, 
	review_comment_title varchar,
	review_comment_message text,
	review_creation_date timestamp,
	review_answer timestamp
);

create table orders_dataset (
	order_id varchar,
	customers_id varchar,
	order_status varchar,
	order_purchase_timestamp timestamp,
	order_approved_at timestamp,
	order_delivered_carrier_date timestamp,
	order_delivered_customer_date timestamp,
	order_estimated_delivered_date timestamp
);

create table product_dataset (
    	no_prod varchar,
	product_id varchar,
	product_category_name varchar,
	product_name_length float,
	product_description_length float,
	product_photos_qty float,
	product_weight_g float,
	product_length_cm float,
	product_height_cm float,
	product_width_cm float
);

create table sellers_dataset (
	seller_id varchar,
	seller_zip_code varchar,
	seller_city varchar,
	seller_state varchar
);

--Monthly Active User
with
mau_yearmonth as (
    select 
	    date_part('year', o.order_purchase_timestamp) as year,
	    date_part('month', o.order_purchase_timestamp) as month,
	    count(distinct cd.customer_unique_id) as mau
    from orders_dataset as o 
    join customers_dataset as cd on o.customer_id = cd.customer_id
    group by 1,2 
)
select 
	year, avg(mau)
from mau_yearmonth
group by 1

-- Cust Baru tiap Tahun
with
new_cust as(
    select 
        c.customer_unique_id,
        min(o.order_purchase_timestamp) as first_purchase_time
    from orders_dataset o 
    join customers_dataset c on c.customer_id = o.customer_id
    group by 1
)
select 
	date_part('year', first_purchase_time) as year,
	count(1) as new_customers
from new_cust
group by 1
order by 1

-- RO
with 
repeat_o as(
    select 
        date_part('year', o.order_purchase_timestamp) as year,
        c.customer_unique_id,
        count(1) as repeat_order
    from orders_dataset o 
    join customers_dataset c on c.customer_id = o.customer_id
    group by 1, 2
    having count(1) > 1
)
select 
	year, 
	count(distinct customer_unique_id) as repeating_customers
from repeat_o
group by 1


-- Avg Order Tiap Tahun
with
freq_p as(
    select 
        date_part('year', o.order_purchase_timestamp) as year,
        c.customer_unique_id,
        count(1) as frequency_purchase
    from orders_dataset o 
    join customers_dataset c on c.customer_id = o.customer_id
    where Order_status != 'canceled'
    group by 1, 2
)
select 
	year, 
	round(avg(frequency_purchase),3) as avg_purchase 
from freq_p
group by 1
order by 1


-- Gabungan table
with 
activeuser as(
    with
    mau_yearmonth as (
        select 
            date_part('year', o.order_purchase_timestamp) as year,
            date_part('month', o.order_purchase_timestamp) as month,
            count(distinct cd.customer_unique_id) as mau
        from orders_dataset as o 
        join customers_dataset as cd on o.customer_id = cd.customer_id
        group by 1,2 
    )
    select 
        year, avg(mau) as avg_mau
    from mau_yearmonth
    group by 1
),
newcust as(

    with
    new_cust as(
        select 
            c.customer_unique_id,
            min(o.order_purchase_timestamp) as first_purchase_time
        from orders_dataset o 
        join customers_dataset c on c.customer_id = o.customer_id
        group by 1
    )
    select 
        date_part('year', first_purchase_time) as year,
        count(1) as new_customers
    from new_cust
    group by 1
    order by 1
),
repeatorder as(
    with 
    repeat_o as(
        select 
            date_part('year', o.order_purchase_timestamp) as year,
            c.customer_unique_id,
            count(1) as repeat_order
        from orders_dataset o 
        join customers_dataset c on c.customer_id = o.customer_id
        group by 1, 2
        having count(1) > 1
    )
    select 
        year, 
        count(distinct customer_unique_id) as repeating_customers
    from repeat_o
    group by 1
),
avgfreq as( 
    with
    freq_p as(
        select 
            date_part('year', o.order_purchase_timestamp) as year,
            c.customer_unique_id,
            count(1) as frequency_purchase
        from orders_dataset o 
        join customers_dataset c on c.customer_id = o.customer_id
        where Order_status != 'canceled'
        group by 1, 2
    )
    select 
        year, 
        round(avg(frequency_purchase),3) as avg_purchase 
    from freq_p
    group by 1
    order by 1
)
select 
    au.year,
    au.avg_mau,
    nc.new_customers,
    ro.repeating_customers,
    af.avg_purchase
from activeuser as au
join newcust as nc on au.year=nc.year
join repeatorder as ro on ro.year=au.year
join avgfreq as af on af.year=au.year

-- Revenue per tahun
with
order_deliv as(
    select 
        order_id,
        date_part('year', order_purchase_timestamp) as year,
        order_status
    from orders_dataset 
    where order_status = 'delivered'
),
order_revenue as (
    select 
        order_id,
        sum(price+freight_value) as total
    from order_items_dataset 
    group by 1
)
select 
    od.year,
    sum(rev.total) as Revenue
from order_deliv as od
join order_revenue as rev on od.order_id =rev.order_id
group by 1
order by 1


-- Cancel Order Pertahun
select 
    date_part('year', order_purchase_timestamp) as year,
    count(order_id) as canceled
from orders_dataset 
where order_status = 'canceled'
group by 1


-- Kategori Revenue tertinggi 
with 
    rank_category as (
    select 
        date_part('year', od.order_purchase_timestamp) as year,
        sum(oi.price+oi.freight_value) as revenue,    
        pd.product_category_name as top_category,
        rank() OVER (PARTITION BY date_part('year', od.order_purchase_timestamp)  ORDER BY sum(oi.price+oi.freight_value) DESC) as rank_cat
    from order_items_dataset as oi
    join orders_dataset as od on oi.order_id = od.order_id
    join product_dataset as pd on oi.product_id=pd.product_id
    where order_status = 'delivered'
    group by 1,3
    order by 1, 2 desc
    )
    select 
        year,
        revenue,
        top_category,
        rank_cat
    from rank_category
    where rank_cat=1


-- Kategori Cancel terbanyak pertahunnya
with
    rank_cancel as(
        select 
            date_part('year', od.order_purchase_timestamp) as year,
            count(od.order_id) as cancel,    
            pd.product_category_name as top_cancel,
            rank() OVER (PARTITION BY date_part('year', od.order_purchase_timestamp)  ORDER BY count(od.order_id) DESC) as rank_can
        from order_items_dataset as oi
        join orders_dataset as od on oi.order_id = od.order_id
        join product_dataset as pd on oi.product_id=pd.product_id
        where order_status = 'canceled'
        group by 1,3
        order by 1, 2 desc
    )
    select * from rank_cancel
    where rank_can =1


--- Gabungan table
with
revenue as(
    with
    order_deliv as(
        select 
            order_id,
            date_part('year', order_purchase_timestamp) as year,
            order_status
        from orders_dataset 
        where order_status = 'delivered'
    ),
    order_revenue as (
        select 
            order_id,
            sum(price+freight_value) as total
        from order_items_dataset 
        group by 1
    )
    select 
        od.year as year,
        sum(rev.total) as Revenue
    from order_deliv as od
    join order_revenue as rev on od.order_id =rev.order_id
    group by 1
    order by 1
),
--------------
cancel as(
    select 
        date_part('year', order_purchase_timestamp) as year,
        count(order_id) as canceled
    from orders_dataset 
    where order_status = 'canceled'
    group by 1
),
-------------
top_category as(
    with 
    rank_category as (
    select 
        date_part('year', od.order_purchase_timestamp) as year,
        sum(oi.price+oi.freight_value) as revenue,    
        pd.product_category_name as top_category,
        rank() OVER (PARTITION BY date_part('year', od.order_purchase_timestamp)  ORDER BY sum(oi.price+oi.freight_value) DESC) as rank_cat
    from order_items_dataset as oi
    join orders_dataset as od on oi.order_id = od.order_id
    join product_dataset as pd on oi.product_id=pd.product_id
    where order_status = 'delivered'
    group by 1,3
    order by 1, 2 desc
    )
    select 
        year,
        revenue,
        top_category,
        rank_cat
    from rank_category
    where rank_cat=1 
),
top_cancel as (
    with
    rank_cancel as(
        select 
            date_part('year', od.order_purchase_timestamp) as year,
            count(od.order_id) as cancel,    
            pd.product_category_name as top_cancel,
            rank() OVER (PARTITION BY date_part('year', od.order_purchase_timestamp)  ORDER BY count(od.order_id) DESC) as rank_can
        from order_items_dataset as oi
        join orders_dataset as od on oi.order_id = od.order_id
        join product_dataset as pd on oi.product_id=pd.product_id
        where order_status = 'canceled'
        group by 1,3
        order by 1, 2 desc
    )
    select * from rank_cancel
    where rank_can =1
)
select
    rev.year,
    rev.Revenue as total_revenue,
    canceled as total_cancel,
    top_category as top_category_name,
    tc.revenue as top_category_revenue,
    top_cancel as top_cancel_category,
    tcan.cancel as total_cancel_category
    
from revenue as rev
join cancel as can on rev.year = can.year
join top_category as tc on rev.year = tc.year
join top_cancel as tcan on rev.year = tcan.year
    


--- Ranking type payment
select 
	payment_type,
	count(payment_type) as qty
from order_payments_dataset
group by 1
order by 2 desc

--- detail type payment
with
payment_type as(
    select 
        date_part('year', od.order_purchase_timestamp) as year,
        payment_type,
        count(payment_type) as qty
    from order_payments_dataset as op
    join orders_dataset as od on op.order_id=od.order_id
    group by 1,2
    order by 3 desc
)
select 
    payment_type,
    sum(case when year = '2016' then qty else 0 end) as year_2016,
    sum(case when year = '2017' then qty else 0 end) as year_2017,
    sum(case when year = '2018' then qty else 0 end) as year_2018
from payment_type
group by 1
