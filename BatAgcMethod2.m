function [BatPower,status] = BatAgcMethod2(AgcLimit,GenPower,Pall,BatSoc,Verbose)
% function [BatPower,status] = BatAgcMethod(AgcLimit,GenPower,BatSoc,Verbose)
%
% 本函数旨在实现储能AGC算法，即根据AGC功率限值和机组功率求解需储能总出力并输出。
% 输入：
%	AgcLimit：   标量，表示AGC功率限值，由调度给定，单位：MW。
%	GenPower：   标量，表示发电机组实测功率值，单位：MW。
%   BatSoc：     标量，电池可用容量，0～100，单位：%。
%   Verbose：    标量，表示告警显示等级，0-9，9显示最多告警，0不显示告警。
% 输出：
%	BatPower：	标量，表示储能总功率，单位：MW，放电为正。
%	status：     标量，表示函数的返回状态，>=0表示正常，<0表示异常。
% 版本：最后修改于 2016-09-13
% 2016-09-13 HB
% 1. 建立函数，定义输入输出，编制程序，撰写注释。

    % 全局变量定义
    global Tline;   % 测试用，用于计算时间。
    global AgcStart;    % 起始时间。
    global GenPower0;   % 机组起始出力。
    global LastAgc;     % 标量，表示上一次AGC功率限值，由调度给定，单位MW。
    global LastPbat;	% 标量，表示上一次储能指令值，由算法求得，单位MW。
    global Para;        % 向量，1×14，t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone，算法参数。
    global LastAgcLimit;%上一次AGC指令
    global SOC0;        %初始荷电
    global Pall0;       %初始联合功率
    global SocFlag;     % 已开始SOC维护
    global FlagAGC;     % 机组曾达到AGC指令
    global VgP0;
    global Vg;
    
    status = -1;    % 完成初始化，状态为-1

    % 输入检查
    if (isempty(Verbose)||isnan(Verbose))
        Verbose = 0;
    end
    if (isempty(AgcLimit)||isempty(GenPower)||isempty(BatSoc)||isempty(Para)) || ...
       (isnan(AgcLimit)||isnan(GenPower)||isnan(BatSoc)||(sum(isnan(Para))>0))
        % 输入存在空数组或NAN，状态为-2
        status = -2;
        WarnLevel = 1;
        if WarnLevel < Verbose
            fprintf('Input data can not be empty or NaN!');
        end
        return;
    elseif (length(Para) ~= 14)
        % 参数数据格式不符合要求，状态为-3
        status = -3;
        WarnLevel = 1;
        if WarnLevel < Verbose
            fprintf('Para data is not correct format!');
        end
        return;
    elseif AgcLimit <= 0
        % AGC限值小于等于0，状态为0
        status = 0;
        WarnLevel = 3;
        if WarnLevel < Verbose
            fprintf('AGC limit is 0!');
        end
        return;
    end
    
    Erate = Para(11);  %储能额定容量
    Prgen = Para(12);  %机组额定容量
    Vgen = Para(13);   % MW/min，升降负荷速率
    Cdead = 0.005;%Para(14);  %死区
    Cdead2= 0.005;
    % AGC算法
    if (AgcLimit > LastAgc+Cdead2*Prgen) ||  (AgcLimit < LastAgc-Cdead2*Prgen)    % AGC发生指令新变化，该段记录本次变化初始值
    %if (AgcLimit > LastAgc+5) ||  (AgcLimit < LastAgc-5)    % AGC指令变化
        FlagAGC = 0;
        SocFlag = 0;
        AgcStart = Tline;     %Tline全局时间，上层调度函数的时间
        GenPower0 = GenPower; %该次AGC调节时火电机组的初始出力
        LastAgcLimit = LastAgc; %LastAgc是上一次调度指令，腾出位置，保存新的指令
        LastAgc = AgcLimit;   %如果该秒AGC有较大变化，说明AGC指令改变了，那么要将该AGC指令值记录下来
        SOC0 = BatSoc;        %BatSoc指本次调节时不断改变的荷电状态，该指令是将本次调节初始荷电状态保存到SOC0中
        Pall0 = Pall;         %当前联合功率
        VgP0 = GenPower;      %火电当前出力
    end
    %%如果AGC指令值没有太大变化，上述所有初始变量就不发生变化
    DetP = AgcLimit - GenPower;     % 计算待调整功率，本秒开始时机组功率距离指令值的距离
    DetT = Tline-AgcStart;          % 该秒距离本次AGC调节起始时间的值
    if (DetT<=Para(1))                  % AGC指令初始t01内，限功率输出，保证K3指标
        BatPower = DetP+(Pall0-AgcLimit)*0.95;  %Pall0-AgcLimit指上一秒结束后距离调节目标还有多远；该调节方式看不太懂
        if (AgcLimit<GenPower)
            Vg = -2;  %设定调节速度在t01内
        else
            Vg = 2;
        end
        status = 1;
    else
        if (DetT==Para(1)+1)              %机组越出响应死区后的下一秒
            Pall0 = Pall;                 %重置联合功率（死区和正常升降负荷的储能出力不同）
        elseif (mod(DetT,60)==0)
            Vg = GenPower-VgP0;             %计算每分钟机组实际的升降速率
            VgP0 = GenPower;                %60s更改一次火电的初始出力，用于计算下一次机组的升降速率
        end
        
        if (BatSoc<=Para(10))                                % SOC超下限维护，SocMin
            Pall0 = Pall;                                    % 变更该秒的初始联合出力
            BatPower = min(DetP,-Para(5)/2);                 % 限制储能的最大出力，负号为充电，当同向时可以充
            SocFlag = 1;                                     % 储能SOC维护标志
        elseif (BatSoc>Para(9))                              % SOC超上限维护，SocMax     
            Pall0 = Pall;
            BatPower = max(DetP,Para(5)/2);                  % 这种情况很有可能DetP是负值，所以会选择para(5)/2的正值
            SocFlag = 1;
        elseif (BatSoc>Para(10)+Para(8))&&(BatSoc<=Para(9)-Para(8))   % SOC在范围内，可进行AGC调节，SocMin+SocDead～SocMax-SocDead
            SocFlag = 0;                                     % 储能SOC告警解除
            if (abs(DetP)>Cdead*Prgen)                       % 机组AGC调节过程，提升K1\K2；差值在死区范围外，需要进行调节
                if (FlagAGC>0)                               % 机组曾调节完毕：机组指令响应完成
                    if (BatSoc>Para(6)+Para(7))
                        BatPower = max(DetP,Para(5)/2);      % 如果机组调节完毕后，还需要调节储能的SOC，使其向中间靠拢
                    elseif (BatSoc<Para(6)-Para(7))
                        BatPower = min(DetP,-Para(5)/2);     % 同理
                    else
                        BatPower = 0;
                    end
                    SocFlag=1;                               % SOC调节状态(=1表示正在调节，=0表示调节完成)
                elseif (DetT>Para(2))                        % 长时间补偿，检查机组速率
                    if (AgcLimit>GenPower0)                  % 代表向上调节
                        if Vg<0                              % 机组在降负荷
                            Pall0 = 0.95*Pall0+0.05*GenPower;  % 当前机组联合出力值计算方法；不懂，有什么特殊限制吗？-->储能缓慢退出？每秒退5%的功率
                        elseif Vg<Vgen/2                     % 升负荷速率较低
                            Pall0 = 0.98*Pall0+0.02*GenPower;%每秒退2%的功率
                        end
                        BatPower = min(DetP,Pall0-GenPower);
                        BatPower = max(0,BatPower);
                    else                                    % 代表向下调节
                        if Vg>0                             % 机组在升负荷
                            Pall0 = 0.95*Pall0+0.05*GenPower;  
                        elseif Vg>-Vgen/2
                            Pall0 = 0.98*Pall0+0.02*GenPower;
                        end
                        BatPower = max(DetP,Pall0-GenPower);
                        BatPower = min(0,BatPower);
                    end
                else                    % 短时补偿，核算容量
                    if (AgcLimit<GenPower0)
                        if (((70-BatSoc)*3600*Erate/100)>(DetP/Vgen*60*Para(4)-0.5*Para(4)/Vgen*60*Para(4)))  %公式有问题？
                            Pall0 = 0.6*Pall0+0.4*AgcLimit;   % 没看懂
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
            else                                % 机组调节完毕，维护SOC
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
        else     % 死区保持Pb方向，直至SOC回到可进行AGC的范围
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
                if (SocFlag==1) % 之前在进行SOC维护，则保持P方向不变，响应同向AGC需求
                    Pall0 = Pall;
                    if LastPbat>=0
                        BatPower = max(DetP,Para(5));
                    else
                        BatPower = min(DetP,-Para(5));
                    end
                else            % 之前在进行AGC调节，需避免震荡，储能缓慢降为0，待机组达到AGC指令后进行SOC维护
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
    if abs(BatPower-LastPbat)<0.2    %过滤0.2的波动
        BatPower = LastPbat;
    end
end

