# Руководство по установке

Полное руководство по настройке Secure P2P Messenger для вашей команды.

[English](INSTALLATION.md) | [Русский](#русский)

---

## Русский

## Содержание

1. [Настройка сервера](#настройка-сервера)
2. [Конфигурация клиента](#конфигурация-клиента)
3. [Сборка приложений](#сборка-приложений)
4. [Распространение пользователям](#распространение-пользователям)
5. [Решение проблем](#решение-проблем)

---

## Настройка сервера

### Требования

- **VPS** с публичным IP адресом
- **512MB RAM** минимум (рекомендуется 1GB для 50+ пользователей)
- **10GB хранилища**
- **Ubuntu 20.04+** или любой Linux дистрибутив
- **Порт 9090** открыт для WebSocket соединений

### Вариант 1: Прямая установка (Рекомендуется)

#### 1. Установка Dart SDK

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка зависимостей
sudo apt install apt-transport-https wget -y

# Добавление репозитория Dart
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'

# Установка Dart
sudo apt update
sudo apt install dart -y

# Добавление Dart в PATH
echo 'export PATH="$PATH:/usr/lib/dart/bin"' >> ~/.bashrc
source ~/.bashrc

# Проверка установки
dart --version
```

#### 2. Настройка сервера

```bash
# Создание директории
mkdir -p ~/messenger-server
cd ~/messenger-server

# Загрузка server.dart из репозитория
wget https://raw.githubusercontent.com/sssilverhand/secure-p2p-messenger/main/server/server.dart

# Редактирование кодов доступа
nano server.dart
```

**Генерация безопасных кодов доступа:**

```bash
# Метод 1: Используя OpenSSL (рекомендуется)
openssl rand -base64 20 | tr -d '/+=' | head -c 24 | sed 's/\(....\)/SECURE-\1-/g' | sed 's/-$//'

# Метод 2: Используя /dev/urandom
cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 24 | head -n 1 | sed 's/\(....\)/SECURE-\1-/g' | sed 's/-$//'

# Пример результата:
# SECURE-A1B2-C3D4-E5F6-G7H8
```

**Отредактируйте server.dart и добавьте свои коды:**

```dart
final Set<String> accessCodes = {
  'SECURE-ВАШ-КОД-ЗДЕСЬ-1234',
  'SECURE-ВАШ-КОД-ЗДЕСЬ-5678',
  'SECURE-ВАШ-КОД-ЗДЕСЬ-9012',
  // Добавьте один код на пользователя/группу
};
```

#### 3. Настройка файрвола

```bash
# Разрешить SSH (если ещё не разрешён)
sudo ufw allow 22

# Разрешить порт мессенджера
sudo ufw allow 9090

# Включить файрвол
sudo ufw enable

# Проверить статус
sudo ufw status
```

#### 4. Создание Systemd сервиса (Автозапуск при загрузке)

```bash
# Создание файла сервиса
sudo nano /etc/systemd/system/messenger-server.service
```

**Добавьте это содержимое:**

```ini
[Unit]
Description=Secure P2P Messenger Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/messenger-server
ExecStart=/usr/lib/dart/bin/dart /root/messenger-server/server.dart
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Включение и запуск сервиса:**

```bash
# Перезагрузка systemd
sudo systemctl daemon-reload

# Включение автозапуска
sudo systemctl enable messenger-server

# Запуск сервера
sudo systemctl start messenger-server

# Проверка статуса
sudo systemctl status messenger-server

# Просмотр логов
sudo journalctl -u messenger-server -f
```

#### 5. Тестирование сервера

```bash
# Проверка работы сервера
netstat -tulpn | grep 9090

# Тест WebSocket соединения
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" http://IP_ВАШЕГО_СЕРВЕРА:9090
```

### Вариант 2: Установка через Docker

#### 1. Создание Dockerfile

```dockerfile
FROM dart:stable

WORKDIR /app

COPY server.dart .

EXPOSE 9090

CMD ["dart", "server.dart"]
```

#### 2. Сборка и запуск

```bash
# Сборка образа
docker build -t messenger-server .

# Запуск контейнера
docker run -d -p 9090:9090 --name messenger --restart unless-stopped messenger-server

# Просмотр логов
docker logs -f messenger

# Остановка/Запуск
docker stop messenger
docker start messenger
```

---

## Конфигурация клиента

### Требования

- **Flutter 3.0+**
- **Dart SDK 3.0+**
- **Android SDK** (для сборки APK)
- **Visual Studio 2019+** (для сборки Windows)

### 1. Клонирование репозитория

```bash
git clone https://github.com/sssilverhand/secure-p2p-messenger.git
cd secure-p2p-messenger
```

### 2. Установка зависимостей

```bash
flutter pub get
```

### 3. Настройка клиента

```bash
# Копирование примера конфига
cp lib/config.example.dart lib/config.dart

# Редактирование конфига
nano lib/config.dart
```

**Обновите эти значения:**

```dart
class Config {
  // Замените на IP адрес вашего VPS
  static const String SERVER_URL = "ws://IP_ВАШЕГО_СЕРВЕРА:9090";
  
  // Получите бесплатный App ID на https://console.agora.io/
  static const String AGORA_APP_ID = "ВАШ_AGORA_APP_ID";
  
  // Опционально: Настройка лимита размера файла
  static const int MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
}
```

### 4. Получение Agora App ID (для голосовых/видеозвонков)

1. Перейдите на [https://console.agora.io/](https://console.agora.io/)
2. Зарегистрируйте бесплатный аккаунт
3. Создайте новый проект
4. Скопируйте **App ID** (НЕ App Certificate)
5. Вставьте его в `config.dart`

**Примечание:** Бесплатный тариф включает:
- 10,000 минут/месяц
- Достаточно для малых групп
- Не требуется кредитная карта

---

## Сборка приложений

### Android APK

#### 1. Настройка Android

Отредактируйте `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    // Измените на уникальное имя пакета
    applicationId = "com.yourcompany.securemessenger"
    minSdk = 21
    targetSdk = 34
    versionCode = 1
    versionName = "1.0.0"
}
```

#### 2. Сборка APK

```bash
# Чистая сборка
flutter clean
flutter pub get

# Сборка релизного APK
flutter build apk --release

# Расположение файла:
# build/app/outputs/flutter-apk/app-release.apk
```

#### 3. (Опционально) Подписание APK для продакшна

```bash
# Генерация keystore
keytool -genkey -v -keystore ~/upload-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias upload

# Создание android/key.properties
cat > android/key.properties << EOF
storePassword=ВАШ_ПАРОЛЬ_ХРАНИЛИЩА
keyPassword=ВАШ_ПАРОЛЬ_КЛЮЧА
keyAlias=upload
storeFile=/путь/к/upload-keystore.jks
EOF

# Обновите android/app/build.gradle.kts (см. комментарии в файле)
# Затем пересоберите
flutter build apk --release
```

### Windows EXE

#### 1. Требования

- **Visual Studio 2019+** с разработкой C++ для десктопа
- **Windows 10+**

#### 2. Сборка Windows приложения

```bash
# Чистая сборка
flutter clean
flutter pub get

# Сборка релиза
flutter build windows --release

# Расположение файлов:
# build/windows/runner/Release/
```

#### 3. Создание пакета для распространения

```bash
# Создание папки для распространения
mkdir secure-messenger-windows

# Копирование всех файлов из Release
cp -r build/windows/runner/Release/* secure-messenger-windows/

# Создание ZIP архива
zip -r secure-messenger-windows.zip secure-messenger-windows/
```

**Файлы для включения:**
- `secure_p2p_messenger.exe`
- Все `.dll` файлы
- Папка `data/`

---

## Распространение пользователям

### Что нужно пользователям

1. **Код доступа** (сгенерированный вами)
2. **APK файл** (Android) или **EXE пакет** (Windows)

### Методы распространения

#### Вариант 1: Прямая передача

- Отправьте APK/EXE через защищённый канал
- Отправьте код доступа отдельно (SMS, зашифрованная почта и т.д.)

#### Вариант 2: GitHub Releases

1. Перейдите в репозиторий → Releases
2. Создайте новый релиз
3. Загрузите APK и Windows ZIP
4. Поделитесь ссылкой на релиз с пользователями

#### Вариант 3: Приватный файловый сервер

- Разместите файлы на вашем VPS
- Поделитесь ссылками для скачивания

### Шаги установки для пользователей

#### Android:

1. Включите "Неизвестные источники" в Настройках
2. Скачайте и установите APK
3. Откройте приложение
4. Введите код доступа
5. Начните общение!

#### Windows:

1. Скачайте и распакуйте ZIP файл
2. Запустите `secure_p2p_messenger.exe`
3. Введите код доступа
4. Начните общение!

---

## Решение проблем

### Проблемы сервера

#### Сервер не запускается

```bash
# Проверьте используется ли порт
sudo lsof -i :9090

# Убейте процесс использующий порт
sudo kill -9 <PID>

# Перезапустите сервер
sudo systemctl restart messenger-server
```

#### Отказ в соединении

```bash
# Проверьте файрвол
sudo ufw status

# Разрешите порт
sudo ufw allow 9090

# Проверьте работает ли сервер
sudo systemctl status messenger-server
```

#### Просмотр логов сервера

```bash
# Логи в реальном времени
sudo journalctl -u messenger-server -f

# Последние 100 строк
sudo journalctl -u messenger-server -n 100
```

### Проблемы клиента

#### Не удаётся подключиться к серверу

1. **Проверьте SERVER_URL в config.dart:**
   - Должен начинаться с `ws://` (не `http://`)
   - Используйте публичный IP VPS (не localhost)
   - Порт должен быть 9090

2. **Проверьте файрвол VPS:**
   ```bash
   sudo ufw allow 9090
   ```

3. **Тест соединения:**
   ```bash
   telnet IP_ВАШЕГО_СЕРВЕРА 9090
   ```

#### Неверный код доступа

- Код чувствителен к регистру
- Формат: `SECURE-XXXX-XXXX-XXXX-XXXX`
- Проверьте существует ли код в server.dart

#### Звонки не работают

1. **Проверьте Agora App ID:**
   - Должен быть действительный App ID (не App Certificate)
   - Без пробелов или кавычек

2. **Проверьте разрешения:**
   - Android: Микрофон + Камера в Настройках
   - Windows: Разрешите приложение в файрволе

#### Ошибки сборки

```bash
# Очистка и пересборка
flutter clean
flutter pub get
flutter pub upgrade

# Для Android
flutter build apk --release

# Для Windows
flutter build windows --release
```

### Проблемы с сетью в ограниченных странах

Если звонки не работают в России/Китае:

1. Agora использует глобальные edge серверы
2. Работает через DPI/packet inspection
3. Переключение на TURN relay при необходимости
4. VPN не требуется для базового функционала

---

## Лучшие практики безопасности

### Для администраторов:

1. **Храните коды доступа в безопасности:**
   - Никогда не коммитьте реальные коды в Git
   - Храните отдельно от репозитория
   - Используйте сильные случайные коды

2. **Регулярно обновляйте сервер:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Мониторьте логи сервера:**
   ```bash
   sudo journalctl -u messenger-server -f
   ```

4. **Делайте резервные копии keystore файлов:**
   - Храните Android keystore безопасно
   - Держите пароль в секрете

### Для пользователей:

1. **Храните код доступа в секрете**
2. **Не делитесь аккаунтом с другими**
3. **Включите блокировку устройства/PIN**
4. **Используйте "Аварийную очистку" при потере устройства**

---

## Обновление

### Обновление сервера

```bash
# Остановите сервер
sudo systemctl stop messenger-server

# Обновите server.dart
cd ~/messenger-server
wget https://raw.githubusercontent.com/sssilverhand/secure-p2p-messenger/main/server/server.dart -O server.dart

# Перезапустите сервер
sudo systemctl start messenger-server
```

### Обновление клиента

```bash
# Получите последние изменения
git pull origin main

# Обновите зависимости
flutter pub get

# Пересоберите
flutter build apk --release
flutter build windows --release
```

---

## FAQ (Часто задаваемые вопросы)

**В: Сколько пользователей может обслужить один сервер?**
О: 50+ пользователей легко на VPS с 1GB RAM. Протестировано с 100+ одновременными подключениями.

**В: Могу ли я использовать доменное имя вместо IP?**
О: Да! Используйте `ws://вашдомен.com:9090` в config.dart

**В: Работает ли без VPS?**
О: Нет. Сервер необходим для relay и хранения оффлайн сообщений.

**В: Могу ли я использовать HTTPS/WSS?**
О: Да, но требуется SSL сертификат и nginx reverse proxy.

**В: Как сгенерировать больше кодов доступа?**
О: Используйте команду OpenSSL из раздела Настройка сервера.

**В: Что если я потеряю свой код доступа?**
О: Администратор должен сгенерировать новый код. Данные не могут быть восстановлены без кода.

---

## Поддержка

- **Проблемы:** [GitHub Issues](https://github.com/sssilverhand/secure-p2p-messenger/issues)
- **Обсуждения:** [GitHub Discussions](https://github.com/sssilverhand/secure-p2p-messenger/discussions)

---

**Сделано с ❤️ автором [sssilverhand](https://github.com/sssilverhand)**
