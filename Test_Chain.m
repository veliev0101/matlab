% Test_Chain.m - сквозная проверка цепочки (команда 2) без Ruler
clear; clc;
LogLanguage = 'Russian';

Params.Source      = struct('NumBitsPerFrame', 48408);
Params.Encoder     = struct('isTransparent', false, 'CodeRate', '3/4');
Params.Interleaver = struct('isTransparent', false);
Params.Mapper      = struct('isTransparent', false, 'Type', 'PSK', ...
    'ModulationOrder', 4, 'PhaseOffset', pi/4, 'SymbolMapping', 'Gray');
Params.PLFramer    = struct('isTransparent', false, 'FECFrame', 'normal', ...
    'Pilots', true, 'ScramblingCode', 0);
Params.Sig         = struct('isTransparent', false, 'RollOff', 0.20, ...
    'SamplesPerSymbol', 4, 'Span', 10);
Params.Channel     = struct('isTransparent', false);
Params.BER         = struct();
Params.Common      = struct();
Params = SetParams(Params, 1, LogLanguage);
Params = CalcAndCheckParams(Params, LogLanguage);

Objs.Source      = ClassDVBS2Source(Params, LogLanguage);
Objs.Encoder     = ClassEncoder(Params, LogLanguage);
Objs.Interleaver = ClassInterleaver(Params, LogLanguage);
Objs.Mapper      = ClassMapper(Params, LogLanguage);
Objs.PLFramer    = ClassPLFramer(Params, LogLanguage);
Objs.Sig         = ClassSig(Params, LogLanguage);
Objs.Channel     = ClassChannel(Params, Objs, LogLanguage);

for h2dB = [30 3.5]          % практически без шума, затем около порога
    F.TxData       = Objs.Source.Step();
    F.TxEncData    = Objs.Encoder.StepTx(F.TxData);
    F.TxIntData    = Objs.Interleaver.StepTx(F.TxEncData);
    F.TxModSymbols = Objs.Mapper.StepTx(F.TxIntData);
    F.TxPLFrame    = Objs.PLFramer.StepTx(F.TxModSymbols);
    F.TxSignal     = Objs.Sig.StepTx(F.TxPLFrame);
    assert(length(F.TxPLFrame) == 33282, 'Длина PLFRAME должна быть 33282');

    [F.RxSignal, Inst] = Objs.Channel.Step(F.TxSignal, h2dB);

    F.RxPLFrame    = Objs.Sig.StepRx(F.RxSignal);
    F.RxModSymbols = Objs.PLFramer.StepRx(F.RxPLFrame);
    F.RxIntData    = Objs.Mapper.StepRx(F.RxModSymbols, Inst);
    F.RxEncData    = Objs.Interleaver.StepRx(F.RxIntData);
    F.RxData       = Objs.Encoder.StepRx(F.RxEncData);

    NumErr = sum(F.TxData ~= F.RxData);
    fprintf('h^2 = %5.1f дБ: ошибок в кадре = %d из %d\n', h2dB, NumErr, ...
        length(F.TxData));
    if h2dB == 30
        assert(NumErr == 0, 'При 30 дБ ошибок быть не должно');
    end
end
fprintf('Сквозная цепочка работает.\n');
