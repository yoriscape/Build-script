#! /bin/bash
# Copyright (C) 2021 rokuSENPAI
#

multi() {

# Configs
changelogROM=""
log="full_error.log"
rclone_remote="Ok"
TOKEN="6658509265:AAHyRISGw9A1znYYUhwwQWaOmHeOuK9eflQ"
CHATID="-1001868608674"
BOT_MSG_URL="https://api.telegram.org/bot${TOKEN}/sendMessage"
BOT_LOG_URL="https://api.telegram.org/bot${TOKEN}/sendDocument"
export TZ=Asia/Kolkata
starttime=$(date "+%a %b %d %r")

# telegram 
tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$1"
}
            
tg_post_doc() {
    curl --progress-bar -F document=@"$1" "$BOT_LOG_URL" \
    -F chat_id="$CHATID"  \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="$2"
}

# Select rom to build
while [ $# -ge 1 ]
    do
        case $1 in
            "--alioth")
            device="alioth"
            buildtype="user"
            folder="0"
            ;;
            "--gauguin")
            device="gauguin"
            buildtype="user"
            folder="2"
            ;;
            "--lisa")
            device="lisa"
            buildtype="user"
            folder="3"
            ;;
            "--violet")
            device="violet"
            buildtype="user"
            folder="6"
            ;;
            "--munch")
            device="munch"
            buildtype="user"
            folder="5"
            ;;
            "--sweet")
            device="sweet"
            buildtype="user"
            folder="7"
            ;;
            "--build")
            #repo sync -j$(nproc --all) --force-sync --no-tags --no-clone-bundle --prune --optimized-fetch
            tg_post_msg "<b>Build Started</b>%0A<b>Device :</b> <code>$device</code>%0A<b>Build Type:</b> <code>$buildtype</code>%0A$starttime"
            
            # Enter to the dir
            cd $(pwd)
            
            #Find old builds and remove them
            find out/target/product/$device -name 'Neoteric*.zip' -type f -delete
            find out/target/product/$device -name 'recov*.img' -type f -delete
            find out/target/product/$device -name 'vendor_boo*.img' -type f -delete
            find out/target/product/$device -name 'boo*.img' -type f -delete
            rm -rf out/.lock
            #Start a new build
            start=$(date +%s)
            source build/envsetup.sh
            export WITH_GAPPS=true
            lunch $device-$buildtype
            m installclean
            make bacon -j$(nproc --all) |& tee $log
            if [ $device == alioth ] ||  [ $device == lisa ] ||  [ $device == munch ]; then 
                make vendorbootimage -j$(nproc --all)
            fi
            end=$(date +%s)
            BUILDTIME=$(echo $((${end} - ${start})) | awk '{print int ($1/3600)"h:"int(($1/60)%60)"m:"int($1%60)"s"}')
            
            #Assign values if they are there using wildcards
            romzip=$(find "out/target/product/$device" -name 'Neoteric*.zip' -type f)
            if [ ! -f "$romzip" ]
            then
                tg_post_msg "<b> Build Failed for Neoteric</b>%0A$BUILDTIME"
                tg_post_doc "$log" "Full Build Log"
                sed '/FAILED/,$!d' $log >err.log
                tg_post_doc "err.log" 
            else
                SERVER=$(curl -s https://apiv2.gofile.io/getServer | jq  -r '.data|.server')
				UPLOAD=$(curl -F file=@${romzip} https://${SERVER}.gofile.io/uploadFile)
				ROM=$(echo $UPLOAD | jq -r '.data|.downloadPage')
                romfile=$(basename $romzip)
                romsize="$(du -h ${romzip}|awk '{print $1}')"
                if [ $device == alioth ] ||  [ $device == lisa ] ||  [ $device == munch ]; then
                    boot=$(find "out/target/product/$device" -name 'boo*.img' -type f)
                    SERVER=$(curl -s https://apiv2.gofile.io/getServer | jq  -r '.data|.server')
				    UPLOAD=$(curl -F file=@${boot} https://${SERVER}.gofile.io/uploadFile)
				    BOOT=$(echo $UPLOAD | jq -r '.data|.downloadPage')
                    bootfile=$(basename $boot)
                    bootsize="$(du -h ${boot}|awk '{print $1}')" 
                    vendorboot=$(find "out/target/product/$device" -name 'vendor_boo*.img' -type f)
                    SERVER=$(curl -s https://apiv2.gofile.io/getServer | jq  -r '.data|.server')
				    UPLOAD=$(curl -F file=@${vendorboot} https://${SERVER}.gofile.io/uploadFile)
				    VENDORROOT=$(echo $UPLOAD | jq -r '.data|.downloadPage')
                    vendorbootfile=$(basename $vendorboot)
                    vendorbootsize="$(du -h ${vendorboot}|awk '{print $1}')"    
                    tg_post_msg "$romfile%0A%0A<a href='$ROM'>Download Rom</a> | <a href='$VENDORROOT'>Download Vendorboot</a> | <a href='$BOOT'>Download boot</a>%0ABuild Time: $BUILDTIME"
                else 
                    rec=$(find "out/target/product/$device" -name 'recov*.img' -type f)
                    SERVER=$(curl -s https://apiv2.gofile.io/getServer | jq  -r '.data|.server')
				    UPLOAD=$(curl -F file=@${rec} https://${SERVER}.gofile.io/uploadFile)
				    REC=$(echo $UPLOAD | jq -r '.data|.downloadPage')
                    recfile=$(basename $rec)
                    recsize="$(du -h ${rec}|awk '{print $1}')"
                    tg_post_msg "$romfile%0A<a href='$ROM'>Download Rom</a> | <a href='$REC'>Download Recovery</a>%0ABuild Time: $BUILDTIME"
                fi
                tg_post_msg "$changelogROM"
            fi
            ;;
            *)
            echo "invalid"
            ;;
        esac
    shift
done
}

#multi --lisa --build
#multi --gauguin --build
#multi --alioth --build
#multi --munch --build
#multi --violet --build
#multi --sweet --build

