classdef repair_crews < handle
    %repair_crews 此处显示有关此类的摘要
    %   此处显示详细说明
    %   t = repair_crews();
    
    properties % 基准时间
        Isolation_time % 队伍检查和隔离管段的标准时间矩阵
        Repair_time % 队伍替换和修复管段的标准时间矩阵
        Displacement_time % 队伍在破坏管段位置之间移动的标准时间矩阵
    end
    properties
        start_time % 工作开始时间
    end
    properties % 工作效率
        Isolationt_efficiency % 隔离效率
        Repair_efficiency % 替换效率
        Displacement_efficiency % 移动效率
    end
    properties % 状态
        Status 
    end
    
    methods
        function obj = repair_crews()
            %repair_crews 构造此类的实例
            %   此处显示详细说明
            
        end
        
      
    end
end

