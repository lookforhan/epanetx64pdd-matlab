classdef unitTest_epanetx64pdd < matlab.unittest.TestCase
    %unitTest_epanetx64pdd ��epanetx64pdd�ĵ�Ԫ�����ļ�
    %   �˴���ʾ��ϸ˵��
    % t = unitTest_epanetx64pdd 
    % t.run
    
    properties
        obj
    end
    
    methods(TestClassSetup) % 
        function creat_epanetx64pdd(testCase)
            net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\brenchmarks\exeter-benchmarks\BAK\BAK.inp';
            damage_net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\epanetx64pdd-matlab-toolkit\damage_BAK_net1.inp';
            testCase.obj = epanetx64pdd();
            testCase.obj.Net_inpfile = net;
            testCase.obj.Damage_scenario_net = damage_net;
        end
    end
    methods(Test)
        function testlib(testCase) % ����dll pass
            testCase.obj.loadLibrary;
            test  = libisloaded('EPANETx64PDD');
            testCase.verifyTrue(test) % �Ƿ�Ϊ��
        end
        function test_unloadlib(testCase) % ж��dll pass
            testCase.obj.unloadLibrary
            test = libisloaded('EPANETx64PDD');
            testCase.verifyFalse(test);
        end
        function test_addFunctionPath(testCase) % pass
            test = which('EPA_F.mat');
            testCase.verifyNotEmpty(test);
        end
        function test_read_net(testCase) % pass
            testCase.obj.loadLibrary;
            testCase.obj.read_net;
            test1 = iscell(testCase.obj.Net_data);
            test2 = (numel(testCase.obj.Net_data)==28*2);
            test = all([test1,test2]);
            testCase.verifyTrue(test);
        end
        function test_getNoedNum(testCase) % pass
            testCase.obj.enOpen(testCase.obj.Net_inpfile)
            nodeCount = testCase.obj.getNodeNum();
            testCase.verifyEqual(nodeCount,int32(35));
        end
        function test_enOpen(testCase) % pass
            testCase.obj.enOpen(testCase.obj.Damage_scenario_net);
%             testCase.verifyEqual(,0);
        end
        function test_enClose(testCase) % pass
            testCase.obj.enOpen(testCase.obj.Damage_scenario_net);
            testCase.obj.enClose();
        end
        function test_addPddParamter(testCase) % pass
            
        end
    end
    methods(TestClassTeardown) % 
    end
    methods(TestMethodSetup) % 
    end
    methods(TestMethodTeardown) % 
    end
end

