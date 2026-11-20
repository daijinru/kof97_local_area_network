# 拳皇 ’97 · macOS 局域网双人对战

## 首次使用

1. 安装 macOS 版 RetroArch，已有安装可以直接使用。[RetroArch 官方下载](https://www.retroarch.com/?page=platforms)
2. 在 RetroArch 主菜单打开「在线更新器 → 核心下载器」，安装 **Arcade (FinalBurn Neo)**。两台 Mac 联机时，请使用相同修订号的核心，各自选择适配本机架构的版本。
3. 在启动脚本旁新建 `roms` 文件夹，把自己提供的 `kof97.zip` 和 `neogeo.zip` 原样放进去。

## 本机直接玩

在 Finder 双击 **play.command** 即可离线启动《拳皇 ’97》。用键盘玩时，先点一下游戏窗口，按 **右 Shift** 投币，再按 **Return（回车）** 开始。用方向键选人，按 **Z** 确认。

## Mac 键盘按键

以下是本机 1P 的键位。联机时，客机也用自己 Mac 上的一套键位操作 2P。

| 操作 | 按键 |
| --- | --- |
| 投币 / 开始 | 右 Shift / Return |
| 移动 / 跳跃 / 下蹲 | ← → / ↑ / ↓ |
| 轻拳 / 轻脚 | Z / X |
| 重拳 / 重脚 | A / S |
| 暂停 / 继续（单机） | P |
| 打开 / 收起 RetroArch 菜单 | F1。如果触发屏幕亮度，按 fn + F1 |
| 退出游戏 | 连按两次 Esc |

## 用手柄玩

1. 用 USB 数据线连接手柄，或在 macOS「系统设置 → 蓝牙」中配对，确认显示「已连接」。
2. 启动游戏。本机已开启手柄自动识别。按映射为 **Select** 的键投币，再按 **Start** 开始。手柄上的标记因型号而异，例如 Xbox 手柄对应 **View / Menu**。
3. 如果手柄没反应，按 **F1** 打开 RetroArch 菜单，进入「设置 → 输入 → 端口 1 控制 → 设备索引」，选中自己的手柄。要查看四个攻击键的对应关系，进入「快捷菜单 → 控制 → 端口 1 控制」。

## 两台 Mac 怎么玩

1. 确认主机已完成首次设置，能用 **play.command** 进入游戏。

2. 把项目文件夹（含 `roms`）复制到第二台 Mac。如果模拟器或核心安装在项目目录之外，也在第二台 Mac 上完成首次设置。两台连同一局域网，各自使用键盘或手柄。两台 Mac 的第一个手柄都使用本机的「端口 1」，联机后 RetroArch 会分配对战席位。
3. 主机双击 **host.command**。看到《拳皇 ’97》标题或演示画面后，把终端显示的完整连接串发给对方，格式为 `IP:端口#校验码`。若显示多个 IP，选当前 Wi-Fi 或以太网连接的 IPv4。
4. 客机双击 **join.command**，粘贴连接串并回车。脚本先比较 FBNeo 报告的版本及 Git 修订号、游戏 ZIP 和 BIOS ZIP 的 SHA-256，再直连。只输入主机 IPv4 也可以，此时双方手动核对终端中的 16 位校验码。默认端口为 **TCP 55435**。
5. 等客机提示以 **玩家 2** 加入，再在各自的 Mac 上投币、按开始。进入选人画面后，双方各移动一次光标，确认主机控制 **1P**、客机控制 **2P**，即可选队开打。

如果提示「双方校验码不同」，对照两个终端显示的 FBNeo 版本、游戏 SHA-256 和 BIOS SHA-256。哪一项不同，就统一对应的核心版本或 ZIP 文件，再双击 **join.command** 重连。

## 安装位置和设置

启动器优先查找已有安装，也支持项目内的 `RetroArch.app`。它从应用的 Info.plist 读取可执行文件名，本机为 `RetroArch.app/Contents/MacOS/RetroArch`。手动安装核心时，Apple Silicon 版可放进 `cores/arm64/fbneo_libretro.dylib`，Intel 版可放进 `cores/x86_64/fbneo_libretro.dylib`。

如需指定安装、游戏目录或端口，可在终端运行下面的命令。要让 Finder 双击也使用这些值，可将相应的 `export` 行加到 `netplay.sh` 顶部的注释之后。已有自定义主配置时，用 `RETROARCH_CONFIG` 指定其完整路径。

```bash
export RETROARCH_APP="/Volumes/Games Disk/RetroArch.app"
export FBNEO_CORE="/Volumes/Games Disk/cores/fbneo_libretro.dylib"
export ROM_DIR="/Volumes/Games Disk/街机游戏"
export NETPLAY_PORT=55436
./host.command
```

启动器用临时配置引用原设置，沿用手柄映射，关闭公开大厅广播、中继和 UPnP 端口映射。联机参数已用本机 `--help` 核对，包括 `-L`、`-c`、`--appendconfig`、`--host`、`--connect` 和 `--port`。[RetroArch 命令行](https://docs.libretro.com/guides/cli-intro/) · [Netplay 官方指南](https://docs.libretro.com/guides/netplay-getting-started/) · [玩家端口分配](https://docs.libretro.com/guides/netplay-multiple-controllers/)

## 本机验证结果

| 项目 | 结果 |
| --- | --- |
| 测试环境 | Apple M3 Pro，macOS 14.4，RetroArch 1.22.2，FBNeo v1.0.0.03 GITe0ecdb1 |
| 游戏与网络 | 用测试游戏 Gridlee 加载 FBNeo。观察到 RetroArch 监听 TCP 55435。同机双实例经 127.0.0.1 直连成功，日志确认主机 1P、客机 2P |
| 两种架构 | arm64 原生主机与 Rosetta x86_64 客机经本机局域网 IPv4 进了同一局。Intel 实体 Mac、第二台 Mac 和两个实体手柄的实机对战仍待验证 |
| 文件和配置 | 两份核心报告相同修订号。错误校验码被拦截，含空格的路径可用，测试前后原配置文件的 SHA-256 相同 |
| 《拳皇 ’97》 | 已用上述两个 ZIP 在本机离线启动。FBNeo 识别为 The King of Fighters ’97 (NGM-2320)，通过 ROM 和 BIOS 校验并成功初始化游戏驱动 |

测试素材仅用于本机验证。[Gridlee 官方授权与下载说明](https://www.mamedev.org/roms/gridlee/) · [FBNeo 的 BIOS 搜索顺序与缺失文件提示](https://docs.libretro.com/library/fbneo/) · [随附核心对应的 Neo Geo 驱动](https://github.com/libretro/FBNeo/blob/e0ecdb1/src/burn/drv/neogeo/d_neogeo.cpp)

**连不上时**，先确认主机还在游戏中。客机可运行 `nc -vz 主机IP 55435` 检查端口是否可达。若超时，检查两台 Mac 的网络是否允许设备互访，并在主机 macOS 防火墙中允许 RetroArch 接收入站连接。需要查看加载或联机日志时，从项目目录运行 `NETPLAY_VERBOSE=1 ./host.command` 或 `NETPLAY_VERBOSE=1 ./join.command`。
