# SWEETLOG —— 重启后还能读到的内核日志

XNU 跑在手机上时没有任何网络/串口通道可用，所以移植版把日志环形缓冲放在
**userdata 分区的最后 4 MiB + 4 KiB**。内核把日志写进这块区域后调用
`sweet_log_sync()` 落盘；测试结束（`sweetreboot=1`）用 PSCI SYSTEM_RESET
把 SoC 复位，手机回到 TWRP/Android，再用 adb 把这块区域读出来。

## 布局

| 偏移 | 内容 |
|---|---|
| 0x000 | `"SWEETLOG"`（8 字节 magic） |
| 0x008 | `u32 version`（当前 1） |
| 0x00C | `u32 size`（环形区字节数） |
| 0x010 | `u64 total`（累计写入字节数） |
| 0x018 | `u64 seq`（序号） |
| 0x1000 | 环形数据起点（`size` 字节） |

读取方式：`ring[(n) % size]`，从 `max(0, total-size)` 解码到 `total`。

## 拉取（这台测试机 2aa26095）

```bash
# TWRP/recovery：adbd 就是 root，直接用
adb exec-out "dd if=/dev/block/sda33 bs=4096 skip=58771962 count=1025" \
  > ring.bin

# Android：userdata 需要 su
adb exec-out "su -c 'dd if=/dev/block/sda33 bs=4096 skip=58771962 count=1025 2>/dev/null'" \
  > ring.bin
```

仓库里的 `scripts/pull_logs.sh` 会自动判断 recovery/Android 并解码。

## 这些常量怎么来的

- `sda33` 是 userdata（`/dev/block/by-name/userdata`）。
- `skip=58771962` = `分区起始扇区 + (分区大小/4096) - 1025`，
  即只读最后 1025 个 4 KiB 块（4 MiB + 4 KiB）。
- 换分区布局或换机器时，用
  `cat /sys/class/block/sda33/{start,size}` 重新计算。

## 复位

cmdline 里的 `sweetreboot=1` 让内核在 ADSP/音频 bring-up 结束后调用
PSCI SYSTEM_RESET。没有这行就停在那里，只能长按电源键。
