class_name Bank
extends RefCounted
## Банк: вклад (только чистые деньги, полиция его не трогает)
## и дешёвый кредит для тех, у кого честная история и низкий розыск.

var deposit: int = 0
var loan: int = 0

var _balance: Dictionary


func _init(balance: Dictionary) -> void:
	_balance = balance


## Сколько ещё можно занять: доля от всех честно заработанных денег.
func loan_limit(clean_earned: int) -> int:
	return maxi(0, floori(clean_earned * _balance.bank_loan_share) - loan)


## Банк не даёт денег тем, кого ищут.
func trusts(max_heat: float) -> bool:
	return max_heat < _balance.bank_max_heat


## Проценты по кредиту раз в неделю. Возвращает начисленное.
func add_interest() -> int:
	var interest := roundi(loan * float(_balance.bank_weekly_interest))
	loan += interest
	return interest


func to_dict() -> Dictionary:
	return { "deposit": deposit, "loan": loan }


func load_dict(data: Dictionary) -> void:
	deposit = int(data.deposit)
	loan = int(data.loan)
