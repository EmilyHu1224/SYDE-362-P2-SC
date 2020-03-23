// Start the server
(
    s.boot;
);

// Read & echo the path to the soundfile (for CLI)
p = '/YOUR_PATH';
p.postln;

// Clear the buffer
Buffer.free();
// Read the soundfile
d = Buffer.read(s, p);

(
    ~toWekinator = NetAddr.new("127.0.0.1", 6448);
    ~toProcessing = NetAddr.new("127.0.0.1", 12000);
);

// FFT & MFCC
(
    x = {
        var in, fft, array;
        in = PlayBuf.ar(1, d, BufRateScale.kr(d), loop: 0);
        fft = FFT(LocalBuf(1024), in);  // for sampling rates 44100 and 48000
        array = MFCC.kr(fft);
        Out.kr(0, array); // control bus out
    }.play;
);

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
            0.01.wait;
        }
    }.fork
);

(
    r.stop;
    s.quit;
)
