# «Последний Архивариус» — спецификация Спринта 9: Рисованный Архив

Статус: v0.3 (2026-10-05) — этап A: арт среза реализован (раздел 17), стиль одобрен; план доработки спринта — раздел 18

Спринт 9 меняет облик игры: процедурные глифы уступают место рисованным 2D-картинкам. Картинки генерирует автор в ChatGPT по промптам из раздела 16, игра подхватывает их скриптом импорта. В спринт также переходит этап B Спринта 8 (достижения, ежедневный забег) и пересмотр баланса всех сложностей.

Два этапа, между ними — плейтест:
- **Этап A**: конвейер арта, вертикальный срез (Архив Пепла и первый акт целиком в новом стиле), достижения, ежедневный забег.
- **Этап B**: остальной арт, звук, баланс всех сложностей с прокачкой.

Цель плейтеста после этапа A — проверить три вещи:
- новый стиль нравится и читается: отряды различимы с первого взгляда, сторона и численность видны;
- стиль держится единым — картинки разных сессий ChatGPT не выглядят чужими друг другу;
- достижения и ежедневный забег дают причину сыграть ещё раз.

## 1. Принятые решения

| Вопрос | Решение |
|---|---|
| Состав | Этап B Спринта 8 + «Арт и звук» + баланс всех сложностей |
| Стиль | Рисованный 2D: живописные фигуры и фоны, контур тушью, тёплый пергамент |
| Источник арта | ChatGPT (генерация изображений), промпты — раздел 16; генерирует автор |
| Ракурс отрядов | Сбоку, 3/4, смотрят вправо; враги — отражение по горизонтали |
| Анимация | Одна картинка на существо, движение — кодом (дыхание, рывок, отдача, вспышка, растворение) |
| Обработка | Скрипт проекта: удаление фона, обрезка, масштаб, точка опоры |
| Старый арт | Глифы остаются запасным вариантом: нет картинки — рисуется глиф |
| Вертикальный срез | Архив Пепла и первый акт |
| Звук | Процедурный, доработка `gen_audio` |
| Испытания | Только на «Тяжело» (вопрос 1 раздела 14 Спринта 8 закрыт) |
| История ежедневного забега | Графиком (вопрос 2 раздела 14 Спринта 8 закрыт) |
| Баланс | Пересмотр всех сложностей, в т. ч. «Тяжело» выше цели после Спринта 7 |
| Стиль среза | Одобрен автором (2026-10-05), расширяем на всю игру |
| Плейтест между этапами | Не нужен: достижения, ежедневный забег и этап B — подряд, плейтест в конце спринта |
| Порядок работы | Сначала код (достижения, ежедневный забег), затем общий промпт этапа B для ChatGPT |
| Карты Кодекса | Вертикальные, в рисованной рамке: Кодекс, награда, лавка |
| Арт сверх плана | Значки достижений, значки действий и состояний, портреты школ |
| Следующий спринт (10) | Сюжет и обучение |

---

## ЭТАП A

## 2. Конвейер арта

### 2.1. Папки

```
art/
  raw/          сюда автор кладёт картинки из ChatGPT как есть (в Godot не импортируется, .gdignore)
  units/        <unit_id>.png        — обработанные фигуры
  cards/        <memory_id>.png      — иллюстрации карт Кодекса
  portraits/    <commander_id>.png, archivist.png
  backgrounds/  battle_act1.png, map_act1.png, menu.png, …
  ui/           panel.png, button_*.png, card_frame.png
  manifest.json                        — что обработано: размер, точка опоры, источник
```

Имя файла в `raw/` задаёт назначение: `unit_salt_guard.png`, `card_salt_legion.png`, `portrait_ash_overseer.png`, `bg_battle_act1.png`, `ui_panel.png`. Регистр и версия в хвосте игнорируются: `unit_salt_guard_v3.png` → `art/units/salt_guard.png` (берётся самый новый файл).

### 2.2. Скрипт импорта `tools/art_import.gd`

Запуск: `godot --headless -s res://tools/art_import.gd [-- --only=units|cards|… --force]`.

Для каждого файла `raw/`:
1. **Фон.** Если у картинки есть прозрачность (ChatGPT отдаёт PNG с прозрачным фоном по просьбе) — берётся как есть. Если нет — фон удаляется заливкой от краёв: пиксели, связанные с рамкой картинки и близкие по цвету к углам (допуск по умолчанию 28 в RGB), становятся прозрачными; край смягчается на 1 px.
2. **Обрезка** по непрозрачной области с полем 8 px.
3. **Масштаб** под назначение (таблица ниже), с сохранением пропорций, фильтр Lanczos.
4. **Точка опоры** для фигур: середина нижнего края непрозрачной области («ноги»). Летуны — центр тени, задаётся в манифесте вручную (`"anchor_y": 0.8`), по умолчанию 0.92 высоты.
5. **Проверки**: картинка не пустая, после удаления фона осталось 10–90 % пикселей (иначе — предупреждение «фон не удалился» или «съеден объект»), размер исходника не меньше половины целевого.
6. Запись в `art/<папка>/<id>.png` и строка в `manifest.json`. Неизменённые исходники повторно не обрабатываются (сравнение по хэшу), `--force` — всё заново.

| Назначение | Размер после обработки | Примечание |
|---|---|---|
| Отряд | высота 384 px | на поле ~150 px высотой при 1920×1080 |
| Крупный отряд (`size_class = large`) | высота 448 px | Таран, Змей, Хранитель Разлома |
| Карта Кодекса | 512×384 (4:3), обрезка по центру | |
| Портрет | 256×256, круглая маска при показе | |
| Фон | 1920×1080, обрезка по центру | без удаления фона |
| Интерфейс | как есть; поля 9-slice — в манифесте | без масштаба |

Итог работы скрипта печатается таблицей: что обработано, что пропущено, предупреждения. Отсутствующие для среза картинки перечисляются отдельно («не хватает: …»).

### 2.3. `ArtDB` — доступ к арту в игре

- `ArtDB.unit(id) -> Texture2D | null`, `card(id)`, `portrait(id)`, `background(id)`, `ui(id)`; данные точки опоры — `ArtDB.anchor(id)`.
- Загрузка лениво, с кэшем; путь — по соглашению из 2.1. Нет файла — `null`, и вызывающий код рисует прежний глиф.
- `UnitDef` получает поле `size_class` (`normal` / `large`), остальные данные не меняются.
- Без рендера (headless, тесты, симуляция) `ArtDB` ничего не грузит.

## 3. Отряды на поле

- **Фигура** вместо глифа: спрайт по точке опоры в центре гекса, чуть ниже (ноги на 0,35 радиуса гекса от центра). Враги — `flip_h`. Порядок отрисовки — по строке гекса, чтобы ближние перекрывали дальних.
- **Тень**: мягкий эллипс под ногами (как сейчас под глифом).
- **Сторона**: цветная плашка-подставка под ногами (синяя — свои, красная — враги) и цвет плашки численности. Обводку силуэта не делаем — она спорит с живописью.
- **Численность, намерения, статусы** — на прежних местах, над фигурой; позиции пересчитываются от высоты спрайта.
- **Активный стек**: подсветка подставки и лёгкий подъём фигуры (−4 px).
- **Анимации кодом** (`UnitSprite`, на твинах; все — в пределах текущих длительностей событий, бой не замедляется):

| Событие | Анимация |
|---|---|
| Покой | «дыхание»: масштаб по Y 1 ± 1,5 %, период 2,4 с, фаза по uid |
| Перемещение | шаги-подскоки по пути (дуга 6 px на клетку) |
| Удар | рывок к цели на 22 px и возврат, наклон 6° |
| Выстрел | отдача назад на 8 px |
| Получил урон | белая вспышка (шейдер), дрожь 4 px |
| Смерть | растворение в чернила: шейдер `ink_dissolve` (порог по шуму, край — тёмные чернила), 0,6 с |
| Способность / заклинание | свечение контура цветом действия, 0,4 с |
| Иллюзия (Сад Лиц) | полупрозрачность 0,65 и рябь шейдером |
| Летун | постоянное покачивание по Y ± 4 px |

- **Портреты** в очереди ходов, панели стека и медальонах — та же картинка, кадрированная по верхней половине фигуры (кадр задаётся в манифесте, по умолчанию верхние 55 %).
- **Производительность**: 20+ спрайтов с шейдерами не хуже нынешнего — `tools/profile_battle` не ниже 48 FPS в массовом бою (как в Спринте 7).

## 4. Карты Кодекса, портреты, фоны, интерфейс (срез)

- **Карты Кодекса**: иллюстрация в верхней части карты в рамке `card_frame`; прочность, тип и название — поверх, как сейчас. Без иллюстрации — прежний глиф на цветном фоне.
- **Портреты командиров** — в чипе командира и на плашке начала боя. **Портрет Архивариуса** — в панели героя на карте и в бою.
- **Фоны**: поле боя первого акта (пол архива — гексы рисуются поверх полупрозрачно), карта первого акта (небо и дальние полки; острова остаются процедурными до этапа B), главное меню.
- **Интерфейс**: панель-пергамент (9-slice), кнопка (обычная / наведение / нажата — одна картинка, состояния — оттенком), рамка карты.
- **Шрифты**: заголовки — Cormorant Garamond SemiBold, текст — PT Sans (обе с кириллицей, лицензия OFL; файлы — в `fonts/` с лицензией). Подключаются в `ui_theme.gd`.

## 5. Список картинок вертикального среза

27 картинок для игры и эталон стиля. Промпты — в разделе 16 по номерам.

| № | Файл в `raw/` | Что | Примечание |
|---|---|---|---|
| U1 | `unit_salt_guard` | Соляной Страж | игрок |
| U2 | `unit_chronicler` | Летописец-стрелок | игрок, стрелок |
| U3 | `unit_ash_ghoul` | Пепельный Гуль | игрок и враг |
| U4 | `unit_ash_priest` | Пепельный Жрец | враг, лекарь |
| U5 | `unit_rust_sentinel` | Ржавый Часовой | враг |
| U6 | `unit_rift_ram` | Разломный Таран | враг, крупный |
| U7 | `unit_shard_archer` | Осколочный Лучник | враг, стрелок |
| U8 | `unit_storm_wyrm_echo` | Эхо Грозового Змея | летун, крупный |
| U9 | `unit_rift_warden` | Хранитель Разлома | босс, крупный |
| U10 | `unit_archive_relic` | Архив | объект цели |
| C1 | `card_salt_legion` | Легион Соляных Стражей | |
| C2 | `card_ash_chroniclers` | Летописцы Пепла | |
| C3 | `card_ghoul_pack` | Стая Пепельных Гулей | |
| C4 | `card_shard_archers` | Осколочные Лучники | |
| C5 | `card_rust_sentinels` | Ржавые Часовые | |
| C6 | `card_storm_wyrm` | Эхо Грозового Змея | |
| C7 | `card_last_king` | Последний Король | геройская карта |
| P1 | `portrait_archivist` | Архивариус | |
| P2 | `portrait_ash_overseer` | Смотритель Пепла | командир |
| P3 | `portrait_rift_herald` | Вестник Разлома | командир |
| P4 | `portrait_salt_keeper` | Хранитель Соли | командир |
| B1 | `bg_battle_act1` | Поле боя первого акта | |
| B2 | `bg_map_act1` | Карта первого акта | |
| B3 | `bg_menu` | Главное меню | |
| I1 | `ui_panel` | Панель-пергамент | 9-slice |
| I2 | `ui_button` | Кнопка | 9-slice |
| I3 | `ui_card_frame` | Рамка карты Кодекса | |
| S0 | — | Эталон стиля | генерируется первым, в игру не идёт |

Код этапа A не ждёт картинок: всё работает с глифами, срез «оживает» по мере того, как картинки попадают в `raw/` и проходит импорт.

## 6. Достижения

Без изменений по сравнению с разделом 8 Спринта 8: 20 достижений, награды — очки памяти (2–10) или открытия; новые открытия — карты «Хранители пепла» и «Зеркальный двойник», реликвии «Песочные часы Разлома» и «Печать Синода», события «Голос из чернил» и «Забытая полка».

- `AchievementDef` (`data/achievements/*.tres`): id, условие-ключ, порог, награда.
- `Achievements.check(profile, run, event)` — на конце боя, конце забега, взятии реликвии, покупке.
- Экран «Достижения» из главного меню: сетка значков; полученные — цветные с датой в подсказке, остальные — тусклые с условием. Скрытых нет.
- Уведомление — плашка сверху (значок и название) на 3 с, не мешает бою.
- Значки достижений — процедурные (`UnitGlyphs`), рисованные — вне спринта.
- `ProfileState.achievements: Dictionary[StringName, String]` (id → дата).

## 7. Ежедневный забег

Как в разделе 9 Спринта 8, плюс решение по истории:
- раскладка задана датой: сид, школа, «Нормально», 2 модификатора из 8 (один плюс, один минус);
- засчитывается первая законченная или брошенная попытка дня; повтор — без таблицы и очков; сохранение отдельное от обычного;
- счёт: слой × 10 + элита × 15 + боссы × 50 + оставшиеся ресурсы;
- **история — графиком**: линия счёта за последние 30 дней (пропущенные дни — разрывы линии), точки окрашены по исходу (победа — золото, поражение — красный), подсказка у точки — дата, школа, модификаторы, слой, счёт; лучший результат — горизонтальная пунктирная линия; под графиком — список последних 7 попыток;
- кнопка «Ежедневный забег» в главном меню с отметкой, если сегодня не сыгран.

## 8. Сохранения

- Профиль v3: `achievements`, `daily` (история 30 дней, дата последней засчитанной попытки), миграция v2 → v3.
- Ежедневный забег — отдельный файл `user://daily_run.json`, формат забега v10: поля `daily_date`, `modifiers`. Миграция v9 → v10 для обычного забега (`daily_date = ""`, `modifiers = []`).
- Арт в сохранения не попадает.

## 9. Тесты этапа A

- **Импорт арта** на фикстурах `tests/fixtures/art/`: картинка с прозрачностью; картинка на однотонном фоне (фон удалён, объект цел); картинка, где «фон съел объект» (предупреждение); обрезка и точка опоры; имя с версией в хвосте; повторный запуск без изменений ничего не переписывает.
- **ArtDB**: нет файла — `null`; есть — текстура и опора из манифеста; каждый id в манифесте существует в `DefsDB`.
- **Запасной вариант**: все сцены (`test_scenes.gd`) строятся и без арта, и с полным набором фикстур.
- **Достижения**: каждое — условие и награда, награда выдаётся один раз.
- **Ежедневный забег**: одна дата — одна раскладка; вторая попытка не в таблице; отдельное сохранение; смена даты посреди забега не меняет раскладку; каждый модификатор срабатывает; счёт; история на 30 дней обрезается.
- **Миграции**: профиль v2 → v3, забег v9 → v10 (фикстуры).

## 10. Критерии готовности этапа A

- `tools/art_import.gd` обрабатывает все 27 картинок среза без ручной правки (кроме опоры летунов в манифесте).
- Бой первого акта за Архив Пепла целиком в новом стиле: все отряды, фон, портреты, интерфейс; анимации из раздела 3.
- Без папки `art/` игра выглядит и работает как в Спринте 8.
- Достижения и ежедневный забег работают, автопрогон ежедневного забега проходит.
- Тесты и стресс без сбоев, `--smoke` — OK, `profile_battle` — не ниже 48 FPS.

---

## ЭТАП B

## 11. Остальной арт

- **Отряды**: остальные 13 существ (Орден Приливов, Машинный Синод, Сад Лиц, второй акт, Глубинный угорь, Хозяин Глубин).
- **Карты Кодекса**: остальные 12 карт, в т. ч. «Утопленная корона» и карты достижений.
- **Портреты**: командир Хозяина Глубин.
- **Фоны**: поле боя и карта второго акта, привал, Тихая гавань, лавка, событие, реликварий, Зал Архива, экран итога.
- **Острова карты**: 7 типов (бой, элита, лавка, гавань, событие, реликварий, босс) × 2 акта = 14 картинок; при отсутствии — процедурные острова.
- **Реликвии**: 10 иллюстраций для экрана реликвария и подсказок; значки в строке героя остаются процедурными.
- Полный список с промптами дописывается в раздел 16 в начале этапа B, по итогам плейтеста стиля.

## 12. Звук (процедурный)

Доработка `tools/gen_audio.gd`; прежние треки и звуки не меняются (свой сид у новых).
- **Слои боевой музыки**: трек боя из двух слоёв — «спокойный» и «напряжение» (ударные, низкие струнные). Громкость второго слоя — по угрозе: доля ОЗ игрока под ударом (`ThreatMap`) и раунд; плавный переход 2 с.
- **Инструменты**: щипковые (лютня — фильтрованный шум + затухающая гармоника), смычковые пэды, «хор» (формантный фильтр на пиле), колокол.
- **Окружение**: петли «пыль архива» (первый акт) и «капель и вода» (второй акт), тихо под музыкой.
- **Звуки ударов по классам** существ: металл (Страж, Часовой), когти и плоть (Гуль), магия (Жрец, Хранитель), стрелы и осколки, крупные (Таран, Змей) — ниже и тяжелее; небольшой разброс высоты, чтобы повторы не резали слух.
- **Реверберация** на шине музыки и звуков (`AudioEffectReverb`, комната «зал»), настройка громкости окружения в «Настройках».

## 13. Баланс всех сложностей

- `sim_balance.gd` — 3 сложности × 4 школы × профили прокачки «пусто», «половина», «полное», 200 забегов на сочетание.
- Цели доли полных побед — как в Спринтах 7–8; отдельная задача — «Тяжело» без прокачки (сейчас 12–14 % при цели 6–12 %): усиление второго акта только на «Тяжело» (численность встреч уровня 5 и элиты второго акта, затем — порог второй фазы босса).
- Испытания на полном дереве — цели раздела 10 Спринта 8 (ступень 1 — 6–12 %, 5 — 3–8 %, 10 — 1–5 %); Машинный Синод на ступенях 1–5 сейчас у верхней границы.
- Модификаторы ежедневного забега — каждый не сдвигает долю побед больше чем на 8 п.п.

## 14. Тесты и критерии готовности этапа B

- Все сцены с полным набором арта; импорт всех картинок проекта без предупреждений.
- Звук: генерация детерминирована; слои боевой музыки меняют громкость от угрозы (тест на `Audio` без устройства).
- Баланс — в целях раздела 13; 12 автопрогонов (школы × сложности) и автопрогон ежедневного забега без ошибок; полный стресс — 0 сбоев.
- `profile_battle` во втором акте — не ниже 48 FPS.

## 15. Вне спринта

Рисованные значки (действия, статусы, достижения), покадровая анимация, озвучка, третий акт, новые школы, онлайн-таблицы.

## 16. Промпты для ChatGPT

### 16.1. Как генерировать

**Проще всего — общий промпт `art/CHATGPT_PROMPT.md`**: вставьте его целиком в новую беседу ChatGPT, дальше отвечайте «дальше», «ещё раз», «исправь: …» или «начни с U5». ChatGPT сам рисует картинки по порядку и называет имя файла. Ниже — те же промпты по отдельности, для ручных правок.

1. **Одна беседа на категорию** (отряды, карты, портреты, фоны, интерфейс) — ChatGPT держит стиль внутри беседы.
2. **Первым — эталон стиля S0.** Сохраните удачный вариант и **прикладывайте его к первому сообщению каждой новой беседы** со словами «Match the art style of the attached image exactly».
3. **Каждый промпт = общий блок стиля (16.2) + блок категории (16.3) + описание объекта (16.4–16.8).** Блоки стиля и категории можно отправить один раз в начале беседы, дальше — только описание: «Next: …».
4. **Формат**: отряды — квадрат 1024×1024; карты, фоны — горизонтальный 1536×1024; портреты — квадрат; интерфейс — квадрат. Прозрачный фон — для отрядов, портретов не нужен.
5. **Если фон не прозрачный** — не страшно: скрипт импорта уберёт однотонный фон. Попросите «on a plain flat light-grey background» — так фон удаляется чище всего.
6. **Сохранение**: скачайте PNG и положите в `art/raw/` с именем из таблицы раздела 5 (`unit_salt_guard.png`). Неудачные версии можно оставлять с хвостом `_v2`, `_v3` — берётся самый новый файл.
7. **Типичные правки** одной фразой: «same character, but facing right», «remove the ground/shadow», «less detail, stronger silhouette», «make it fit the attached reference palette».

### 16.2. Общий блок стиля (в каждую беседу)

```
Art style: hand-painted 2D fantasy illustration for a turn-based tactics game, in the spirit of classic Heroes of Might and Magic III but painterly. Visible brush strokes, soft gouache-like shading, crisp dark ink outlines of varying thickness, slightly desaturated palette: ash grey, warm parchment, ember orange, deep ink blue-black, with accents of violet rift light. Gentle top-left key light, warm rim light. The world is a vast archive of memories that is being erased: dust, ash, torn pages, floating ink. Readable silhouette first, details second. No text, no letters, no watermark, no frame, no UI.
```

### 16.3. Блоки категорий

**Отряды (U1–U10):**
```
Single creature, full body, three-quarter side view facing RIGHT, standing on an invisible ground line, whole figure inside the image with a small margin, no ground, no cast shadow, no background scenery. Transparent background (PNG with alpha). Square 1024x1024. The figure should read clearly when shrunk to 150 pixels tall: bold silhouette, clear head, clear weapon or claws.
```

**Карты Кодекса (C1–C7):**
```
Illustration for a memory card: a vignette scene, landscape 1536x1024, the subject in the centre third, soft painterly background that fades to warm parchment at the edges, like a memory remembered. No border, no text.
```

**Портреты (P1–P4):**
```
Head and shoulders portrait, three-quarter view facing right, centred, square 1024x1024, simple dark parchment background with a soft vignette. Strong readable face or mask at small size (64 pixels).
```

**Фоны (B1–B3):**
```
Wide environment background, landscape 1536x1024, no characters, no text. Composition must leave the central area calm and low-contrast because game elements will be drawn on top.
```

**Интерфейс (I1–I3):**
```
Game UI element, flat front view, no perspective, centred on a plain flat light-grey background, square 1024x1024. Even, uniform edges so it can be stretched as a 9-slice panel; ornament only at the corners.
```

### 16.4. Эталон стиля

**S0:**
```
A style reference sheet: three small figures standing side by side facing right — an armoured guardian made of salt crystals, a hunched ash ghoul, a robed scribe with a quill-crossbow — all on a plain flat light-grey background.
```

### 16.5. Отряды

**U1 Соляной Страж (`unit_salt_guard`):**
```
Salt Guard: a stoic infantry soldier whose armour is grown from pale white-grey salt crystals, tall rectangular tower shield of compressed salt, short sword, helmet with a narrow visor slit, faint glittering salt dust falling off the edges. Colour accents: pale silver-blue.
```

**U2 Летописец-стрелок (`unit_chronicler`):**
```
Ash Chronicler: a lean robed archivist-marksman in ash-grey and amber robes, wearing round brass spectacles, holding a crossbow built from a book spine and a giant quill as the bolt, ink-stained fingers, a bundle of scrolls on the back, sparks of ember-orange ink around the bolt tip.
```

**U3 Пепельный Гуль (`unit_ash_ghoul`):**
```
Ash Ghoul: a hunched gaunt ghoul made of compacted grey ash and charred paper, long clawed hands, glowing ember-orange cracks in its skin, flakes of ash peeling off, hungry open mouth, low predatory crouch.
```

**U4 Пепельный Жрец (`unit_ash_priest`):**
```
Ash Priest: a tall thin priest in tattered ember-orange and charcoal vestments, censer on a chain that pours warm glowing smoke, face hidden under a deep hood with two faint orange eyes, holding an open burning book in the other hand. Calm, healing presence.
```

**U5 Ржавый Часовой (`unit_rust_sentinel`):**
```
Rust Sentinel: a heavy clockwork guardian of rusted iron plates and brass rivets, broad shoulders, big round shield with a gear emblem, a lantern-like single eye, steam leaking from joints, rust-orange and dark bronze colours. Massive and slow.
```

**U6 Разломный Таран (`unit_rift_ram`):**
```
Rift Ram: a huge armoured ram-like beast made of dark stone and violet rift crystals, enormous curled horns glowing with violet energy, lowered head ready to charge, cracked stone hooves, shards of reality floating around it. Large creature, wide body.
```

**U7 Осколочный Лучник (`unit_shard_archer`):**
```
Shard Archer: a slender archer whose body is made of pale blue glass shards held together by light, bow made of a long curved crystal, arrows of sharp glass splinters, a hood of broken glass. Cold pale-blue palette.
```

**U8 Эхо Грозового Змея (`unit_storm_wyrm_echo`):**
```
Storm Wyrm Echo: a translucent ghostly serpent-dragon made of storm clouds and violet-blue lightning, long coiling body in flight, bat-like wings of torn cloud, glowing eyes, lightning arcs between its teeth. Flying, large, semi-transparent edges.
```

**U9 Хранитель Разлома (`unit_rift_warden`):**
```
Rift Warden, the boss of the first act: a towering armoured colossus whose chest is an open rift — a crack into violet void filled with floating torn pages. Cracked obsidian armour, a long blade that looks like a tear in space, crown of floating stone fragments. Menacing, imposing, very readable silhouette.
```

**U10 Архив (`unit_archive_relic`):**
```
The Archive: an ornate old wooden bookcase-reliquary on small legs, packed with glowing books and scrolls, brass corner fittings, a soft golden light from inside, a few loose pages floating around it. An object, not a creature, three-quarter view.
```

### 16.6. Карты Кодекса

**C1 Легион Соляных Стражей (`card_salt_legion`):**
```
A disciplined row of Salt Guards in crystal-salt armour behind a wall of salt tower shields, standing on a salt flat at dusk, salt dust in the air.
```

**C2 Летописцы Пепла (`card_ash_chroniclers`):**
```
Ash Chroniclers on a high gallery of an endless library, aiming quill-crossbows downward, embers and ash drifting between the bookshelves.
```

**C3 Стая Пепельных Гулей (`card_ghoul_pack`):**
```
A pack of Ash Ghouls crawling out of a pile of burnt books, ember-orange eyes in the smoke, charred pages swirling.
```

**C4 Осколочные Лучники (`card_shard_archers`):**
```
Shard Archers made of pale blue glass releasing a volley of glass-splinter arrows that sparkle in the light of a broken stained-glass window.
```

**C5 Ржавые Часовые (`card_rust_sentinels`):**
```
Two Rust Sentinels standing guard at a massive round vault door with gears, steam rising, rust-orange light.
```

**C6 Эхо Грозового Змея (`card_storm_wyrm`):**
```
A ghostly storm wyrm of cloud and violet lightning coiling around a crumbling archive tower in a thunderstorm.
```

**C7 Последний Король (`card_last_king`):**
```
The Last King: a weary old king on a ruined throne made of stacked books, his crown half dissolved into floating ink, holding a fading banner, quiet dignity, warm golden light on him and darkness around.
```

### 16.7. Портреты

**P1 Архивариус (`portrait_archivist`):**
```
The Last Archivist: an ageless keeper of memories, hooded in deep ink-blue robes embroidered with faint golden script, calm wise eyes, a pale scar of ink across one cheek, a glowing open codex held near the chest.
```

**P2 Смотритель Пепла (`portrait_ash_overseer`):**
```
Ash Overseer: a stern masked commander, mask of blackened bronze with ember-orange glowing slits, a high collar of charred paper, ash falling like snow.
```

**P3 Вестник Разлома (`portrait_rift_herald`):**
```
Rift Herald: a gaunt herald whose face is half missing, replaced by a violet crack into the void, ornate violet and black tabard, a trumpet of dark crystal over the shoulder.
```

**P4 Хранитель Соли (`portrait_salt_keeper`):**
```
Salt Keeper: an old general with a beard crusted with salt crystals, armour of pale salt, cold silver-blue eyes, an aura of glittering salt dust.
```

### 16.8. Фоны и интерфейс

**B1 Поле боя первого акта (`bg_battle_act1`):**
```
Top-down three-quarter view of a vast stone floor of an ancient archive hall seen from above at a 45-degree angle, worn dark flagstones, scattered loose pages and ash, faint violet cracks of the rift in the floor near the edges, bookcases and candles only at the very top edge. The central area is an even, calm, slightly darker floor (a hex grid will be drawn over it).
```

**B2 Карта первого акта (`bg_map_act1`):**
```
An endless sky above an archive world: distant floating bookshelves and towers drifting in warm dusk clouds, a violet rift glowing far away at the top, calm empty space in the middle for floating islands that will be drawn on top.
```

**B3 Главное меню (`bg_menu`):**
```
A lone hooded archivist standing at the edge of a giant open book that forms a landscape, pages turning into dust and floating away into a violet-dusk sky, an endless library on the horizon. Leave the left third calm for the menu buttons.
```

**I1 Панель (`ui_panel`):**
```
A rectangular panel of aged parchment with a thin dark ink border and small brass corner ornaments, subtle paper texture, flat lighting.
```

**I2 Кнопка (`ui_button`):**
```
A wide rectangular button plate of dark leather book binding with a thin embossed golden line border and small brass rivets in the corners, flat lighting.
```

**I3 Рамка карты (`ui_card_frame`):**
```
A vertical card frame for a collectible memory card: dark wood and brass border with a parchment inner area, an empty window in the upper half for an illustration, a small round socket at the top-left corner, no text. Portrait proportions 2:3 centred in the image.
```

## 17. Реализация этапа A: арт (детали и отличия)

- **Картинки**: все 27 картинок среза и эталон сгенерированы автором в ChatGPT; стиль единый, отряды смотрят вправо. Отряды пришли с прозрачным фоном, интерфейс — на сером.
- **Импорт** (`tools/art_import.gd`, логика — `ArtImport` в `tools/art_import_lib.gd`): 27 картинок за 18 с, без предупреждений.
  - Фон снимается заливкой от краёв; у рамки карты окно внутри замкнуто — дополнительно удаляются крупные (≥ 2 % картинки) области почти точно цвета фона, чтобы не выесть светлый пергамент. Окно рамки записывается в манифест (`window`).
  - Кнопка уменьшается до высоты 64 px: иначе поля 9-slice больше самой низкой кнопки и заклёпки наезжают на текст.
  - Ручные поправки манифеста (`anchor_manual`, `portrait_manual`) переживают повторный импорт.
  - `UnitDef.size_class = large` — Таран, Змей, Хранитель Разлома, Хозяин Глубин, Чернильный спрут.
- **ArtDB** (`scripts/presentation/art_db.gd`): текстуры по соглашению `art/<папка>/<id>.png`, опора и кадр портрета из манифеста; нет картинки — глиф. `art/manifest.json` добавлен в фильтр экспорта, `art/raw/` — в исключения (и `.gdignore`).
- **Поле боя**:
  - фигура по точке опоры, ноги на 0,22 гекса ниже центра; высота — 2,6 гекса (крупные — 3,1); порядок отрисовки — по экранной высоте;
  - тень и эллипс-подставка цвета стороны (у ходящего стека — толще, фигура приподнята на 4 px); летуны покачиваются;
  - численность, значки и полоска ОЗ — на прежних местах, состояния — над головой фигуры;
  - пол первого акта — рисованный (яркость 0,6), гексы полупрозрачные; во втором акте — прежние плиты.
- **Отличия от раздела 3** (ради производительности все фигуры по-прежнему рисуются одним слоем, без шейдеров на каждую):
  - вспышка при уроне — осветление картинки, а не шейдер;
  - гибель — фигура темнеет в чернила, пока тает, без растворения по шуму;
  - свечение при способности — прежние кольца-вспышки поля;
  - шаги-подскоки и наклон при ударе не добавлялись: остались прежние движение, рывок и отдача.
- **Портреты**: очередь ходов и панель стека — верхняя часть фигуры; медальон карты — иллюстрация карты в круге (без неё — портрет существа); командиры — круглый портрет в чипе; Архивариус — в панели героя.
- **Рамка карты** пока не используется: карты Кодекса в игре горизонтальные, а рамка вертикальная — перенесена в этап B вместе с вертикальным видом Кодекса.
- **Фоны**: меню (кнопки — в левой трети), карта первого акта (яркость 0,62, острова процедурные), поле боя первого акта.
- **Интерфейс**: кнопки темы — рисованная кожа (состояния — оттенком); панели темы и подсказки — затемнённый пергамент (панели со своим стилем — прежние). Над рисованными фонами у подписей тёмная обводка.
- **Шрифты**: PT Sans (текст) и Cormorant Garamond SemiBold (подписи от 26 pt), лицензия OFL — `fonts/`.
- **Инструменты**: `tools/screenshots.tscn` — снимки меню, карты, подготовки, боя (покой, в процессе, Разлом) и награды.
- **Проверки**: тесты 322 (+12: `test_art.gd`, сцены с артом); `profile_battle` с артом и без — в одной среде одинаково (с артом кадр даже чуть короче); абсолютный FPS нужно снять на машине с видеокартой.

## 18. Доработка спринта: план после одобрения стиля

Порядок:
1. **Достижения** (раздел 6) и **ежедневный забег** (раздел 7) — без изменений плана.
2. **Общий промпт этапа B** — `art/CHATGPT_PROMPT_B.md` по образцу среза: те же правила, общий стиль и команды («дальше», «ещё раз», «исправь», «начни с»), эталон S0 прикладывается к беседе.
3. **Код этапа B**, пока генерируется арт: вертикальные карты, значки, портреты школ, острова, фоны экранов — всё с откатом на процедурный вид, как в срезе.
4. **Звук** (раздел 12) и **баланс** (раздел 13).
5. Плейтест — в конце спринта.

### 18.1. Список картинок этапа B — 114

| Группа | Сколько | Что |
|---|---|---|
| Отряды | 13 | Глубинный страж, Медный Ремонтник, Заводная Турель, Глубинный угорь, Глубинная Медуза, Утопленный летописец, Похититель Лиц, Хор Безликих, Чернильный спрут, Зеркальный Двойник, Сирена, Приливный Страж, Хозяин Глубин |
| Карты Кодекса | 14 | 12 оставшихся карт + «Хранители пепла» и «Зеркальный двойник» (награды достижений) |
| Портреты | 1 | командир Хозяина Глубин |
| Фоны | 10 | поле боя и карта второго акта, привал, Тихая гавань, лавка, событие, реликварий, Зал Архива, итог забега, выбор школы |
| Острова карты | 14 | 7 типов (бой, элита, лавка, гавань, событие, реликварий, босс) × 2 акта |
| Реликвии | 12 | 10 нынешних + «Песочные часы Разлома» и «Печать Синода» (награды достижений) |
| Значки достижений | 20 | по одному на достижение |
| Значки интерфейса | 26 | все значки `UnitGlyphs.ALL_ICONS`: ближний бой, стрелок, летун, ответ, защита, ожидание, ход, способность, метка, броня, лечение, приказ, заклинание, три ресурса, ОЗ, скорость, гибель, очки, замок, маска, угроза, вода, чаша |
| Портреты школ | 4 | Архив Пепла, Орден Приливов, Машинный Синод, Сад Лиц |

Картинки можно генерировать порциями: каждая подключается сразу после импорта, недостающие остаются процедурными.

### 18.2. Вертикальные карты Кодекса

- Карта — рамка `ui_card_frame` (пропорции 2:3, ~220×330 px на экране 1920×1080): иллюстрация в окне рамки (без неё — силуэт существа на цветном фоне), гнездо в левом верхнем углу — прочность цифрой, ниже окна — название, численность и значки (способность, стрелок, летун, характеристики).
- Подробности — в подсказке, как сейчас.
- Где: Кодекс (экран памяти), награда после боя, лавка, выбор карт перед боем. Состояния: выбрана — золотая обводка, угасает (прочность 1) — красная, недоступна — затемнение.
- Подробный режим (`Settings.detailed`) — текст характеристик строками под названием, карта выше.
- Тесты: карта строится с артом и без, для каждой карты из `DefsDB`; экраны с картами — в `test_scenes.gd`.

### 18.3. Рисованные значки

- Импорт: вид `icon` (`icon_<id>.png` → `art/icons/<id>.png`, 128×128, прозрачный фон), `ach_<id>.png` → `art/achievements/<id>.png`, `school_<id>.png` → `art/schools/<id>.png`.
- Значки интерфейса рисуются как есть, без перекраски: цвет состояния передаёт кружок-подложка (как сейчас у значков на поле). Нет картинки — процедурный значок.
- `IconAtlas` берёт рисованный значок вместо запечённого, если он есть; размер на экране не меняется (16–30 px), поэтому промпт требует крупный силуэт без мелочей.
