# chl-interview-processor

This program cuts between two angles based on the dominant audio channel.
If the L (left) audio channel is louder for a given second-long interval, then the 'left' video channel will show, and vice versa. Ideal for long interviews for which I don't want to manually cut.

# Dependencies

-   ffmpeg
-   audiowaveform (a C++ cli tool by the BBC)

# Synchronising and exporting with FCP

First, synchronise both clips with the audio inside Final Cut Pro.
Then, to export, make all three clips into compound clips.
Then export the compound clips using `cmd+E`.

# Usage

`./run.sh`

# Setting it up on your system

You'll need to build ffmpeg with gpl and libx264.

```bash
brew uninstall ffmpeg
cd ~
git clone https://git.ffmpeg.org/ffmpeg.git
brew install yasm
./configure --enable-gpl --enable-libx264
make install # this took AGES!
```
