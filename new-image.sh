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

# خطوة الفحص المبدئي لتحديد نوع الصورة في متغير واستخدامه بالأسفل
if grep -q -i "openatv" /etc/image-version 2>/dev/null || grep -q -i "openatv" /etc/os-release 2>/dev/null; then
    IMG_TYPE="openatv"
elif grep -q -i "openpli" /etc/image-version 2>/dev/null || grep -q -i "openpli" /etc/os-release 2>/dev/null; then
    IMG_TYPE="openpli"
else
    IMG_TYPE="openatv" # افتراضي في حال لم يتعرف عليها
fi

# التعديل الجديد: تحديث الفيد وتثبيت wget وحزم الأمان إجبارياً كأول خطوة وفصل الأوامر لضمان الاستمرارية
echo "====== [1/24] Updating Feed & Installing Wget + Certificates ======"
opkg update
opkg install wget ca-certificates --force-depends
opkg upgrade

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


echo "====== [4/24] Installing Channels and Bouquets ======"
wget --no-check-certificate -O /tmp/channels.tar.gz https://raw.githubusercontent.com/anow2008/channels/main/channels.tar.gz
tar -xzf /tmp/channels.tar.gz -C /tmp && rm -rf /etc/enigma2/userbouquet.*
cp -rf /tmp/etc/enigma2/* /etc/enigma2/
chmod 644 /etc/enigma2/userbouquet.* /etc/enigma2/lamedb
wget -qO - http://127.0.0.1/web/servicelistreload?mode=0
rm -rf /tmp/channels.tar.gz /tmp/etc 2>/dev/null

echo "====== [5/24] Installing ArabicSavior ======"
run_safe_script "https://raw.githubusercontent.com/fairbird/ArabicSavior/main/installer.sh"

echo "====== [6/24] Installing EPGImport ======"
opkg update && opkg install enigma2-plugin-extensions-epgimport

echo "====== [7/24] Installing Cacheflush ======"
opkg update && opkg install enigma2-plugin-extensions-cacheflush

echo "====== [8/24] Installing My-Translator ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/my-translator/main/mytranslator.sh"

echo "====== [9/24] Installing RaedQuickSignal ======"
run_safe_script "https://raw.githubusercontent.com/fairbird/RaedQuickSignal/main/installer.sh"

echo "====== [10/24] Installing FootOnsat ======"
run_safe_script "https://raw.githubusercontent.com/fairbird/FootOnsat/main/Download/install.sh"

echo "====== [11/24] Installing IPAudioPro ======"
run_safe_script "https://raw.githubusercontent.com/zKhadiri/IPAudioPro-Releases-/refs/heads/main/installer.sh"

echo "====== [12/24] Downloading IPAudioPro Configuration ======"
wget -O /etc/enigma2/IPAudioPro.json https://raw.githubusercontent.com/anow2008/sound/refs/heads/main/etc/enigma2/IPAudioPro.json

echo "====== [13/24] Installing OAWeather Plugin (Without Reboot) ======"
wget -qO- https://github.com/oe-alliance/OAWeather/archive/refs/heads/main.tar.gz | tar -xzv --strip-components=2 -C /usr/lib/enigma2/python/ OAWeather-main/src/
chmod -R 755 /usr/lib/enigma2/python/Plugins/Extensions/OAWeather /usr/lib/enigma2/python/Components/Converter /usr/lib/enigma2/python/Components/Sources /usr/lib/enigma2/python/Components/Renderer
find /usr/lib/enigma2/python/Plugins/Extensions/OAWeather -name "*.py[oc]" -delete

echo "====== [14/24] Installing BissPro-Smart ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/BissPro-Smart/main/install.sh"

echo "====== [15/24] Installing AJPanel ======"
run_safe_script "https://raw.githubusercontent.com/biko-73/AjPanel/main/installer.sh"

echo "====== [16/24] Installing SmartAddons Panel ======"
run_safe_script "https://raw.githubusercontent.com/emilnabil/download-plugins/refs/heads/main/SmartAddonspanel/smart-Panel.sh"

echo "====== [17/24] Installing CiefpsettingsPanel ======"
run_safe_script "https://raw.githubusercontent.com/ciefp/CiefpsettingsPanel/main/installer.sh"

echo "====== [18/24] Installing Eliesat Panel ======"
run_safe_script "https://raw.githubusercontent.com/eliesat/eliesatpanel/main/installer.sh"

echo "====== [19/24] Installing Anow Panel ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/anow-panel/main/install.sh"

echo "====== [20/24] Installing PremiumFHD-Blue Skin ======"
run_safe_script "https://gitlab.com/eliesat/skins/-/raw/main/all/premium-fhd/premiumfhd-blue.sh"

echo "====== [21/24] Configuring AJPanel Commands ======"
mkdir -p /media/hdd/Ajpanel_Eliesatpanel
rm -f /media/hdd/ajpanel_cmd /media/hdd/Ajpanel_Eliesatpanel/ajpanel_cmd
wget --no-check-certificate "https://raw.githubusercontent.com/anow2008/ajpanel_cmd/refs/heads/main/ajpanel_cmd" -P /media/hdd/
cp /media/hdd/ajpanel_cmd /media/hdd/Ajpanel_Eliesatpanel/

echo "====== [22/24] Downloading AJPanel Menu Customization ======"
rm -f /media/hdd/Ajpanel_Eliesatpanel/ajpanel_menu_Haitham.xml
wget --no-check-certificate "https://gitlab.com/hmeng80/AjPanel/-/raw/main/ajpanel_menu_Haitham.xml?ref_type=heads" -O /media/hdd/Ajpanel_Eliesatpanel/ajpanel_menu_Haitham.xml

echo "====== [23/24] Installing Ncam & Oscam EMU & Configs & SoftCam ====="
run_safe_script "https://raw.githubusercontent.com/biko-73/Ncam_EMU/main/installer.sh"
run_safe_script "https://raw.githubusercontent.com/anow2008/cam-emu/main/oscam/2install.sh"
run_safe_script "https://raw.githubusercontent.com/anow2008/conf/main/install/install.sh"
mkdir -p /etc/tuxbox/config
wget -O /etc/tuxbox/config/SoftCam.Key https://raw.githubusercontent.com/anow2008/softcam.key/main/softcam.key

echo "====== [24/24] Running Final Clean Script ======"
run_safe_script "https://raw.githubusercontent.com/anow2008/clean/main/clean.sh"

echo "================================================="
echo "   All tasks completed successfully, anow2008!    "
echo "            Rebooting Enigma2 Now...             "
echo "================================================="

# عمل ريستارت كامل ونظيف للإنيجما في النهاية
init 4 && sleep 3 && init 6
