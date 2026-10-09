#!/bin/bash

DIRNAME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! test -f "$DIRNAME/.env"; then
    echo "No .env file in this directory"
    exit
fi

source "$DIRNAME/.env"

# Required variables. Set in .env
if [ -z $SAMPLE_RATE ]; then echo "Please set: SAMPLE_RATE (recommended: 1)"; exit; fi
if [ -z $TMP_DIRECTORY ]; then echo "Please set: TMP_DIRECTORY (absolute path)"; exit; fi
if [ -z $COMPRESSION_LEVEL ]; then echo "Please set: COMPRESSION_LEVEL (number between 1 and 51)"; exit; fi
if [ -z $COMPRESSION_SPEED ]; then echo "Please set: COMPRESSION_SPEED (slow|fast)"; exit; fi
if [ -z $OUTPUT_FILE ]; then echo "Please set: OUTPUT_FILE (absolute path)"; exit; fi

# Refuse to overwrite the output file
if test -f $OUTPUT_FILE; then
    echo "A file already exists at the path $OUTPUT_FILE"
    echo "Remove or rename the file before retrying."
    exit
fi

# Prompt for the number of videos in each channel
read -p "Enter the number of L channel videos: " NUM_L
read -p "Enter the number of R channel videos: " NUM_R

# Initialize arrays to store the video paths
VIDEO_L=()
VIDEO_R=()

# Read L channel video paths
echo "Enter paths for $NUM_L L channel videos:"
for ((i=1; i<=NUM_L; i++)); do
    read -e -p "Enter path for L video $i: " path
    VIDEO_L+=("$path")
done

# Read R channel video paths
echo "Enter paths for $NUM_R R channel videos:"
for ((i=1; i<=NUM_R; i++)); do
    read -e -p "Enter path for R video $i: " path
    VIDEO_R+=("$path")
done

read -e -p "Enter audio path: " AUDIO

while true; do
    read -p "If $TMP_DIRECTORY exists, it will be removed. Is this okay? (y/N) " yn
    case $yn in
        [Yy]* ) rm -r $TMP_DIRECTORY; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

mkdir $TMP_DIRECTORY

AUDIO_L="$TMP_DIRECTORY/audio-L.wav"
AUDIO_R="$TMP_DIRECTORY/audio-R.wav"
AUDIO_L_WAVEFORM_DATA="$TMP_DIRECTORY/audio-L-waveform-data.json"
AUDIO_R_WAVEFORM_DATA="$TMP_DIRECTORY/audio-R-waveform-data.json"

echo "Splitting audio channels"
ffmpeg-bar -i "$AUDIO" -filter_complex "[0:a]pan=mono|c0=c0[audio_l]; [0:a]pan=mono|c0=c1[audio_r]" -map "[audio_l]" "$AUDIO_L" -map "[audio_r]" "$AUDIO_R"

echo "Ascertaining waveform data"
audiowaveform -i $AUDIO_L -o $AUDIO_L_WAVEFORM_DATA --bits 8 --pixels-per-second $SAMPLE_RATE --height 256
audiowaveform -i $AUDIO_R -o $AUDIO_R_WAVEFORM_DATA --bits 8 --pixels-per-second $SAMPLE_RATE --height 256

COMPLEX_FILTER=$(node "$DIRNAME/generateFilter.js" -l $AUDIO_L_WAVEFORM_DATA -r $AUDIO_R_WAVEFORM_DATA -y $NUM_L -z $NUM_R)
VIDEO_SILENT="$TMP_DIRECTORY/video-silent.mov"

# Initialize input arguments
INPUT_ARGS=()

# Add L channel inputs
for path in "${VIDEO_L[@]}"; do
    INPUT_ARGS+=("-i" "$path")
done

# Add R channel inputs
for path in "${VIDEO_R[@]}"; do
    INPUT_ARGS+=("-i" "$path")
done

echo "Splicing clips"
ffmpeg-bar "${INPUT_ARGS[@]}" \
    -filter_complex "$COMPLEX_FILTER" \
    -map "[out]" \
    -codec:v h264_videotoolbox \
    -crf "$COMPRESSION_LEVEL" \
    -preset "$COMPRESSION_SPEED" \
    "$VIDEO_SILENT"

AUDIO_MONO="$TMP_DIRECTORY/audio-mono.aac"

echo "Creating mono audio file"
ffmpeg-bar -i $AUDIO -ac 1 -acodec aac $AUDIO_MONO

echo "Combining video and audio"
ffmpeg-bar -i $VIDEO_SILENT -i $AUDIO_MONO -map 0:v -map 1:a "$OUTPUT_FILE"

echo "Cleanup"
rm -r $TMP_DIRECTORY

echo "Processing complete. Find the video at $OUTPUT_FILE"
