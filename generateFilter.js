const WaveformData = require("waveform-data");
const fs = require("fs");

require("dotenv").config();

const argv = require("minimist")(process.argv.slice(2));

const { l: waveformLeftJSON, r: waveformRightJSON } = argv;

const waveformLeftData = WaveformData.create(
		JSON.parse(fs.readFileSync(waveformLeftJSON))
	),
	leftChannel = waveformLeftData.channel(0),
	waveformRightData = WaveformData.create(
		JSON.parse(fs.readFileSync(waveformRightJSON))
	),
	rightChannel = waveformRightData.channel(0);

const clipData = [];

for (
	let sampleIndex = 0;
	sampleIndex < waveformLeftData.length;
	sampleIndex += +process.env.SAMPLE_RATE
) {
	const maxLeftSample =
			Math.abs(leftChannel.min_sample(sampleIndex)) +
			leftChannel.max_sample(sampleIndex),
		maxRightSample =
			Math.abs(rightChannel.min_sample(sampleIndex)) +
			rightChannel.max_sample(sampleIndex);

	const dominantChannel = Number(maxLeftSample > maxRightSample);

	const currentClipIndex = clipData.length - 1,
		isDominantChannelSwitching =
			clipData[currentClipIndex]?.dominantChannel !== dominantChannel;

	if (isDominantChannelSwitching)
		clipData.push({ dominantChannel, length: 1, sampleIndex });
	else clipData[currentClipIndex].length++;
}

console.log(
	clipData
		.map(
			(clipDatum, index) =>
				`[${clipDatum.dominantChannel}:v]trim=${
					clipDatum.sampleIndex
				}:${
					clipDatum.sampleIndex + clipDatum.length
				},setpts=PTS-STARTPTS[v${index}];`
		)
		.join("") +
		clipData.map((d, index) => `[v${index}]`).join("") +
		`concat=n=${clipData.length}:a=0:v=1[out]`
);
