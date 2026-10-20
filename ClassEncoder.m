classdef ClassEncoder < handle
    % ClassEncoder - каскадное кодирование BCH + LDPC (DVB-S2, normal FECFRAME)
    %   StepTx: BBFRAME (K_bch бит) -> FECFRAME (64800 бит)
    %   StepRx: LLR (или биты) -> BBFRAME (K_bch бит)

    properties (SetAccess = private)
        isTransparent;
        isSoftInput;
        LogLanguage;
        CodeRate;
        Kbch;
        Nbch;
        BCHt;
        Rate;
        MaxNumIter;
    end
    properties (Access = private)
        BchEnc;
        BchDec;
        LdpcEncCfg;
        LdpcDecCfg;
        HardLLR = 10;
    end
    methods
        function obj = ClassEncoder(Params, LogLanguage)
            Encoder = Params.Encoder;
            obj.isTransparent = Encoder.isTransparent;
            obj.LogLanguage   = LogLanguage;
            obj.CodeRate      = Encoder.CodeRate;
            obj.MaxNumIter    = Encoder.MaxNumIter;
            if isfield(Encoder, 'isSoftInput')
                obj.isSoftInput = Encoder.isSoftInput;
            else
                obj.isSoftInput = false;
            end

            nLdpc = 64800;
            [obj.Kbch, obj.Nbch, obj.BCHt] = ...
                ClassEncoder.CodeParams(obj.CodeRate);
            obj.Rate = obj.Kbch / nLdpc;

            if obj.isTransparent
                obj.Rate = 1;
                return
            end

            % --- BCH: GF(2^16) с примитивным полиномом DVB-S2 ---
            % Полином 1 + x^2 + x^3 + x^5 + x^16 (в десятичном виде: 65581)
            
            obj.BchEnc = comm.BCHEncoder( ...
                'CodewordLength', obj.Nbch, ...
                'MessageLength', obj.Kbch);
            obj.BchDec = comm.BCHDecoder( ...
                'CodewordLength', obj.Nbch, ...
                'MessageLength', obj.Kbch);

            % --- LDPC: проверочная матрица DVB-S2 ---
            H = dvbs2ldpc(ClassEncoder.RateToNum(obj.CodeRate));
            obj.LdpcEncCfg = ldpcEncoderConfig(H);
            obj.LdpcDecCfg = ldpcDecoderConfig(H);
        end

        function FECFrame = StepTx(obj, BBFrame)
            if obj.isTransparent
                FECFrame = BBFrame;
                return
            end
            BBFrame = double(BBFrame(:));
            if length(BBFrame) ~= obj.Kbch
                error(['ClassEncoder: ожидалось %d бит BBFRAME, ', ...
                    'получено %d.'], obj.Kbch, length(BBFrame));
            end
            % 1. BCH-кодирование
            BchWord = double(obj.BchEnc(BBFrame));            % N_bch бит
            % 2. LDPC-кодирование
            FECFrame = double(ldpcEncode(BchWord, obj.LdpcEncCfg)); % 64800
        end

        function BBFrame = StepRx(obj, InData)
            if obj.isTransparent
                BBFrame = InData;
                return
            end
            LLR = double(InData(:));
            if ~obj.isSoftInput
                LLR = (1 - 2*LLR) * obj.HardLLR;
            end
            % 1. LDPC-декодирование
            LdpcOut = double(ldpcDecode(LLR, obj.LdpcDecCfg, ...
                obj.MaxNumIter));                               % N_bch бит
            % 2. BCH-декодирование
            [Msg, ~] = obj.BchDec(LdpcOut(:));
            BBFrame = double(Msg(:));                           % K_bch бит
        end
    end

    methods (Static)
        function [Kbch, Nbch, t] = CodeParams(rate)
            % Таблица 1 лабораторной: нормальный FECFRAME, n_ldpc = 64800
            T = { ...
                '1/4',  16008, 16200, 12; ...
                '1/3',  21408, 21600, 12; ...
                '2/5',  25728, 25920, 12; ...
                '1/2',  32208, 32400, 12; ...
                '3/5',  38688, 38880, 12; ...
                '2/3',  43040, 43200, 10; ...
                '3/4',  48408, 48600, 12; ...
                '4/5',  51648, 51840, 12; ...
                '5/6',  53840, 54000, 10; ...
                '8/9',  57472, 57600,  8; ...
                '9/10', 58192, 58320,  8};
            idx = find(strcmp(T(:,1), rate), 1);
            if isempty(idx)
                error('Invalid LDPC code rate ''%s''.', rate);
            end
            Kbch = T{idx, 2};
            Nbch = T{idx, 3};
            t    = T{idx, 4};
        end

        function r = RateToNum(rate)
            p = strsplit(rate, '/');
            r = str2double(p{1}) / str2double(p{2});
        end
    end
end
