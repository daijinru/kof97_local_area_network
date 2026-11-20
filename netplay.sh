#!/bin/bash
# Finder 启动器共用。可在此文件顶部填写自定义路径，也可设置同名环境变量。
set -eu
set -o pipefail
ROOT=$(cd -P -- "$(dirname -- "$0")" && pwd)
cd -- "$ROOT"
role=${1:?请运行 play.command、host.command 或 join.command}
port=${NETPLAY_PORT:-55435}
assets=${ROM_DIR:-$ROOT/roms}
[[ $assets == /* ]] || assets="$ROOT/$assets"
rom="$assets/kof97.zip"
bios="$assets/neogeo.zip"
support="$HOME/Library/Application Support/RetroArch"
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

valid_port() {
    [[ $1 =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}
valid_ip() {
    local part
    [[ $1 =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    local IFS=.
    for part in $1; do (( 10#$part <= 255 )) || return 1; done
}
if [[ $role != offline ]]; then
    valid_port "$port" || die "端口应为 1–65535 的整数。"
fi
machine=$(uname -m)
if [[ $machine == x86_64 && $(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null || true) == 1 ]]; then machine=arm64; fi
case "$machine" in arm64|x86_64) ;; *) die "需要 Apple Silicon 或 64 位 Intel Mac。";; esac
printf '本机架构：%s\n' "$machine"

# 先找用户指定或已经安装的版本，最后找本项目中的独立安装。
steam="$HOME/Library/Application Support/Steam/steamapps/common/RetroArch"
apps=("/Applications/RetroArch.app" "$HOME/Applications/RetroArch.app" "$steam/RetroArch.app" "$ROOT/RetroArch.app")
if [[ -n ${RETROARCH_APP:-} ]]; then apps=("$RETROARCH_APP"); fi
app=${apps[0]}
for candidate in "${apps[@]}"; do
    if [[ -d $candidate ]]; then app=$(cd -- "$candidate" && pwd -P); break; fi
done
exe=
if [[ -f "$app/Contents/Info.plist" ]]; then
    exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist" 2>/dev/null || true)
fi
bin="$app/Contents/MacOS/${exe:-RetroArch}"
config=${RETROARCH_CONFIG:-}
if [[ -z $config ]]; then
    for candidate in "$support/config/retroarch.cfg" "$support/retroarch.cfg" "${XDG_CONFIG_HOME:-$HOME/.config}/retroarch/retroarch.cfg" "$HOME/.retroarch.cfg" "$HOME/Documents/RetroArch/retroarch.cfg"; do
        if [[ -r $candidate ]]; then config=$candidate; break; fi
    done
elif [[ ! -r $config ]]; then
    die "无法读取 RETROARCH_CONFIG：$config"
fi
core_dir=
if [[ -n $config ]]; then
    core_dir=$(awk -F'"' '/^[[:space:]]*libretro_directory[[:space:]]*=/{print $2;exit}' "$config")
    case "$core_dir" in "~/"*) core_dir="$HOME/${core_dir:2}";; esac
fi

missing=0
if [[ ! -x $bin ]]; then
    printf '找不到 RetroArch 可执行文件：%s\n可将官方应用放在：%s/RetroArch.app\n' "$bin" "$ROOT" >&2
    missing=1
fi
core_name=fbneo_libretro.dylib
archs=("$machine")
if [[ $machine == arm64 ]]; then archs+=(x86_64); fi
core=
run_arch=
for cpu in "${archs[@]}"; do
    if [[ -x $bin && $(file -Lb "$bin") != *"$cpu"* ]]; then continue; fi
    dirs=("$support/cores" "$app/Contents/Resources/cores" "$app/Contents/Resources/modules" "$app/Contents/Frameworks" "$steam/cores" "$HOME/.config/retroarch/cores" "$ROOT/cores/$cpu" "$ROOT/cores")
    if [[ -n $core_dir ]]; then dirs=("$core_dir" "${dirs[@]}"); fi
    candidates=()
    for dir in "${dirs[@]}"; do candidates+=("$dir/$core_name"); done
    if [[ -n ${FBNEO_CORE:-} ]]; then candidates=("$FBNEO_CORE"); fi
    for candidate in "${candidates[@]}"; do
        if [[ -r $candidate && $(file -Lb "$candidate") == *"$cpu"* ]]; then
            core=$(cd -- "$(dirname -- "$candidate")" && pwd -P)/$(basename -- "$candidate")
            run_arch=$cpu
            break 2
        fi
    done
done
if [[ -z $core ]]; then
    printf '缺少与 RetroArch 架构匹配的 FBNeo 核心。放置位置：%s\n' "${FBNEO_CORE:-$ROOT/cores/$machine/$core_name}" >&2
    missing=1
fi
for archive in "$rom" "$bios"; do
    if [[ ! -f $archive || ! -r $archive ]]; then
        printf '请放入：%s\n' "$archive" >&2
        missing=1
    elif ! /usr/bin/unzip -tqq "$archive" </dev/null; then
        printf 'ZIP 完整性检查失败：%s\n' "$archive" >&2
        missing=1
    fi
done
(( missing == 0 )) || exit 1
printf 'RetroArch：%s\nFBNeo：%s (%s)\n' "$bin" "$core" "$run_arch"

# 从正在使用的二进制读取核心自行报告的版本（含 Git 修订号），可跨 CPU 比较。
core_id=$(/usr/bin/arch "-$run_arch" /usr/bin/ruby -rfiddle/import - "$core" <<'RUBY'
# encoding: UTF-8
module Core
  extend Fiddle::Importer
  dlload ARGV.fetch(0)
  Info = struct(["char* name", "char* version", "char* extensions", "char fullpath", "char block_extract"])
  extern "void retro_get_system_info(void*)"
end
info = Core::Info.malloc
Core.retro_get_system_info(info)
abort "指定的核心没有报告 FinalBurn Neo" unless info.name.to_s == "FinalBurn Neo"
puts "#{info.name} #{info.version}".squeeze(" ").strip
RUBY
) || die "无法读取 FBNeo 版本。请检查上面的动态库路径和架构。"
# 与随附版本的 neogeo 驱动对照，能在打开窗口前指出错包或缺失的芯片。
# 其他版本由其自身的 ROM 审计决定所需内容。
audit_chips() {
    local archive=$1
    shift
    LC_ALL=C /usr/bin/unzip -v "$archive" | awk -v required="$*" -v archive="$archive" '
        NF >= 8 && $1 ~ /^[0-9]+$/ { found[tolower($7)] = 1 }
        END {
            n = split(required, chips, " ")
            for (i = 1; i <= n; i++) {
                split(chips[i], pair, ":")
                if (!(pair[2] in found)) {
                    print archive " 缺少 " pair[1] " (CRC " pair[2] ")" > "/dev/stderr"
                    failed = 1
                }
            }
            exit failed
        }'
}
if [[ $core_id == *GITe0ecdb1 ]]; then
    audit_chips "$rom" 232-p1.p1:7db81ad9 232-p2.sp2:158b23f6 232-s1.s1:8514ecf5 \
        232-c1.c1:5f8bf0a1 232-c2.c2:e4d45c81 232-c3.c3:581d6618 232-c4.c4:49bb1e68 \
        232-c5.c5:34fc4e51 232-c6.c6:4ff4d47b 232-m1.m1:45348747 \
        232-v1.v1:22a2b5b5 232-v2.v2:2304e744 232-v3.v3:759eb954
    audit_chips "$bios" sp-s3.sp1:91b64be3 sm1.sm1:94416d67 sfix.sfix:c2ea0cfd 000-lo.lo:5a86cff2
fi
digest() { LC_ALL=C /usr/bin/shasum -a 256 < "$1" | awk '{print $1}'; }
if [[ $role != offline ]]; then
    game_hash=$(digest "$rom")
    bios_hash=$(digest "$bios")
    code=$(printf '%s\n' "$core_id" "$game_hash" "$bios_hash" | LC_ALL=C /usr/bin/shasum -a 256 | cut -c1-16)
    printf '%s\n游戏 SHA-256：%s\nBIOS SHA-256：%s\n联机校验码：%s\n' "$core_id" "$game_hash" "$bios_hash" "$code"
fi

if [[ $role == join ]]; then
    address=${2:-}
    if [[ -z $address ]]; then
        printf '粘贴主机连接串，或输入主机 IPv4：'
        IFS= read -r address || exit 1
    fi
    if [[ $address == *'#'* ]]; then
        expected=${address#*#}
        [[ $expected == "$code" ]] || die "双方校验码不同。请核对上方的核心版本、游戏和 BIOS。"
        address=${address%%#*}
        echo '双方核心版本、游戏和 BIOS 校验通过。'
    else
        echo '仅输入了 IP，双方请核对上方的联机校验码。'
    fi
    ip=${address%%:*}
    valid_ip "$ip" || die "主机地址应为 IPv4，例如 192.168.1.20。"
    if [[ $address == *:* ]]; then port=${address#*:}; fi
    valid_port "$port" || die "连接串中的端口无效。"
elif [[ $role == host ]]; then
    if /usr/sbin/lsof -nP -iTCP:"$((10#$port))" -sTCP:LISTEN >/dev/null 2>&1; then
        die "TCP $port 已有程序监听。请关闭之前的房间，或设置 NETPLAY_PORT。"
    fi
    # 枚举有 IPv4 的以太网/Wi-Fi 接口，VPN 作为默认路由时也可找到局域网。
    ips=$(/sbin/ifconfig | awk '/^[^ \t]/ {lan=($1 ~ /^(en|bridge|vlan|bond)[0-9]+:$/)} lan && $1=="inet" {print $2}' | sort -u)
    if [[ -n $ips ]]; then
        echo '在另一台 Mac 粘贴同一局域网对应的连接串：'
        while IFS= read -r ip; do printf '  %s:%s#%s\n' "$ip" "$port" "$code"; done <<< "$ips"
    else
        echo "请在「系统设置 → 网络 → 当前连接 → 详细信息 → TCP/IP」查看 IPv4，对方输入 IPv4:$port#$code。"
    fi
elif [[ $role == offline ]]; then
    echo '本地游戏 · 拳皇 ’97'
else
    die '请运行 play.command、host.command 或 join.command。'
fi
if [[ $role != offline ]]; then port=$((10#$port)); fi

runtime=(/usr/bin/arch "-$run_arch" "$bin")
help=$("${runtime[@]}" --help 2>&1) || die "无法运行 RetroArch --help。"
session=$(mktemp -d "${TMPDIR:-/tmp}/kof97-netplay.XXXXXXXX")
trap 'rm -rf -- "$session"' EXIT
# 临时主配置只读引用原配置，避免保存设置时写回用户文件。
base="$session/base.cfg"
: > "$base"
if [[ -n $config ]]; then
    config=$(cd -- "$(dirname -- "$config")" && pwd -P)/$(basename -- "$config")
    printf '#include "%s"\n' "$config" > "$base"
fi
mkdir -p "$session/system" "$session/config"
overlay="$session/netplay.cfg"
cat > "$overlay" <<CFG
config_save_on_exit = "false"
auto_overrides_enable = "false"
rgui_config_directory = "$session/config"
core_options_path = "$session/core-options.cfg"
system_directory = "$session/system"
netplay_public_announce = "false"
netplay_use_mitm_server = "false"
netplay_nat_traversal = "false"
netplay_start_as_spectator = "false"
CFG
if [[ $role != offline ]]; then printf 'netplay_ip_port = "%s"\n' "$port" >> "$overlay"; fi
for ((i=1; i<=16; i++)); do
    printf 'netplay_request_device_p%d = "false"\n' "$i" >> "$overlay"
done
args=(-L "$core")
[[ ${NETPLAY_VERBOSE:-0} != 1 ]] || args+=(-v)
[[ $help != *--no-patch* ]] || args+=(--no-patch)
if [[ $help == *--appendconfig* ]]; then
    args+=(-c "$base" "--appendconfig=$overlay")
else
    cat "$base" >> "$overlay"
    args+=(-c "$overlay")
fi
if [[ $role != offline && $help == *--port=* ]]; then args+=("--port=$port"); fi
if [[ $role == host && $help == *--host* ]]; then
    args+=(--host)
elif [[ $role == join && $help == *--connect=* ]]; then
    args+=("--connect=$ip")
elif [[ $role == host ]]; then
    echo '进入游戏后，按菜单切换热键（默认 F1），返回主菜单 → Netplay → Host → Start Netplay Host。'
elif [[ $role == join ]]; then
    echo "进入游戏后，打开菜单 → 主菜单 → Netplay → Connect to Netplay Host，输入 $ip，端口 $port。"
fi
"${runtime[@]}" "${args[@]}" "$rom"
