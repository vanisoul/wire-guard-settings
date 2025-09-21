# 內部目標 IP (固定變數)
INTERNAL_IP := "10.10.0.2"

default:
    @echo "可用指令:"
    @echo "  just forward <協議> <外部Port> <內部Port>        - 建立端口轉發隧道"
    @echo "  just forward-range <協議> <Port區間>             - 建立Port區間轉發 (例: 10000:11111)"
    @echo "  just delete <協議> <外部Port> <內部Port>         - 刪除端口轉發隧道"
    @echo "  just delete-range <協議> <Port區間>              - 刪除Port區間轉發"
    @echo "  just list                                    - 查看目前的轉發規則"

# 建立端口轉發隧道
# 用法: just forward <協議> <外部Port> <內部Port>
# 協議只能是 tcp 或 udp
forward protocol external_port internal_port:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    sudo iptables -t nat -A PREROUTING -p {{protocol}} --dport {{external_port}} -j DNAT --to-destination {{INTERNAL_IP}}:{{internal_port}}
    sudo iptables -t nat -A POSTROUTING -p {{protocol}} -d {{INTERNAL_IP}} --dport {{internal_port}} -j MASQUERADE
    sudo iptables -A FORWARD -p {{protocol}} -d {{INTERNAL_IP}} --dport {{internal_port}} -j ACCEPT
    sudo iptables -A FORWARD -p {{protocol}} -s {{INTERNAL_IP}} --sport {{internal_port}} -j ACCEPT

# 建立Port區間轉發
# 用法: just forward-range <協議> <Port區間>
# 協議只能是 tcp 或 udp，Port區間格式: 開始Port:結束Port (例: 10000:11111)
# 外部和內部使用相同的Port區間
forward-range protocol port_range:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    @if ! echo "{{port_range}}" | grep -q "^[0-9]*:[0-9]*$"; then \
        echo "錯誤: Port區間格式必須是 開始Port:結束Port (例: 10000:11111)"; \
        exit 1; \
    fi
    sudo iptables -t nat -A PREROUTING -p {{protocol}} --dport {{port_range}} -j DNAT --to-destination {{INTERNAL_IP}}
    sudo iptables -t nat -A POSTROUTING -p {{protocol}} -d {{INTERNAL_IP}} --dport {{port_range}} -j MASQUERADE
    sudo iptables -A FORWARD -p {{protocol}} -d {{INTERNAL_IP}} --dport {{port_range}} -j ACCEPT
    sudo iptables -A FORWARD -p {{protocol}} -s {{INTERNAL_IP}} --sport {{port_range}} -j ACCEPT

# 刪除端口轉發隧道
# 用法: just delete <協議> <外部Port> <內部Port>
# 協議只能是 tcp 或 udp
delete protocol external_port internal_port:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    sudo iptables -t nat -D PREROUTING -p {{protocol}} --dport {{external_port}} -j DNAT --to-destination {{INTERNAL_IP}}:{{internal_port}}
    sudo iptables -t nat -D POSTROUTING -p {{protocol}} -d {{INTERNAL_IP}} --dport {{internal_port}} -j MASQUERADE
    sudo iptables -D FORWARD -p {{protocol}} -d {{INTERNAL_IP}} --dport {{internal_port}} -j ACCEPT
    sudo iptables -D FORWARD -p {{protocol}} -s {{INTERNAL_IP}} --sport {{internal_port}} -j ACCEPT

# 刪除Port區間轉發
# 用法: just delete-range <協議> <Port區間>
# 協議只能是 tcp 或 udp，Port區間格式: 開始Port:結束Port (例: 10000:11111)
delete-range protocol port_range:
    @if [ "{{protocol}}" != "tcp" ] && [ "{{protocol}}" != "udp" ]; then \
        echo "錯誤: 協議必須是 tcp 或 udp"; \
        exit 1; \
    fi
    @if ! echo "{{port_range}}" | grep -q "^[0-9]*:[0-9]*$"; then \
        echo "錯誤: Port區間格式必須是 開始Port:結束Port (例: 10000:11111)"; \
        exit 1; \
    fi
    sudo iptables -t nat -D PREROUTING -p {{protocol}} --dport {{port_range}} -j DNAT --to-destination {{INTERNAL_IP}}
    sudo iptables -t nat -D POSTROUTING -p {{protocol}} -d {{INTERNAL_IP}} --dport {{port_range}} -j MASQUERADE
    sudo iptables -D FORWARD -p {{protocol}} -d {{INTERNAL_IP}} --dport {{port_range}} -j ACCEPT
    sudo iptables -D FORWARD -p {{protocol}} -s {{INTERNAL_IP}} --sport {{port_range}} -j ACCEPT

# 查看目前的轉發規則
list:
    @echo "=== NAT PREROUTING 規則 (端口轉發) ==="
    @sudo iptables -t nat -L PREROUTING -n -v --line-numbers | grep -e "{{INTERNAL_IP}}" -e num || echo "沒有找到轉發到 {{INTERNAL_IP}} 的規則"
    @echo ""
    @echo "=== NAT POSTROUTING 規則 (地址偽裝) ==="
    @sudo iptables -t nat -L POSTROUTING -n -v --line-numbers | grep -e "{{INTERNAL_IP}}" -e num || echo "沒有找到相關的 POSTROUTING 規則"
    @echo ""
    @echo "=== FORWARD 規則 ==="
    @sudo iptables -L FORWARD -n -v --line-numbers | grep -e "{{INTERNAL_IP}}" -e num || echo "沒有找到相關的 FORWARD 規則"
