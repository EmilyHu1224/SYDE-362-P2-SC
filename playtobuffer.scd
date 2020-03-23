// Start the server
(
    s.boot;
);

// Read & echo the path to the soundfile (for CLI)
p = File.getcwd+/+"isolated_failure_sounds/C.wav";
p = File.getcwd+/+"control_test_failures/Control Test-10.wav";
p.postln;

// Read sound file into an array
(
f = SoundFile.new;
f.openRead(p);
a = FloatArray.newClear(f.numFrames);
f.readData(a);
a.plot;
);

// Loop through and find all sounds
(
i = 0;
while ( { i < (f.numFrames-1) }, { i = i + 1;
	b = d[i];
	if (b > 0, { b.postln });
});
)

// Clear the buffer
d.free;
// Read the soundfile
d = Buffer.alloc(s, f.numFrames)
d.setn(0, a);
d.getn(0, 5, {|msg| msg.postln});

// d = Buffer.loadCollection(s, a, action:x.play);
d = Buffer.loadCollection(s, a);
d = Buffer.read(s, p);
d.getn(0, 5, {|msg| msg.postln});

(
    ~toWekinator = NetAddr.new("127.0.0.1", 6448);
    ~toProcessing = NetAddr.new("127.0.0.1", 12000);
);

// FFT & MFCC
(
    x = {
        var in, fft, array;
	    "Finished loading".postln;
        in = PlayBuf.ar(1, d, BufRateScale.kr(d), loop: 0);
        fft = FFT(LocalBuf(1024), in);  // for sampling rates 44100 and 48000
        array = MFCC.kr(fft);
	    Out.kr(0, array); // control bus out
    }.play;
);
x.free
c.value = 0

(
    c = Bus(\control, 0, 13);
);

// Tell UI to initialize the timestamp
~toProcessing.sendMsg("/sc/outputs", [1, 2, 3, 4]);

// Send coefficients to Wekinator
(
    r = {
        inf.do {
            c.getn(13, { |val| ~toWekinator.sendMsg("/wek/inputs",*val[0..]) });
		    c.getn.postln;
		// 0.01.wait;
		    0.5.wait;
        }
    }.fork
);

r.stop

(
    r.stop;
    s.quit;
)
