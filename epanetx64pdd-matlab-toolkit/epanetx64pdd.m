classdef epanetx64pdd < handle
    %epanetx64pdd  һ��epanetx64pdd.dll��MATLAB��
    %   �˴���ʾ��ϸ˵��
    % net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\brenchmarks\exeter-benchmarks\BAK\BAK.inp';
    % obj = epanetx64pdd(net)
    properties
        Net_inpfile
        Net_data
        Root
        EPA_inp_format
        err
    end
    properties (SetAccess = private, GetAccess = private, Dependent)
        Temp_rpt
        Temp_dll_inp
        
        Check_net_inp
    end
    properties
        lib_name = 'EPANETx64PDD';
        h_name = 'toolkit.h';
    end
    methods
        function obj = epanetx64pdd(varargin)
            %epanetx64pdd ��������ʵ��
            %   �˴���ʾ��ϸ˵��
            % DLL
            obj.Root = [fileparts(which('epanetx64pdd.m')),'\'];%��Ŀ¼
            obj.Net_inpfile = varargin{1};
            obj.loadLibrary;
            obj.addFunctionPath;
            obj.EPA_format;
%             obj.read_net
        end        
    end
    methods
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
    methods
        function loadLibrary(obj) % ���� epanetx64pdd.dll
            if libisloaded(obj.lib_name)
            else
                loadlibrary([obj.Root,'library\',obj.lib_name],[obj.Root,'library\',obj.h_name]);
            end
         end
        function unloadLibrary(obj) % ж�� epanetx64pdd.dll
            if libisloaded(obj.lib_name)
                unloadlibrary(obj.lib_name);
            end
        end
        function addFunctionPath(obj)
            addpath([obj.Root,'matlab-toolkit-functions\','readNet\'])
            
        end
        function EPA_format(obj)
            obj.EPA_inp_format = load_epa_format();
        end
        function read_net(obj)
            obj.err.openNet=calllib(obj.lib_name,'ENopen',obj.Net_inpfile,obj.Temp_rpt,'');% �򿪹��������ļ�
            if obj.err.openNet==0%�ж�Read_File��ȡinput_net_filename�ļ������Ƿ�ɹ�
                obj.err.saveinpfile = calllib(obj.lib_name,'ENsaveinpfile',obj.Temp_dll_inp);
                obj.err.closeNet = calllib(obj.lib_name,'ENclose'); %�رռ���
                [obj.err.readNet,obj.Net_data]=Read_File_dll_inp4(obj.Temp_dll_inp,obj.EPA_inp_format);%��ȡˮ��ģ��inp�ļ������ݣ�
                if obj.err.readNet ~=0
                    disp([funcName,'��ȡ����',obj.Temp_dll_inp])
                    keyboard
                end
            else
                obj.err.closeNet = calllib(obj.lib_name,'ENclose'); %�رռ���
                obj.Net_data=0;
                return
            end
        end
    end
end

