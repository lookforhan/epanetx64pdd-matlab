classdef unitTest_epanetx64pdd < matlab.unittest.TestCase
    %unitTest_epanetx64pdd 对epanetx64pdd的单元测试文件
    %   此处显示详细说明
    % t = unitTest_epanetx64pdd 
    % t.run
    
    properties
        obj
    end
    
    methods(TestClassSetup) % 
        function creat_epanetx64pdd(testCase)
            net = 'C:\Users\hc042\Documents\GitHub\epanetx64pdd-matlab\brenchmarks\exeter-benchmarks\BAK\BAK.inp';
            testCase.obj = epanetx64pdd(net);
        end
    end
    methods(Test)
        function testlib(testCase) % 加载dll pass
            testCase.obj.loadLibrary;
            test  = libisloaded('EPANETx64PDD');
            testCase.verifyTrue(test) % 是否为真
        end
        function test_unloadlib(testCase) % 卸载dll pass
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
            test2 = (numel(testCase.obj.Net_data)==27*2);
            test = all([test1,test2]);
            testCase.verifyTrue(test);
        end
    end
    methods(TestClassTeardown) % 
    end
    methods(TestMethodSetup) % 
    end
    methods(TestMethodTeardown) % 
    end
end

