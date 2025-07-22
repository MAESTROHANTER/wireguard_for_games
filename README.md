#!/usr/bin/env bash
# README.md

## wireguard_for_games
Скрипт `setup_wg.sh` автоматически настраивает WireGuard VPN на Debian/Ubuntu сервере для минимальных задержек и генерирует клиентский конфиг `wg0-client.conf`.

### Возможности
- Установка `wireguard-tools`, `iproute2`, `ethtool`
- Генерация ключей сервера и клиента
- Создание `/etc/wireguard/wg0.conf` (сервер) и `/etc/wireguard/wg0-client.conf` (клиент)
- Отключение offload‑функций на внешнем интерфейсе для минимизации задержек
- Автоматический запуск интерфейса через `wg-quick up wg0`

### Требования
- Сервер на Debian/Ubuntu с root-доступом
- Интернет-соединение
- Порт UDP 51820 открыт

### Установка и использование
```bash
# Клонирование репозитория
git clone https://github.com/MAESTROHANTER/wireguard_for_games.git
cd wireguard_for_games

# Делаем скрипт исполняемым
chmod +x setup_wg.sh

# Запуск скрипта от root
sudo ./setup_wg.sh
```

После выполнения скрипта на сервере появятся файлы:
- `/etc/wireguard/wg0.conf` — конфигурация сервера
- `/etc/wireguard/wg0-client.conf` — готовый клиентский конфиг

### Получение клиентского конфига
Скопируйте `wg0-client.conf` на игровой ПК через SCP / SFTP:
```bash
scp root@<VPS_IP>:/etc/wireguard/wg0-client.conf ./
```
Затем импортируйте его в GUI WireGuard и активируйте туннель.

### Настройка клиента (Windows/Linux)
1. **Windows**: установите WireGuard MSI, импортируйте `wg0-client.conf` и нажмите **Activate**.
2. **Linux**: скопируйте `wg0-client.conf` в `/etc/wireguard/` и выполните:
   ```bash
   sudo wg-quick up wg0-client.conf
   ```

### Тестирование
- **Пинг туннельного шлюза**:
  ```bash
  ping 10.0.0.1
  ```
- **Проверка внешнего IP**:
  ```bash
  curl ifconfig.me
  ```

### Дополнительно
- Если требуется изменить порт или сеть, отредактируйте `setup_wg.sh` перед запуском.
- Для постоянного включения при старте: добавьте `wg-quick up wg0` в `/etc/rc.local` или Systemd Unit.

---
*Автоматизация создания простого и быстрого WireGuard туннеля для геймеров*
