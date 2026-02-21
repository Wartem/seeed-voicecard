savedcmd_/home/wartem/seeed-voicecard/snd-soc-wm8960.mod := printf '%s\n'   wm8960.o | awk '!x[$$0]++ { print("/home/wartem/seeed-voicecard/"$$0) }' > /home/wartem/seeed-voicecard/snd-soc-wm8960.mod
