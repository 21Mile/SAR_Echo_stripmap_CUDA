
function data_RD=RDA_imaging(pulse_s, lamda, R0, fa, fr, va, distance_r,ta)

c=3e8;
[nr, na]=size(pulse_s);
%方位向FFT
Doppler_azi=myfft(pulse_s,2);

%距离徙动矫正，频域
delta_R=lamda^2*R0*fa.^2/8/va^2;
correct_part=exp(1i*4*pi*fftshift(fr.')*delta_R/c);
pulse_correct_range=fftshift(ifft((fft(fftshift(Doppler_azi, 1),[],1).*correct_part),[],1), 1);

% figure;plot(abs(pulse_correct_range(8501,:)));
%方位向压缩
% Ka=repmat((2*va^2/lamda./(distance_r)).',1,na);
% Ha=exp(-1i*pi*repmat(fa,nr,1).^2./Ka).*(abs(fa)<Ba/2); %近似线性调频信号
% H_ta = conj(fftx(exp(-1i*4*pi./lamda.*sqrt((distance_r.').^2+(va.*ta).^2)))).*(abs(fa)<Ba/2);
H_ta = conj(myfft(exp(-1i*4*pi./lamda.*sqrt((distance_r.').^2+(va.*ta).^2)),2));
% data_RD=iftx(pulse_correct_range.*Ha);
data_RD=myifft(pulse_correct_range.*H_ta,2);
figure;imagesc(abs(data_RD))
