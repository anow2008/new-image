#!/bin/sh

# ==========================================
# Auto Setup Script for New Enigma2 Images (Smart Image Detection)
# Developed by: anow2008 - Fixed version (single reboot at the end)
# ==========================================

ORIG_PATH="$PATH"
export ORIG_PATH
FAKEBIN="/tmp/fakebin"
TOTAL=24
STEP=0

step() {
    STEP=$((STEP + 1))
    echo "====== [$STEP/$TOTAL] $1 ======"
}

# ---------- دالة تحميل ملف مع فحص الفشل ----------
# الاستخدام: dl URL DEST
dl() {
    _url="$1"
    _dest="$2"
    _tmp="/tmp/dl_$$.tmp"
    if wget -q --no-check-certificate -O "$_tmp" "$_url" 2>/dev/null || \
       curl -fsSLk -o "$_tmp" "$_url" 2>/dev/null; then
        if [ -s "$_tmp" ]; then
            mv -f "$_tmp" "$_dest"
            return 0
        fi
    fi
    rm -f "$_tmp"
    echo "!! Download failed: $_url"
    return 1
}

# ---------- إصلاح الشبكة (بيتنفذ فقط لو opkg update فشل) ----------
fix_network() {
    echo "--- Fixing network connection ---"
    /etc/init.d/networking restart 2>/dev/null || systemctl restart networking 2>/dev/null
    ifconfig eth0 up 2>/dev/null
    ifconfig wlan0 up 2>/dev/null
    udhcpc -i eth0 -n -q 2>/dev/null || udhcpc -i wlan0 -n -q 2>/dev/null
    sleep 3
}

# ---------- تشغيل سكريبت خارجي مع تعطيل أي ريستارت ----------
run_safe_script() {
    URL="$1"
    TMP="/tmp/temp_install_$$.sh"
    echo "Downloading and patching script from: $URL"
    if ! dl "$URL" "$TMP"; then
        echo "!! Skipping: $URL"
        return 1
    fi

    # طبقة إضافية: تعطيل أوامر الريستارت الشائعة داخل الاسكربت نفسه
    sed -i \
        -e 's/init [0-6]/: init/g' \
        -e 's/killall -9 enigma2/: killall enigma2/g' \
        -e 's/killall enigma2/: killall enigma2/g' \
        -e 's/systemctl restart enigma2/: restart enigma2/g' \
        -e 's/shutdown -r now/: shutdown/g' \
        -e 's#web/powerstate#web/powerstate_disabled#g' \
        "$TMP"

    chmod 755 "$TMP"
    "$TMP"
    rm -f "$TMP"
}

# ---------- إنشاء أوامر وهمية تمنع الريستارت من أي سكريبت ----------
create_fake_bin() {
    rm -rf "$FAKEBIN"
    mkdir -p "$FAKEBIN"

    # init 0-6 → تجاهل
    cat > "$FAKEBIN/init" << 'EOF'
#!/bin/sh
case "$1" in
    0|1|2|3|4|5|6|S|s|q|Q) echo "[blocked] init $*"; exit 0 ;;
esac
REAL=$(PATH="$ORIG_PATH" command -v init)
[ -n "$REAL" ] && exec "$REAL" "$@"
exit 0
EOF

    # killall enigma2 → تجاهل، أي حاجة تانية تتنفذ عادي
    cat > "$FAKEBIN/killall" << 'EOF'
#!/bin/sh
for a in "$@"; do
    case "$a" in
        enigma2) echo "[blocked] killall $*"; exit 0 ;;
    esac
done
REAL=$(PATH="$ORIG_PATH" command -v killall)
[ -n "$REAL" ] && exec "$REAL" "$@"
exit 0
EOF

    # reboot / poweroff / halt → تجاهل
    for c in reboot poweroff halt; do
        cat > "$FAKEBIN/$c" << 'EOF'
#!/bin/sh
echo "[blocked] $0 $*"
exit 0
EOF
    done

    # shutdown -r → تجاهل
    cat > "$FAKEBIN/shutdown" << 'EOF'
#!/bin/sh
echo "[blocked] shutdown $*"
exit 0
EOF

    # systemctl restart/stop enigma2 أو reboot → تجاهل
    cat > "$FAKEBIN/systemctl" << 'EOF'
#!/bin/sh
ACT=""; SVC=""
for a in "$@"; do
    case "$a" in
        restart|stop|try-restart|reload-or-restart) ACT=1 ;;
        enigma2*) SVC=1 ;;
        reboot|poweroff|halt) echo "[blocked] systemctl $*"; exit 0 ;;
    esac
done
if [ -n "$ACT" ] && [ -n "$SVC" ]; then
    echo "[blocked] systemctl $*"
    exit 0
fi
REAL=$(PATH="$ORIG_PATH" command -v systemctl)
[ -n "$REAL" ] && exec "$REAL" "$@"
exit 0
EOF

    chmod 755 "$FAKEBIN"/*
    PATH="$FAKEBIN:$ORIG_PATH"
    export PATH
}

remove_fake_bin() {
    PATH="$ORIG_PATH"
    export PATH
    rm -rf "$FAKEBIN"
}

# ==========================================
# 1) أول حاجة: تحديث الفيد وتثبيت wget ثم curl
# ==========================================
step "Updating Feed & Installing Base Tools"
if ! opkg update; then
    echo "opkg update failed, fixing network and retrying..."
    fix_network
    opkg update
fi
opkg install wget --force-depends
opkg install curl --force-depends
opkg install ca-certificates --force-depends

# ==========================================
# 2) فحص نوع الصورة
# ==========================================
step "Detecting Image Type"
if grep -q -i "openatv" /etc/image-version 2>/dev/null || grep -q -i "openatv" /etc/os-release 2>/dev/null; then
    IMG_TYPE="openatv"
elif grep -q -i "openpli" /etc/image-version 2>/dev/null || grep -q -i "openpli" /etc/os-release 2>/dev/null; then
    IMG_TYPE="openpli"
else
    IMG_TYPE="openatv" # افتراضي في حال لم يتعرف عليها
fi
echo "Detected image: $IMG_TYPE"

# ==========================================
# 3) منع أي ريستارت لحد آخر السكريبت
# ==========================================
step "Blocking Restarts (single reboot at the end)"
create_fake_bin

# ==========================================
# 4) إعدادات الصورة
# ==========================================
step "Downloading Image Settings ($IMG_TYPE)"
if [ "$IMG_TYPE" = "openatv" ]; then
    run_safe_script "https://raw.githubusercontent.com/anow2008/Downloading-settings/main/OpenATV/install.sh"
else
    run_safe_script "https://raw.githubusercontent.com/anow2008/Downloading-settings/main/openpli/install.sh"
fi

# ==========================================
# 5) astra-sm
# ==========================================
step "Installing astra-sm"
echo "————●●★::| (  astra-sm ) |::★●●————"
opkg update
opkg install astra-sm

if [ "$IMG_TYPE" = "openatv" ]; then
    echo "★★★ تحميل الملف فى امر واحد ★★★"
    wget -O /etc/astra/scripts/abertis https://raw.githubusercontent.com/anow2008/astra/main/scripts/abertis && chmod 755 /etc/astra/scripts/abertis && wget --no-check-certificate https://raw.githubusercontent.com/anow2008/astra/refs/heads/main/astra.conf -O /etc/astra/astra.conf && chmod 755 /etc/astra/astra.conf && wget --no-check-certificate https://raw.githubusercontent.com/anow2008/astra/refs/heads/main/etc/sysctl.conf -O /etc/sysctl.conf && chmod 644 /etc/sysctl.conf && sysctl -p
elif [ "$IMG_TYPE" = "openpli" ]; then
    echo "★★★ openpli  تحميل الملف فى امر واحد صورة  ★★★"
    wget -O /etc/astra/scripts/abertis https://raw.githubusercontent.com/anow2008/astra/main/scripts/abertis && chmod 755 /etc/astra/scripts/abertis && wget --no-check-certificate https://raw.githubusercontent.com/anow2008/astra/refs/heads/main/astra-sm.lua -O /etc/astra/astra-sm.lua && chmod 755 /etc/astra/astra-sm.lua && wget --no-check-certificate https://raw.githubusercontent.com/anow2008/astra/refs/heads/main/astra-sm.conf -O /etc/astra/astra-sm.conf && chmod 755 /etc/astra/astra-sm.conf && wget --no-check-certificate https://raw.githubusercontent.com/anow2008/astra/refs/heads/main/etc/sysctl.conf -O /etc/sysctl.conf && chmod 644 /etc/sysctl.conf && sysctl -p
fi

# ==========================================
# 6) القنوات والـ Bouquets (مسح القديم بعد التأكد من نجاح التحميل)
# ==========================================
step "Installing Channels and Bouquets"
CH_TMP="/tmp/ch_extract"
rm -rf "$CH_TMP" && mkdir -p "$CH_TMP"
if dl "https://raw.githubusercontent.com/anow2008/channels/main/channels.tar.gz" /tmp/channels.tar.gz \
   && tar -xzf /tmp/channels.tar.gz -C "$CH_TMP" \
   && [ -d "$CH_TMP/etc/enigma2" ]; then
    rm -rf /etc/enigma2/userbouquet.*
    cp -rf "$CH_TMP/etc/enigma2/"* /etc/enigma2/
    chmod 644 /etc/enigma2/userbouquet.* /etc/enigma2/lamedb 2>/dev/null
    echo "Channels installed."
else
    echo "!! Channels download/extract failed - existing bouquets kept."
fi
rm -rf /tmp/channels.tar.gz "$CH_TMP"

# ==========================================
# 7+) البلجنات
# ==========================================
step "Installing ArabicSavior"
run_safe_script "https://raw.githubusercontent.com/fairbird/ArabicSavior/main/installer.sh"

step "Installing EPGImport"
opkg update && opkg install enigma2-plugin-extensions-epgimport

step "Installing Cacheflush"
opkg install enigma2-plugin-extensions-cacheflush

step "Installing RaedQuickSignal"
run_safe_script "https://raw.githubusercontent.com/fairbird/RaedQuickSignal/main/installer.sh"

step "Installing FootOnsat"
run_safe_script "https://raw.githubusercontent.com/fairbird/FootOnsat/main/Download/install.sh"

step "Installing IPAudioPro"
run_safe_script "https://raw.githubusercontent.com/zKhadiri/IPAudioPro-Releases-/refs/heads/main/installer.sh"

step "Downloading IPAudioPro Configuration"
dl "https://raw.githubusercontent.com/anow2008/sound/refs/heads/main/etc/enigma2/IPAudioPro.json" /etc/enigma2/IPAudioPro.json

step "Installing BissPro-Smart"
run_safe_script "https://raw.githubusercontent.com/anow2008/BissPro-Smart/main/install.sh"

step "Installing AJPanel"
run_safe_script "https://raw.githubusercontent.com/biko-73/AjPanel/main/installer.sh"

step "Installing SmartAddons Panel"
run_safe_script "https://raw.githubusercontent.com/emilnabil/download-plugins/refs/heads/main/SmartAddonspanel/smart-Panel.sh"

step "Installing CiefpsettingsPanel"
run_safe_script "https://raw.githubusercontent.com/ciefp/CiefpsettingsPanel/main/installer.sh"

step "Installing Anow Panel"
run_safe_script "https://raw.githubusercontent.com/anow2008/anow-panel/main/install.sh"

step "Installing Aglare-FHD v8.1 Skin"
run_safe_script "https://raw.githubusercontent.com/anow2008/skin/main/skin.sh"

step "Installing PremiumFHD-Blue Skin"
run_safe_script "https://raw.githubusercontent.com/anow2008/skin/main/skins1.sh"

step "Configuring AJPanel Commands"
mkdir -p /media/hdd/Ajpanel_Eliesatpanel
rm -f /media/hdd/ajpanel_cmd /media/hdd/Ajpanel_Eliesatpanel/ajpanel_cmd
if dl "https://raw.githubusercontent.com/anow2008/ajpanel_cmd/refs/heads/main/ajpanel_cmd" /media/hdd/ajpanel_cmd; then
    cp -f /media/hdd/ajpanel_cmd /media/hdd/Ajpanel_Eliesatpanel/
fi

step "Downloading AJPanel Menu Customization"
rm -f /media/hdd/Ajpanel_Eliesatpanel/ajpanel_menu_Haitham.xml
dl "https://gitlab.com/hmeng80/AjPanel/-/raw/main/ajpanel_menu_Haitham.xml?ref_type=heads" /media/hdd/Ajpanel_Eliesatpanel/ajpanel_menu_Haitham.xml

step "Installing Ncam & Oscam EMU & Configs & SoftCam"
run_safe_script "https://raw.githubusercontent.com/biko-73/Ncam_EMU/main/installer.sh"
run_safe_script "https://raw.githubusercontent.com/anow2008/cam-emu/main/oscam/3install.sh"
run_safe_script "https://raw.githubusercontent.com/anow2008/conf/main/install/install.sh"
mkdir -p /etc/tuxbox/config
dl "https://raw.githubusercontent.com/anow2008/softcam.key/main/softcam.key" /etc/tuxbox/config/SoftCam.Key

step "Running Final Clean Script"
run_safe_script "https://raw.githubusercontent.com/anow2008/clean/main/clean.sh"

# ==========================================
# الختام: رجوع الأوامر الأصلية ثم ريستارت واحد فقط
# ==========================================
remove_fake_bin

echo "================================================="
echo "   All tasks completed successfully, anow2008!    "
echo "            Rebooting Device Now...              "
echo "================================================="

sync
sleep 2
reboot
