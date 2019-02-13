function [Mall,M0all,Days] = CalMoneyHB(Agc,Pdg,Pbat)
% function [Mall,M0all,Days] = CalMoney(Agc,Pdg,Pbat)
%
% 本函数旨在实现储能AGC收益计算，即根据AGC功率限值、机组功率、储能功率等求解日收益和电池寿命。
% 输入：
%	Agc：    向量，1×n，表示AGC功率限值，由调度给定，单位：MW。
%	Pdg：    向量，1×n，表示表示发电机组实测功率值，单位：MW。
%	Pbat：   向量，1×n，表示储能总功率，单位：MW，放电为正。
% 输出：
%	Mall：   标量，表示储能AGC系统总收益，单位：元。
%	Days：   标量，表示储能AGC系统电池可用天数，单位：日。
% 版本：最后修改于 2016-09-18
% 2016-09-18 胡斌
% 1. 建立函数，定义输入输出，编制程序，撰写注释。

global Prate;
global Emax;
global Result;
global LineMax;
global Rall;
Pall(1:LineMax) = Pdg(1:LineMax)+Pbat(1:LineMax);  % 总出力
%Pall = Pdg;  % 总出力
% 参数初始化
T=1;
% 检验数据合法性
for i=1:1:LineMax
    if isnan(Agc(i))
        Agc(i) = Agc(i-1);
    end
    if isnan(Pall(i))
        Pall(i) = Pall(i-1);
    end
end

% 变量初始化
Result = zeros(100,23); 
% 列数：1,   2,  3, 4,  5, 6,  7, 8, 9,10,  11,  12,13,14,15,16,     17,18,  19,   20,21,22,23,
% 定义：Pagc,Pt0,T0,Pt1,T1,Pt2,T2,T3,V,detP,detT,K1,K2,K3,KP,backFlag,D,Money,OldM,Ev,Ep,Et,Eall
Bat = zeros(LineMax,3);
% 列数：1,   2,        3
% 定义：Pbat,运行倍率/C,运行DOD%
BatResult = zeros(100,7);
% 列数：1,         2,          3        ,4       ,5       ,6      ,7
% 定义：次运行DOD%,次运行倍率/C,运行倍率/C,循环基数,换能系数,循环次数,每次循环衰减/%
Result(1,1) = Agc(1);
Result(1,2) = Pall(1);
Result(1,3) = 1;
backFlag = Agc(1) - Pall(1);
ctrlNo = 1;
batNo = 1;
lastAgc = Agc(1);
%KpNo = 0;
Dall = 0;
KPall = 0;
Cdead = 1.0*Prate/100;          % Cdead是K1指标用，机组功率达到新AGC指令的死区，目前取的1%机组额定功率。% 上都、开滦、大同1.0%，宣化0.5% 
detAGC = 2.2*Prate/100;         % detAGC是AGC指令变化的死区，死区内不算变化。 % 上都、开滦、大同2.2%，宣化1.0% 
MAXP = 0;                       % 是不是写反了？
MINP = Prate;
K1rate = 0.015;   % 上都、开滦1%，大同、宣化1.5% 指的是vn是额定功率的1.5%
K2rate = 0.015;   % 指的是Pn是额定功率的1.5%
K3rate = 60;      % 指的是tn的值，华北不应该是60s吗？
K2set = 0.1;      %
Yagc = 5.0;       % 补偿价格
backC = 1.0/100;  % 上都、开滦0%，大同、宣化1.0%--->折返算法? 

% 收益相关分析计算
scanRate = 5;     % 扫描频率为何是5？减少计算量，提高计算速度？
for i=1:1:LineMax
    if ((mod(i,scanRate)==1)||(scanRate==1))
        K3dead = 0.005*lastAgc; % K3dead是K3指标用，机组功率离开旧AGC指令的死区，目前取的1%旧AGC指令值。
        if (Agc(i) > detAGC+Result(ctrlNo,1)) ||  (Agc(i) < Result(ctrlNo,1)-detAGC)
            % AGC指令改变，计算上次调整数据，记录新一次调整初始数据
            % 计算V detP detT K1 K2 K3 KP D M E        
            % ==========计算K3============
            if (Result(ctrlNo,5)==0) % (T1=0)
                Result(ctrlNo,5) = i;        %没有响应死区的时的情况？包括第一个及机组未跟踪上的情况
                Result(ctrlNo,4) = Pall(i);  %并将该时刻的联合出力赋值？
            end
            % detT = (T1-T0)/60
            Result(ctrlNo,11) = (Result(ctrlNo,5)-Result(ctrlNo,3))*T/K3rate;%K3rate是否有问题
            % K3 = 2-detT
            Result(ctrlNo,14) = max(0.1, (2-Result(ctrlNo,11)));         

            % ==========计算K1============
            if (Result(ctrlNo,7)>0) % T2>0
                % V = ABS(Pt2-Pt1)/(T2-T1)*60
                if abs(Result(ctrlNo,6)-Result(ctrlNo,4))>0
                    Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,4))/((Result(ctrlNo,7)-Result(ctrlNo,5))*T)*60; % P2-P1/T2-T1
                    Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,2))/((Result(ctrlNo,7)-Result(ctrlNo,3))*T)*60; % P2-P0/T2-T0  %这行代码是否多余需要商榷_heliang20180827
                else
                    Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,2))/((Result(ctrlNo,7)-Result(ctrlNo,3))*T)*60; % P2-P0/T2-T0；当P2<P1时(降负荷)为何不用P2-P1/T2-T1
                end
                % K1 = 2-0.015*Prate/V
                Result(ctrlNo,12) = max(0.1, (2-K1rate*Prate/Result(ctrlNo,9))); 
            else
                Result(ctrlNo,7)=i;
                Result(ctrlNo,6)=Pall(i);
                Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,2))/((Result(ctrlNo,7)-Result(ctrlNo,3))*T)*60; % P2-P0/T2-T0（同上）
                Result(ctrlNo,12) = max(0.1, (2-K1rate*Prate/Result(ctrlNo,9)));  
            end

            % ==========计算K2============
            if (Result(ctrlNo,8)>0) % T3>0
                % detP = detP/(T3-T2)
                Result(ctrlNo,10) = Result(ctrlNo,10)/(Result(ctrlNo,8)-Result(ctrlNo,7))*scanRate; %扫描频率scanRate值不应该在此被乘_heliang20180828---->对Result(ctrlNo,10)没看懂
                % K2 = 2-detP/(0.01*Prate)
                Result(ctrlNo,13) = max(0.1, (2-Result(ctrlNo,10)/(K2rate*Prate)));  
            else
                Result(ctrlNo,13) = K2set;
            end

            % KP = K1*K2*K3
             Result(ctrlNo,15) = Result(ctrlNo,12) * Result(ctrlNo,13) * Result(ctrlNo,14);
            % D = |Pagc-Pt0| + Prate*0.02*backFlag
            if (Result(ctrlNo,1)>Result(ctrlNo,2))
                Result(ctrlNo,17) = abs(min(MAXP,Result(ctrlNo,1))-Result(ctrlNo,2)) + Prate*backC*Result(ctrlNo,16);
            else
                Result(ctrlNo,17) = abs(max(MINP,Result(ctrlNo,1))-Result(ctrlNo,2)) + Prate*backC*Result(ctrlNo,16);
            end
            % M = D*(ln(KP)+1)*Yagc
            Result(ctrlNo,18) = max(0,Result(ctrlNo,17)*(log(Result(ctrlNo,15))+1)*Yagc);%华北和山东的收益公式
            Result(ctrlNo,19) = Result(ctrlNo,17)*Result(ctrlNo,15)*Yagc;%山西、广东的收益公式
            % Ev IF(K1>1,0,(1-K1)*330*2)
            if (Result(ctrlNo,12)<1)
                Result(ctrlNo,20) = (1-Result(ctrlNo,12))*Prate*2;
            end
            % Ep IF(K2>1,0,(1-K2)*330*2)
            if (Result(ctrlNo,13)<1)
                Result(ctrlNo,21) = (1-Result(ctrlNo,13))*Prate*2;
            end
            % Et IF(K3>1,0,(1-K3)*330*2)
            if (Result(ctrlNo,14)<1)
                Result(ctrlNo,22) = (1-Result(ctrlNo,14))*Prate*2;
            end
            % Eall
            Result(ctrlNo,23) = Result(ctrlNo,20) + Result(ctrlNo,21) + Result(ctrlNo,22);
            %Ev、Ep、Et是什么意思？
            % 累加D值
            Dall = Dall + Result(ctrlNo,17);
            lastAgc = Result(ctrlNo,1);
            ctrlNo = ctrlNo + 1;
            Result(ctrlNo,1) = Agc(i);                  % Pagc
            Result(ctrlNo,2) = Pall(i);                 % Pt0
            Result(ctrlNo,3) = i;                       % T0
            backFlag = backFlag * (Agc(i) - lastAgc);
            if (backFlag < 0)
                Result(ctrlNo,16) = 1;                  % backFlag
            end
            backFlag = Agc(i) - lastAgc;
            MAXP = 0;
            MINP = Prate;
        else        % AGC指令不变，计算T1、T2、T3并累加detP
            if (Result(ctrlNo,1)>Result(ctrlNo,2))
                if (Pall(i)>MAXP)
                    MAXP = Pall(i);
                end
            else
                if (Pall(i)<MINP)
                    MINP = Pall(i);
                end
            end
            if (Result(ctrlNo,5) == 0)  % T1未得到
                if (((Result(ctrlNo,1)-Result(ctrlNo,2))*(Pall(i)-Result(ctrlNo,2)))>0)     % 变化方向一致
                    if (abs(Pall(i)-lastAgc)>K3dead)  % 出死区
                        Result(ctrlNo,4) = Pall(i);         % Pt1
                        Result(ctrlNo,5) = i;               % T1
                    end
                end
            elseif (Result(ctrlNo,7) == 0)  % T2未得到
                if (Result(ctrlNo,1) > lastAgc)    % AGC指令大于出力
                    if (Pall(i) > Result(ctrlNo,1)-Cdead)
                        Result(ctrlNo,6) = Pall(i);     % Pt2
                        Result(ctrlNo,7) = i;           % T2
                    end
                else    % AGC指令小于出力
                    if (Pall(i) < Result(ctrlNo,1)+Cdead)
                        Result(ctrlNo,6) = Pall(i);     % Pt2
                        Result(ctrlNo,7) = i;           % T2
                    end
                end
            else    % 更新T3并累加detP
                Result(ctrlNo,8) = i;                   % T3
                Result(ctrlNo,10) = Result(ctrlNo,10) + abs(Agc(i) - Pall(i));
            end
        end
        if i==LineMax
            % 最后一个数据后，计算V detP detT K1 K2 K3 KP D M E
            % ==========计算K3============
            if (Result(ctrlNo,5)==0) % (T1=0)
                Result(ctrlNo,5) = i;
                Result(ctrlNo,4) = Pall(i);
            end
            % detT = (T1-T0)/60
            Result(ctrlNo,11) = (Result(ctrlNo,5)-Result(ctrlNo,3))*T/K3rate;
            % K3 = 2-detT
            Result(ctrlNo,14) = max(0.1, (2-Result(ctrlNo,11)));         

            % ==========计算K1============
            if (Result(ctrlNo,7)>0) % T2>0
                % V = ABS(Pt2-Pt1)/(T2-T1)*60
                if abs(Result(ctrlNo,6)-Result(ctrlNo,4))>0
                    Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,4))/((Result(ctrlNo,7)-Result(ctrlNo,5))*T)*60; % P2-P1/T2-T1
                else
                    Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,2))/((Result(ctrlNo,7)-Result(ctrlNo,3))*T)*60; % P2-P0/T2-T0
                end
                % K1 = 2-0.015*Prate/V
                Result(ctrlNo,12) = max(0.1, (2-K1rate*Prate/Result(ctrlNo,9))); 
            else
                Result(ctrlNo,7)=i;
                Result(ctrlNo,6)=Pall(i);
                Result(ctrlNo,9) = abs(Result(ctrlNo,6)-Result(ctrlNo,2))/((Result(ctrlNo,7)-Result(ctrlNo,3))*T)*60; % P2-P0/T2-T0
                Result(ctrlNo,12) = max(0.1, (2-K1rate*Prate/Result(ctrlNo,9)));  
            end

            % ==========计算K2============
            if (Result(ctrlNo,8)>0) % T3>0
                % detP = detP/(T3-T2)
                Result(ctrlNo,10) = Result(ctrlNo,10)/(Result(ctrlNo,8)-Result(ctrlNo,7))*scanRate;
                % K2 = 2-detP/(0.01*Prate)
                Result(ctrlNo,13) = max(0.1, (2-Result(ctrlNo,10)/(K2rate*Prate)));  
            else
                Result(ctrlNo,13) = K2set;
            end

            % KP = K1*K2*K3
             Result(ctrlNo,15) = Result(ctrlNo,12) * Result(ctrlNo,13) * Result(ctrlNo,14);
            % D = |Pagc-Pt0| + Prate*0.02*backFlag
            if (Result(ctrlNo,1)>Result(ctrlNo,2))
                Result(ctrlNo,17) = abs(min(MAXP,Result(ctrlNo,1))-Result(ctrlNo,2)) + Prate*backC*Result(ctrlNo,16);
            else
                Result(ctrlNo,17) = abs(max(MINP,Result(ctrlNo,1))-Result(ctrlNo,2)) + Prate*backC*Result(ctrlNo,16);
            end
            % M = D*(ln(KP)+1)*Yagc
            Result(ctrlNo,18) = max(0,Result(ctrlNo,17)*(log(Result(ctrlNo,15))+1)*Yagc);
            Result(ctrlNo,19) = Result(ctrlNo,17)*Result(ctrlNo,15)*Yagc;
        end
    end
end

    if (sum(Result(:,12))/ctrlNo<1)
        Result(ctrlNo,20) = (1-sum(Result(:,12))/ctrlNo)*Prate*2;
    end
    if (sum(Result(:,13))/ctrlNo<1)
        Result(ctrlNo,21) = (1-sum(Result(:,13))/ctrlNo<1)*Prate*2;
    end
    if (sum(Result(:,14))/ctrlNo<1)
        Result(ctrlNo,22) = (1-sum(Result(:,14))/ctrlNo<1)*Prate*2;
    end
    % Eall
    Result(ctrlNo,23) = Result(ctrlNo,20) + Result(ctrlNo,21) + Result(ctrlNo,22);
    
    % 累加D值、KP值日总量
    K1 = 0;
    K2 = 0;
    K3 = 0;
    Dall=0;
    KPall=0;
    counter=0;
    for i=1:1:ctrlNo
        %if (Result(i,14)>0.1)
        if (Result(i,12)>0.1)      % K1>0.1
            K1 = K1 + Result(i,12);
            K2 = K2 + Result(i,13);
            K3 = K3 + Result(i,14);
            Dall = Dall + Result(i,17);
            KPall = KPall + Result(i,15);
            counter=counter+1;
        end;
    end;
    if counter==0
        counter=1;
    end
    K1 = K1/counter;
    K2 = K2/counter;
    K3 = K3/counter;
    KPall = KPall/counter;
    Eall = sum(Result(:,23));
    Mall = Dall*(log(KPall)+1)*5;
    M0all = 0;

    
    % 辅助分析
    for j=1:1:ctrlNo
        if (Result(j,8) == 0)
            Result(j,8)=Result(j,7); 
        end
        if (Result(j,6) <= 0.002)
            %a=a+1;
        end
    end

% 电池寿命相关分析计算
Bat(:,1) = Pbat;
Bat(:,2) = Bat(:,1);        % 运行功率
Bat(:,3) = Bat(:,2)/3600;   % 运行电量%
lastBat = Bat(1,1);
counterB = 0;
for i=1:1:LineMax
    if (Bat(i,1)*lastBat<0) % 充放电方向改变
        BatResult(batNo,2) = BatResult(batNo,1)/counterB*3600*1000000/Emax/120/24*T; %计算平均单串电输出功率值,2C
        %BatResult(batNo,2) = BatResult(batNo,1)/counterB*3600*1000000/Emax/6/3/6/72; %计算平均单串电输出功率值,3C
        if (BatResult(batNo,2)<0); %计算平均单串电池电流
            BatResult(batNo,2)=BatResult(batNo,2)/3.4;
        else
            BatResult(batNo,2)=BatResult(batNo,2)/3.2;
        end
        BatResult(batNo,2) = abs(BatResult(batNo,2))/120; %计算平均单串电池倍率 % 次运行倍率/C
        %BatResult(batNo,2) = abs(BatResult(batNo,2))/40;  %计算平均单串电池倍率 % 次运行倍率/C
        BatResult(batNo,1) = BatResult(batNo,2)*counterB/3600*100*T;                % 次运行DOD%    
        
        % 2C
        if (BatResult(batNo,2)>1)                               % 运行倍率/C 1/2,循环基数 6000/4000
            BatResult(batNo,3) = 2;
            BatResult(batNo,4) = 4000;
        else
            BatResult(batNo,3) = 1;
            BatResult(batNo,4) = 6000;
        end
%         % 3C
%         if (BatResult(batNo,2)>2)                               % 运行倍率/C 1/2/3/4,循环基数 10224/9725/9225/8726
%             BatResult(batNo,3) = 3;
%             BatResult(batNo,4) = 9225;
%         elseif (BatResult(batNo,2)>1)
%             BatResult(batNo,3) = 1;
%             BatResult(batNo,4) = 9725;
%         else
%             BatResult(batNo,3) = 1;
%             BatResult(batNo,4) = 10224;
%         end
        X = abs(BatResult(batNo,1));
        %BatResult(batNo,5) = 2502550-71290.22364*X+958.96523*X^2-4.30786*X^3;  % 换能系数，4C
%         BatResult(batNo,5) = (126245.62675*X-4343.98492*X^2+55.75335*X^3-0.24209*X^4)*BatResult(batNo,4)/8726;           % 换能系数，3C
%         if (X<4.28)
%             BatResult(batNo,5) = (479329.63895-1150.96212*X)*BatResult(batNo,4)/8726;                                     % 换能系数，3C
%         end
        %BatResult(batNo,5) = 1140532-3158.36*X;                                     % 换能系数，3C
        BatResult(batNo,5) = (479329.63895-1150.96212*X)*(BatResult(batNo,4)/3644); % 换能系数，2C
        BatResult(batNo,6) = BatResult(batNo,5)/X*2;            % 循环次数
        BatResult(batNo,7) = 20/BatResult(batNo,6);             % 每次循环衰减/%
        if isnan(BatResult(batNo,7))
            BatResult(batNo,7) =0;
        end
        batNo = batNo+1;
        BatResult(batNo,1) = Bat(i,3);
        BatResult(batNo,2) = Bat(i,2);
        counterB = 0;
    else
        BatResult(batNo,1) = BatResult(batNo,1)+Bat(i,3);
        BatResult(batNo,2) = BatResult(batNo,2)+Bat(i,2);
    end
    if (i==LineMax)
        BatResult(batNo,2) = BatResult(batNo,1)/counterB*3600*1000000/Emax/120/24*T; %计算平均单串电输出功率值,2C
        %BatResult(batNo,2) = BatResult(batNo,1)/counterB*3600*1000000/Emax/6/3/6/72; %计算平均单串电输出功率值,3C
        if (BatResult(batNo,2)<0); %计算平均单串电池电流
            BatResult(batNo,2)=BatResult(batNo,2)/3.4;
        else
            BatResult(batNo,2)=BatResult(batNo,2)/3.2;
        end
        BatResult(batNo,2) = abs(BatResult(batNo,2))/120; %计算平均单串电池倍率 % 次运行倍率/C
        %BatResult(batNo,2) = abs(BatResult(batNo,2))/40;  %计算平均单串电池倍率 %
        %次运行倍率/C
        BatResult(batNo,1) = BatResult(batNo,2)*counterB/3600*100*T;                % 次运行DOD%    
        
        if (BatResult(batNo,2)>1)                               % 运行倍率/C 1/2,循环基数 6000/4000
            BatResult(batNo,3) = 2;
            BatResult(batNo,4) = 4000;
        else
            BatResult(batNo,3) = 1;
            BatResult(batNo,4) = 6000;
        end
        X = abs(BatResult(batNo,1));
        %BatResult(batNo,5) = 2502550-71290.22364*X+958.96523*X^2-4.30786*X^3;  % 换能系数，4C
        %BatResult(batNo,5) = 1140532-3158.36*X;                                     % 换能系数，3C
        BatResult(batNo,5) = (479329.63895-1150.96212*X)*(BatResult(batNo,4)/3644); % 换能系数，2C
        BatResult(batNo,6) = BatResult(batNo,5)/X*2;            % 循环次数
        BatResult(batNo,7) = 20/BatResult(batNo,6);             % 每次循环衰减/%
        if isnan(BatResult(batNo,7))
            BatResult(batNo,7) =0;
        end
    end
    lastBat = Bat(i,1);
    counterB = counterB+1;
end
BatDeath = sum(BatResult(:,7)); % SOC%
Days = 20/BatDeath;

Rall(1)=K1;
Rall(2)=K2;
Rall(3)=K3;
Rall(4)=KPall;
Rall(5)=Dall;
Rall(6)=Mall/10000;
Rall(7)=Days;
Rall(9)=Eall;
