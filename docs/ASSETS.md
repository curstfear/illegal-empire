# Журнал ассетов

Каждая модель, текстура, звук, шрифт или музыка из чужого источника записывается сюда **до** того, как попадёт в игру. Без лицензии — не используем.

| Файл / папка в проекте | Что это | Источник (ссылка) | Автор | Лицензия | Платно? | Дата |
|---|---|---|---|---|---|---|
| `icon.svg` | Иконка проекта (стандартная Godot) | Godot Engine | Godot contributors | MIT | нет | 2026-10-30 |
| `assets/models/kaykit_city/` | KayKit: City Builder Bits 1.0 (FREE) — 41 модель glTF: здания, дороги, машины, скамейки, кусты; текстура `citybits_texture.png` | https://kaylousberg.itch.io/city-builder-bits | Kay Lousberg | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |
| `assets/models/kenney_city_commercial/` | Kenney: City Kit Commercial 2.1 — 41 модель GLB: магазины, офисы, высотки | https://kenney.nl/assets/city-kit-commercial | Kenney | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |
| `assets/models/kenney_city_roads/` | Kenney: City Kit Roads 2.2 — 95 моделей GLB: дороги, перекрёстки, знаки, фонари | https://kenney.nl/assets/city-kit-roads | Kenney | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |
| `assets/models/kenney_cars/` | Kenney: Car Kit 3.1 — 50 моделей GLB: легковые, такси, полиция, грузовики, колёса | https://kenney.nl/assets/car-kit | Kenney | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |

| `assets/audio/kenney_interface/` | Kenney: Interface Sounds 1.0 — 6 звуков OGG: click_002, open_002, close_002, confirmation_002, error_004, select_002 | https://kenney.nl/assets/interface-sounds | Kenney | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |
| `assets/models/kenney_city_industrial/` | Kenney: City Kit Industrial 2.0 — 37 моделей GLB: склады, ангары, цеха, трубы, баки, контейнеры | https://kenney.nl/assets/city-kit-industrial | Kenney | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |
| `assets/models/kenney_city_suburban/` | Kenney: City Kit Suburban 2.0 — 40 моделей GLB: частные дома, заборы, дорожки, деревья | https://kenney.nl/assets/city-kit-suburban | Kenney | CC0 1.0 (`License.txt` в папке) | нет | 2026-10-30 |
| `assets/fonts/inter/` | Шрифт Inter: Regular, Medium, SemiBold, Bold (OTF) — шрифт интерфейса | https://rsms.me/inter/ (архив скачал пользователь) | Rasmus Andersson | SIL OFL 1.1 (`LICENSE.txt` в папке) | нет | 2026-10-30 |
| (в коде) `autoload/audio.gd` | Шум улицы, «дзынь» монет, сирена — синтезируются кодом при запуске, файлов нет | — | Claude для проекта | свои | нет | 2026-10-30 |

Архивы скачал пользователь в `~/Downloads`; в проект скопированы только glTF/GLB, текстуры и лицензии (без FBX/OBJ).

## Разрешённые лицензии
- **CC0** (Kenney, Quaternius, Poly Pizza CC0) — можно всё, указывать автора не обязательно, но пишем.
- **CC-BY** — можно, но автора обязательно указать в титрах игры.
- **Платные паки** — только после «да» пользователя; лицензию сохраняем в `docs/licenses/`.

## Нельзя
- CC-BY-NC (запрет коммерции), «free for personal use», модели без указанной лицензии, рипы из других игр.
