classdef epanetx64pdd < handle
    %epanetx64pdd  一个epanetx64pdd.dll的MATLAB类
    %   此处显示详细说明
    % net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\brenchmarks\exeter-benchmarks\BAK\BAK.inp';
    % obj = epanetx64pdd()
    % obj.Net_inpfile = net;
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
        function creat_damage_net(obj,damage_txt,damage_net)
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
        function get_damage_info(obj)
            [ obj.err.readDamageInfo,damage_data ] = read_damage_info( obj.Damage_scenario_txt );% from 'damageNet\'
            [obj.err.changeDamgeInfo,obj.Damage_info] = ND_Execut_deterministic1(obj.Net_data,damage_data);% from 'damageNet\'
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
    end
    methods % pdd.DLL only functions
        function addPddParamter_Wagner_Hminimum(obj,node_index,Hminimum)
            obj.err.addPddParamter_Wagner_Hminimum = calllib (obj.lib_name,'ENsetnodevalue',node_index,120,Hminimum);
        end
        function addPddParamter_Wagner_Hcritical(obj,node_index,Hcritical)
            obj.err.addPddParamter_Wagner_Hminimum = calllib (obj.lib_name,'ENsetnodevalue',node_index,120,Hcritical);
        end
    end
end

