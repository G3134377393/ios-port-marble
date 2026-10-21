# marble XNU — GitHub Actions 构建仓库

用 GitHub Actions 的 `macos-14` runner 构建 **xnu-8796.141.3**，
目标是产出可配合 marble shim/ADT 使用的 XNU kernel。

## 内容

- `.github/workflows/xnu.yml` — 基于 ios-topaz workflow，改动：
  - `-mcpu=cortex-a53` → **`-mcpu=cortex-a55`**（ARMv8.2 + LSE）
  - `MACOS_VERSION=13.5`、`KERNEL_CONFIG=DEVELOPMENT`、`MACHINE_CONFIG=SWEET`
  - 固定 DXB `6639065...`
- `xnu/patches/` — **ios-sweet 的 84 个基础补丁**（不含 topaz 的
  0080-0089：那些是 ARMv8.0 / Gold handoff / FocalTech 专用）

## 使用步骤

1. 在 GitHub 新建一个仓库，例如 `marble-ios-xnu`（private 或 public 均可；
   public 的 macOS Actions 分钟数通常更宽松）。
2. 在本目录：

   ```bash
   cd ~/Desktop/marble-ios/work/xnu-gh
   git init
   git add .
   git commit -m "marble XNU build"
   git branch -M main
   git remote add origin git@github.com:<你的用户名>/marble-ios-xnu.git
   git push -u origin main
   ```

   如果没用 SSH，把 remote 换成
   `https://github.com/<你的用户名>/marble-ios-xnu.git`。

3. 打开 GitHub → Actions → **xnu** → **Run workflow**：
   - `macos_version`: `13.5`
   - `kernel_config`: `DEVELOPMENT`
   - `machine_config`: `SWEET`
   - `keep_going`: 可保持默认
4. 等待 30-60 分钟。成功后下载 artifact **`xnu-kernel`**（以及可选的
   `xnu-buildtree`）。
5. 把下载的 `kernel.development.sweet` 放到
   `~/Desktop/marble-ios/work/xnu/out/`，下一步做 ADT + loader + XNU 启动。

## 可选：用 gh CLI

```bash
brew install gh
gh auth login
gh workflow run xnu.yml -R <你的用户名>/marble-ios-xnu
gh run watch
gh run download -R <你的用户名>/marble-ios-xnu -n xnu-kernel -D ~/Desktop/marble-ios/work/xnu/out
```

## 注意

- 第一次构建很可能有编译错误；先让 workflow 跑出完整日志，
  把错误贴回来，我们再改 patch/编译参数。
- 这个仓库只放 workflow + 补丁，不放 XNU 源码、KDK 或 Apple 固件。
- macOS runner 分钟数按 10x 计费（public 仓库通常免费）。
