function h=argmin_h(T,mu,lambda,g_f,l_f,w0,mu1,h_f)  %%% 加入mu1,上一帧h_f

%      lhd= T ./  (lambda*w0 .^2 + mu*T); % left hand
     
     %%% 改变
     lhd= T ./  (lambda*w0 .^2 + mu*T + mu1);
     hd2= 1 ./  (lambda*w0 .^2 + mu*T + mu1);
     %%%
  
     X=ifft2(mu*g_f + l_f);
     %%%
     X1 = ifft2(h_f);
     %%%
%      h=gpuArray(zeros(size(X)));
     % compute T for each channel

%      h=bsxfun(@times,lhd,X);
     
     %%%
     h = bsxfun(@times,lhd,X) + bsxfun(@times,hd2,X1);
     %%%

end