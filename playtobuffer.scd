// Start the server
(
    s.boot;
);

// ------------------------------------------------------
// ---------- Inputting isolated failure sounds ---------
// ------------------------------------------------------

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
			c.getn(13).postln;
		    0.5.wait;
        }
    }
);
r.stop

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


// ------------------------------------------------------
// ---------- Inputting control test failures  ----------
// ------------------------------------------------------
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
	// List to store timestamps of errors
	e = List.new(0);
	// Int to store number of errors
	z = -1;
	// Bool to store if currently on an error
	t = false;
	// Loop index
    i = 0;
    while ( { i < a.size }, {
	    if (t,
		    // If currently on an error sound
		    {
				y[z].add(a[i]);

				// Keep track of consecutive zero entries seen
				if (a[i] == 0, {n = n + 1}, {n = 0});

				// If past 30 entries were 0's, remove them (real error sounds have some 0 values in them)
				if( n == 30,
					{
						for (0, 29, { y[z].pop() });
						t = false;
					}
				)
	        },
		    // If not on an error sound
		    {
				// If start of error sound, add new array with current value to master list
			if(a[i] > 0, {i.postln; e.add(i); t = true; z = z + 1; q = List.new(0); q.add(a[i]); y.add(q); n = 0})
		    }
	    );
	    i = i + 1;
    });
)


// Most promising method for queueing coefficients - just needs to be fixed
(
// FFT & MFCC
	x = {
        var in, fft, array;
        in = PlayBuf.ar(1, d, BufRateScale.kr(d), loop: 0);
        fft = FFT(LocalBuf(1024), in);  // for sampling rates 44100 and 48000
        array = MFCC.kr(fft);
	    Out.kr(0, array); // control bus out
    };

r = Routine({
	i = 0;
	z = e.size;
	p = e[i] * (1 / 44100);
	p.postln;
	p.yield;
    z.size.do {
		//Load Buffer
		i.postln;
		d.free;
		b = FloatArray.newFrom(y[i].array);
		d = Buffer.loadCollection(s, b);
		x.play;
		if( i + 1 < e.size, {q = (e[i+1] - e[i]-100)*(1/44100)}, {q = y[i].size*(1/44100)});
        q.yield;
		s.freeAll;
		c.value = 0;
		i = i + 1;
    }
});

SystemClock.sched(0, r);
)

// Shutdown bus output and server
(
    r.stop;
    s.quit;
)

// ------------------------------------------------------
// ---- Failed methods for scheduling coefficients  -----
// ------------------------------------------------------

// Schedule coefficients using SystemClock without a routine
(
// FFT & MFCC
x = {
    var in, fft, array;
    in = PlayBuf.ar(1, d, BufRateScale.kr(d), loop: 0);
    fft = FFT(LocalBuf(1024), in);  // for sampling rates 44100 and 48000
    array = MFCC.kr(fft);
    Out.kr(0, array); // control bus out
};

// Loop through all errors and schedule their coefficients to be passed through at the right time
for (0, y.size-1, { arg i;
	p = e[i] * (1 / 44100);
	SystemClock.sched(p,{
		//Load Buffer
		b = FloatArray.newFrom(y[i].array);
		d = Buffer.loadCollection(s, b);
		x.play;
		if( i + 1 < e.size, {q = (e[i+1] - e[i]-100)*(1/44100)}, {q = y[i].size*(1/44100)});

		SystemClock.sched(q,{
			s.freeAll;
			c.value = 0;
		});
	});
});
)

// Schedule coefficients using thisThread.seconds - doesn't work because it returns the same value inside a while loop??
(
	// Define FFT and MFCC
	x = {
        var in, fft, array;
        in = PlayBuf.ar(1, d, BufRateScale.kr(d), loop: 0);
        fft = FFT(LocalBuf(1024), in);  // for sampling rates 44100 and 48000
        array = MFCC.kr(fft);
	    Out.kr(0, array); // control bus out
    };
	// Total length of sound file
	g = f.numFrames * (1 / 44100);
	// Error number
	z = 0;
	// Start time
	u = thisThread.seconds;
	// Delta
	q = thisThread.seconds - u;

	thisThread.seconds.postln;
	d = Buffer.loadCollection(s, FloatArray.newFrom(y[z].array), action: {thisThread.seconds.postln;} );

	i = 0;

	while ({i < 1000}, {
		/*if(q > (e[z] * (1 / 44100)),
			{
				/*d = Buffer.loadCollection(s, FloatArray.newFrom(y[z].array));
				s.freeAll;
				c.value = 0;
				x.play;
				z = z + 1;*/
			"test".postln;
			}
		);*/

		q = thisThread.seconds;
		q.postln;
		i = i + 1;
	});
)
