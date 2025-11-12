#!/bin/bash
# -------------------------------------------------------
# vpn-iptables.sh
# 功能：一鍵新增 / 移除 VPN 相關 iptables 規則
# -------------------------------------------------------
# 使用方式：
#   ./vpn-iptables.sh add     # 新增規則
#   ./vpn-iptables.sh del     # 移除規則
# -------------------------------------------------------

VPN_NET="192.168.42.0/24"
LAN_NET="172.22.88.0/24"
TUN_IF="wg0"      # 通往內網的介面
TUN_IP="10.10.0.1"
WAN_IF="ens4"     # 外網出口介面

add_rules() {
  echo "🚀 新增 VPN iptables 規則中..."
  sudo sysctl -w net.ipv4.ip_forward=1

  # 允許 VPN ↔ 內網流量通行
  iptables -I FORWARD 1 -s "$VPN_NET" -d "$LAN_NET" -j ACCEPT
  iptables -I FORWARD 2 -s "$LAN_NET" -d "$VPN_NET" -j ACCEPT

  # NAT：VPN Client 經 wg0 進內網時 SNAT 成 10.10.0.1
  iptables -t nat -A POSTROUTING -s "$VPN_NET" -o "$TUN_IF" -j SNAT --to-source "$TUN_IP"

  # VPN Client 上外網（可選）
  iptables -t nat -A POSTROUTING -s "$VPN_NET" -o "$WAN_IF" -j MASQUERADE

  echo "✅ 新增完成"
}

del_rules() {
  echo "🧹 移除 VPN iptables 規則中..."

  # 移除 FORWARD 規則
  iptables -D FORWARD -s "$VPN_NET" -d "$LAN_NET" -j ACCEPT 2>/dev/null
  iptables -D FORWARD -s "$LAN_NET" -d "$VPN_NET" -j ACCEPT 2>/dev/null

  # 移除 NAT 規則
  iptables -t nat -D POSTROUTING -s "$VPN_NET" -o "$TUN_IF" -j SNAT --to-source "$TUN_IP" 2>/dev/null
  iptables -t nat -D POSTROUTING -s "$VPN_NET" -o "$WAN_IF" -j MASQUERADE 2>/dev/null

  echo "✅ 移除完成"
}


case "$1" in
  add)
    add_rules
    ;;
  del)
    del_rules
    ;;
  *)
    echo "用法: $0 {add|del}"
    exit 1
    ;;
esac