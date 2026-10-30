class_name World
extends RefCounted
## Мир: страны и города (data/world.json). У каждого города свои районы (поле "city" в data/districts.json),
## своя раскладка 3D (layout) и район, куда прилетаешь (start). Расстояние — по настоящим координатам.

const EARTH_RADIUS_KM := 6371.0

var home: String
var countries: Array = []
var cities: Array = []

var _districts: Array = []
var _balance: Dictionary


func _init(data: Dictionary, district_list: Array, balance: Dictionary) -> void:
	home = data.home
	countries = data.countries
	cities = data.cities
	_districts = district_list
	_balance = balance


func get_city(id: String) -> Dictionary:
	for city: Dictionary in cities:
		if city.id == id:
			return city
	return {}


func get_country(id: String) -> Dictionary:
	for country: Dictionary in countries:
		if country.id == id:
			return country
	return {}


func country_of(city_id: String) -> Dictionary:
	return get_country(get_city(city_id).get("country", ""))


## Город района (старые районы без поля "city" — в родном городе).
func city_of(district: String) -> String:
	for d: Dictionary in _districts:
		if d.id == district:
			return d.get("city", home)
	return ""


func districts_of(city_id: String) -> Array:
	return _districts.filter(func(d: Dictionary) -> bool: return d.get("city", home) == city_id)


## Расстояние между городами по поверхности Земли, км.
func distance_km(a: String, b: String) -> float:
	var ca := get_city(a)
	var cb := get_city(b)
	var lat1 := deg_to_rad(float(ca.lat))
	var lat2 := deg_to_rad(float(cb.lat))
	var dlat := lat2 - lat1
	var dlon := deg_to_rad(float(cb.lon) - float(ca.lon))
	var h := sin(dlat / 2.0) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2.0) ** 2
	return 2.0 * EARTH_RADIUS_KM * asin(sqrt(h))


## Билет на самолёт: база и цена за километр.
func flight_cost(a: String, b: String) -> int:
	return roundi(float(_balance.flight_base) + distance_km(a, b) * float(_balance.flight_per_km))


## Сколько часов в пути: дорога в аэропорт и сам полёт.
func flight_hours(a: String, b: String) -> float:
	return snappedf(float(_balance.flight_hours_base) + distance_km(a, b) / float(_balance.flight_km_per_hour), 0.5)
