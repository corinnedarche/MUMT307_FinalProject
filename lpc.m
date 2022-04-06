% PROGRAM: lpc.m
% CREATED BY: Corinne Darche
% DESCRIPTION: An implementation of LPC analysis based on the documentation
% in MATLAB's DSP Toolbox
% https://www.mathworks.com/help/dsp/ug/lpc-analysis-and-synthesis-of-speech.html

% Parts adjusted to rely less on the DSP Toolbox and to fully understand
% the function myself.

% Initialization

clear

frameSize = 1600;

% Add functionality for real-time I/O or preloading files
realTimeOutput = true;
recordAudioInput = false;
seeScope = true;

fileName = "";

if recordAudioInput == false
    fileName = convertCharsToStrings(input("What is the name of the file you want to use? ", "s"));
    while(isfile(fileName) == false)
        fileName = convertCharsToStrings(input("Please input a valid file name or path. ", "s"));
    end
else
    fileName = "LPC_input.m4a";
end

% Create System object to read audio file 

% Taken from MATLAB's Documentation. 
if recordAudioInput == true
    realTimeReader = audioDeviceReader();
    realTimeWriter = dsp.AudioFileWriter(fileName, 'FileFormat', "MPEG4", "SampleRate", realTimeReader.SampleRate);

    process = @(x) x.*5;

    disp("Now recording for 5 seconds...")
    tic
    while toc<5
        signal = realTimeReader();
        processedSignal = process(signal);
        realTimeWriter(processedSignal);
    end

    disp("Done recording!")

    release(realTimeReader)
    release(realTimeWriter)
end

audioReader = dsp.AudioFileReader(fileName, 'SamplesPerFrame', frameSize, ...
        'OutputDataType', 'double');

fileInfo = info(audioReader);
Fs = fileInfo.SampleRate;

% Create FIR filter coefficients for pre-emphasis stage

% y[n] = x[n] - ax[n-1]
% Recommended to use 0.9 < a < 1.0
preEmphB = [1 -0.70];
preEmphA = [1];

% De-emphasis, which basically reverses the pre-emphasis
deEmphB = [1];
deEmphA = [1 -0.70];

if seeScope
    scope = dsp.SpectrumAnalyzer('SampleRate', Fs, ...
        'PlotAsTwoSidedSpectrum', false, 'YLimits', [-140, 0], ...
        'Title', 'Linear Prediction of Speech', ...
        'ShowLegend', true, 'ChannelNames', {'Signal', 'LPC'});
end

% System object to play final audio

if realTimeOutput == true
    audioPlayer = audioDeviceWriter('SampleRate', Fs);
else
    audioWriter = dsp.AudioFileWriter("LPC_output.m4a", 'FileFormat', 'MPEG4', 'SampleRate', Fs);
end

% LPC algorithm
while ~isDone(audioReader)
    sig = audioReader(); % Read audio input

    % Analysis
    % Filter coefficients passed in as argument to analysisFilter
    sigpreem = filter(preEmphB, preEmphA, sig);
    hammingwin = hamming(frameSize);
    sigwin = hammingwin.*sigpreem;

    % Autocorrelation sequence on [0:13]
    sigacfOne = xcorr(sigwin, 12);
    sigacf = sigacfOne(13:end);

    % Compute reflection coefficients using Levinson-Durbin recursion
    [sigA, ~, sigK] = levinson(sigacf);
    siglpc = latcfilt(sigK, sigpreem);

    % Synthesis
    sigsyn = latcfilt(sigK.', 1, siglpc);
    sigout = filter(deEmphB, deEmphA, sigsyn);

    if seeScope
        sigA_padded = zeros(size(sigwin), 'like', sigA.'); % Zero-padded to plot
        sigA_padded(1:size(sigA.',1), :) = sigA.';
        scope([sigwin, sigA_padded]);
    end

    % Play output audio
    if realTimeOutput == true
        audioPlayer(sigout);
    else
        audioWriter(sigout);
    end

end

release(audioReader);
pause(10*audioReader.SamplesPerFrame/audioReader.SampleRate);

if realTimeOutput == false
    release(audioWriter);
else
    release(audioPlayer);
end

if seeScope
    release(scope);
end
