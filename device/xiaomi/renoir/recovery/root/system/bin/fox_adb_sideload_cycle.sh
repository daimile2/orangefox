#!/system/bin/sh

PATH=/system/bin:/sbin
export PATH

LOG=/tmp/fox_adb_boot.log

exec >> "$LOG" 2>&1
set -x

echo "===== boot adb/sideload sequence start ====="

echo "initial USB/ADB state:"
getprop sys.usb.config
getprop sys.usb.state
getprop sys.usb.ffs.ready
getprop init.svc.adbd

# Manual UI operations usually happen later than this automation script.
# Wait for the normal boot flow to switch the USB state to adb first,
# up to 30 seconds.
i=0
while [ "$i" -lt 30 ]; do
    state="$(getprop sys.usb.state)"

    case "$state" in
        *adb*)
            echo "initial ADB USB state is ready: $state"
            break
            ;;
    esac

    sleep 1
    i=$((i + 1))
done

echo "1/3: GUIAction::adb(disable)"
twrp action adb disable
echo "adb disable command returned: $?"

echo "2/3: GUIAction::adbsideload()"
twrp action adbsideload
echo "adbsideload dispatch returned: $?"

# No more fixed sleep 3.
# Wait until minadbd has been created and the USB is in sideload state.
ready=0
i=0

while [ "$i" -lt 30 ]; do
    state="$(getprop sys.usb.state)"

    if [ "$state" = "sideload" ] && \
       ps -eo comm | grep -q '^minadbd$'; then
        ready=1
        echo "minadbd and USB sideload state are both ready"
        break
    fi

    sleep 1
    i=$((i + 1))
done

if [ "$ready" != "1" ]; then
    echo "error: sideload not ready, not cancelling early"
    getprop sys.usb.config
    getprop sys.usb.state
    getprop sys.usb.ffs.ready
    ps -eo comm
    exit 1
fi

# minadbd 已启动不代表 USB 主机枚举和侧载通道已经完全稳定。
# 避免刚收到 FUNCTIONFS_ENABLE 就立刻销毁通道。
sleep 5

echo "3/3: GUIAction::adbsideloadcancel()"
twrp action adbsideloadcancel
echo "adbsideloadcancel command returned: $?"

# 等待 GUIAction::adbsideload() 完成：
# 1. USB 恢复到 adb 或 mtp,adb；
# 2. adbd 服务运行；
# 3. 最关键的是 FunctionFS 重新就绪。
ready=0
i=0

while [ "$i" -lt 40 ]; do
    state="$(getprop sys.usb.state)"
    adbd_state="$(getprop init.svc.adbd)"
    ffs_ready="$(getprop sys.usb.ffs.ready)"

    echo "等待 ADB 恢复：state=$state adbd=$adbd_state ffs.ready=$ffs_ready"

    case "$state" in
        *adb*)
            if [ "$adbd_state" = "running" ] && \
               [ "$ffs_ready" = "1" ]; then
                ready=1
                break
            fi
            ;;
    esac

    sleep 1
    i=$((i + 1))
done

echo "===== final state ====="
echo "sys.usb.config=$(getprop sys.usb.config)"
echo "sys.usb.state=$(getprop sys.usb.state)"
echo "sys.usb.configfs=$(getprop sys.usb.configfs)"
echo "sys.usb.ffs.ready=$(getprop sys.usb.ffs.ready)"
echo "init.svc.adbd=$(getprop init.svc.adbd)"

ps -eo comm | grep -E 'adbd|minadbd'

if [ "$ready" != "1" ]; then
    echo "===== ADB USB transport NOT ready ====="

    # 只读取状态，不用其他命令替代那三个原函数。
    echo "USB controller=$(getprop sys.usb.controller)"
    echo "UDC=$(cat /config/usb_gadget/g1/UDC 2>/dev/null)"
    ls -l /dev/usb-ffs/adb 2>/dev/null

    exit 1
fi

echo "===== ADB USB transport ready ====="
exit 0
