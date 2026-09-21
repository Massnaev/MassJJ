# Contributing to MassJJ

Спасибо за интерес к MassJJ. Сейчас проект находится на стадии Android MVP.

## Перед началом

1. Прочитайте `AGENTS.md`, `docs/AI_HANDOFF.md` и `SECURITY.md`.
2. Для значительного изменения сначала создайте Issue с описанием поведения и
   границ задачи.
3. Не смешивайте рефакторинг, дизайн и изменение протокола в одном PR.

## Проверка

```powershell
flutter analyze
flutter test
node --test server/test/*.test.mjs
```

Для Android-изменений дополнительно выполните:

```powershell
flutter build apk --release
```

Изменения интерфейса должны сопровождаться обновлёнными golden-тестами и их
визуальной проверкой. Любое изменение должно обновлять `docs/AI_HANDOFF.md` в том
же коммите.

## Безопасность

Не добавляйте настоящие recovery-коды, токены, `.env`, relay-данные, APK,
keystore или signing credentials. Уязвимости отправляйте приватно согласно
`SECURITY.md`, а не через публичный Issue.

