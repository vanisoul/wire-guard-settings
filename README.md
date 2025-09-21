這份文章主要在描述如何 Debug WireGuard 隧道連線的流程，以下是整理後的脈絡，包含指令、實際反饋，以及如何從反饋中找出下一步需要的資訊：

---

## 1. 建立測試環境

- 前提是雙方必須先建立正確的 WireGuard (wg) 通道。
- 範例中使用：

  ```bash
  sudo wg-quick down wg0
  ```

  **反饋**：沒有輸出，表示通道已關閉，準備進行測試。

---

## 2. 內部主機檢查 NAT 來源

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

  - `<社區網路NAT>.6807` → NAT 來源 IP 與埠號 (這是之後外部主機要使用的關鍵資訊)。
  - `10.140.0.2.51820` → 內部主機收到封包的目標位址與埠號。
  - `wg0 Out` → 表示封包已轉進 WireGuard 內部位址 (10.10.0.x)。

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
  - **這個埠號的來源**：WireGuard 隧道建立時會指定一個 `listening port` 來接收對方傳來的封包。社區 NAT 收到外部隧道封包後，會轉發到內部主機的 `40458`。
  - 其實更直接的方法是用：

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

    → `listening port` 就是內部主機等待對方隧道封包時所使用的埠號。

- **Flow 表示法**：

  ```
  外部主機 (WireGuard 封包, sourcePort=51820)
  ↓
  社區 NAT (轉換來源 port → 6807)
  ↓
  內部主機 ens4 (接收封包, listening port=40458)
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

### 總結

這份筆記的核心流程是：

1. 先用 `tcpdump` 找出 NAT 來源 IP 與埠號。
2. 用 `ss` 或 `wg show` 找出內部主機的 listening port (例：40458)。
3. 外部端必須用相同的 **NAT sourcePort** 傳回封包，才能通過 NAT。
4. 透過 `tcpdump` 驗證封包是否真的抵達內部主機。
