% this is a m-file for simulation AGC control.
% hubin, 2017.6.28
% 全局变量定义
clear all;

global Tline;   % 测试用，用于计算时间。
global LastAgc; % 标量，表示上一次AGC功率限值，由调度给定，单位MW。
global LastPbat; % 标量，表示上一次储能指令值，由算法求得，单位MW。
global Para;    % 向量，1×8，t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone，算法参数。
global LastAgcLimit;%上一次AGC指令
global Result;  %参数输出结果矩阵
global GenPower0;
global SOC0;    %起始荷电状态
global SOC;     %荷电状态
global Prate;   %机组额定功率
global Emax;    %储能额定功率
global AAA;
global LineMax; %数据的最大行数（也是取数据的时间长度）
global Rall;    %
% for id=1:1:30
%     a=strcat(num2str(id),'.mat');
%     if id<10        
%         fileName=strcat('data2016120',a);
%     else
%         fileName=strcat('data201612',a);
%     end
%     load('BatData1.mat');
%     load(fileName);
% load('test111.mat');     % 载入文件
load('HZdata.mat')
% 处理一下数据
data1=HZdata12h.data;
j=1;
for m=1:length(data1(:,1))
        data(j:j+9,1)=data1(m,1);
        data(j:j+9,2)=data1(m,2);
        data(j:j+9,3)=data1(m,3);
        j=j+9;
end
data(end,:)=[];

agcSet = 1; %agcSet=1为有储能计算；agcSet=0为无储能收益计算
%data=data/600*330;
[RowNum,LineNum] = size(data);
% 常量设定
LineMax = RowNum;    % 86400;
Prate = 710;        % 机组额定功率，MW
Pmax = 18;         % 储能额定功率，MW
Pmin =-Pmax;
Emax = Pmax/2;    % 储能额定容量，MWh
Mday = 3;           % 电池寿命成本，元/W
Para = [2,200,Pmax,Pmin,(0.05*Pmax),50.0,5.0,5.0,80.0,20.0,Emax,Prate,0.01*Prate,0.01];
% t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone
% t12 广东100 蒙西100 华北200
% Phold 广东0 其他0.05
% 变量初始化
Result = zeros(100,23); 
Pbat = zeros(LineMax,1);
LastAgc = 0;
LastAgcLimit = 0;
LastPbat = 0;
SOC = 50.0;
SOC0 = SOC;
Status = 99;
MoneyMax = 0;
%ParaMax = [0,0,0,0,0,0,0,0];

% 历史数据非法值过滤--默认AGC指令和机组功率始终存在（其实可以不存在-另外的情况）
for i=2:1:LineMax
    if (isnan(data(i,1))||(data(i,1)==0))
       data(i,1) = data(i-1,1);
    end
    if (isnan(data(i,2))||(data(i,2)==0))
       data(i,2) = data(i-1,2);
    end
end
Agc = data(:,3);  % 第一列为AGC指令
Pdg = data(:,1);  % 第二列为发电机出力
%data(:,4)=0;
%Pbat = data(:,4); 
%Pbat(6:LineMax) = data(1:LineMax-5,4);  % 人工延时处理

GenPower0 = Pdg(1);
Pall = Pdg(1); %储能和机组的联合功率
SocHist=zeros(LineMax,1);

% 模拟计算开始，1s一次计算，1s一次调节
for i=1:1:LineMax
    Tline = i;
    if i==10950          
        test=0;
    end
    % 数据更新
    Pbat(i) = LastPbat;
    Pall = Pdg(i)+Pbat(i);
    if (agcSet==0)
        LastPbat = Pbat(i);
    else
        %[LastPbat,Status] = BatAgcMethodMX(Agc(i),Pdg(i),Pall,SOC,0);            % AGC算法，蒙西
        [LastPbat,Status] = BatAgcMethod2(Agc(i),Pdg(i),Pall,SOC,0);            % AGC算法，华北、山西
        %[LastPbat,Status] = BatAgcMethodGD(Agc(i),Pdg(i),Pall,SOC,0);            % AGC算法，广东
    end
    
    % 总数据更新
    SocHist(i)= SOC;
    SOC = SOC - LastPbat/3600/Emax*100;
    SOC = min(SOC,100);  
    SOC = max(0,SOC);    
end

% 计算收益
%[Mall,M0all,Days] = CalMoneyMX(Agc,Pdg,Pbat);
%[Mall,M0all,Days] = CalMoneyHB(Agc,Pdg,Pbat);
%[Mall,M0all,Days] = CalMoneySX(Agc,Pdg,Pbat);
%[Mall,M0all,Days] = CalMoneyGD(Agc,Pdg,Pbat);
[Mall,M0all,Days] = CalMoneyHZ(Agc,Pdg,Pbat);

data(:,5) = Pbat;
data(:,4) = Pbat+Pdg;

AAA=Rall';
[Mall_a,M0all_a,Days_a] = CalMoneyHZ(Agc,Pdg,zeros(43200,1));
AAA2=Rall';
% [RowNum,LineNum] = size(Result);
% n = 0;
% Kp = 0;
% for i=1:1:RowNum
%   if (Result(i,15)>0.01)
%     Kp = Kp+Result(i,15);
%     n = n+1;
%   end
% end
% Kp = Kp/n;
figure(10)
subplot(2,1,1);
timeline = LineMax;
plot(data(1:timeline,1),'b');hold on;
plot(data(1:timeline,4),'g');hold on;
plot(data(1:timeline,3),'r');hold off;
legend('机组','联合','Agc')
%plot(data)
M=(0:3600:timeline);
T=(0:1:(timeline/3600));
set(gca,'xtick',M);
set(gca,'xticklabel',T);
xlabel('time / h');
ylabel('power / MW');
subplot(2,1,2);
plot(SocHist(1:timeline));
set(gca,'xtick',M);
set(gca,'xticklabel',T);
xlabel('time / h');
ylabel('SOC / %');
figure(11)
timeline = LineMax;
plot(data(1:timeline,1),'b');hold on;
plot(data(1:timeline,3),'r');hold off;
legend('机组','Agc')
%plot(data)
M=(0:3600:timeline);
T=(0:1:(timeline/3600));
set(gca,'xtick',M);
set(gca,'xticklabel',T);
xlabel('time / h');
ylabel('power / MW');