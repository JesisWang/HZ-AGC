%========补全云平台数据的程序=======%
clear
load('HZdata12h')
N=fieldnames(SDPCSdata1228);% 输出结构体下的域名
N=length(N);% 计算个数
for i=1:9
    for j=1:4
        data2=0;
        if (i==6 && j==1)
            
        else
            data=['SDPCSdata1228.A',num2str(i),'00',num2str(j)];
            data1=eval(data);
            n=1;
            N=length(data1(:,1));
            for m=1:N
                if m~=N
                    data2(n:n+data1(m,2),1)=logspace(data1(m,1),data1(m+1,1),data1(m,2)+1);
                    n=n+data1(m,2);
                else
                    data2(n:n+data1(m,2),1)=data1(m,1);
                    n=n+data1(m,2);
                end
            end
            name=['SDPCSdata1228deal.A',num2str(i),'00',num2str(j)];
            eval( [name, '=data2;']);% 将字符串转换为变量名，并且对其赋值data2，即不加引号的是需要转换字符串，加引号的是不需要转换部分
        end
        data3(:,(i-1)*4+j)=data2;
    end
end
for i=1:86400
    data3(i,37)=sum(data3(i,1:36));
end
SDPCSdata1228deal.all=data3;
% 检查好在保存
% save('SHDPCSdata1228deal.mat','SDPCSdata1228deal.all')
%==========以上为上都PCS数据不全法，其他的在此基础上增改========%
% % % data1;
% % % j=1;
% % % for i=1:length(data1(:,1))
% % %     for m=1:length(data1(:,1))
% % %         data2(j:j+data1(j,2),1)=data1(i,1);
% % %         j=j+data1(m,2);
% % %     end
% % % end
% for i=1:length(data(:,1))
%     data1(j:j+data(i,2),1)=data(i,3);
%     data2(j:j+data(i,2),1)=data(i,1);
%     j=j+data(i,2);
% end
% data1(1)=[];
% data2(1)=[];
% sum(data1(data1>0))
% sum(data1(data1<0))
% sum(data1>0)
% for i=1:86400
%     if data1(i)>0
%         data1(i)=data1(i)-3.4941;
%     end
% end
% data3(1)=data2(1);
% for i=2:86400
%     data3(i,1)=-data1(i-1)*1/3600/9*100+data2(i-1);
% end