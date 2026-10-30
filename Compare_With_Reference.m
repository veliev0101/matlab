% Compare_With_Reference.m
clear; clc; close all;
LogLanguage = 'Russian';
sps = 4; span = 10; beta = 0.20; MODCOD = 7;

%% 1. Параметры и объекты
Params.Source      = struct('NumBitsPerFrame', 48408);
Params.Encoder     = struct('isTransparent', false, 'CodeRate', '3/4', 'MaxNumIter', 20);
Params.Interleaver = struct('isTransparent', false);
Params.Mapper      = struct('isTransparent', false, 'Type', 'PSK', ...
    'ModulationOrder', 4, 'PhaseOffset', pi/4, 'SymbolMapping', 'Gray', ...
    'DecisionMethod', 'Hard decision');
Params.PLFramer    = struct('isTransparent', false, 'FECFrame', 'normal', ...
    'Pilots', true, 'ScramblingCode', 0);
Params.Sig         = struct('isTransparent', false, 'RollOff', beta, ...
    'SamplesPerSymbol', sps, 'Span', span);
Params.Channel     = struct('isTransparent', false);
Params.BER         = struct(); Params.Common = struct();
Params = SetParams(Params, 1, LogLanguage);
Params = CalcAndCheckParams(Params, LogLanguage);

Src = ClassDVBS2Source(Params, LogLanguage);
Enc = ClassEncoder(Params, LogLanguage);
Itl = ClassInterleaver(Params, LogLanguage);
Map = ClassMapper(Params, LogLanguage);
PL  = ClassPLFramer(Params, LogLanguage);

%% 2. Передатчик
rng(1);
TxData = Src.Step(); Info = Src.LastInfo; TSBits = Info.TSBits;
TxEnc  = Enc.StepTx(TxData);
TxInt  = Itl.StepTx(TxEnc);
TxSym  = Map.StepTx(TxInt);
TxPL   = PL.StepTx(TxSym);
N      = numel(TxPL);

%RRC-фильтр с нормировкой на единичную среднюю мощность 
% rcosdesign(...,'sqrt') даёт sum(h.^2) = sps, т.е. усиление по мощности sps.
% Делим на sqrt(sps), чтобы средняя мощность сигнала после upfirdn была 1.
h      = rcosdesign(beta, span, sps, 'sqrt');
%h      = h / sqrt(sps);
h = h/sum(h);
mine   = upfirdn(TxPL, h, sps);

Kbch = Enc.Kbch; Nbch = Enc.Nbch; DFL = numel(TSBits);
fprintf('Kbch=%d, Nbch=%d, DFL=%d\n', Kbch, Nbch, DFL);

%% 3. Эталон
if ~exist('dvbs2xLDPCParityMatrices.mat','file')
    if ~exist('s2xLDPCParityMatrices.zip','file')
        url = ['https://ssd.mathworks.com/supportfiles/spc/satcom/DVB/', ...
               's2xLDPCParityMatrices.zip'];
        websave('s2xLDPCParityMatrices.zip', url, weboptions('Timeout',120));
    end
    unzip('s2xLDPCParityMatrices.zip');
end
if ~exist('dvbs2xLDPCParityMatrices.mat','file')
    f = dir(fullfile(pwd,'**','dvbs2xLDPCParityMatrices.mat'));
    addpath(f(1).folder);
end
gen = dvbs2WaveformGenerator(StreamFormat="TS", FECFrame="normal", ...
    MODCOD=MODCOD, DFL=DFL, HasPilots=true, RolloffFactor=beta, ...
    FilterSpanInSymbols=span, SamplesPerSymbol=sps);
ref = gen(TSBits(:)); try, ref=[ref;flushFilter(gen)]; end; ref=ref(:);

%% 4. Выравнивание (без убийственной нормировки)
maxlag = min(numel(ref), numel(mine)) - 1;
[c,lags] = xcorr(ref, mine, maxlag);
[~,ix] = max(abs(c));
lag = lags(ix);
if lag >= 0, refA = ref(1+lag:end); else, refA = [zeros(-lag,1); ref]; end
M = min(numel(refA), numel(mine));
refA = refA(1:M); mineA = mine(1:M);

% Вычисляем комплексный масштаб для диагностики
alpha = sum(conj(mineA).*refA) / sum(abs(mineA).^2);
fprintf('Диагностика масштаба: |alpha| = %.4f, arg(alpha) = %.3f рад\n', abs(alpha), angle(alpha));

%% 5. Теоретические уровни
gRRC  = sum(h.^2) / sps;              % усиление RRC после нормировки = 1
P_th  = gRRC;                         % средняя мощность огибающей
rms_th = sqrt(P_th);

fprintf('Теоретический RMS огибающей: %.4f\n', rms_th);
fprintf('Фактический RMS эталона:    %.4f\n', rms(refA));
fprintf('Фактический RMS модели:     %.4f\n', rms(mineA));

% Приводим графики к единицам теории (делим на теоретический RMS)
refP  = refA  / rms_th;
mineP = mineA / rms_th;

%% 6. Восстановление символов PLFRAME из эталона
refN  = refA  / rms(refA);
mineN = mineA / rms(mineA);
mf   = conv(refN, h(:));
[~,i0] = max(abs(mf(1:2*sps)));
idx = i0 + sps*(0:N-1);
idx = idx(idx <= numel(mf));
refSym = mf(idx); refSym = refSym(:);
Nc = numel(refSym);

% Убираем пилоты и скремблер
Body   = refSym(91:end) .* conj(PL.ScrSeq(1:Nc-90));
pm     = PL.PilotMask(1:Nc-90);
refX   = Body(~pm);

% QPSK: поворот на -pi/4, затем знаки Re/Im
rot = refX * exp(-1j*pi/4);
refBits = zeros(2*numel(rot), 1);
refBits(1:2:end) = real(rot) < 0;
refBits(2:2:end) = imag(rot) < 0;

% Сравнение
nb = min(numel(refBits), numel(TxEnc));
secName = {'BBHEADER','DATA FIELD+PADDING','BCH parity','LDPC parity'};
secIdx  = {1:80, 81:Kbch, Kbch+1:Nbch, Nbch+1:nb};
mism = zeros(1,4); secLen = zeros(1,4);
for s = 1:4
    r = secIdx{s};
    mism(s)   = sum(refBits(r) ~= TxEnc(r));
    secLen(s) = numel(r);
    fprintf('  %-22s: mism %6d / %6d\n', secName{s}, mism(s), secLen(s));
end

%% 7. Графики
figure('Position',[60 60 1250 800]); tl=tiledlayout(2,2,'TileSpacing','compact');

% Огибающая: используем abs(), а не real() и нормируем по RMS
nexttile;
% Ограничим окно для наглядности
k1 = span*sps + (1:300);

% Нормируем на RMS ТОЛЬКО для этого графика
ref_plot  = abs(refA)  / rms(refA);
mine_plot = abs(mineA) / rms(mineA);

plot(k1, ref_plot(k1),  'b', 'LineWidth', 1.2); hold on;
plot(k1, mine_plot(k1), 'r--', 'LineWidth', 1.2);

grid on; legend('эталон','модель', 'Location','best');
title('Огибающая |s(t)| (нормированная)');

% СПМ: одинаковая нормировка всех трёх кривых на единичную среднюю мощность
nexttile;
refN_psd  = refA  / rms(refA);
mineN_psd = mineA / rms(mineA);

[Pr,fp] = pwelch(refN_psd,  hann(4096), 2048, 4096, sps, 'centered');
Pm      = pwelch(mineN_psd, hann(4096), 2048, 4096, sps, 'centered');

% Считаем теоретическую АЧХ RRC на частотах fp
% fp - это частоты в Гц (в твоем случае в отсчетах на символ)
Hrrc2 = zeros(size(fp));
for i = 1:length(fp)
    f_abs = abs(fp(i));
    if f_abs <= (1-beta)/2
        Hrrc2(i) = 1;
    elseif f_abs <= (1+beta)/2
        Hrrc2(i) = cos(pi/(4*beta) * (2*f_abs - (1-beta)))^2;
    else
        Hrrc2(i) = 0;
    end
end
% Сигналы нормированы на единичную мощность, поэтому теория — это просто Hrrc2
S_th_dB = 10*log10(Hrrc2 + eps);

plot(fp, 10*log10(Pr), 'b', 'LineWidth', 1.2); hold on;
plot(fp, 10*log10(Pm), 'r--', 'LineWidth', 1.2);
plot(fp, S_th_dB, 'k:', 'LineWidth', 2);
xline([-(1+beta)/2 (1+beta)/2]*sps,'k:');
grid on; legend('эталон','модель','теория RRC','Location','south');
title('СПМ (нормированная на единичную мощность)');

% Ошибка по символам (для проверки)
nexttile;
refN = refA / alpha; % компенсируем задержку и фазу
mf   = conv(refN, h(:));
[~,i0] = max(abs(mf(1:2*sps)));
idx = i0 + sps*(0:N-1);
idx = idx(idx <= numel(mf));
refSym = mf(idx); refSym = refSym(:);
Nc = numel(refSym);
symErr = abs(refSym - TxPL(1:Nc));
semilogy(1:Nc, symErr+1e-6); hold on;
xline(90.5,'k--'); yline(0.2,'r:');
grid on; title('Ошибка по символам');

% Биты
nexttile;
rot = refSym(91:end) .* conj(PL.ScrSeq(1:Nc-90));
pm = PL.PilotMask(1:Nc-90);
refX = rot(~pm);
rot_q = refX * exp(-1j*pi/4);
refBits = zeros(2*numel(rot_q), 1);
refBits(1:2:end) = real(rot_q) < 0;
refBits(2:2:end) = imag(rot_q) < 0;
nb = min(numel(refBits), numel(TxEnc));

secName = {'BBHEADER','DATA+PAD','BCH parity','LDPC parity'};
secIdx  = {1:80, 81:Kbch, Kbch+1:Nbch, Nbch+1:nb};
mism = zeros(1,4); secLen = zeros(1,4);
for s = 1:4
    r = secIdx{s}; mism(s) = sum(refBits(r) ~= TxEnc(r)); secLen(s) = numel(r);
end
b = bar(100*mism./secLen); b.FaceColor = 'flat';
set(gca,'XTickLabel',secName,'XTickLabelRotation',20);
ylabel('% несовпавших бит'); grid on;
title('Биты FECFRAME: эталон vs модель');