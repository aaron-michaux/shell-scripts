
# Using PulseAudio: Create an Output Sink, and Recording From It
 
```bash
# (1) Create the sink
SINK_NAME="MySink"
pacmd load-module module-null-sink sink_name=$SINK_NAME
pacmd update-sink-proplist MySink device.description=$SINK_NAME

# (2) List links to ensure it exists
pacmd list-sinks | grep -e 'name:' -e 'index' -e 'Speakers'

# (3) Use "Pulse Audio Volume Control" to route output to the sink

# (4) Start recording!
parec -d $SINK_NAME.monitor | lame  -r -V0 - out.mp3
```



