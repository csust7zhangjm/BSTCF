function [g_f]=ADMM_base(params,use_sz,model_xf,xf,yf,small_filter_sz,frame,w)
    
    g_f = gpuArray(single(zeros(size(xf))));
%     g_f =single(zeros(size(xf)));
    
%      %%%改的代码？？
%      if frame ==1
%          h_f = g_f;
%      else
%          h_f = h_f2;
% %          global g1
% %          g1 = h_f2;
% %      else 
% %          h_f = (h_f2 + g1)/2;
% %          g1 = h_f2;
%      end
%      %%%
    h_f = g_f;
    h_f2 = g_f;
    l_f = g_f;
    
     %%% 改变 
    mu1 = 16;
    %%% 结束
    
    mu    = 1;
    betha = 10;
    betha1 = 2;
    mumax = 10000;
    mumax1 = 100;
    i = 1;
    
    ws=w;%111
    
    T = prod(use_sz);
    S_xx = sum(conj(model_xf) .* model_xf, 3);
      if frame <=params.admm_3frame
        params.admm_iterations=16;end
    %   ADMM
    while (i <= params.admm_iterations)
        %   solve for G- please refer to the paper for more details
        B = S_xx + (T * mu);
        S_lx = sum(conj(model_xf) .* l_f, 3);
        S_hx = sum(conj(model_xf) .* h_f, 3);
        g_f = 1/(T*mu) * bsxfun(@times, yf, model_xf) - (1/mu) * l_f + h_f - ...
            (bsxfun(@rdivide,(1/(T*mu) * bsxfun(@times, model_xf, (S_xx .* yf)) - (1/mu) * bsxfun(@times, model_xf, S_lx) + bsxfun(@times, model_xf, S_hx)), B));
        
        %   solve for H
%         h = (T/(mu*T+ params.admm_lambda1))* ifft2(mu*g_f + l_f);
        h=argmin_h(T,mu,params.admm_lambda1,g_f,l_f,ws,mu1,h_f2);  %%% 加入mu1
        [sx,sy,h] = get_subwindow_no_window(h, floor(use_sz/2) , small_filter_sz);
        t = gpuArray(single(zeros(use_sz(1), use_sz(2), size(h,3))));
%         t = single(zeros(use_sz(1), use_sz(2), size(h,3)));
        t(sx,sy,:) = h;
        h_f = fft2(t);
            h_f2 = (h_f + fft2(t))/(params.admm_iterations-1);
        
        %   update L
        l_f = l_f + (mu * (g_f - h_f));
        
        %   update mu- betha = 10.
        mu = min(betha * mu, mumax);
        %mu1 = min(betha1 * mu1, mumax1);
        i = i+1;
               
    end



end