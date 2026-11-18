class_name MatchConfig
extends RefCounted
## Настройки запускаемого матча. Главное меню выставляет их перед загрузкой match.tscn.

static var vs_ai: bool = false
## Индекс уровня (0..Levels.count()-1) — играть только его; -1 — ротация уровней каждый раунд.
static var level: int = -1
