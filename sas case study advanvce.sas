options compress=yes symbolgen mprint mlogic;


/* ________________________Data Pepration for analysis___________________________________________ */

%let path = /folders/myshortcuts/myfolder/sas master case study 2 ;
%macro importcsv(dataset,newdatasetname);
proc import datafile="&path./&dataset..csv"
dbms = csv replace
out= &newdatasetname. ;
getnames = yes ;
guessingrows= 10000;
run;
%mend;


%macro appending(newdatasetname,dataset_to_append);
proc append base=&newdatasetname data=&dataset_to_append;
run;
%mend;

%importcsv(laptops,laptops);
%importcsv(london_postal_codes,london_postal_codes);
%importcsv(store_locations,store_locations);
%importcsv(pos_q1,pos_q1);
%importcsv(pos_q2,pos_q2);
%importcsv(pos_q3,pos_q3);
%importcsv(pos_q4,pos_q4);
%appending(pos_data,pos_q1);
%appending(pos_data,pos_q2);
%appending(pos_data,pos_q3);
%appending(pos_data,pos_q4);

data london_postal_codes1 ;
set london_postal_codes;
rename os_x = customer_x os_y = customer_y;
run;

data store_locations1 ;
set store_locations ;
rename os_x = store_x os_y = store_y;
run;

proc sql;
create table laptop_dataset as
select a.*,b.customer_x,b.customer_y,c.store_x,c.store_y,d.* from pos_data as a
left join london_postal_codes1 as b on a.customer_postcode = b.postcode 
left join store_locations1 as c on a.store_postcode =c.postcode  
left join laptops as d on a.configuration = d.configuration ;
quit;

data laptop_dataset1;
set laptop_dataset ;
distance = round((sqrt(((store_x - customer_x)**2)+((store_y -customer_y)**2)))/1000,.01);
if retail_price = . then delete; 
run;

proc format ;
value montha
1 ='Jan'
2= 'Feb'
3 = 'Mar'
4 = 'Apr'
5 ='May'
6 ='Jun'
7 ='Jul'
8 = 'Aug'
9 ='Sep'
10= 'Oct'
11 ='Nov'
12='Dec' ;
run;

/* store_location data of postcode S1P3AU is missing */

/* _______________________________________________________________________________________ */


/* ________________________PRICING – What effects changes in Prices?___________________________ */

/* ⦁      Does laptop price change with time? 
(Remember you define time element and can choose between quarters/months/weekdays/etc) */
data laptop_dataset2;
set laptop_dataset1 ;
quarter = qtr(datepart(date));
format month montha. ;
run;


ods excel file="&path./report.xls";
proc tabulate data = laptop_dataset2  ;
class quarter month configuration ;
var retail_price ;
table configuration*mean=' ',retail_price*quarter*month ;
run;
ods excel close;

/*yes average price of laptop changes with time
their is price drop of $5 every month for each model also there is huge drop(about ~15%) in end of each quarter due to discounts given by stores
*/


                    /* _______________________________________________________________ */


/* ⦁	Are prices consistent across retail outlets? Do stores with lower average pricing also sell more? */
proc tabulate data=laptop_dataset2 ;
class store_postcode  month ;
var retail_price  ;
table store_postcode,retail_price= 'average_retail_price by month'*(mean=' ' )*month=' ' retail_price='average retail price'*mean=' ' retail_price='count of configuration sold'*N=' ' ;
run;

/* price over retail outlets are consistent except CR78LE,E78NW,N31DH,SW1P3AU and W43PH .These stores are offering 30% discount across all models at the end of each quarter(ie. in month March,June,September and December ) */

 



/* ⦁	How does configuration effect laptop prices? */
proc tabulate data=laptop_dataset2 ;
class configuration  month ;
var retail_price  ;
table configuration,retail_price= 'average_retail_price by month'*(mean=' ')*month=' ' retail_price='average retail price'*mean=' '  ;
run;
/*  The price variation across different configuration is about ~65% and the variation increases over period of time(JAN  to DEC) */
 


/* __________________________________________________________________________________________________ */


/* LOCATION – How does location influence Sales? */
/* (For this create the distance between Customer and Store using the Euclidean distance formula as follows: */
   


/* ⦁	How far do customers travel to buy their laptops? */


/* for seeing how far a customer can travel and how total volume of sales is affected by distance */
data laptop_dataset3 ;
set laptop_dataset1 ;
distance1 = round(distance);
run;


proc tabulate data= laptop_dataset3 out = distance_data(drop =_type_ _page_);
class store_postcode distance1 ;
var distance retail_price ;
table store_postcode,distance1='percentage of customers by distance'*pctn=' ' distance='avg distance travel b y a customer'*mean=' ' ;
table store_postcode,distance1*retail_price*(sum 
         reppctsum='percentage of sum') retail_price*sum;
run;

proc means data = distance_data nway ;
var  pctn_00 pctsum ;
output out = agg_distance_data(drop = _type_ _freq_) 
sum = sum_pctn_00 sum_pctsum;
class distance1 ;
run;

data  percentages_of_customer_sales(drop = sum_pctn_00 sum_pctsum) ;
set  agg_distance_data ;
running_per_of_no_of_customers + sum_pctn_00 ;
running_per_of_sales+ sum_pctsum ;
run;

/* infrence -Customer can travel maximum distance 20 km
 94% customers can travel only 7 km and 94% revenue is generated by customers in 7km */








/* ⦁	Does store proximity to customers help in increasing sales of the stores? */


/* for checking proximity */
proc tabulate data= laptop_dataset1  out=store_postcode_data(drop= _type_ _page_ _table_) ;
class store_postcode ;
var distance retail_price ;
table store_postcode,distance='avg distance travell by customer'*(mean=' ') retail_price='percentage of sale'*(colpctsum=' ');
title 'Average distance travel by customer for a store and contrubution of store to total sales';
footnote 'proximity to customer helps in increase in sales of store ';
run;

/* infrence - yes proximity helps in increasing sales of the stores
for the stores generating high revenue average distance travel by customer is small */

/* __________________________________OTHER QUESTIONS_______________________________ */
/* 1.	Which stores are selling the most? Is there any relationship between sales revenue and sales volume? */

/* for contribution of store towards sales */
proc sort data=store_postcode_data(drop=distance_mean);
by descending pctsum;
run; 


data running_of_sales ;
set store_postcode_data;
total + pctsum ;
run; 

/* 71% of total revenue is generated by these 5 stores(SW1P3AU-19%,SE12BN-16%,SW1V4QQ-15%,NW52QH-11%,E20RY-10%) */






/* relationship between sale revenue and sales volume */
proc tabulate data=laptop_dataset1;
class store_postcode;
var retail_price ;
table store_postcode,retail_price='total sale revenue by store'*sum=' ' retail_price='total volume by stores'*n='';
title 'total sale revenue and total volume of sales by store_postcode';
footnote 'higher the volume of sales higher is the sales revenue';
run;


/* higher the volume of sales higher is the sales revenue */





/* 2.	How do different configuration features effect prices of laptops? */
%macro soting(columnname);
proc sort data=laptop_dataset(keep= &columnname) nodupkey out=&columnname;
by &columnname ;
run;
%mend; 

proc contents data=laptops ;
run;

%soting(Battery_Life__Hours_);
%soting(HD_Size__GB_);
%soting(Processor_Speeds__GHz_);
%soting(RAM__GB_);
%soting(Screen_Size__Inches_);



proc format ;
value batery 
4 ='low'
5 ='medium'
6='large';

value hdsize
40 = 'very small'
80 ='small size'
120 ='medium size'
300 ='large size';

value processor
1.5 ='low speed'
2 ='medium speed'
2.4 = 'high speed';

value ram
1 ='small ram'
2 ='medium ram'
4 ='large ram';

value screen
15 ='small screen'
17 = 'large screen';
run;


data laptop_dataset4;
set laptop_dataset;
format Battery_Life__Hours_ batery. 
HD_Size__GB_ hdsize.
Processor_Speeds__GHz_ processor.
RAM__GB_ ram.
Screen_Size__Inches_ screen.;
run;

proc means data=laptop_dataset4 mean sum ;
class Battery_Life__Hours_ HD_Size__GB_ Processor_Speeds__GHz_ RAM__GB_ Screen_Size__Inches_;
var retail_price;
title 'avg price and total revenue by different configuration types';
footnote 'configuration matters alot for pricing of laptops';
run;

/* price of positively correlated with configurations features.features plays an important role in pricing */


