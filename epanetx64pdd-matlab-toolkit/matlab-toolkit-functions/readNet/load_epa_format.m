function [outputArg] = load_epa_format()
%load_epa_format ��������
%   �˴���ʾ��ϸ˵��

    load('EPA_F.mat','EPA_format')

outputArg = EPA_format;

end

