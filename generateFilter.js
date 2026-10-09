require("dotenv").config();
let WaveformData = require("waveform-data");
let fs = require("fs");

let log = (text) => {
  fs.appendFileSync("./log", text + "\n");
};

let argv = require("minimist")(process.argv.slice(2));

let {
  l: waveformLeftJSON,
  r: waveformRightJSON,
  y: numberOfLeftVideoChannels,
  z: numberOfRightVideoChannels,
} = argv;

let waveformLeftData = WaveformData.create(
    JSON.parse(fs.readFileSync(waveformLeftJSON))
  ),
  leftChannel = waveformLeftData.channel(0),
  waveformRightData = WaveformData.create(
    JSON.parse(fs.readFileSync(waveformRightJSON))
  ),
  rightChannel = waveformRightData.channel(0);

let clipData = [];

for (
  let sampleIndex = 0;
  sampleIndex < waveformLeftData.length;
  sampleIndex += +process.env.SAMPLE_RATE
) {
  let maxLeftSample =
      Math.abs(leftChannel.min_sample(sampleIndex)) +
      leftChannel.max_sample(sampleIndex),
    maxRightSample =
      Math.abs(rightChannel.min_sample(sampleIndex)) +
      rightChannel.max_sample(sampleIndex);

  let dominantChannel = Number(maxLeftSample > maxRightSample);

  let currentClipIndex = clipData.length - 1,
    isDominantChannelSwitching =
      clipData[currentClipIndex]?.dominantChannel !== dominantChannel;

  if (isDominantChannelSwitching)
    clipData.push({ dominantChannel, length: 1, sampleIndex });
  else clipData[currentClipIndex].length++;
}

let leftChannelTicker = 0,
  rightChannelTicker = 0;

let chooseVideoStream = (dominantChannel) => {
  if (dominantChannel === 1) {
    leftChannelTicker = (leftChannelTicker + 1) % numberOfLeftVideoChannels;
    return leftChannelTicker;
  }
  if (dominantChannel === 0) {
    rightChannelTicker = (rightChannelTicker + 1) % numberOfRightVideoChannels;
    return numberOfLeftVideoChannels + rightChannelTicker; // Left video inputs come in first
  }

  log("Error: dominant channel out of bounds!");
};

let filter =
  clipData
    .map(
      (clipDatum, index) =>
        `[${chooseVideoStream(clipDatum.dominantChannel)}:v]trim=${
          clipDatum.sampleIndex
        }:${
          clipDatum.sampleIndex + clipDatum.length
        },setpts=PTS-STARTPTS[v${index}];`
    )
    .join("") +
  clipData.map((d, index) => `[v${index}]`).join("") +
  `concat=n=${clipData.length}:a=0:v=1[out]`;

// Return by logging
console.log(filter);
