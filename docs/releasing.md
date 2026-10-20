# Выпуск macOS-релиза

Обновления использует Sparkle 2.10.0; архивы и `appcast.xml` хранятся в
публичных GitHub Releases репозитория `DartMule/walone`.
Собственный сервер, GitHub Pages и токен внутри приложения не требуются.

## Подготовка на Mac владельца

1. Установите **Developer ID Application** сертификат с закрытым ключом
   в login Keychain. Apple Development для распространения не подходит.
   Проверка: `security find-identity -v -p codesigning`.
2. Настройте профиль нотариализации в Keychain командой
   `xcrun notarytool store-credentials walone-notary`. Вводите учётные данные
   интерактивно, не сохраняйте их в репозитории или истории команд.
3. Установите GitHub CLI и выполните `gh auth login`. Нужен доступ на запись
   к `DartMule/walone`; репозиторий с начальной веткой должен уже существовать.
4. Скачайте официальный [Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)
   и распакуйте вне репозитория. Сборка использует ту же закреплённую версию
   через Swift Package Manager. Параметр `--sparkle-tools` указывает на его `bin/`.
5. Проверьте публичный ключ:

   ```sh
   /path/to/Sparkle/bin/generate_keys --account dev.soyjanks.walone.flutter -p
   ```

   Он должен совпадать с `SUPublicEDKey` в `macos/Runner/Info.plist`.
   Закрытый ключ Walone уже создан в Keychain этого Mac под указанным account.
   Его нельзя генерировать заново после распространения первой версии.
   Для резервной копии используйте экспорт `generate_keys -x` в защищённое
   хранилище вне проекта; не передавайте ключ в аргументах команд или GitHub.

Официальные инструкции: [Developer ID](https://developer.apple.com/developer-id/),
[нотариализация](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[публикация Sparkle](https://sparkle-project.org/documentation/publishing/).

## Проверка и сборка

Увеличьте версию и номер сборки в `pubspec.yaml`, например `0.1.1+2`.
Номер после `+` должен строго расти. Номер версии тоже должен быть новым:
релиз получает тег `v0.1.1`, существующий релиз не перезаписывается.
Запишите изменения для пользователя в отдельный Markdown-файл без секретов.

```sh
python3 tool/check_migration.py
python3 -m unittest discover -s tool -p '*_test.py'
python3 tool/resource_queue.py .fvm/flutter_sdk/bin/flutter analyze --no-pub
python3 tool/resource_queue.py .fvm/flutter_sdk/bin/flutter test --no-pub --concurrency=1
python3 tool/resource_queue.py python3 -m tool.publish_macos \
  --flutter "$PWD/.fvm/flutter_sdk/bin/flutter" \
  --sparkle-tools /path/to/Sparkle/bin \
  --identity 'Developer ID Application: Your Name (TEAMID)' \
  --notary-profile walone-notary \
  --notes CHANGELOG.md
```

Без `--publish` команда создаёт проверенные файлы в
`dist/macos/<версия>+<сборка>/` и ничего не публикует.
Установленная `/Applications/Walone.app`, музыка и настройки не меняются.
DMG содержит ссылку «Программы» для первоначальной установки и используется
Sparkle как архив обновления. Приложение и DMG нотариализируются;
ticket прикрепляется к обоим. Подпись Sparkle создаётся из Keychain.

Каталог конкретной сборки не перезаписывается. При повторной подготовке
используйте новый номер сборки или самостоятельно переместите прежний каталог.
Если сертификатов несколько, `--identity` обязателен.
`--skip-build` разрешает использовать существующую Release-сборку;
её версия берётся из собранного `Info.plist`, а не из изменённого pubspec.

## Публикация

После проверки материалов запустите ту же команду с `--publish` при подготовке
новой сборки. Она проверит видимость репозитория и опубликованный номер сборки,
создаст draft-релиз с DMG, `appcast.xml` и `SHA256SUMS`, затем опубликует его
как latest. Релиз с тем же тегом не перезаписывается. При ошибке загрузки
draft остаётся неопубликованным: проверьте его перед ручным продолжением.

Уже подготовленные файлы можно опубликовать без пересборки:

```sh
gh release create v0.1.0 --repo DartMule/walone --draft \
  --title 'Walone 0.1.0' --notes-file CHANGELOG.md \
  dist/macos/0.1.0+1/Walone-0.1.0-1-macos.dmg \
  dist/macos/0.1.0+1/appcast.xml dist/macos/0.1.0+1/SHA256SUMS
gh release edit v0.1.0 --repo DartMule/walone --draft=false --latest
```

Адрес проверки внутри приложения:
`https://github.com/DartMule/walone/releases/latest/download/appcast.xml`.
До первой публикации он не существует. Каждый latest-релиз обязан содержать
валидный `appcast.xml`; не назначайте latest посторонним или тестовым релизам.
Первый экземпляр Walone со Sparkle нужно установить вручную: старые сборки
без механизма обновлений не могут скачать его сами.

## Приёмка обновления

До приглашения знакомых проверьте переход между **двумя** Developer ID
подписанными, нотариализированными версиями со строго растущими номерами:

- Ручная проверка из настроек и меню, обнаружение доступной версии.
- Фоновая загрузка, кнопка «Обновить и перезапустить» и установка при обычном выходе.
- Сохранность медиатеки, статистики, позиции и настроек; корректное завершение импорта.
- Мониторинг ввода и автозапуск после замены приложения.
- Отсутствие сети, отказ загрузки и недействительная подпись обновления.
- Первый запуск DMG на другом Mac, по возможности Apple Silicon и Intel.

Эта проверка не заменяется успешной компиляцией или подписью локального архива.
Windows-релизы и автоматическое обновление Windows пока не настроены.

## Локальная установка для разработки

Прежний локальный установщик сохранён:

```sh
python3 tool/resource_queue.py python3 tool/macos_release.py \
  --flutter "$PWD/.fvm/flutter_sdk/bin/flutter"
python3 tool/macos_release.py --verify-only
```

Он использует постоянную сертификатную подпись, проверяет замену и откат,
но не нотариализирует приложение и не выпускает GitHub-релиз.
