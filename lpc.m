% PROGRAM: lpc.m
% CREATED BY: Corinne Darche
% DESCRIPTION: An implementation of LPC analysis based on the documentation
% in MATLAB's DSP Toolbox

% Initialization

clear

frameSize = 1600;

fileName = "";

% Input selection and recording
recordAudioInput = input("Do you want to use real-time input? (Y/N) ", "s");

if recordAudioInput == 'N'
    fileName = convertCharsToStrings(input("What is the name of the file you want to use? ", "s"));
    while(isfile(fileName) == false)
        fileName = convertCharsToStrings(input("Please input a valid file name or path. ", "s"));
    end
else
    fileName = "LPC_input.m4a";
end

% Create System object to read audio file 

% Taken from MATLAB's Documentation. 
if recordAudioInput == 'Y'
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
preEmphB = [1 -0.95];
preEmphA = [1];

% De-emphasis, which basically reverses the pre-emphasis
deEmphB = [1];
deEmphA = [1 -0.95];

% Output selection (save file or real-time)
realTimeOutput = input("Do you want real-time audio output? (Y/N) ", "s");

if realTimeOutput == 'Y'
    audioPlayer = audioDeviceWriter('SampleRate', Fs);
else
    audioWriter = dsp.AudioFileWriter("LPC_output.m4a", 'FileFormat', 'MPEG4', 'SampleRate', Fs);
end

% Spectrum Analyzer selection

seeScope = input("Would you like to see the Spectrum Analyzer for the speech signal and the LPC autocorrelation coefficients? (Y/N) ", "s");

if seeScope == 'Y'
    scope = dsp.SpectrumAnalyzer('SampleRate', Fs, ...
        'PlotAsTwoSidedSpectrum', false, 'YLimits', [-140, 0], ...
        'Title', 'Linear Prediction of Speech', ...
        'ShowLegend', true, 'ChannelNames', {'Signal', 'LPC'});
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

    if seeScope == 'Y'
        sigA_padded = zeros(size(sigwin), 'like', sigA.'); % Zero-padded to plot
        sigA_padded(1:size(sigA.',1), :) = sigA.';
        scope([sigwin, sigA_padded]);
    end

    % Play output audio
    if realTimeOutput == 'Y'
        audioPlayer(sigout);
    else
        audioWriter(sigout);
    end

end

% Release all the DSP readers
release(audioReader);
pause(10*audioReader.SamplesPerFrame/audioReader.SampleRate);

if realTimeOutput == 'Y'
    release(audioPlayer);
else
    disp("Audio is saved as LPC_output.m4a")
    release(audioWriter);
end

if seeScope == 'Y'
    release(scope);
end