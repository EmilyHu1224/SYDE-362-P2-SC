// Start the server
(
    s.boot;
)

// ------------------------------------------------------
// ---------- Inputting isolated failure sounds ---------
// ------------------------------------------------------

// Define ports
(
    ~toWekinator = NetAddr.new("127.0.0.1", 6448);
    ~toProcessing = NetAddr.new("127.0.0.1", 12000);
)

// Define control bus
(
    c = Bus(\control, 0, 13);
)

// Send coefficients to Wekinator
(
    r = {
        inf.do {
            c.getn(13, { |val| ~toWekinator.sendMsg("/wek/inputs",*val[0..]) });
			// c.getn(13).postln;
		    0.05.wait;
        }
    }.fork;
);
// r.stop;
// r. reset;

p = File.getcwd+/+"control_test_failures/Control Test-10.wav";

// Read full sound file into array a
(
    f = SoundFile.new;
    f.openRead(p);
    a = FloatArray.newClear(f.numFrames);
    f.readData(a);
// a.plot;
)

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

// Send the list of timestamps to the UI
~toProcessing.sendMsg("/sc/outputs", *e.array);

// Set coefficient values on bus at scheduled times
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
		s.freeAll;
		i = 0;
		z = e.size;
		p = e[i] * (1 / 44100);
		p.yield;
    	z.do {
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
