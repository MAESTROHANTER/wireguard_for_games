#!/usr/bin/env bash
# wireguard_setup_script.sh
# Минимальный по задержкам автосетап WireGuard сервера + клиентского конфига.
# Без плейсхолдеров. Скрипт сам найдёт публичный IP и покажет команду scp.
# Поддержка: Debian / Ubuntu.

set -euo pipefail

### === Пользовательские параметры (меняйте по желанию) === ###
WG_IF="wg0"                 # имя интерфейса WireGuard
WG_NET="10.0.0.0/24"        # внутренняя сеть WG
WG_SRV_IP="10.0.0.1/24"     # адрес сервера в туннеле
WG_CLI_IP="10.0.0.2/24"     # адрес клиента (первого) в туннеле
WG_PORT=51820                # UDP порт WireGuard
WG_DNS="1.1.1.1"            # DNS в клиентском конфиге
ENABLE_NAT=1                 # 1=включить маскарадинг, 0=нет

WG_DIR="/etc/wireguard"
SERVER_CONF="${WG_DIR}/${WG_IF}.conf"
CLIENT_CONF="${WG_DIR}/${WG_IF}-client.conf"
PUBIP_CACHE="/root/wg_public_ip.txt"

# Проверка root
if [[ $EUID -ne 0 ]]; then
  echo "[ERR] Запустите как root или через sudo." >&2
  exit 1
fi

# Требуемые пакеты
apt update
apt install -y wireguard-tools iproute2 iptables ethtool curl

mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"
cd "$WG_DIR"

umask 077
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee client.key | wg pubkey > client.pub

SERVER_PRIV_KEY=$(<server.key)
SERVER_PUB_KEY=$(<server.pub)
CLIENT_PRIV_KEY=$(<client.key)
CLIENT_PUB_KEY=$(<client.pub)

# Определяем внешний интерфейс (по default route)
EXT_IF=$(ip -o -4 route show to default | awk '{print $5; exit}')
[[ -z "$EXT_IF" ]] && { echo "[ERR] Не удалось определить внешний интерфейс." >&2; exit 1; }

echo "[INFO] Внешний интерфейс: $EXT_IF"

# Определяем публичный IPv4 сервера (несколько попыток)
get_pub_ip() {
  local ip
  for url in \
    "https://ifconfig.co" \
    "https://api.ipify.org" \
    "https://ifconfig.me" \
    "https://icanhazip.com"; do
    ip=$(curl -4 -fsSL "$url" || true)
    if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

if ! PUB_IP=$(get_pub_ip); then
  echo "[WARN] Не удалось определить публичный IP автоматически." >&2
  PUB_IP="UNKNOWN"
else
  echo "$PUB_IP" > "$PUBIP_CACHE"
fi

echo "[INFO] Публичный IP сервера: $PUB_IP"

# Разбираем адреса / маски
SRV_IP_NO_MASK=${WG_SRV_IP%%/*}
CLI_IP_NO_MASK=${WG_CLI_IP%%/*}

# Создаём серверный конфиг
cat > "$SERVER_CONF" <<EOF
[Interface]
PrivateKey = $SERVER_PRIV_KEY
Address = $WG_SRV_IP
ListenPort = $WG_PORT

# Включим форвардинг при апе
PostUp = sysctl -w net.ipv4.ip_forward=1
PostDown = sysctl -w net.ipv4.ip_forward=0
EOF

# NAT (маскарадинг) – по желанию
if [[ "$ENABLE_NAT" -eq 1 ]]; then
  cat >> "$SERVER_CONF" <<EOF
PostUp = iptables -t nat -C POSTROUTING -s $WG_NET -o $EXT_IF -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s $WG_NET -o $EXT_IF -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s $WG_NET -o $EXT_IF -j MASQUERADE 2>/dev/null || true
EOF
fi

cat >> "$SERVER_CONF" <<EOF

[Peer]
PublicKey = $CLIENT_PUB_KEY
AllowedIPs = ${CLI_IP_NO_MASK}/32
EOF

chmod 600 "$SERVER_CONF"

echo "[INFO] Серверный конфиг создан: $SERVER_CONF"

# Клиентский конфиг
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $WG_CLI_IP
DNS = $WG_DNS

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $PUB_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"

echo "[INFO] Клиентский конфиг создан: $CLIENT_CONF"

# Отключаем offload на внешнем интерфейсе для снижения джиттера
ethtool -K "$EXT_IF" tx off rx off gro off gso off lro off || true

echo "[INFO] Offload отключён на $EXT_IF (ошибки можно игнорировать, если драйвер не поддерживает)."

# Поднимаем WireGuard
wg-quick down "$WG_IF" 2>/dev/null || true
wg-quick up   "$WG_IF"

echo "[OK] WireGuard $WG_IF поднят."

# Готовая команда SCP без плейсхолдеров
if [[ "$PUB_IP" != "UNKNOWN" ]]; then
  echo "\n=== СКАЧАЙТЕ КЛИЕНТСКИЙ КОНФИГ НА СВОЮ МАШИНУ ==="
  echo "scp root@${PUB_IP}:${CLIENT_CONF} ./wg0-client.conf"
else
  echo "[WARN] Публичный IP неизвестен. Скачайте вручную: scp root@<IP_ВАШЕГО_СЕРВЕРА>:${CLIENT_CONF} ./wg0-client.conf"
fi

exit 0
