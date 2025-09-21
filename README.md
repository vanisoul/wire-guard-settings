## 1. 建立測試環境

- 前提是雙方必須先建立正確的 WireGuard (wg) 通道。
- 已使用：

  ```bash
  sudo wg-quick up wg0
  ```

---

## 2. 外部主機檢查 NAT 來源

- 使用 `tcpdump` 監聽 WireGuard 的 UDP 連線：

  ```bash
  sudo tcpdump -i any udp port 51820 -nn
  ```

- **反饋範例**：

  ```
  06:47:20.014179 ens4  In  IP <社區網路NAT>.6807 > 10.140.0.2.51820: UDP, length 148
  06:47:20.014219 wg0   Out IP 10.10.0.1.6807 > 10.10.0.2.51820: UDP, length 148
  ```

  **解讀**：

  - In `<社區網路NAT>.6807` → NAT 來源 IP 與埠號。
  - 也就是本次測試要送到 `<社區網路NAT>` 的 `6807` 埠，NAT 才會轉發到內部主機。

---

## 3. 內部主機監聽封包前的狀態

- 使用 `ss` 查看內部主機的動態 UDP port：

  ```bash
  ss -upl
  ```

- **反饋範例**：

  ```
  State     Recv-Q    Send-Q        Local Address:Port           Peer Address:Port    Process
  UNCONN    0         0                   0.0.0.0:40458               0.0.0.0:*
  UNCONN    0         0                      [::]:40458                  [::]:*
  ```

  **解讀**：

  - `Local Address:Port` 顯示當前使用的 UDP 埠號是 `40458`。
  - **這個埠號的來源**：WireGuard 隧道建立時會指定一個 `listening port` 在內部主機來接收傳來的封包。社區 NAT 收到封包後，會直接轉發到內部主機的 `40458`，再交由 `wg0` 處理。
  - 更直接的方法是用：

    ```bash
    sudo wg show
    ```

    **範例反饋**：

    ```
    interface: wg0
      public key: O4ctGpL/rEFe7BjniQWKBkYizigdw/UXlUc9bhB8Ehg=
      private key: (hidden)
      listening port: 40458
    ```

    → `listening port` 就是內部主機在等待封包時所使用的埠號。

- **修正版 Flow 表示法**：

  ```
  外部主機 (WireGuard 封包, sourcePort=51820, targetPort=6807)
       ↓
  社區 NAT (listeningPort=6807, targetPort=40458)
       ↓
  內部主機 ens4 (接收封包, listeningPort=40458)
       ↓
  內部主機 wg0 (處理封包並導入隧道)
  ```

- 接著在該埠監聽：

  ```bash
  sudo tcpdump -i any udp port 40458 -nn
  ```

  **目的**：確認外部回送的封包是否能真正抵達內部應用層。

---

## 4. 外部主機測試回送封包

- 關閉外部主機的 WireGuard 通道：

  ```bash
  sudo wg-quick down wg0
  ```

- 在 NAT 尚未清除前，送封包回去：

  ```bash
  echo "hello" | socat - UDP4-SENDTO:<NAT_IP>:<NAT_PORT>,sourceport=51820
  ```

- **需要的資料**：

  - `<NAT_IP>` 與 `<NAT_PORT>` → 從 **步驟 2 tcpdump** 的 NAT 來源找到 (例：`<社區網路NAT>.6807` → IP=`<社區網路NAT>`, Port=`6807`)。
  - `sourceport=51820` → 必須與原本 WireGuard 使用的 port 一致，才能通過 NAT。

---

## 5. 確認 NAT 轉發效果

- 在內部主機 `tcpdump` (步驟 3 的 40458 埠) 中檢查是否收到封包。
- **可能結果**：

  - **有收到** → NAT 尚未過期，封包轉發成功。
  - **沒有收到** → NAT 資料表已清除，無法再轉發，此為正常行為 (心跳超時，NAT 會自動清除)。

---

## 與直接透過 WireGuard 網段測試的差異

- **一般情況**：

  - 封包透過 WireGuard 網段傳輸，會先經過加密，再由對方解密後進入 `wg0`，符合 WireGuard 封包格式。

- **本次流程**：

  - WireGuard 主要用來建立心跳，維持 NAT 映射。
  - 實際測試時，資料不是透過 WireGuard 隧道傳送，而是用 `socat` 直接送 UDP 封包。
  - 因為封包不符合 WireGuard 格式，`wg0` 不會接受，而是被丟棄。
  - 透過 `tcpdump` 仍能觀察封包是否到達 **內部主機的 listening port**，藉此測試 NAT 是否正常轉發、是否被阻擋。

---

### 總結

這份筆記的核心流程是：

1. 用 `tcpdump` 找出 NAT 來源 IP 與埠號。
2. 用 `ss` 或 `wg show` 找出內部主機的 listening port (例：40458)。
3. 外部端利用相同的 **NAT sourcePort** 發送封包，確認 NAT 是否正常轉發。
4. 封包實際上並未經過 WireGuard 加解密，只是單純驗證 NAT 映射行為。
