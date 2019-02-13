function [BatPower,status] = BatAgcMethod2(AgcLimit,GenPower,Pall,BatSoc,Verbose)
% function [BatPower,status] = BatAgcMethod(AgcLimit,GenPower,BatSoc,Verbose)
%
% ������ּ��ʵ�ִ���AGC�㷨��������AGC������ֵ�ͻ��鹦������财���ܳ����������
% ���룺
%	AgcLimit��   ��������ʾAGC������ֵ���ɵ��ȸ�������λ��MW��
%	GenPower��   ��������ʾ�������ʵ�⹦��ֵ����λ��MW��
%   BatSoc��     ��������ؿ���������0��100����λ��%��
%   Verbose��    ��������ʾ�澯��ʾ�ȼ���0-9��9��ʾ���澯��0����ʾ�澯��
% �����
%	BatPower��	��������ʾ�����ܹ��ʣ���λ��MW���ŵ�Ϊ����
%	status��     ��������ʾ�����ķ���״̬��>=0��ʾ������<0��ʾ�쳣��
% �汾������޸��� 2016-09-13
% 2016-09-13 HB
% 1. ��������������������������Ƴ���׫дע�͡�

    % ȫ�ֱ�������
    global Tline;   % �����ã����ڼ���ʱ�䡣
    global AgcStart;    % ��ʼʱ�䡣
    global GenPower0;   % ������ʼ������
    global LastAgc;     % ��������ʾ��һ��AGC������ֵ���ɵ��ȸ�������λMW��
    global LastPbat;	% ��������ʾ��һ�δ���ָ��ֵ�����㷨��ã���λMW��
    global Para;        % ������1��14��t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone���㷨������
    global LastAgcLimit;%��һ��AGCָ��
    global SOC0;        %��ʼ�ɵ�
    global Pall0;       %��ʼ���Ϲ���
    global SocFlag;     % �ѿ�ʼSOCά��
    global FlagAGC;     % �������ﵽAGCָ��
    global VgP0;
    global Vg;
    
    status = -1;    % ��ɳ�ʼ����״̬Ϊ-1

    % ������
    if (isempty(Verbose)||isnan(Verbose))
        Verbose = 0;
    end
    if (isempty(AgcLimit)||isempty(GenPower)||isempty(BatSoc)||isempty(Para)) || ...
       (isnan(AgcLimit)||isnan(GenPower)||isnan(BatSoc)||(sum(isnan(Para))>0))
        % ������ڿ������NAN��״̬Ϊ-2
        status = -2;
        WarnLevel = 1;
        if WarnLevel < Verbose
            fprintf('Input data can not be empty or NaN!');
        end
        return;
    elseif (length(Para) ~= 14)
        % �������ݸ�ʽ������Ҫ��״̬Ϊ-3
        status = -3;
        WarnLevel = 1;
        if WarnLevel < Verbose
            fprintf('Para data is not correct format!');
        end
        return;
    elseif AgcLimit <= 0
        % AGC��ֵС�ڵ���0��״̬Ϊ0
        status = 0;
        WarnLevel = 3;
        if WarnLevel < Verbose
            fprintf('AGC limit is 0!');
        end
        return;
    end
    
    Erate = Para(11);  %���ܶ����
    Prgen = Para(12);  %��������
    Vgen = Para(13);   % MW/min��������������
    Cdead = 0.005;%Para(14);  %����
    Cdead2= 0.005;
    % AGC�㷨
    if (AgcLimit > LastAgc+Cdead2*Prgen) ||  (AgcLimit < LastAgc-Cdead2*Prgen)    % AGC����ָ���±仯���öμ�¼���α仯��ʼֵ
    %if (AgcLimit > LastAgc+5) ||  (AgcLimit < LastAgc-5)    % AGCָ��仯
        FlagAGC = 0;
        SocFlag = 0;
        AgcStart = Tline;     %Tlineȫ��ʱ�䣬�ϲ���Ⱥ�����ʱ��
        GenPower0 = GenPower; %�ô�AGC����ʱ������ĳ�ʼ����
        LastAgcLimit = LastAgc; %LastAgc����һ�ε���ָ��ڳ�λ�ã������µ�ָ��
        LastAgc = AgcLimit;   %�������AGC�нϴ�仯��˵��AGCָ��ı��ˣ���ôҪ����AGCָ��ֵ��¼����
        SOC0 = BatSoc;        %BatSocָ���ε���ʱ���ϸı�ĺɵ�״̬����ָ���ǽ����ε��ڳ�ʼ�ɵ�״̬���浽SOC0��
        Pall0 = Pall;         %��ǰ���Ϲ���
        VgP0 = GenPower;      %��統ǰ����
    end
    %%���AGCָ��ֵû��̫��仯���������г�ʼ�����Ͳ������仯
    DetP = AgcLimit - GenPower;     % ������������ʣ����뿪ʼʱ���鹦�ʾ���ָ��ֵ�ľ���
    DetT = Tline-AgcStart;          % ������뱾��AGC������ʼʱ���ֵ
    if (DetT<=Para(1))                  % AGCָ���ʼt01�ڣ��޹����������֤K3ָ��
        BatPower = DetP+(Pall0-AgcLimit)*0.95;  %Pall0-AgcLimitָ��һ�������������Ŀ�껹�ж�Զ���õ��ڷ�ʽ����̫��
        if (AgcLimit<GenPower)
            Vg = -2;  %�趨�����ٶ���t01��
        else
            Vg = 2;
        end
        status = 1;
    else
        if (DetT==Para(1)+1)              %����Խ����Ӧ���������һ��
            Pall0 = Pall;                 %�������Ϲ��ʣ������������������ɵĴ��ܳ�����ͬ��
        elseif (mod(DetT,60)==0)
            Vg = GenPower-VgP0;             %����ÿ���ӻ���ʵ�ʵ���������
            VgP0 = GenPower;                %60s����һ�λ��ĳ�ʼ���������ڼ�����һ�λ������������
        end
        
        if (BatSoc<=Para(10))                                % SOC������ά����SocMin
            Pall0 = Pall;                                    % �������ĳ�ʼ���ϳ���
            BatPower = min(DetP,-Para(5)/2);                 % ���ƴ��ܵ�������������Ϊ��磬��ͬ��ʱ���Գ�
            SocFlag = 1;                                     % ����SOCά����־
        elseif (BatSoc>Para(9))                              % SOC������ά����SocMax     
            Pall0 = Pall;
            BatPower = max(DetP,Para(5)/2);                  % ����������п���DetP�Ǹ�ֵ�����Ի�ѡ��para(5)/2����ֵ
            SocFlag = 1;
        elseif (BatSoc>Para(10)+Para(8))&&(BatSoc<=Para(9)-Para(8))   % SOC�ڷ�Χ�ڣ��ɽ���AGC���ڣ�SocMin+SocDead��SocMax-SocDead
            SocFlag = 0;                                     % ����SOC�澯���
            if (abs(DetP)>Cdead*Prgen)                       % ����AGC���ڹ��̣�����K1\K2����ֵ��������Χ�⣬��Ҫ���е���
                if (FlagAGC>0)                               % ������������ϣ�����ָ����Ӧ���
                    if (BatSoc>Para(6)+Para(7))
                        BatPower = max(DetP,Para(5)/2);      % ������������Ϻ󣬻���Ҫ���ڴ��ܵ�SOC��ʹ�����м俿£
                    elseif (BatSoc<Para(6)-Para(7))
                        BatPower = min(DetP,-Para(5)/2);     % ͬ��
                    else
                        BatPower = 0;
                    end
                    SocFlag=1;                               % SOC����״̬(=1��ʾ���ڵ��ڣ�=0��ʾ�������)
                elseif (DetT>Para(2))                        % ��ʱ�䲹��������������
                    if (AgcLimit>GenPower0)                  % �������ϵ���
                        if Vg<0                              % �����ڽ�����
                            Pall0 = 0.95*Pall0+0.05*GenPower;  % ��ǰ�������ϳ���ֵ���㷽������������ʲô����������-->���ܻ����˳���ÿ����5%�Ĺ���
                        elseif Vg<Vgen/2                     % ���������ʽϵ�
                            Pall0 = 0.98*Pall0+0.02*GenPower;%ÿ����2%�Ĺ���
                        end
                        BatPower = min(DetP,Pall0-GenPower);
                        BatPower = max(0,BatPower);
                    else                                    % �������µ���
                        if Vg>0                             % ������������
                            Pall0 = 0.95*Pall0+0.05*GenPower;  
                        elseif Vg>-Vgen/2
                            Pall0 = 0.98*Pall0+0.02*GenPower;
                        end
                        BatPower = max(DetP,Pall0-GenPower);
                        BatPower = min(0,BatPower);
                    end
                else                    % ��ʱ��������������
                    if (AgcLimit<GenPower0)
                        if (((70-BatSoc)*3600*Erate/100)>(DetP/Vgen*60*Para(4)-0.5*Para(4)/Vgen*60*Para(4)))  %��ʽ�����⣿
                            Pall0 = 0.6*Pall0+0.4*AgcLimit;   % û����
                        end
                        BatPower = max(DetP,Pall0-GenPower);
                        BatPower = min(0,BatPower);
                    else
                        if (((BatSoc-30)*3600*Erate/100)>(DetP/Vgen*60*Para(3)-0.5*Para(3)/Vgen*60*Para(3)))
                            Pall0 = 0.6*Pall0+0.4*AgcLimit;
                        end
                        BatPower = min(DetP,Pall0-GenPower);
                        BatPower = max(0,BatPower);
                    end
                end
            else                                % ���������ϣ�ά��SOC
                FlagAGC = 1;
                if (BatSoc>Para(6)+Para(7))
                    BatPower = max(DetP,Para(5));
                elseif (BatSoc<Para(6)-Para(7))
                    BatPower = min(DetP,-Para(5));
                else
                    BatPower = DetP;%0;
                end
                SocFlag=1;
            end
        else     % ��������Pb����ֱ��SOC�ص��ɽ���AGC�ķ�Χ
            if (abs(DetP)<=Cdead*Prgen)
                Pall0 = Pall;
                FlagAGC = 1;
                if (BatSoc>Para(6)+Para(7))
                    BatPower = max(DetP,Para(5));
                elseif (BatSoc<Para(6)-Para(7))
                    BatPower = min(DetP,-Para(5));
                else
                    BatPower = 0;
                end
                SocFlag=1;
            else
                if (SocFlag==1) % ֮ǰ�ڽ���SOCά�����򱣳�P���򲻱䣬��Ӧͬ��AGC����
                    Pall0 = Pall;
                    if LastPbat>=0
                        BatPower = max(DetP,Para(5));
                    else
                        BatPower = min(DetP,-Para(5));
                    end
                else            % ֮ǰ�ڽ���AGC���ڣ�������𵴣����ܻ�����Ϊ0��������ﵽAGCָ������SOCά��
                    if (Pall0-GenPower>0)
                        Pall0 = 0.95*Pall0+0.05*GenPower;
                        BatPower = max(0,Pall0-GenPower);
                    else
                        Pall0 = 0.95*Pall0+0.05*GenPower;
                        BatPower = min(0,Pall0-GenPower);
                    end
                    if (BatSoc>Para(6)+Para(7))
                        BatPower = max(DetP,BatPower);
                    elseif (BatSoc<Para(6)-Para(7))
                        BatPower = min(DetP,BatPower);
                    else
                        BatPower = 0;
                    end
                end
            end
        end
    end
    if (BatPower>Para(3))
        BatPower = Para(3);
    elseif  (BatPower<Para(4))
        BatPower = Para(4);
    end
    if abs(BatPower-LastPbat)<0.2    %����0.2�Ĳ���
        BatPower = LastPbat;
    end
end

