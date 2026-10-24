# 厂商播放图 0xb00000d6（从 AGM 服务内存提取）

## 提取方法（可复用）
Android 里 root 可读 `/proc/<pid>/mem`（本机 `/dev/mem`、`/proc/kcore` 都没有）。
1. 找到 AGM 服务：`ps -A | grep AGMIPC` → pid（本次 1670）
2. 触发一次系统音效，使其建图
3. 用 `dd if=/proc/1670/mem bs=4096 skip=<VA/4096> count=N` 按页读取
4. 在堆里搜序列 `01 00 00 00 01 10 00 08 30 00 00 00`
   （iid=1, PARAM_ID_SUB_GRAPH_CONFIG=0x08001001, size=0x30）

本次命中：VA `0x75d9434e76`，周围 16 KiB 已存为 `agm-heap-b00000d6.bin`。

## 图结构（紧凑表格式：12 字节头 {iid, param_id, size}）

```
0x08001001 SG_CFG : sg=0xb00000d6, perf=2, direction=2(RX/playback), scenario=1
0x08001000        : 4 个 container，各 7 条属性
0x08001002        : 4 个 container 的模块列表
0x08001003        : 模块端口属性
0x08001004        : 12 条连接
```

### 模块（module_id / iid）
| container | 模块 |
|---|---|
| 0xe0000123 | 0x07001000/0x458e (WR_SHARED_MEM_EP), 0x0700101a/0x458f,
0x07001005/0x4590, 0x07001003/0x4591, 0x0700101a/0x4592 |
| 0xe0000124 | 0x0700101a/0x4593, 0x0700101b/0x4594, 0x07001019/0x4595,
0x07001015/0x4596, 0x0700101a/0x4597 |
| 0xe0000125 | 0x07001032/0x4598 |
| 0xe0000158 | 0x07001041/0x4655 |

### 连接（src iid:port → dst iid:port）
```
0x458e:1 → 0x458f:2
0x458f:1 → 0x4590:2
0x4590:1 → 0x4591:2
0x4591:1 → 0x4592:2
0x4592:1 → 0x4593:2
0x4593:1 → 0x4594:2
0x4594:1 → 0x4595:2
0x4595:1 → 0x4596:2
0x4596:1 → 0x4597:2
0x4597:1 → 0x4598:2
0x4598:1 → 0x4655:2
0x4655:1 → 0x458b:2   ← 跨图连接（虚拟后端），0x458b 不在本图模块表里
```

## 关键结论
- **AP 的输入端点必须是 `WR_SHARED_MEM_EP 0x07001000`**：它支持
  `PARAM_ID_MEDIA_FORMAT 0x0800100C` 与 `DATA_BUFFER_V2 0x0400100A`。
  AGM 表里的简单图用 SAL(0x07001010) 当输入，SAL 对 0x0800100C 返回
  **status 3 (EUNSUPPORTED)**——这就是我们 0122 图中 `sal/media_format` 被拒的原因。
- 该图是 **RX（direction=2）播放图**，最终经跨图虚拟连接送到设备图；
  设备图里才是 TDM 端点。厂商用「流图 + 设备图」两段式。
- 扬声器设备后端（`resourcemanager_ukee_mtp.xml`）：
  `PAL_DEVICE_OUT_SPEAKER` → `TDM-LPAIF-RX-TERTIARY-VIRT-0`，
  **96000 Hz / 2ch / 32 bit**。
- `backend_conf.xml` 组 `TDM-LPAIF-RX-TERTIARY`: 96k / 3ch / 32bit / slot_mask=7；
  虚拟设备 VIRT-0 是 96k / 2ch / 32bit（slot_mask=3，和捕获到的 0x0800101B 一致）。

## 设备端文件
- `/vendor/etc/backend_conf.xml`
- `/vendor/etc/audio/sku_ukee/resourcemanager_ukee_mtp.xml`
- `/vendor/lib64/libar-pal.so`（PAL，含 "speaker ckv: AW_mode Music" 等字符串）
- `/vendor/lib64/libar-gpr.so`
