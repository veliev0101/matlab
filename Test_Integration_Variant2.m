[BBFRAME_scr, Info] = DVBS2_Variant2_Chain(NumTSFrames, true);
% Проверка, что ClassDVBS2Source корректно работает в составе модели

    LogLanguage = 'Russian';

    % Параметры (минимальный набор для конструирования)
        Params.Common.NumWorkers         = 1;
        Params.Common.NumOneIterFrames   = 2;
        Params.Common.SaveFileName       = 'TestVariant2';
        Params.Common.SaveDirName        = 'Results';
        Params.Common.isRealTimeLogCWin  = 0;
        Params.Common.isRealTimeLogFile  = 0;

        Params.BER = struct();  % значения по умолчанию
        Params.Source      = struct();
        Params.Encoder     = struct('isTransparent', true);
        Params.Interleaver = struct('isTransparent', true);
        Params.Mapper      = struct('isTransparent', false, ...
                                    'Type', 'PSK', ...
                                    'ModulationOrder', 4, ...
                                    'PhaseOffset', pi/4, ...
                                    'SymbolMapping', 'Gray', ...
                                    'DecisionMethod', 'Hard decision');
        Params.Sig         = struct('isTransparent', true);
        Params.Channel     = struct('isTransparent', false, ...
                                    'Type', 'AWGN', 'FadingType', '');

        
    % Дозаполним значения по умолчанию
        Params.Source.NumBitsPerFrame = 48600;
        Params = SetParams(Params, 1, LogLanguage);
        Params = CalcAndCheckParams(Params, LogLanguage);

    % Создаём объект-источник
        Src = ClassDVBS2Source(Params, LogLanguage);

    % Проверяем Step()
        Bits = Src.Step();
        fprintf('Длина выхода ClassDVBS2Source: %d бит\n', length(Bits));
        assert(length(Bits) == 48600, 'Ожидалось 48600 бит!');

    % Проверяем, что Info сохранился
        assert(~isempty(Src.LastInfo), 'LastInfo не заполнен!');
        assert(length(Src.LastInfo.BBFRAME) == 48600, ...
            'BBFRAME должен быть 48600 бит!');
        assert(isequal(Src.LastInfo.BBFRAME_scrambled, Bits), ...
            'Выход Step() должен совпадать с BBFRAME_scrambled!');

    % Проверяем MATYPE-1 = 0xFA для beta=0.20
        assert(Src.LastInfo.MATYPE1 == 0xFA, ...
            sprintf('MATYPE1 = 0x%02X, ожидалось 0xFA', ...
            Src.LastInfo.MATYPE1));

    % Проверяем обратимость скремблирования
        initSeq = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];
        recovered = bb_scramble_test_local(Bits, initSeq);
        assert(isequal(recovered, Src.LastInfo.BBFRAME), ...
            'Скремблирование необратимо!');

    fprintf('Интеграция ClassDVBS2Source проверена успешно.\n');
    delete(Src);
end

function out = bb_scramble_test_local(in, initSeq)
    reg = initSeq(:).';
    out = zeros(size(in));
    for k = 1:length(in)
        p = bitxor(reg(14), reg(15));
        out(k) = bitxor(in(k), p);
        reg = [p, reg(1:14)];
    end
end