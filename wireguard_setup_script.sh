#!/usr/bin/env bash
# setup_wg.sh – автоматическая настройка WireGuard VPN с генерацией клиентского конфига
# Требуется: Debian/Ubuntu (root)

set -euo pipefail
WG_DIR=/etc/wireguard
CLIENT_CONF=${WG_DIR}/wg0-client.conf
SERVER_CONF=${WG_DIR}/wg0.conf

# Проверка запуска от root
if [[ "$EUID" -ne 0 ]]; then
  echo "Запустите скрипт от root: sudo $0"
  exit 1
fi

# 1. Установка WireGuard
apt update
apt install -y wireguard-tools iproute2 ethtool

# 2. Создание директории и прав
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

# 3. Генерация ключей
umask 077
wg genkey | tee "$WG_DIR/server.key" | wg pubkey > "$WG_DIR/server.pub"
wg genkey | tee "$WG_DIR/client.key" | wg pubkey > "$WG_DIR/client.pub"

SERVER_PRIV_KEY=$(cat "$WG_DIR/server.key")
SERVER_PUB_KEY=$(cat "$WG_DIR/server.pub")
CLIENT_PRIV_KEY=$(cat "$WG_DIR/client.key")
CLIENT_PUB_KEY=$(cat "$WG_DIR/client.pub")

# 4. Составление server конфигурации
cat > "$SERVER_CONF" <<EOF
[Interface]
PrivateKey = ${SERVER_PRIV_KEY}
Address = 10.0.0.1/24
ListenPort = 51820
# Включаем форвардинг
PostUp = sysctl -w net.ipv4.ip_forward=1
PostDown = sysctl -w net.ipv4.ip_forward=0

[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = 10.0.0.2/32
EOF
chmod 600 "$SERVER_CONF"

# 5. Составление client конфигурации
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = \$(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
chmod 600 "$CLIENT_CONF"

# 6. Настройка offload для минимальных задержек
IFACE_EXTERNAL=$(ip route show default | awk '/default/ {print $5; exit}')
for IF in "$IFACE_EXTERNAL"; do
  ethtool -K "$IF" tx off rx off gro off gso off lro off
done

# 7. Активировать WireGuard интерфейс
wg-quick up wg0

# 8. Вывод информации
echo "WireGuard настроен."
echo "Server config: ${SERVER_CONF}"
echo "Client config для импорта: ${CLIENT_CONF}"
echo "Чтобы скачать клиентский конфиг: scp root@\$HOSTNAME:${CLIENT_CONF} ."
