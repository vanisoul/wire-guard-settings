#!/bin/bash
# ------------------------------
# 自動建立 hwdsl2/ipsec-vpn-server
# 會隨機產生 PSK / USER / PASSWORD
# ------------------------------

# 隨機產生字串
VPN_IPSEC_PSK=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 26)
VPN_USER=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)
VPN_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 26)

# 顯示產生的帳密
echo "-------------------------------------"
echo "VPN_IPSEC_PSK:  $VPN_IPSEC_PSK"
echo "VPN_USER:       $VPN_USER"
echo "VPN_PASSWORD:   $VPN_PASSWORD"
echo "-------------------------------------"
echo ""

# 啟動 docker container
docker run -d \
  --name ipsec-vpn-server \
  --restart=always \
  --privileged \
  -e VPN_IPSEC_PSK="$VPN_IPSEC_PSK" \
  -e VPN_USER="$VPN_USER" \
  -e VPN_PASSWORD="$VPN_PASSWORD" \
  -e VPN_CLIENT_NET='172.22.77.0/24' \
  -e VPN_CLIENT_DNS='8.8.8.8,8.8.4.4' \
  -p 500:500/udp \
  -p 4500:4500/udp \
  -v /lib/modules:/lib/modules:ro \
  hwdsl2/ipsec-vpn-server

# 確認是否啟動成功
if [ $? -eq 0 ]; then
  echo "✅ VPN container 已啟動成功！"
  echo "可以使用以上帳密連線 VPN。"
else
  echo "❌ 啟動失敗，請檢查 docker log。"
fi


### 1️⃣ 允許 VPN Client 流量轉送至內網
sudo iptables -A FORWARD -s 172.22.77.0/24 -d 172.22.88.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 172.22.88.0/24 -d 172.22.77.0/24 -j ACCEPT

### 2️⃣ NAT：VPN Client 經 tun0（10.10.0.1）訪問內網時做 SNAT
sudo iptables -t nat -A POSTROUTING -s 172.22.77.0/24 -o wg0 -j SNAT --to-source 10.10.0.1

### 3️⃣ 若要讓 VPN Client 上外網（走 eth0）
sudo iptables -t nat -A POSTROUTING -s 172.22.77.0/24 -o ens4 -j MASQUERADE
