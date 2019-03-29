#!/usr/bin/env bash

SCRATCH=$(mktemp -d -t teslacam.XXXXXXXXXX)
function finish {
  rm -rf "${SCRATCH}"

  if [ ! -z "${WSL_MNT}" ]; then
    echo "Unmounting ${WSL_MNT}"
    sleep 5   # delay here to hopefully prevent "drive is busy message"
    sudo umount -l ${WSL_MNT}
  fi
}
trap finish EXIT

if grep -q Microsoft /proc/version; then
  WSL="true"
  WSL_MNT="/mnt/teslacam_mount"
  sudo mkdir -p ${WSL_MNT}

  echo "Detected Windows Subsystem for Linux"
  echo "Looking for USB drives with \"Tesla\" in their drive name"
  WIN_DRIVE=$(WMIC.exe logicaldisk where drivetype=2 get DeviceID,VolumeName | grep Tesla | awk '{print $1}')
  if [ ! -z "${WIN_DRIVE}" ]; then
    echo "Mounting TeslaCam (${WIN_DRIVE}) at ${WSL_MNT}"
      sudo mount -t drvfs "${WIN_DRIVE}" ${WSL_MNT}
  fi
  USBPATH=${WSL_MNT}
else
  echo "Detected native Linux"
  USBPATH=$(readlink -f /dev/disk/by-id/usb-*-0:0* | \
          while read dev;do mount | grep "$dev\b" | \
          awk '{print $3}';done)
fi

TESLACAM=${USBPATH}/TeslaCam/SavedClips

if [[ ! -d ${TESLACAM} ]]; then
    echo "Could not find ${TESLACAM} directory."
    echo "Is USB mounted?"
    exit 1
fi

echo "TESLACAM directory: ${TESLACAM}"

DIRS=$(find ${TESLACAM} -maxdepth 1 -type d | tail -n +2)

for d in ${DIRS}; do
    cd ${d}
    # ls 
    echo ${d}

    # Get name for output from first name
    OUTPUT_NAME=$(ls ${d} | head -n 1 | cut -d '-' -f 1-4)
    DATE=$(echo ${OUTPUT_NAME} | cut -d '_' -f 1)
    TIME=$(echo ${OUTPUT_NAME} | cut -d '_' -f 2 | sed 's/-/:/'):00
    # echo ${OUTPUT_NAME}
    # echo ${DATE}
    # echo ${TIME}
    # exit 0

    # check if output exists and is longer than 2 minutes:
    if [ -f ../${OUTPUT_NAME}.mp4 ]; then
      DURATION=$(ffprobe ../${OUTPUT_NAME}.mp4 2>&1 > /dev/null | grep Duration | awk '{print $2}')
      DURATION=${DURATION//,/}
      length=$(date -d"$DURATION" +%s)
      zero=$(date -d"00:00:00" +%s)
      let "diff = ${length} - ${zero}"
      
      if [[ ${diff} -gt 120 ]]; then
        echo "Looks like this file has been processed already"
        # output is presumed to be good, so skip this iteration
        continue
      fi
      echo "Output exists, but looks to be too short, so reprocessing"
    fi
    
    # if output doesn't exist, or it's shorter than five minutes, do our
    # process:


    newline=$'\r'
    
    echo "Building mosaics, please be patient..."
    i=1
    numclips=$(find . -name "*front.mp4" | wc -l)
    for f in $(ls *front.mp4); do
        timestamp=$(echo ${f} | cut -d '-' -f 1-4)
        DATE=$(echo ${timestamp} | cut -d '_' -f 1)
        TIME=$(echo ${timestamp} | cut -d '_' -f 2 | sed 's/-/:/'):00
        echo "${SCRATCH}/${timestamp} (#${i}/${numclips})"
        # echo ${timestamp} ${DATE} ${TIME}
        # ffmpeg -y \
        ffmpeg -loglevel panic -hide_banner -y \
            -i ${timestamp}-front.mp4 \
            -i ${timestamp}-left_repeater.mp4 \
            -i ${timestamp}-right_repeater.mp4 \
            -r 30 \
            -x264opts "keyint=60:min-keyint=60:no-scenecut" \
            -filter_complex "color=size=1280x960:c=black [base]; \
                                [0:v] setpts=PTS-STARTPTS, scale=640x480 [upper]; \
                                [1:v] setpts=PTS-STARTPTS, scale=640x480 [lowerleft]; \
                                [2:v] setpts=PTS-STARTPTS, scale=640x480 [lowerright]; \
                                [base][upper] overlay=shortest=1:x=320 [tmp1]; \
                                [tmp1][lowerleft] overlay=shortest=1:y=480 [tmp2]; \
                                [tmp2][lowerright] overlay=shortest=1:x=640:y=480 [out]; \
                                [out]drawtext=x=36:y=36:box=1:fontcolor=white:boxcolor=black:
                                fontsize=36:expansion=strftime:
                                basetime=$(date +%s -d"${DATE} ${TIME}")000000:
                                text='$newline %Y-%m-%d $newline$newline%H\\:%M\\:%S $newline'" \
                -c:v libx264 -preset ultrafast ${SCRATCH}/${timestamp}.mp4 
        let "i = $i + 1"
    done
    
    echo "Joining mosaics together..."
    for f in $(ls ${SCRATCH}/*.mp4); do
      ffmpeg -loglevel panic -hide_banner -y -i $f -c copy -bsf:v h264_mp4toannexb -f mpegts $f.ts 
    done
    CONCAT=$(echo $(ls -v ${SCRATCH}/*.ts) | sed -e "s/ /|/g")
    ffmpeg -loglevel panic -hide_banner -y -i "concat:$CONCAT" -c copy ../${OUTPUT_NAME}.mp4 
    rm ${SCRATCH}/*.ts ${SCRATCH}/*.mp4
done

