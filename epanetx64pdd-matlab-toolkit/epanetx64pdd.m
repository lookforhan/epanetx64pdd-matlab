classdef epanetx64pdd < handle
    %epanetx64pdd  一个epanetx64pdd.dll的MATLAB类
    %   此处显示详细说明
    % net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\epanetx64pdd-matlab-toolkit\BAK.inp';
    % obj = epanetx64pdd()
    % obj.Net_inpfile = net;
    % obj.read_net
    % damage_net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\epanetx64pdd-matlab-toolkit\damage_BAK_net.inp';
    % obj = epanetx64pdd()
    % obj.Damage_scenario_net = damage_net;
    % obj.read_PDD_parameter('BAK_PDD_parameter.txt')
    % 
    % obj.create_PDD_net
    properties
        Net_inpfile
        Net_data
        Root
        EPA_inp_format
        err
    end
    properties % damage net
        Damage_scenario_txt
        Damage_scenario_net
        Damage_info
        Damage_net_data
        Pipe_relative
    end
    properties % PDD
        PDD_net % 输出文件
        PDD_parameter % 参数
        PDD_parameter_file
    end
    properties (Dependent) %(SetAccess = private, GetAccess = private, Dependent)
        Temp_rpt
        Temp_dll_inp
        Check_net_inp
    end
    properties
        lib_name = 'EPANETx64PDD';
        h_name = 'toolkit.h';
    end
    methods
        function obj = epanetx64pdd()
            %epanetx64pdd 构造此类的实例
            %   此处显示详细说明
            % DLL
            obj.Root = [fileparts(which('epanetx64pdd.m')),'\'];%根目录
            obj.loadLibrary;
            obj.addFunctionPath;
            obj.EPA_format;
            %             obj.read_net
        end
    end
    methods % get functions
        function Check_net_inp = get.Check_net_inp(obj)
            [~,~,fileType] = fileparts(obj.Net_inpfile);
            if strcmpi(fileType,'.inp')
                Check_net_inp = 0;
            else
                Check_net_inp = 1;
            end
        end
        function Temp_dll_inp = get.Temp_dll_inp(obj)
            [filePath,fileName,ext] = fileparts(obj.Net_inpfile);
            Temp_dll_inp = fullfile(filePath,['temp-',fileName,ext]);
        end
        function Temp_rpt = get.Temp_rpt(obj)
            [filePath,fileName,~] = fileparts(obj.Net_inpfile);
            Temp_rpt = fullfile(filePath,[fileName,'.rpt']);
        end
    end
    methods % functions
        function addFunctionPath(obj)
            addpath([obj.Root,'matlab-toolkit-functions\','readNet\'])
            
        end
        function EPA_format(obj)
            obj.EPA_inp_format = load_epa_format();
        end
        function read_net(obj)
            obj.err.openNet=calllib(obj.lib_name,'ENopen',obj.Net_inpfile,obj.Temp_rpt,'');% 打开管网数据文件
            if obj.err.openNet==0%判断Read_File读取input_net_filename文件数据是否成功
                obj.err.saveinpfile = calllib(obj.lib_name,'ENsaveinpfile',obj.Temp_dll_inp);
                obj.err.closeNet = calllib(obj.lib_name,'ENclose'); %关闭计算
                [obj.err.readNet,obj.Net_data]=Read_File_dll_inp4(obj.Temp_dll_inp,obj.EPA_inp_format);%读取水力模型inp文件的数据；
                if obj.err.readNet ~=0
                    disp([funcName,'读取错误：',obj.Temp_dll_inp])
                    keyboard
                end
            else
                obj.err.closeNet = calllib(obj.lib_name,'ENclose'); %关闭计算
                obj.Net_data=0;
                return
            end
        end
        function create_damage_net(obj,damage_txt,damage_net)
            addpath([obj.Root,'\matlab-toolkit-functions\damageNet\'])
            obj.Damage_scenario_txt = damage_txt;
            obj.Damage_scenario_net = damage_net;
            obj.get_damage_info;
            [obj.err.ND_j,damage_node_data]=ND_Junction5(obj.Net_data,obj.Damage_info);%生成管线中的破坏点数据
            [obj.err.ND_p,pipe_new_add,obj.Pipe_relative]=ND_Pipe5(damage_node_data,obj.Damage_info,obj.Net_data{5,2});%生成管线破坏点的邻接管段数据
            [obj.err.ND_g,all_add_node_data,pipe_new_add]=ND_P_Leak4_GIRAFFE2_R(damage_node_data,obj.Damage_info,pipe_new_add);
            pipe_data=obj.Net_data{5,2}; %cell,初始管网中管线的属性信息：管线编号(字符串),起点编号(字符串),终点编号(字符串),管线长度(m),管段直径(mm),沿程水头损失摩阻系数,局部水头损失摩阻系数;
            for i = 1:numel(obj.Damage_info{1,1})
                pipe_data{obj.Damage_info{1,1}(i),8}='Closed;' ;
            end
            mid_data=(struct2cell(pipe_new_add))';
            all_pipe_data=[pipe_data;mid_data];%cell,初始管网中管线+破坏管线的属性信息：管线编号(字符串),起点编号(字符串),终点编号(字符串),管线长度(m),管段直径(mm),沿程水头损失摩阻系数,局部水头损失摩阻系数;
            all_node_coordinate=[obj.Net_data{23,2};all_add_node_data(:,1:3)]; %所有节点坐标（包括水源、水池、用户节点）；
            [~,outdata]=ND_Out_no_delete(all_pipe_data,all_add_node_data,all_node_coordinate,obj.Net_data);
            obj.Damage_net_data = outdata; % 输出的数据格式 暂时，需要进一步优化
            obj.err.write=Write_Inpfile5(obj.Net_data,obj.EPA_inp_format,outdata,damage_net);% 写入新管网inp
        end
        function create_PDD_net(obj)
            [path,name,ext]=fileparts(which(obj.Damage_scenario_net));
            obj.PDD_net = [path,'\',name,'PDD',ext];
            obj.enOpen(obj.Damage_scenario_net);
            nodeCount = numel(obj.PDD_parameter.node_id);
            for i = 1:nodeCount
                [~,index] = epanetx64pdd.ENgetnodeindex(obj.PDD_parameter.node_id{i},obj.lib_name);
                obj.addPddParamter_Wagner_Hcritical(index,20);
                obj.addPddParamter_Wagner_Hminimum(index,0);
            end
            obj.enSaveinpfile(obj.PDD_net);
            obj.enClose();
        end
        function get_damage_info(obj)
            [ obj.err.readDamageInfo,damage_data ] = read_damage_info( obj.Damage_scenario_txt );% from 'damageNet\'
            [obj.err.changeDamgeInfo,obj.Damage_info] = ND_Execut_deterministic1(obj.Net_data,damage_data);% from 'damageNet\'
        end
        function clearUp(obj)
            if isfile(obj.Temp_dll_inp)
                delete(obj.Temp_dll_inp)
            end
            if isfile(obj.Temp_rpt)
                delete(obj.Temp_rpt)
            end
        end
        function read_PDD_parameter(obj,file)
            obj.PDD_parameter_file = file;
            fid = fopen(file,'r');
            data = textscan(fid,'%s%f%f','delimiter','|','headerlines',1);
            fclose(fid);
            obj.PDD_parameter.node_id = strtrim(data{1});
            obj.PDD_parameter.Hcritical = data{2};
            obj.PDD_parameter.Hminimum = data{3};
        end
    end
    methods % DLL functions
        function loadLibrary(obj) % 加载 epanetx64pdd.dll
            if libisloaded(obj.lib_name)
            else
                loadlibrary([obj.Root,'library\',obj.lib_name],[obj.Root,'library\',obj.h_name]);
            end
        end
        function unloadLibrary(obj) % 卸载 epanetx64pdd.dll
            if libisloaded(obj.lib_name)
                unloadlibrary(obj.lib_name);
            end
        end
        function enOpen(obj,inpfile)
            [filepath,filename,~] = fileparts(inpfile);
            rptfile = [filepath,filename,'.rpt'];
            libName = obj.lib_name;
            epanetx64pdd.ENopen(inpfile,rptfile,'',libName)
        end
        function enClose(obj)
            [~] = epanetx64pdd.ENclose(obj.lib_name);
        end
        function enSaveinpfile(obj,inpfile)
            obj.err.enSaveinpfile = calllib(obj.lib_name,'ENsaveinpfile',inpfile);
        end
        function nodeCount = getNodeNum(obj) % user's node count
            libName = obj.lib_name;
            [~, count1] = epanetx64pdd .ENgetcount(0,libName);
            [~, count2] = epanetx64pdd .ENgetcount(1,libName);
            nodeCount = count1 -count2;
        end
    end
    methods % pdd.DLL only functions
        function addPddParamter_Wagner_Hminimum(obj,node_index,Hminimum)
            obj.err.addPddParamter_Wagner_Hminimum = calllib (obj.lib_name,'ENsetnodevalue',node_index,120,Hminimum);
        end
        function addPddParamter_Wagner_Hcritical(obj,node_index,Hcritical)
            obj.err.addPddParamter_Wagner_Hminimum = calllib (obj.lib_name,'ENsetnodevalue',node_index,121,Hcritical);
        end
    end
    methods(Static) % 封装epanet的各个函数命令
        function [Errcode] = ENwriteline (line,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENwriteline',line);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENaddpattern(patid,LibEPANET)
            Errcode=calllib(LibEPANET,'ENaddpattern',patid);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENclose(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENclose');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENcloseH(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENcloseH');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetnodevalue(index, paramcode,LibEPANET)
            value=single(0);
            %p=libpointer('singlePtr',value);
            index=int32(index);
            paramcode=int32(paramcode);
            [Errcode, value]=calllib(LibEPANET,'ENgetnodevalue',index, paramcode,value);
            if Errcode==240
                value=NaN;
            end
        end
        function [Errcode, value] = ENgetbasedemand(index,numdemands,LibEPANET)
            %epanet20100
            [Errcode,value]=calllib(LibEPANET,'ENgetbasedemand',index,numdemands,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetnumdemands(index,LibEPANET)
            %epanet20100
            [Errcode,value]=calllib(LibEPANET,'ENgetnumdemands',index,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetdemandpattern(index,numdemands,LibEPANET)
            %epanet20100
            [Errcode,value]=calllib(LibEPANET,'ENgetdemandpattern',index,numdemands,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetstatistic(code,LibEPANET)
            %epanet20100
            [Errcode,value]=calllib(LibEPANET,'ENgetstatistic',code,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENcloseQ(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENcloseQ');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        
        function [Errcode, ctype,lindex,setting,nindex,level] = ENgetcontrol(cindex,LibEPANET)
            [Errcode, ctype,lindex,setting,nindex,level]=calllib(LibEPANET,'ENgetcontrol',cindex,0,0,0,0,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, count] = ENgetcount(countcode,LibEPANET)
            [Errcode,count]=calllib(LibEPANET,'ENgetcount',countcode,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
%         function [errmsg, e] = ENgeterror(Errcode,LibEPANET)
%             if Errcode
%                 errmsg = char(32*ones(1,79));
%                 [e,errmsg] = calllib(LibEPANET,'ENgeterror',Errcode,errmsg,79);
%             else
%                 e=0;
%                 errmsg='';
%             end
%         end
        function [Errcode,flowunitsindex] = ENgetflowunits(LibEPANET)
            [Errcode, flowunitsindex]=calllib(LibEPANET,'ENgetflowunits',0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,id] = ENgetlinkid(index,LibEPANET)
            id=char(32*ones(1,31));
            [Errcode,id]=calllib(LibEPANET,'ENgetlinkid',index,id);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,index] = ENgetlinkindex(id,LibEPANET)
            [Errcode,~,index]=calllib(LibEPANET,'ENgetlinkindex',id,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,from,to] = ENgetlinknodes(index,LibEPANET)
            [Errcode,from,to]=calllib(LibEPANET,'ENgetlinknodes',index,0,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, type] = ENgetlinktype(index,LibEPANET)
            [Errcode,type]=calllib(LibEPANET,'ENgetlinktype',index,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetlinkvalue(index, paramcode,LibEPANET)
            [Errcode,value]=calllib(LibEPANET,'ENgetlinkvalue',index, paramcode, 0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,id] = ENgetnodeid(index,LibEPANET)
            id=char(32*ones(1,31));
            [Errcode,id]=calllib(LibEPANET,'ENgetnodeid',index,id);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,index] = ENgetnodeindex(id,LibEPANET)
            [Errcode, ~, index]=calllib(LibEPANET,'ENgetnodeindex',id,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, type] = ENgetnodetype(index,LibEPANET)
            [Errcode,type]=calllib(LibEPANET,'ENgetnodetype',index,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetoption(optioncode,LibEPANET)
            [Errcode,value]=calllib(LibEPANET,'ENgetoption',optioncode,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, id] = ENgetpatternid(index,LibEPANET)
            id=char(32*ones(1,31));
            [Errcode,id]=calllib(LibEPANET,'ENgetpatternid',index,id);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, id] = ENgetcurveid(index,LibEPANET)
            %New version dev2.1
            id=char(32*ones(1,31));
            [Errcode,id]=calllib(LibEPANET,'ENgetcurveid',index,id);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, index] = ENgetpatternindex(id,LibEPANET)
            [Errcode,~, index]=calllib(LibEPANET,'ENgetpatternindex',id,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, len] = ENgetpatternlen(index,LibEPANET)
            [Errcode,len]=calllib(LibEPANET,'ENgetpatternlen',index,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetpatternvalue(index, period,LibEPANET)
            [Errcode,value]=calllib(LibEPANET,'ENgetpatternvalue',index, period, 0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,qualcode,tracenode] = ENgetqualtype(LibEPANET)
            [Errcode,qualcode,tracenode]=calllib(LibEPANET,'ENgetqualtype',0,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, timevalue] = ENgettimeparam(paramcode,LibEPANET)
            [Errcode,timevalue]=calllib(LibEPANET,'ENgettimeparam',paramcode,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, LibEPANET] = ENgetversion(LibEPANET)
            [Errcode,LibEPANET]=calllib(LibEPANET,'ENgetversion',0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENinitH(flag,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENinitH',flag);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENinitQ(saveflag,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENinitQ',saveflag);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function ENMatlabCleanup(LibEPANET)
            % Load library
            if libisloaded(LibEPANET)
                unloadlibrary(LibEPANET);
            else
                errstring =['Library ', LibEPANET, '.dll was not loaded.'];
                disp(errstring);
            end
        end
        function ENLoadLibrary(LibEPANETpath,LibEPANET)
            if ~libisloaded(LibEPANET)
                loadlibrary([LibEPANETpath,LibEPANET],[LibEPANETpath,LibEPANET,'.h'])
            end
            if libisloaded(LibEPANET)
                LibEPANETString = 'EPANET loaded sucessfuly.';
                disp(LibEPANETString);
            else
                warning('There was an error loading the EPANET library (DLL).')
            end
        end
        function [Errcode, tstep] = ENnextH(LibEPANET)
            [Errcode,tstep]=calllib(LibEPANET,'ENnextH',int32(0));
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, tstep] = ENnextQ(LibEPANET)
            [Errcode,tstep]=calllib(LibEPANET,'ENnextQ',int32(0));
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
            tstep = double(tstep);
        end
        function [Errcode] = ENopen(inpname,repname,binname,LibEPANET) %DE
            Errcode=calllib(LibEPANET,'ENopen',inpname,repname,binname);
            if Errcode
                [~,errmsg] = calllib(LibEPANET,'ENgeterror',Errcode,char(32*ones(1,79)),79);
                warning(errmsg);
            end
        end
        function [Errcode] = ENopenH(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENopenH');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENopenQ(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENopenQ');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENreport(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENreport');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENresetreport(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENresetreport');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, t] = ENrunH(LibEPANET)
            [Errcode,t]=calllib(LibEPANET,'ENrunH',int32(0));
            t = double(t);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, t] = ENrunQ(LibEPANET)
            t=int32(0);
            [Errcode,t]=calllib(LibEPANET,'ENrunQ',t);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsaveH(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsaveH');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsavehydfile(fname,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsavehydfile',fname);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsaveinpfile(inpname,LibEPANET)
            Errcode=calllib(LibEPANET,'ENsaveinpfile',inpname);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetcontrol(cindex,ctype,lindex,setting,nindex,level,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetcontrol',cindex,ctype,lindex,setting,nindex,level);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetlinkvalue(index, paramcode, value,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetlinkvalue',index, paramcode, value);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetnodevalue(index, paramcode, value,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetnodevalue',index, paramcode, value);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetoption(optioncode,value,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetoption',optioncode,value);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetpattern(index, factors, nfactors,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetpattern',index,factors,nfactors);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetpatternvalue(index, period, value,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetpatternvalue',index, period, value);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetqualtype(qualcode,chemname,chemunits,tracenode,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetqualtype',qualcode,chemname,chemunits,tracenode);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetreport(command,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetreport',command);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetstatusreport(statuslevel,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsetstatusreport',statuslevel);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsettimeparam(paramcode, timevalue,LibEPANET)
            paramcode=int32(paramcode);
            timevalue=int32(timevalue);
            [Errcode]=calllib(LibEPANET,'ENsettimeparam',paramcode,timevalue);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsolveH(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsolveH');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsolveQ(LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENsolveQ');
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, tleft] = ENstepQ(LibEPANET)
            tleft=int32(0);
            [Errcode,tleft]=calllib(LibEPANET,'ENstepQ',tleft);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
            tleft=double(tleft);
        end
        function [Errcode] = ENusehydfile(hydfname,LibEPANET)
            [Errcode]=calllib(LibEPANET,'ENusehydfile',hydfname);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetcurve(index, x, y, nfactors,LibEPANET)
            % New version dev2.1
            [Errcode]=calllib(LibEPANET,'ENsetcurve',index,x,y,nfactors);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, x, y] = ENgetcurvevalue(index, period,LibEPANET)
            % New version dev2.1
            [Errcode,x, y]=calllib(LibEPANET,'ENgetcurvevalue',index, period, 0, 0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, x, y] = ENsetcurvevalue(index, pnt, x, y, LibEPANET)
            % New version dev2.1
            % index  = curve index
            % pnt    = curve's point number
            % x      = curve x value
            % y      = curve y value
            % sets x,y point for a specific point and curve
            [Errcode]=calllib(LibEPANET,'ENsetcurvevalue',index, pnt, x, y);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, index] = ENgetcurveindex(id,LibEPANET)
            % New version dev2.1
            [Errcode,~, index]=calllib(LibEPANET,'ENgetcurveindex',id,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENaddcurve(cid,LibEPANET)
            % New version dev2.1
            Errcode=calllib(LibEPANET,'ENaddcurve',cid);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, ids, nvalue, xvalue, yvalue] = ENgetcurve(value,LibEPANET)
            [~,~,nvalue,~,~]=calllib(LibEPANET,'ENgetcurve',value,char(32*ones(1,31)),0,0,0);
            [Errcode,ids,~, xvalue, yvalue]=calllib(LibEPANET,'ENgetcurve',value,char(32*ones(1,31)),0,zeros(1,nvalue),zeros(1,nvalue));
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, len] = ENgetcurvelen(index,LibEPANET)
            % New version dev2.1
            [Errcode,len]=calllib(LibEPANET,'ENgetcurvelen',index,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetheadcurveindex(pumpindex,LibEPANET)
            % New version dev2.1
            [Errcode,value]=calllib(LibEPANET,'ENgetheadcurveindex',pumpindex,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetpumptype(pumpindex,LibEPANET)
            % New version dev2.1
            [Errcode,value]=calllib(LibEPANET,'ENgetpumptype',pumpindex,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, value] = ENgetaveragepatternvalue(index,LibEPANET)
            % return  average pattern value
            % New version dev2.1
            [Errcode,value]=calllib(LibEPANET,'ENgetaveragepatternvalue',index,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode, x, y] = ENgetcoord(index,LibEPANET)
            % New version dev2.1
            [Errcode,x,y]=calllib(LibEPANET,'ENgetcoord',index,0,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetcoord(index,x,y,LibEPANET)
            % New version dev2.1
            [Errcode]=calllib(LibEPANET,'ENsetcoord',index,x,y);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode] = ENsetbasedemand(index, demandIdx, value, LibEPANET)
            % New version dev2.1
            [Errcode]=calllib(LibEPANET,'ENsetbasedemand',index, demandIdx, value);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
        function [Errcode,qualcode,chemname,chemunits,tracenode] = ENgetqualinfo(LibEPANET)
            chm=char(32*ones(1,31));
            [Errcode,qualcode,chemname,chemunits,tracenode]=calllib(LibEPANET,'ENgetqualinfo',0,chm,chm,0);
            if Errcode
                ENgeterror(Errcode,LibEPANET);
            end
        end
    end
end

        function [errmsg, e] = ENgeterror(Errcode,LibEPANET)
            if Errcode
                errmsg = char(32*ones(1,79));
                [e,errmsg] = calllib(LibEPANET,'ENgeterror',Errcode,errmsg,79);
            else
                e=0;
                errmsg='';
            end
        end
