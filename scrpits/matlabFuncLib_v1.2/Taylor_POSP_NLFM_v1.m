%{
    Function:  Taylor_POSP_NLFM_v1
    Author: Zhang Xifeng
    Description: ????????????????????NLFM???
    Input:  ????????
    Output: ????????
    Date: 2024/10/31
%}
function [sig, ft] = Taylor_POSP_NLFM_v1(Br, Tp, Fs, n, p)
    %????Taylor????POSPNLFM???????
    %   Br????
    %   Tp???
    %   Fs??????
    %   n??????????
    %   p????????
    %   sig???
    %   ft?????

    N = ceil(Tp * Fs);
    % N = ceil(Tp*Fs/2)*2;
    t = ((0:N - 1) - N / 2) / Fs;
    f = ((0:N - 1) - N / 2) / N * Fs;
    Tf = zeros(1, N);
    [~, Fm] = taylorwin(N, p, n);

    for ii = 1:p - 1
        Pf = Fm(ii) * Tp / (pi * ii) * sin(2 * pi * ii / Br * f);
        Tf = Tf + Pf;
    end

    Tf = Tp / Br * f + Tf;

    % Tf 可能不严格单调，排序后再插值并允许外推，避免越界
    [Tf_sorted, sortIdx] = sort(Tf);
    f_sorted = f(sortIdx);
    ft = interp1(Tf_sorted, f_sorted, t, 'linear', 'extrap'); %+2.36e6

    phase = 2 * pi * cumtrapz(t, ft);
    sig = exp(1j * phase);

end
