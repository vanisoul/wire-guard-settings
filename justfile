# 內部目標 IP (固定變數)
INTERNAL_IP := "10.10.0.2"

default:
    @echo "請使用 'just forward <協議> <外部Port> <內部Port>' 來建立端口轉發隧道"

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
