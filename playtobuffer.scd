// Start the server
(
    s.boot;
);

// ---------- Inputting isolated failure sounds ----------

// Define ports
(
    ~toWekinator = NetAddr.new("127.0.0.1", 6448);
    ~toProcessing = NetAddr.new("127.0.0.1", 12000);
);

// Define control bus
(
    c = Bus(\control, 0, 13);
);

// Send coefficients to Wekinator
(
    r = {
        inf.do {
            c.getn(13, { |val| ~toWekinator.sendMsg("/wek/inputs",*val[0..]) });
		    // c.getn(13).postln;
		    0.01.wait;
        }
    }.fork
);

// Read each isolated sound
// p = File.getcwd+/+"isolated_failure_sounds/A.wav";
// p = File.getcwd+/+"isolated_failure_sounds/B.wav";
// p = File.getcwd+/+"isolated_failure_sounds/C.wav";
// p = File.getcwd+/+"isolated_failure_sounds/D.wav";

// Clear the buffer
d.free;
// Read the soundfile
d = Buffer.read(s, p);

// Tell UI to initialize the timestamp
~toProcessing.sendMsg("/sc/outputs", [1, 2, 3, 4]);

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

// Call this after inputting each sound in Wekinator
(
    x.free
    c.value = 0
)

// ---------- Inputting control test failures  ----------
p = File.getcwd+/+"control_test_failures/Control Test-10.wav";

// Read full sound file into array a
(
    f = SoundFile.new;
    f.openRead(p);
    a = FloatArray.newClear(f.numFrames);
    f.readData(a);
// a.plot;
);

// Find all failures and store in list y
(
	// List to store arrays of sound info for each failure
	y = List.new(0);
	// Int to store number of errors
	z = -1;
	// Bool to store if currently on an error
	f = false;
	// Loop index
    i = 0;
    while ( { i < (a.size) }, {
	    if (f,
		    // If currently on an error sound
		    {
				y[z].add(a[i]);
			// y[z].postln;

				// Keep track of consecutive zero entries seen
				if (a[i] == 0, {n = n + 1}, {n = 0});

				// If past 30 entries were 0's, remove them (real error sounds have some 0 values in them)
				if( n == 30,
					{
						for (0, 29, { y[z].pop() });
						f = false;
					}
				)
	        },
		    // If not on an error sound
		    {
				// If start of error sound, add new array with current value to master list
			if(a[i] > 0, {i.postln; f = true; z = z + 1; q = List.new(0); q.add(a[i]); y.add(q); n = 0})
		    }
	    );
	    i = i + 1;
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


r.stop

(
    r.stop;
    s.quit;
)
