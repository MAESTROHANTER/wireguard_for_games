Минимально‑задержочный (low‑latency) автосетап **WireGuard для геймеров** на Debian/Ubuntu + готовый клиентский конфиг для Windows/Linux **без ручной генерации ключей на клиенте** и **без дурацких плейсхолдеров**.

---

## Зачем
Вам нужен максимально быстрый туннель через ближайший к вам VPS / VDS, чтобы игровой трафик шёл через сервер с наименьшими задержками и чтобы вы могли быстро раздать готовый конфиг друзьям / сообществу.

---

## Ключевые цели
- **Никаких плейсхолдеров типа <VPS_IP>** — скрипт сам определяет публичный IP сервера.
- **Автогенерация ключей сервера и клиента на сервере.** Клиент только скачивает готовый файл.
- **Авто‑NAT (маскарадинг)**, чтобы внешний IP на клиенте стал IP вашего VPS (иначе вы увидите старый IP и подумаете, что «не работает»).
- **Отключение сетевых offload‑функций** на внешнем интерфейсе сервера для снижения джиттера.
- **Минимум зависимостей**. Если на сервере нет `git`, всё равно работает (используйте `curl` или `wget`).

---

# Быстрый старт (если НЕТ git на сервере)
> Работает на чистом Debian/Ubuntu.

```bash
# 1. Зайдите на сервер по SSH под root (или sudo).
# 2. Скачайте скрипт напрямую (raw) c GitHub:
curl -fsSL https://raw.githubusercontent.com/MAESTROHANTER/wireguard_for_games/main/wireguard_setup_script.sh -o wireguard_setup_script.sh

# 3. Сделайте исполняемым и запустите
chmod +x wireguard_setup_script.sh
sudo ./wireguard_setup_script.sh
```

Если нет `curl`, попробуйте `wget`:
```bash
wget -O wireguard_setup_script.sh https://raw.githubusercontent.com/MAESTROHANTER/wireguard_for_games/main/wireguard_setup_script.sh
chmod +x wireguard_setup_script.sh
sudo ./wireguard_setup_script.sh
```

---

# Быстрый старт (если git ЕСТЬ или вы хотите его поставить)
```bash
sudo apt update
sudo apt install -y git

git clone https://github.com/MAESTROHANTER/wireguard_for_games.git
cd wireguard_for_games
chmod +x wireguard_setup_script.sh
sudo ./wireguard_setup_script.sh
```

---

# Что делает скрипт
1. Устанавливает нужные пакеты: `wireguard-tools`, `iproute2`, `iptables`, `ethtool`, `curl` (если его нет).
2. Генерирует **серверный** и **клиентский** ключи.
3. Создаёт **/etc/wireguard/wg0.conf** и **/etc/wireguard/wg0-client.conf**.
4. Определяет **публичный IP сервера** автоматически (через несколько внешних служб; берётся первый успешный ответ).
5. Вставляет найденный IP в клиентский конфиг (Endpoint = <public_ip>:порт).
6. Отключает offload‑функции на внешнем сетевом интерфейсе (который обнаружен по default‑маршруту).
7. Включает IPv4‑форвардинг.
8. Ставит NAT (MASQUERADE) с WireGuard‑подсети на внешний интерфейс, чтобы у клиента был внешний IP сервера.
9. Запускает интерфейс `wg0`.
10. Показывает **готовую команду scp** с реальным IP — её можно копипастить без правок.

---

# Выходные файлы
| Файл | Назначение |
|---|---|
| `/etc/wireguard/wg0.conf` | Конфигурация сервера WireGuard |
| `/etc/wireguard/wg0-client.conf` | Готовый клиентский конфиг (импортировать в Windows/Linux) |
| `/root/wg_public_ip.txt` | Кэш определённого публичного IP (для логов/отладки) |

---

# Как скачать клиентский конфиг (готовая копипаста)
После запуска скрипт **сам напечатает** что‑то вида:
```
=== СКАЧАЙТЕ КЛИЕНТСКИЙ КОНФИГ ===
scp root@203.0.113.27:/etc/wireguard/wg0-client.conf ./wg0-client.conf
```
Скопируйте строку как есть — IP уже подставлен.

> **Важно:** если ваш пользователь не root — замените `root@` на `username@`.

---

# Импорт на Windows
1. Установите WireGuard for Windows (MSI с официального сайта).
2. Запустите WireGuard → **Add Tunnel → Add empty tunnel**, или проще: **Import tunnel(s) from file…**.
3. Выберите скачанный `wg0-client.conf`.
4. Нажмите **Activate**.
5. Проверьте:
   ```powershell
   ping 10.0.0.1
   curl ifconfig.me
   ```
   Во втором случае вы должны увидеть IP вашего VPS.

---

# Импорт на Linux‑клиенте
```bash
sudo cp wg0-client.conf /etc/wireguard/
sudo wg-quick up wg0-client.conf
# или:
sudo wg-quick up wg0-client
```
Проверьте:
```bash
ping -c 3 10.0.0.1
curl ifconfig.me
```

---

# Настройки по умолчанию
- Сеть WireGuard: `10.0.0.0/24` (сервер `10.0.0.1`, первый клиент `10.0.0.2`).
- Порт: UDP 51820.
- DNS в клиентском конфиге: 1.1.1.1 (можете заменить).
- NAT: **включён** (иначе у клиента не сменится внешний IP и не всё будет работать в играх).

Хотите другое? Редактируйте переменные в начале скрипта.
