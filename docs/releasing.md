# Как выпускать обновления Walone для macOS

GitHub хранит установщики и ленту обновлений Sparkle. Пользователи получают
новую версию из последнего стабильного GitHub Release. Собственный сервер
и токен GitHub внутри приложения не нужны.

**Push запускает CI, но не выпускает релиз.** Подпись Developer ID,
нотариализация Apple и подпись Sparkle выполняются на Mac владельца, где
в Keychain хранятся сертификат и ключи. Затем готовые файлы загружаются на GitHub.
Сборка установщика и обновления Windows описаны в [отдельной инструкции](windows-releasing.md).

## 1. Что уже настроено и что нужно сохранить

| Параметр | Значение |
| --- | --- |
| Репозиторий | [DartMule/walone](https://github.com/DartMule/walone) |
| Подпись | `Developer ID Application: Kirill Tyudeshev (H8U6D688WD)` |
| Профиль нотариализации в Keychain | `walone-notary` |
| Account ключа Sparkle в Keychain | `dev.soyjanks.walone.flutter` |
| Инструменты Sparkle | Версия 2.10.0, каталог `bin/` официального дистрибутива |
| Flutter | Версия из `.fvmrc`, локальный SDK `.fvm/flutter_sdk` |
| Последний выпуск при написании инструкции | `0.1.1+2`, тег `v0.1.1` |

Для следующих выпусков на этом Mac повторная настройка Apple Account не нужна,
пока сертификат, профиль и ключи действуют. На новом Mac понадобятся сертификат
**с закрытым ключом**, профиль нотариализации, исходный закрытый ключ Sparkle,
Flutter и авторизованный GitHub CLI.

Сохраните резервные копии сертификата с закрытым ключом и ключа Sparkle
в защищённом хранилище вне репозитория. Способ экспорта ключа описывает
`generate_keys --help`. Не генерируйте новый ключ Sparkle для обычного релиза:
установленные приложения доверяют ключу из своего `SUPublicEDKey`.
Не меняйте bundle ID или команду Apple, которой подписано приложение,
как часть обычного обновления.

Распакуйте [официальный Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)
в постоянный каталог вне проекта. Каталог `/private/tmp/walone-release-tools/bin`,
использованный для первых выпусков, временный и может исчезнуть после очистки Mac.

## 2. Подготовить новую версию

Все команды ниже выполняются из корня Walone в одном терминале.
Пример следующего выпуска — **0.1.2, сборка 3**. Перед каждым выпуском проверьте
[последний релиз](https://github.com/DartMule/walone/releases/latest) и выберите
новые номера. Оба номера должны расти; номер после `+` никогда не обнуляется.
Например: `0.1.1+2` → `0.1.2+3` → `0.2.0+4`.

1. Завершите и сохраните изменения приложения.
2. В `pubspec.yaml` задайте:

   ```yaml
   version: 0.1.2+3
   ```

3. Добавьте в `CHANGELOG.md` раздел версии с изменениями для пользователя.
4. Задайте переменные; замените путь `SPARKLE_BIN` на свой:

   ```sh
   VERSION=0.1.2
   BUILD=3
   SPARKLE_BIN="/absolute/path/to/Sparkle-2.10.0/bin"
   IDENTITY='Developer ID Application: Kirill Tyudeshev (H8U6D688WD)'
   NOTES="$PWD/.local/release-notes-$VERSION.md"
   OUTPUT="$PWD/dist/macos/$VERSION+$BUILD"
   ARCHIVE="Walone-$VERSION-$BUILD-macos.dmg"
   ```

5. Создайте `.local/`, если его ещё нет, и файл описания только нового выпуска:

   ```sh
   mkdir -p .local
   cat > "$NOTES" <<'NOTES_END'
   Что изменилось в этой версии:

   - Опишите исправления и новые возможности для пользователя.
   NOTES_END
   ```

   Отредактируйте пример перед сборкой. Этот текст попадёт в GitHub Release
   и окно обновления. Не используйте весь накопленный CHANGELOG как описание
   одной версии. `.local/` исключён из Git.

## 3. Проверить исходники и доступы

```sh
git status --short
gh auth status
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile walone-notary --output-format json
"$SPARKLE_BIN/generate_keys" --account dev.soyjanks.walone.flutter -p
/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' macos/Runner/Info.plist
```

Две последние команды выводят **публичный** ключ; значения должны совпадать.
Убедитесь, что сертификат Developer ID виден и не истёк, а `notarytool`
возвращает историю без ошибки авторизации.

Запускайте проверки последовательно; обёртка очереди использует общий
для локальных проектов lock. Каждую команду оборачивайте один раз.

```sh
python3 tool/resource_queue.py .fvm/flutter_sdk/bin/flutter pub get --enforce-lockfile
python3 tool/check_migration.py
python3 -m unittest discover -s tool -p '*_test.py'
python3 tool/resource_queue.py .fvm/flutter_sdk/bin/flutter analyze --no-pub
python3 tool/resource_queue.py .fvm/flutter_sdk/bin/flutter test --no-pub --concurrency=1
```

Если менялись зависимости, сначала обновите и проверьте `pubspec.lock`
обычным `pub get`, затем включите его в коммит. Не обходите ошибку
`--enforce-lockfile`, не разобрав причину.

Сохраните изменения и отправьте их на GitHub. Пример ниже добавляет только
метаданные выпуска; изменённый код должен быть закоммичен отдельно или добавлен
явным списком файлов. Эти команды выполняются, когда вы решили выпускать релиз:

```sh
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: prepare $VERSION release"
git push origin main
RELEASE_COMMIT=$(git rev-parse HEAD)
gh run list --repo DartMule/walone --commit "$RELEASE_COMMIT" --limit 1
```

Дождитесь успешного [CI](https://github.com/DartMule/walone/actions).
Он проверяет секреты в файлах и истории, ресурсы, Python-тесты, Dart-анализ,
Flutter-тесты и сборку macOS. Затем убедитесь, что `git status --short` пуст.
Собирайте из того же коммита, который будет указан в релизе; не меняйте исходники
между сборкой и публикацией.

## 4. Собрать подписанный установщик

```sh
python3 tool/resource_queue.py python3 -m tool.publish_macos \
  --flutter "$PWD/.fvm/flutter_sdk/bin/flutter" \
  --sparkle-tools "$SPARKLE_BIN" \
  --identity "$IDENTITY" \
  --notary-profile walone-notary \
  --notes "$NOTES"
```

Команда соберёт Release, подпишет приложение и вложенные компоненты, отправит
приложение и DMG на нотариализацию, прикрепит tickets, проверит Gatekeeper,
создаст подписанный `appcast.xml` и контрольную сумму. Ожидание Apple может
занять несколько минут. При ошибке команда завершится без публикации.

Готовые файлы появятся в `dist/macos/0.1.2+3/`:

- `Walone-0.1.2-3-macos.dmg` — первоначальная установка и архив обновления;
- `appcast.xml` — версия, URL архива и подпись Ed25519;
- `SHA256SUMS` — контрольная сумма DMG;
- файл `.md` — копия описания выпуска, публиковать её отдельным asset необязательно.

Проверьте результат:

```sh
(cd "$OUTPUT" && shasum -a 256 -c SHA256SUMS)
xcrun stapler validate "$OUTPUT/$ARCHIVE"
```

Проверьте в `appcast.xml` версию, номер сборки и URL вида
`https://github.com/DartMule/walone/releases/download/v0.1.2/Walone-0.1.2-3-macos.dmg`.
При необходимости откройте DMG и проверьте приложение на тестовом Mac.
Сборщик сам не заменяет `/Applications/Walone.app` и пользовательские данные.

**Не меняйте DMG после создания appcast:** подпись и контрольная сумма относятся
к конкретным байтам архива. Не редактируйте `Info.plist` внутри подписанного приложения.

## 5. Создать черновик и опубликовать

Перед ручной публикацией ещё раз проверьте, что выбранные версия и номер сборки
новее опубликованных: эта защита встроена в режим `--publish`, но не в ручные
команды `gh` ниже.

```sh
gh release create "v$VERSION" --repo DartMule/walone --draft \
  --target "$RELEASE_COMMIT" \
  --title "Walone $VERSION" --notes-file "$NOTES" \
  "$OUTPUT/$ARCHIVE" "$OUTPUT/appcast.xml" "$OUTPUT/SHA256SUMS"

gh release view "v$VERSION" --repo DartMule/walone \
  --json tagName,isDraft,targetCommitish,assets
```

`RELEASE_COMMIT` должен содержать **полный SHA**, полученный через `git rev-parse HEAD`.
Убедитесь, что в черновике правильный коммит и все три файла имеют состояние
`uploaded`. Пока релиз — draft, пользователи его не получают.

Опубликовать и назначить последним стабильным релизом:

```sh
gh release edit "v$VERSION" --repo DartMule/walone --draft=false --latest
```

**С этого момента приложение может скачать обновление в фоне.** GitHub создаст
тег `v0.1.2`, если его ещё нет. Каждый релиз, назначенный `latest`, должен
содержать корректный `appcast.xml`; не назначайте latest посторонним или
экспериментальным выпускам.

Проверьте ленту без авторизации:

```sh
curl --fail --silent --show-error --location \
  https://github.com/DartMule/walone/releases/latest/download/appcast.xml \
  --output .local/published-appcast.xml
cmp "$OUTPUT/appcast.xml" .local/published-appcast.xml
```

Проверьте скачивание DMG по ссылке из ленты и его SHA-256. Страница для знакомых
остаётся постоянной: [скачать последнюю версию](https://github.com/DartMule/walone/releases/latest).
Им не нужен аккаунт GitHub.

### Альтернатива: сборка и немедленная публикация одной командой

Для нового, ещё не собранного выпуска можно добавить `--publish` к команде
из шага 4. Сборщик проверит публичность репозитория и рост номера сборки,
создаст draft, загрузит файлы и сразу опубликует latest.

Основной порядок выше позволяет осмотреть файлы до публикации и явно указать
коммит. Не запускайте сборщик второй раз с `--publish` для уже существующего
`OUTPUT`: он откажется перезаписывать каталог. Готовые файлы публикуются
командами `gh` из шага 5 без пересборки.

## 6. Проверить обновление на установленной предыдущей версии

Перед проверкой сохраните резервную копию пользовательских данных при закрытом
приложении. На macOS они находятся здесь:

```text
~/Library/Application Support/dev.soyjanks.walone.flutter/WaloneFlutter/
~/Library/Preferences/dev.soyjanks.walone.flutter.plist
```

В Application Support находятся музыка, `Music/library.json`, `appearance.json`,
`atmosphere.json`, история клавиатур при её наличии и `statistics.sqlite`.
Не помещайте резервную копию в Git. Для открытой SQLite используйте SQLite backup
API; копирование одного файла живой базы без WAL не гарантирует целую копию.

1. Оставьте установленной предыдущую опубликованную версию. Не устанавливайте
   новый DMG поверх неё перед тестом — иначе переход через Sparkle не проверяется.
2. Дождитесь фоновой загрузки. Автоматическая проверка периодическая,
   она не обязана начаться немедленно после публикации. При необходимости
   нажмите «Проверить обновления…» в настройках или в меню приложения.
3. Начиная с 0.1.1 при доступной версии появляется небольшая кнопка рядом
   с «Настройками». После фоновой загрузки её подсказка — «Обновить и перезапустить».
   Такая же кнопка есть в разделе обновлений настроек.
4. Нажмите «Обновить и перезапустить». Проверьте, что приложение само завершилось,
   обновилось и открылось снова. Версию установленной копии можно прочитать так:

   ```sh
   /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Walone.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' /Applications/Walone.app/Contents/Info.plist
   ```

5. Сравните тему, материал интерфейса, громкости, наборы, треки, плейлисты,
   порядок очереди, выбранный трек, позицию и статистику с состоянием до обновления.
   Проверьте уже выданное разрешение «Мониторинг ввода» и статус автозапуска.
6. Для изменений хранения дополнительно проверьте миграции на копии реальных
   данных. Для изменений подписи, разрешений или минимальной версии macOS
   проверьте первый запуск на другом Mac; по возможности на Apple Silicon и Intel.

[Проверка перехода 0.1.0 → 0.1.1](update-check-0.1.1.md) содержит фактические
результаты и ограничения первого прогона. Отдельные сценарии расширенной приёмки:
установка при обычном выходе, отсутствие сети, ошибка загрузки и недействительная
подпись. Успешная сборка их не заменяет.

## Если что-то пошло не так

| Ситуация | Действие |
| --- | --- |
| `notarytool` возвращает 401 или не находит профиль | Повторно сохраните `walone-notary` через интерактивный `xcrun notarytool store-credentials`; нужен пароль приложения Apple Account. Не вставляйте его в чат, файл или аргументы команды. |
| Не найден сертификат или закрытый ключ | Проверьте login Keychain и `security find-identity -v -p codesigning`. Для распространения нужен Developer ID Application. |
| Ключ Sparkle не совпадает | Остановите выпуск и восстановите исходный ключ из защищённой резервной копии. Не заменяйте публичный ключ ради обхода ошибки. |
| Каталог `dist` этой сборки уже существует | Для публикации готового результата используйте шаг 5. Для новой сборки увеличьте номер либо сохраните прежний каталог отдельно до повторной подготовки ещё не опубликованного выпуска. |
| Загрузка assets оборвалась | Найдите draft через `gh release list` и `gh release view`. Загрузите недостающий файл командой `gh release upload "v$VERSION" --repo DartMule/walone <путь-к-файлу>`, затем проверьте все assets перед публикацией. Не перезаписывайте публичные файлы. |
| Вышел неудачный релиз | Выпустите исправление с новой версией и большим номером сборки. Переназначение latest на старую версию не откатит уже обновившиеся приложения и не отменит уже скачанное обновление. |
| После первоначальной установки пропал глобальный ввод | Проверьте «Мониторинг ввода» для установленной Walone и перезапустите её. Локальная Apple Development и распространяемая Developer ID сборки могут требовать отдельного разрешения. |

Для возврата к старой версии на одном Mac закройте приложение, сохраните данные
и установите прежний подписанный DMG вручную. Если менялся формат данных,
сначала проверьте совместимость: старое приложение может не читать новую базу.
Не восстанавливайте старую резервную копию поверх новых данных без отдельного решения.

Существующие публичные теги и бинарные файлы релизов не перезаписываются.
Обычное исправление — следующий релиз со строго большим номером сборки.

## Локальная установка для разработки

```sh
python3 tool/resource_queue.py python3 tool/macos_release.py \
  --flutter "$PWD/.fvm/flutter_sdk/bin/flutter"
python3 tool/macos_release.py --verify-only
```

Этот отдельный установщик заменяет локальную копию с проверкой и откатом,
но не нотариализирует её и не выпускает обновление на GitHub.

Справка: [Developer ID](https://developer.apple.com/developer-id/),
[нотариализация Apple](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[публикация Sparkle](https://sparkle-project.org/documentation/publishing/),
[GitHub CLI Releases](https://cli.github.com/manual/gh_release).
