---
layout: post
title: Leveraging US Census Data in BigQuery
tags: [census, BigQuery, SQL, geocoding, ACS]
---

I've been using Google's cloud services more and more, specifically [BigQuery](https://cloud.google.com/bigquery). Besides the speed of queries and the simple API integration for different languages, like R, BigQuery makes available a large number of public data sets that come in quite handy. Here's a quick guide to leveraging some of the Census data sets with your own data.

Let's say you have a data set that includes locations with longitude and latitude coordinates like so:

| place                                          | longitude   | latitude  |
|------------------------------------------------|-------------|-----------|
| Dodgers Stadium                                | -118.240288 | 34.072578 |
| Citi Field                                     | -73.503273  | 42.81469  |
| Smithsonian National Museum of Natural History | -77.025963  | 38.892071 |
| Disneyland                                     | -117.926399 | 33.815395 |

Now, we would like to get Census tract-level information for each location. This is pretty simple with BigQuery.

## Finding a Location's Census Tract

First, we need to figure out the Census tract for each location. We can use standard geomgraphy functions to see which Census tract each address intersects with. Here's a sample query:

```
SELECT * 
  EXCEPT (internal_point_geo, tract_geom)
FROM `mm-sandbox-decision-sciences.sample_places.sample_places_long_lat` places
JOIN `bigquery-public-data.geo_census_tracts.us_census_tracts_national` as c_us_n
ON ST_CONTAINS(c_us_n.tract_geom, st_geogpoint(places.longitude, places.latitude))
```

We need to make the long/lat for each of our locations a geography object (specifically, a point) and then we join the `us_census_tracts_national` table to our locations based on which tract (based on `tract_geom`) each point intersects with.

*Note that we exclude two columns from our output (another convenient feature of BigQuery's syntax)*

Here's what the results look like:

| place                                          | longitude   | latitude  | state_name           | state_fips_code | county_fips_code | tract_ce | geo_id      | tract_name | lsad_name            | functional_status | area_land_meters | area_water_meters | internal_point_lat | internal_point_lon |
| ---------------------------------------------- | ----------- | --------- | -------------------- | --------------- | ---------------- | -------- | ----------- | ---------- | -------------------- | ----------------- | ---------------- | ----------------- | ------------------ | ------------------ |
| Citi Field                                     | -73.503273  | 42.81469  | New York             | 36              | 083              | 051800   | 36083051800 | 518        | Census Tract 518     | S                 | 159662573        | 8309272           | +42.8663030        | -073.5166161       |
| Smithsonian National Museum of Natural History | -77.025963  | 38.892071 | District of Columbia | 11              | 001              | 006202   | 11001006202 | 62.02      | Census Tract 62.02   | S                 | 6539769          | 4970897           | +38.8809933        | -077.0363219       |
| Dodgers Stadium                                | -118.240288 | 34.072578 | California           | 06              | 037              | 980010   | 06037980010 | 9800.10    | Census Tract 9800.10 | S                 | 3757605          | 76091             | +34.0786807        | -118.2395140       |
| Disneyland                                     | -117.926399 | 33.815395 | California           | 06              | 059              | 980000   | 06059980000 | 9800       | Census Tract 9800    | S                 | 2766486          | 0                 | +33.8096249        | -117.9186718       |

The key here is the `geo_id`. We can use that to join in information from the [American Community Survey (ACS)](https://www.census.gov/programs-surveys/acs) for each of our locations based on their Census tract.

## Joining ACS Data

Now that we know which Census tracts our locations belong to we can pull in lots of rich information from the ACS. All we need is to reference the right ACS table (found withing the `census_bureau_acs` dataset), as there are various levels represented there (e.g. census tracts, census blocks, counties, etc.), and join based on the `geo_id`.

Here's the full query, combining both elements:

```
SELECT * 
  EXCEPT (internal_point_geo, tract_geom)
FROM `mm-sandbox-decision-sciences.sample_places.sample_places_long_lat` places
JOIN `bigquery-public-data.geo_census_tracts.us_census_tracts_national` as c_us_n
ON ST_CONTAINS(c_us_n.tract_geom, st_geogpoint(places.longitude, places.latitude))
JOIN `bigquery-public-data.census_bureau_acs.censustract_2018_5yr` as ctract
ON c_us_n.geo_id = ctract.geo_id
```

And here's the output for one location (json just to make it easier to read here):

```
[
  {
    "place": "Dodgers Stadium",
    "longitude": "-118.240288",
    "latitude": "34.072578",
    "state_name": "California",
    "state_fips_code": "06",
    "county_fips_code": "037",
    "tract_ce": "980010",
    "geo_id": "06037980010",
    "tract_name": "9800.10",
    "lsad_name": "Census Tract 9800.10",
    "functional_status": "S",
    "area_land_meters": "3757605",
    "area_water_meters": "76091",
    "internal_point_lat": "+34.0786807",
    "internal_point_lon": "-118.2395140",
    "geo_id_1": "06037980010",
    "do_date": "2014-01-01",
    "total_pop": "189.0",
    "households": "69.0",
    "male_pop": "96.0",
    "female_pop": "93.0",
    "median_age": "44.4",
    "male_under_5": "5.0",
    "male_5_to_9": "0.0",
    "male_10_to_14": "0.0",
    "male_15_to_17": "0.0",
    "male_18_to_19": "0.0",
    "male_20": "0.0",
    "male_21": "1.0",
    "male_22_to_24": "0.0",
    "male_25_to_29": "0.0",
    "male_30_to_34": "5.0",
    "male_35_to_39": "13.0",
    "male_40_to_44": "12.0",
    "male_45_to_49": "17.0",
    "male_50_to_54": "0.0",
    "male_55_to_59": "5.0",
    "male_60_to_61": "0.0",
    "male_62_to_64": "7.0",
    "male_65_to_66": "5.0",
    "male_67_to_69": "6.0",
    "male_70_to_74": "0.0",
    "male_75_to_79": "5.0",
    "male_80_to_84": "5.0",
    "male_85_and_over": "10.0",
    "female_under_5": "0.0",
    "female_5_to_9": "0.0",
    "female_10_to_14": "17.0",
    "female_15_to_17": "32.0",
    "female_18_to_19": "0.0",
    "female_20": "0.0",
    "female_21": "0.0",
    "female_22_to_24": "0.0",
    "female_25_to_29": "0.0",
    "female_30_to_34": "0.0",
    "female_35_to_39": "0.0",
    "female_40_to_44": "19.0",
    "female_45_to_49": "0.0",
    "female_50_to_54": "0.0",
    "female_55_to_59": "5.0",
    "female_60_to_61": "5.0",
    "female_62_to_64": "0.0",
    "female_65_to_66": "0.0",
    "female_67_to_69": "5.0",
    "female_70_to_74": "0.0",
    "female_75_to_79": "5.0",
    "female_80_to_84": "5.0",
    "female_85_and_over": "0.0",
    "white_pop": "45.0",
    "population_1_year_and_over": "189.0",
    "population_3_years_over": "184.0",
    "pop_5_years_over": null,
    "pop_15_and_over": null,
    "pop_16_over": "151.0",
    "pop_25_years_over": "134.0",
    "pop_25_64": "88.0",
    "pop_never_married": null,
    "pop_now_married": null,
    "pop_separated": null,
    "pop_widowed": null,
    "pop_divorced": null,
    "not_us_citizen_pop": "43.0",
    "black_pop": "2.0",
    "asian_pop": "25.0",
    "hispanic_pop": "117.0",
    "amerindian_pop": "0.0",
    "other_race_pop": "0.0",
    "two_or_more_races_pop": "0.0",
    "hispanic_any_race": "117.0",
    "not_hispanic_pop": "72.0",
    "asian_male_45_54": "0.0",
    "asian_male_55_64": "5.0",
    "black_male_45_54": "0.0",
    "black_male_55_64": "0.0",
    "hispanic_male_45_54": "17.0",
    "hispanic_male_55_64": "0.0",
    "white_male_45_54": "0.0",
    "white_male_55_64": "7.0",
    "median_income": null,
    "income_per_capita": "15788.0",
    "income_less_10000": "27.0",
    "income_10000_14999": "9.0",
    "income_15000_19999": "5.0",
    "income_20000_24999": "5.0",
    "income_25000_29999": "0.0",
    "income_30000_34999": "5.0",
    "income_35000_39999": "0.0",
    "income_40000_44999": "9.0",
    "income_45000_49999": "0.0",
    "income_50000_59999": "0.0",
    "income_60000_74999": "0.0",
    "income_75000_99999": "0.0",
    "income_100000_124999": "5.0",
    "income_125000_149999": "0.0",
    "income_150000_199999": "0.0",
    "income_200000_or_more": "4.0",
    "pop_determined_poverty_status": "189.0",
    "poverty": "136.0",
    "gini_index": "0.7086",
    "housing_units": "69.0",
    "renter_occupied_housing_units_paying_cash_median_gross_rent": null,
    "owner_occupied_housing_units_lower_value_quartile": "785300.0",
    "owner_occupied_housing_units_median_value": "875000.0",
    "owner_occupied_housing_units_upper_value_quartile": "964700.0",
    "occupied_housing_units": "69.0",
    "housing_units_renter_occupied": "36.0",
    "vacant_housing_units": "0.0",
    "vacant_housing_units_for_rent": "0.0",
    "vacant_housing_units_for_sale": "0.0",
    "dwellings_1_units_detached": "28.0",
    "dwellings_1_units_attached": "22.0",
    "dwellings_2_units": "0.0",
    "dwellings_3_to_4_units": "0.0",
    "dwellings_5_to_9_units": "0.0",
    "dwellings_10_to_19_units": "10.0",
    "dwellings_20_to_49_units": "9.0",
    "dwellings_50_or_more_units": "0.0",
    "mobile_homes": "0.0",
    "housing_built_2005_or_later": "0.0",
    "housing_built_2000_to_2004": "0.0",
    "housing_built_1939_or_earlier": "10.0",
    "median_year_structure_built": "1953.0",
    "married_households": "31.0",
    "nonfamily_households": "38.0",
    "family_households": "31.0",
    "households_public_asst_or_food_stamps": "5.0",
    "male_male_households": "0.0",
    "female_female_households": "0.0",
    "children": "54.0",
    "children_in_single_female_hh": "0.0",
    "median_rent": "1544.0",
    "percent_income_spent_on_rent": "51.0",
    "rent_burden_not_computed": "5.0",
    "rent_over_50_percent": "31.0",
    "rent_40_to_50_percent": "0.0",
    "rent_35_to_40_percent": "0.0",
    "rent_30_to_35_percent": "0.0",
    "rent_25_to_30_percent": "0.0",
    "rent_20_to_25_percent": "0.0",
    "rent_15_to_20_percent": "0.0",
    "rent_10_to_15_percent": "0.0",
    "rent_under_10_percent": "0.0",
    "owner_occupied_housing_units": "33.0",
    "million_dollar_housing_units": "0.0",
    "mortgaged_housing_units": "23.0",
    "different_house_year_ago_different_city": "1.0",
    "different_house_year_ago_same_city": "11.0",
    "families_with_young_children": "5.0",
    "two_parent_families_with_young_children": "5.0",
    "two_parents_in_labor_force_families_with_young_children": "5.0",
    "two_parents_father_in_labor_force_families_with_young_children": "0.0",
    "two_parents_mother_in_labor_force_families_with_young_children": "0.0",
    "two_parents_not_in_labor_force_families_with_young_children": "0.0",
    "one_parent_families_with_young_children": "0.0",
    "father_one_parent_families_with_young_children": "0.0",
    "father_in_labor_force_one_parent_families_with_young_children": "0.0",
    "commute_less_10_mins": "1.0",
    "commute_10_14_mins": "0.0",
    "commute_15_19_mins": "4.0",
    "commute_20_24_mins": "0.0",
    "commute_25_29_mins": "5.0",
    "commute_30_34_mins": "10.0",
    "commute_35_44_mins": "24.0",
    "commute_60_more_mins": "1.0",
    "commute_45_59_mins": "5.0",
    "commuters_16_over": "50.0",
    "walked_to_work": "1.0",
    "worked_at_home": "11.0",
    "no_car": "0.0",
    "no_cars": "9.0",
    "one_car": "10.0",
    "two_cars": "31.0",
    "three_cars": "10.0",
    "four_more_cars": "9.0",
    "aggregate_travel_time_to_work": null,
    "commuters_by_public_transportation": "1.0",
    "commuters_by_bus": "1.0",
    "commuters_by_car_truck_van": "48.0",
    "commuters_by_carpool": "0.0",
    "commuters_by_subway_or_elevated": "0.0",
    "commuters_drove_alone": "48.0",
    "group_quarters": "5.0",
    "associates_degree": "6.0",
    "bachelors_degree": "26.0",
    "high_school_diploma": "19.0",
    "less_one_year_college": "5.0",
    "masters_degree": "5.0",
    "one_year_more_college": "10.0",
    "less_than_high_school_graduate": "47.0",
    "high_school_including_ged": "30.0",
    "bachelors_degree_2": "26.0",
    "bachelors_degree_or_higher_25_64": "26.0",
    "graduate_professional_degree": "10.0",
    "some_college_and_associates_degree": "21.0",
    "male_45_64_associates_degree": "6.0",
    "male_45_64_bachelors_degree": "0.0",
    "male_45_64_graduate_degree": "0.0",
    "male_45_64_less_than_9_grade": "17.0",
    "male_45_64_grade_9_12": "5.0",
    "male_45_64_high_school": "1.0",
    "male_45_64_some_college": "0.0",
    "male_45_to_64": "29.0",
    "employed_pop": "61.0",
    "unemployed_pop": "1.0",
    "pop_in_labor_force": "62.0",
    "not_in_labor_force": "89.0",
    "workers_16_and_over": "61.0",
    "armed_forces": "0.0",
    "civilian_labor_force": "62.0",
    "employed_agriculture_forestry_fishing_hunting_mining": "0.0",
    "employed_arts_entertainment_recreation_accommodation_food": "0.0",
    "employed_construction": "7.0",
    "employed_education_health_social": "12.0",
    "employed_finance_insurance_real_estate": "13.0",
    "employed_information": "0.0",
    "employed_manufacturing": "10.0",
    "employed_other_services_not_public_admin": "1.0",
    "employed_public_administration": "0.0",
    "employed_retail_trade": "0.0",
    "employed_science_management_admin_waste": "1.0",
    "employed_transportation_warehousing_utilities": "17.0",
    "employed_wholesale_trade": "0.0",
    "occupation_management_arts": "17.0",
    "occupation_natural_resources_construction_maintenance": "16.0",
    "occupation_production_transportation_material": "18.0",
    "occupation_sales_office": "10.0",
    "occupation_services": "0.0",
    "management_business_sci_arts_employed": "17.0",
    "sales_office_employed": "10.0",
    "in_grades_1_to_4": "0.0",
    "in_grades_5_to_8": "17.0",
    "in_grades_9_to_12": "32.0",
    "in_school": "51.0",
    "in_undergrad_college": "1.0",
    "speak_only_english_at_home": null,
    "speak_spanish_at_home": null,
    "speak_spanish_at_home_low_english": null
  }
]
```


