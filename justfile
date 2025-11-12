default:
    @echo "可用指令:"
    @echo "  just forward <協議> <外部Port> <內部IP> <內部Port>        - 建立端口轉發隧道"
    @echo "  just forward-range <協議> <內部IP> <Port區間>             - 建立Port區間轉發 (例: 10000:11111)"
    @echo "  just delete <協議> <外部Port> <內部IP> <內部Port>         - 刪除端口轉發隧道"
    @echo "  just delete-range <協議> <內部IP> <Port區間>              - 刪除Port區間轉發"
    @echo "  just list <內部IP>                                      - 查看目前的轉發規則"

# 建立端口轉發隧道
# 用法: just forward <協議> <外部Port> <內部IP> <內部Port>
# 協議只能是 tcp 或 udp
forward protocol external_port internal_ip internal_port:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    sudo iptables -t nat -A PREROUTING -p {{protocol}} --dport {{external_port}} -j DNAT --to-destination {{internal_ip}}:{{internal_port}}
    sudo iptables -t nat -A POSTROUTING -p {{protocol}} -d {{internal_ip}} -j MASQUERADE
    sudo iptables -I FORWARD 1 -p {{protocol}} -d {{internal_ip}} -j ACCEPT
    sudo iptables -I FORWARD 2 -p {{protocol}} -s {{internal_ip}} -j ACCEPT

# 建立Port區間轉發
# 用法: just forward-range <協議> <內部IP> <Port區間>
# 協議只能是 tcp 或 udp，Port區間格式: 開始Port:結束Port (例: 10000:11111)
# 外部和內部使用相同的Port區間
forward-range protocol internal_ip port_range:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    @if ! echo "{{port_range}}" | grep -q "^[0-9]*:[0-9]*$"; then \
        echo "錯誤: Port區間格式必須是 開始Port:結束Port (例: 10000:11111)"; \
        exit 1; \
    fi
    sudo iptables -t nat -A PREROUTING -p {{protocol}} --dport {{port_range}} -j DNAT --to-destination {{internal_ip}}
    sudo iptables -t nat -A POSTROUTING -p {{protocol}} -d {{internal_ip}} -j MASQUERADE
    sudo iptables -I FORWARD 1 -p {{protocol}} -d {{internal_ip}} -j ACCEPT
    sudo iptables -I FORWARD 2 -p {{protocol}} -s {{internal_ip}} -j ACCEPT

# 刪除端口轉發隧道
# 用法: just delete <協議> <外部Port> <內部IP> <內部Port>
# 協議只能是 tcp 或 udp
delete protocol external_port internal_ip internal_port:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    sudo iptables -t nat -D PREROUTING -p {{protocol}} --dport {{external_port}} -j DNAT --to-destination {{internal_ip}}:{{internal_port}}
    sudo iptables -t nat -D POSTROUTING -p {{protocol}} -d {{internal_ip}} -j MASQUERADE
    sudo iptables -D FORWARD -p {{protocol}} -d {{internal_ip}} -j ACCEPT
    sudo iptables -D FORWARD -p {{protocol}} -s {{internal_ip}} -j ACCEPT

# 刪除Port區間轉發
# 用法: just delete-range <協議> <內部IP> <Port區間>
# 協議只能是 tcp 或 udp，Port區間格式: 開始Port:結束Port (例: 10000:11111)
delete-range protocol internal_ip port_range:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    @if ! echo "{{port_range}}" | grep -q "^[0-9]*:[0-9]*$"; then \
        echo "錯誤: Port區間格式必須是 開始Port:結束Port (例: 10000:11111)"; \
        exit 1; \
    fi
    sudo iptables -t nat -D PREROUTING -p {{protocol}} --dport {{port_range}} -j DNAT --to-destination {{internal_ip}}
    sudo iptables -t nat -D POSTROUTING -p {{protocol}} -d {{internal_ip}} -j MASQUERADE
    sudo iptables -D FORWARD -p {{protocol}} -d {{internal_ip}} -j ACCEPT
    sudo iptables -D FORWARD -p {{protocol}} -s {{internal_ip}} -j ACCEPT

# 22 / 1820 不可轉
auto-settings:
    just forward tcp 443 172.22.88.50 443
    just forward tcp 27020 172.22.88.21 27020
    just forward-range udp 172.22.88.21 27015:27016

auto-remove:
    just delete tcp 443 172.22.88.50 443
    just delete tcp 27020 172.22.88.21 27020
    just delete-range udp 172.22.88.21 27015:27016

# 查看目前的轉發規則
list internal_ip:
    @echo "=== NAT PREROUTING 規則 (端口轉發) ==="
    @sudo iptables -t nat -L PREROUTING -n -v --line-numbers | grep -e "{{internal_ip}}" -e num || echo "沒有找到轉發到 {{internal_ip}} 的規則"
    @echo ""
    @echo "=== NAT POSTROUTING 規則 (地址偽裝) ==="
    @sudo iptables -t nat -L POSTROUTING -n -v --line-numbers | grep -e "{{internal_ip}}" -e num || echo "沒有找到相關的 POSTROUTING 規則"
    @echo ""
    @echo "=== FORWARD 規則 ==="
    @sudo iptables -L FORWARD -n -v --line-numbers | grep -e "{{internal_ip}}" -e num || echo "沒有找到相關的 FORWARD 規則"
