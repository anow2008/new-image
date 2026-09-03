#!/bin/sh

# ==========================================
# Auto Setup Script for New Enigma2 Images (Smart Image Detection)
# Developed by: anow2008 & Edited for Force Install wget
# ==========================================

# دالة ذكية لتحميل وتشغيل الاسكربتات الخارجية مع تخطي أوامر الريستارت المفاجئة
run_safe_script() {
    URL=$1
    echo "Downloading and patching script from: $URL"
    wget -qO /tmp/temp_install.sh "$URL"
    
    # تعطيل أوامر الريستارت الشائعة داخل الاسكربت المحمل
    sed -i 's/init 3/#init 3/g' /tmp/temp_install.sh
    sed -i 's/init 4/#init 4/g' /tmp/temp_install.sh
    sed -i 's/killall -9 enigma2/#killall -9 enigma2/g' /tmp/temp_install.sh
    sed -i 's/systemctl restart enigma2/#systemctl restart enigma2/g' /tmp/temp_install.sh
    
    # تشغيل الاسكربت بأمان
    chmod 755 /tmp/temp_install.sh
    /tmp/temp_install.sh
    rm -f /tmp/temp_install.sh
}

# إصلاح وإعادة تنشيط الشبكة أولاً لضمان وجود إتصال بالإنترنت
echo "====== [Fixing Network Connection] ======"
/etc/init.d/networking restart 2>/dev/null || systemctl restart networking 2>/dev/null
ifconfig eth0 up 2>/dev/null
ifconfig wlan0 up 2>/dev/null
udhcpc -i eth0 -n -q 2>/dev/null || udhcpc -i wlan0 -n -q 2>/dev/null
sleep 3

# خطوة الفحص المبدئي لتحديد نوع الصورة في متغير واستخدامه بالأسفل
if grep -q -i "openatv" /etc/image-version 2>/dev/null || grep -q -i "openatv" /etc/os-release 2>/dev/null; then
    IMG_TYPE="openatv"
elif grep -q -i "openpli" /etc/image-version 2>/dev/null || grep -q -i "openpli" /etc/os-release 2>/dev/null; then
    IMG_TYPE="openpli"
else
    IMG_TYPE="openatv" # افتراضي في حال لم يتعرف عليها
fi

# التعديل المطلوب: تحديث الفيد ثم تثبيت wget ثم curl كل واحدة بالترتيب وبأمر مستقل
echo "====== [1/22] Updating Feed & Installing Base Tools ======"
opkg update
opkg install wget --force-depends
opkg install curl --force-depends
opkg install ca-certificates --force-depends

echo "————●●★::| ( تحميل اعدات للصورة ) |::★●●————"
if [ "$IMG_TYPE" = "openatv" ]; then
    echo "★★★ OpenATV ★★★"
    run_safe_script "https://raw.githubusercontent.com/anow2008/Downloading-settings/main/OpenATV/install.sh"
elif [ "$IMG_TYPE" = "openpli" ]; then
    echo "★★★ openpli ★★★"
    run_safe_script "https://raw.githubusercontent.com/anow2008/Downloading-settings/main/openpli/install.sh"
fi
echo "●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●"


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


echo "====== [4/22] Installing Channels and Bouquets ======"
wget --no-check-certificate -O /tmp/channels.tar.gz https://raw.githubusercontent.com/anow2008/channels/main/channels.tar.gz
tar -xzf /tmp/channels.tar.gz -C /tmp && rm -rf /etc/enigma2/userbouquet.*
cp -rf /tmp/etc/enigma2/* /etc/enigma2/
chmod 644 /etc/enigma2/userbouquet.* /etc/enigma2/lamedb
wget -qO - http://127.0.0.1/web/servicelistreload?mode=0
rm -rf /tmp/channels.tar.gz /tmp/etc 2>/dev/null

echo "====== [5/22] Installing ArabicSavior ======"
run_safe_script "https://raw.githubusercontent.com/fairbird/ArabicSavior/main/installer.sh"

echo "====== [6/22] Installing EPGImport ======"
opkg update && opkg install enigma2-plugin-extensions-epgimport

echo "====== [7/22] Installing Cacheflush ======"
opkg update && opkg install enigma2-plugin-extensions-cacheflush

echo "====== [8/22] Installing RaedQuickSignal ======"
run_safe_script "https://raw.githubusercontent.com/fairbird/RaedQuickSignal/main/installer.sh"

echo "====== [9/22] Installing FootOnsat ======"
run_safe_script "https://raw.githubusercontent.com/fairbird/FootOnsat/main/Download/install.sh"

echo "====== [10/22] Installing IPAudioPro ======"
run_safe_script "https://raw.githubusercontent.com/zKhadiri/IPAudioPro-Releases-/refs/heads/main/installer.sh"

echo "====== [11/22] Downloading IPAudioPro Configuration ======"
wget -O /etc/enigma2/IPAudioPro.json https://raw.githubusercontent.com/anow2008/sound/refs/heads/main/etc/enigma2/IPAudioPro.json

echo "====== [12/22] Installing BissPro-Smart ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/BissPro-Smart/main/install.sh"

echo "====== [13/22] Installing AJPanel ======"
run_safe_script "https://raw.githubusercontent.com/biko-73/AjPanel/main/installer.sh"

echo "====== [14/22] Installing SmartAddons Panel ======"
run_safe_script "https://raw.githubusercontent.com/emilnabil/download-plugins/refs/heads/main/SmartAddonspanel/smart-Panel.sh"

echo "====== [15/22] Installing CiefpsettingsPanel ======"
run_safe_script "https://raw.githubusercontent.com/ciefp/CiefpsettingsPanel/main/installer.sh"

echo "====== [16/22] Installing Anow Panel ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/anow-panel/main/install.sh"

echo "====== [17/22] Installing Aglare-FHD v8.1 Skin ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/skin/main/skin.sh"

echo "====== [18/22] Installing PremiumFHD-Blue Skin ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/skin/main/skins1.sh"

echo "====== [19/22] Configuring AJPanel Commands ======"
mkdir -p /media/hdd/Ajpanel_Eliesatpanel
rm -f /media/hdd/ajpanel_cmd /media/hdd/Ajpanel_Eliesatpanel/ajpanel_cmd
wget --no-check-certificate "https://raw.githubusercontent.com/anow2008/ajpanel_cmd/refs/heads/main/ajpanel_cmd" -P /media/hdd/
cp /media/hdd/ajpanel_cmd /media/hdd/Ajpanel_Eliesatpanel/

echo "====== [20/22] Downloading AJPanel Menu Customization ======"
rm -f /media/hdd/Ajpanel_Eliesatpanel/ajpanel_menu_Haitham.xml
wget --no-check-certificate "https://gitlab.com/hmeng80/AjPanel/-/raw/main/ajpanel_menu_Haitham.xml?ref_type=heads" -O /media/hdd/Ajpanel_Eliesatpanel/ajpanel_menu_Haitham.xml

echo "====== [21/22] Installing Ncam & Oscam EMU & Configs & SoftCam ====="
run_safe_script "https://raw.githubusercontent.com/biko-73/Ncam_EMU/main/installer.sh"
run_safe_script "https://raw.githubusercontent.com/anow2008/cam-emu/main/oscam/2install.sh"
run_safe_script "https://raw.githubusercontent.com/anow2008/conf/main/install/install.sh"
mkdir -p /etc/tuxbox/config
wget -O /etc/tuxbox/config/SoftCam.Key https://raw.githubusercontent.com/anow2008/softcam.key/main/softcam.key

echo "====== [22/22] Running Final Clean Script ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/clean/main/clean.sh"

# تثبيت وتفعيل إعدادات الشبكة التلقائية عند الإقلاع
echo "====== [Applying Auto Network Fix] ======"
/etc/init.d/networking restart 2>/dev/null || systemctl restart networking 2>/dev/null

echo "================================================="
echo "   All tasks completed successfully, anow2008!    "
echo "            Rebooting Enigma2 Now...             "
echo "================================================="

# عمل ريستارت كامل ونظيف للإنيجما في النهاية
init 4 && sleep 3 && init 6
