function [gK_uu, gK_uf, g_Lambda, g_Lambda2] = gpCovGrads(model, Y)

% GPCOVGRADS Sparse objective function gradients wrt Covariance functions for inducing variables.

% FGPLVM

switch model.approx
 case 'dtc'
  % Deterministic training conditional.
  if ~isfield(model, 'isSpherical') | model.isSpherical
    E = model.K_uf*Y;
    EET = E*E';
    AinvEET = model.Ainv*EET;
    AinvEETAinv = AinvEET*model.Ainv;
    gK_uu = 0.5*(model.d*(model.invK_uu-(1/model.beta)*model.Ainv) ...
                 - AinvEETAinv);
    
    AinvK_uf = model.Ainv*model.K_uf;
    gK_uf = -model.d*AinvK_uf-model.beta*(AinvEET*AinvK_uf-(model.Ainv*E*Y'));
    
    g_Lambda2 = 0.5*(model.d*((model.N-model.k)/model.beta ...
                              +sum(sum(model.Ainv.*model.K_uu))/(model.beta*model.beta))...
                     +sum(sum(AinvEETAinv.*model.K_uu))/model.beta ...
                     +(trace(AinvEET)-sum(sum(Y.*Y))));
    
    fhandle = str2func([model.betaTransform 'Transform']);
    g_Lambda2 = g_Lambda2*fhandle(model.beta, 'gradfact');
    g_Lambda = [];
  else
    gK_uu = zeros(model.k, model.k);
    gK_uf = zeros(model.k, model.N);
    g_Lambda2 = 0;
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      e = model.K_uf(:, ind)*Y(ind, i);
      Ainve = model.Ainv{i}*e;
      AinveeT = Ainve*e';      
      AinveeTAinv = Ainve*Ainve';
      gK_uu = gK_uu+0.5*((model.invK_uu-(1/model.beta)*model.Ainv{i}) ...
                         - AinveeTAinv);
      
      AinvK_uf = model.Ainv{i}*model.K_uf(:, ind);
      gK_uf(:, ind) = gK_uf(:, ind) - AinvK_uf...
          -model.beta*(AinveeT*AinvK_uf-(Ainve*Y(ind, i)'));
      
      g_Lambda2 = g_Lambda2 ...
          + 0.5*(((model.N-model.k)/model.beta ...
                  +sum(sum(model.Ainv{i}.*model.K_uu))/(model.beta*model.beta))...
                 +sum(sum(AinveeTAinv.*model.K_uu))/model.beta ...
                 +(trace(AinveeT)-sum(sum(Y(ind, i).*Y(ind, i)))));
    end
    fhandle = str2func([model.betaTransform 'Transform']);
    g_Lambda2 = g_Lambda2*fhandle(model.beta, 'gradfact');
    g_Lambda = [];
  end
 case 'fitc'
  % Fully independent training conditonal.
  if ~isfield(model, 'isSpherical') | model.isSpherical
    E = model.K_uf*model.Dinv*Y;
    EET = E*E';
    AinvE = model.Ainv*E;
    %AinvEET = model.Ainv*EET;
    diagK_fuAinvEYT = sum(model.K_uf.*(model.Ainv*E*Y'), 1)';
    AinvEETAinv = AinvE*AinvE';
    diagK_ufdAinvplusAinvEETAinvK_fu = ...
        sum(model.K_uf.*((model.d*model.Ainv+model.beta*AinvEETAinv)*model.K_uf), 1)';
    invK_uuK_uf = model.invK_uu*model.K_uf;
    if true
      invK_uuK_ufDinv = invK_uuK_uf*model.Dinv;
    else
      invK_uuK_ufDinv = model.L'\model.V;
    end
    diagYYT = sum(Y.*Y, 2);
    diagQ = -model.d*model.diagD + model.beta*diagYYT ...
            + diagK_ufdAinvplusAinvEETAinvK_fu...
            -2*model.beta*diagK_fuAinvEYT;
    gK_uu = 0.5*(model.d*(model.invK_uu ...
                 -model.Ainv/model.beta) - AinvEETAinv ...
                 + model.beta*invK_uuK_ufDinv*sparseDiag(diagQ)*invK_uuK_ufDinv');
    gK_uf = -model.beta*invK_uuK_ufDinv*sparseDiag(diagQ)*model.Dinv ...      
            -model.d*model.Ainv*model.K_uf*model.Dinv ...
            -model.beta*AinvEETAinv*model.K_uf*model.Dinv ...
            +model.beta*model.Ainv*E*Y'*model.Dinv;
    g_Lambda = (0.5*diagQ*model.beta)./(model.diagD.*model.diagD);
    g_Lambda2 = -sum(g_Lambda)/(model.beta*model.beta);
    fhandle = str2func([model.betaTransform 'Transform']);
    g_Lambda2 = g_Lambda2*fhandle(model.beta, 'gradfact');
  else
    gK_uu = zeros(model.k, model.k);
    gK_uf = zeros(model.k, model.N);
    g_Lambda = zeros(model.N, 1);
    g_Lambda2 = 0;
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      K_ufDinvK_uf = model.K_uf(:, ind)*model.Dinv{i}*model.K_uf(:, ...
                                                        ind)';
      e = model.K_uf(:, ind)*model.Dinv{i}*Y(ind, i);
      Ainve = model.Ainv{i}*e;
      AinveeTAinv = Ainve*Ainve';
      diagK_fuAinveyT = sum(model.K_uf(:, ind).*(Ainve*Y(ind,i)'), 1)';
      diagK_ufdAinvplusAinveeTAinvK_fu = ...
          sum(model.K_uf(:, ind).*((model.Ainv{i}+model.beta*AinveeTAinv)*model.K_uf(:, ...
                                                        ind)), 1)';
      invK_uuK_uf = model.invK_uu*model.K_uf(:, ind);
      invK_uuK_ufDinv = invK_uuK_uf*model.Dinv{i};
      diagyyT = Y(ind, i).*Y(ind, i);
      diagQ = -model.diagD{i} + model.beta*diagyyT ...
              + diagK_ufdAinvplusAinveeTAinvK_fu...
              -2*model.beta*diagK_fuAinveyT;
      gK_uu = gK_uu ...
              +0.5*(model.invK_uu ...
                    - model.Ainv{i}/model.beta - AinveeTAinv ...
                    + model.beta*invK_uuK_ufDinv*sparseDiag(diagQ)*invK_uuK_ufDinv');
      gK_uf(:, ind) = gK_uf(:, ind) ...
              -model.beta*invK_uuK_ufDinv*sparseDiag(diagQ)*model.Dinv{i} ...      
              -model.Ainv{i}*model.K_uf(:, ind)*model.Dinv{i} ...
              -model.beta*AinveeTAinv*model.K_uf(:, ind)*model.Dinv{i} ...
              +model.beta*Ainve*Y(ind, i)'*model.Dinv{i};
      g_Lambda(ind) = g_Lambda(ind) ...
          + 0.5*model.beta*diagQ./(model.diagD{i}.*model.diagD{i});
    end
    g_Lambda2 = g_Lambda2 - sum(g_Lambda)/(model.beta*model.beta);
    fhandle = str2func([model.betaTransform 'Transform']);
    g_Lambda2 = g_Lambda2*fhandle(model.beta, 'gradfact');
  end
 
 case 'pitc' 
  % Partially independent training conditional.
  if ~isfield(model, 'isSpherical') | model.isSpherical
    E = zeros(model.k, model.d);
    for i = 1:length(model.blockEnd)
      ind = gpBlockIndices(model, i);
      E = E + model.K_uf(:, ind)*model.Dinv{i}*Y(ind, :);
    end
    AinvE = model.Ainv*E;
    AinvEET = AinvE*E';
    AinvEETAinv = AinvEET*model.Ainv;
    for i = 1:length(model.blockEnd)
      ind = gpBlockIndices(model, i);
      K_fuAinvEYT = model.beta*model.K_uf(:, ind)'*AinvE*Y(ind, :)';
      blockQ{i} = -model.d*model.D{i} + model.beta*Y(ind, :)*Y(ind, :)' ...
          + model.K_uf(:, ind)'*(model.d*model.Ainv + model.beta*AinvEETAinv)*model.K_uf(:, ind)...
          -K_fuAinvEYT - K_fuAinvEYT';
    end
    gK_uu = model.d*model.invK_uu ...
            - model.d*model.Ainv/model.beta - AinvEETAinv;
    g_Lambda2 = 0;
    gK_ufBase = -(model.d*model.Ainv + model.beta*AinvEETAinv)*model.K_uf ...
        + model.beta*AinvE*Y';
    
    for i = 1:length(model.blockEnd)
      ind = gpBlockIndices(model, i);
      invK_uuK_ufDinv = model.invK_uu*model.K_uf(:, ind)*model.Dinv{i};
      gK_uu = gK_uu + model.beta*invK_uuK_ufDinv*blockQ{i}*invK_uuK_ufDinv';
      
      gK_uf(:, ind) = (gK_ufBase(:, ind) ...
                       -model.beta*invK_uuK_ufDinv*blockQ{i})*model.Dinv{i};
      
      
      g_Lambda{i} = 0.5*model.Dinv{i}*blockQ{i}*model.Dinv{i}*model.beta;
      g_Lambda2 = g_Lambda2 - sum(diag((g_Lambda{i})))/(model.beta*model.beta);
    end
    gK_uu = gK_uu*0.5;
    fhandle = str2func([model.betaTransform 'Transform']);
    g_Lambda2 = g_Lambda2*fhandle(model.beta, 'gradfact');
  else
    gK_uu = zeros(model.k, model.k);
    gK_uf = zeros(model.k, model.N);
    for i = 1:length(model.blockEnd)
      if i == 1
        indLen = model.blockEnd(1);
      else
        indLen = model.blockEnd(i) - model.blockEnd(i-1);
      end
      g_Lambda{i} = zeros(indLen, indLen);
    end
    g_Lambda2 = 0;
    for j = 1:model.d
      e = zeros(model.k, 1);
      for i = 1:length(model.blockEnd)
        ind = gpDataIndices(model, j, i);
        e = e + model.K_uf(:, ind)*model.Dinv{i, j}*Y(ind, j);
      end
      Ainve = model.Ainv{j}*e;
      AinveeT = Ainve*e';
      AinveeTAinv = AinveeT*model.Ainv{j};
      for i = 1:length(model.blockEnd)
        ind = gpDataIndices(model, j, i);
        K_fuAinveyT = model.beta*model.K_uf(:, ind)'*Ainve*Y(ind, j)';
        blockQ{i} = -model.D{i, j} + model.beta*Y(ind, j)*Y(ind, j)' ...
            + model.K_uf(:, ind)'*(model.Ainv{j} + model.beta*AinveeTAinv)*model.K_uf(:, ind)...
            -K_fuAinveyT - K_fuAinveyT';
      end
      gK_uu = gK_uu + model.invK_uu ...
            - model.Ainv{j}/model.beta - AinveeTAinv;
      gK_ufBase = -(model.Ainv{i} + model.beta*AinveeTAinv)*model.K_uf ...
        + model.beta*Ainve*Y(:, j)';
    
      for i = 1:length(model.blockEnd)
        ind = gpDataIndices(model, j, i);
        invK_uuK_ufDinv = model.invK_uu*model.K_uf(:, ind)*model.Dinv{i,j};
        gK_uu = gK_uu + model.beta*invK_uuK_ufDinv*blockQ{i}*invK_uuK_ufDinv';
      
        gK_uf(:, ind) = gK_uf(:, ind) + (gK_ufBase(:, ind) ...
                         -model.beta*invK_uuK_ufDinv*blockQ{i})*model.Dinv{i,j};
      
        if i == 1
          localInd = ind;
        else
          localInd = ind - (model.blockEnd(i-1));
        end
        g_Lambda{i}(localInd, localInd) = g_Lambda{i}(localInd, localInd) ...
            + 0.5*model.Dinv{i,j}*blockQ{i}*model.Dinv{i,j}*model.beta;
      end
    end
    for i = 1:length(model.blockEnd)
      g_Lambda2 = g_Lambda2 - sum(diag((g_Lambda{i})))/(model.beta*model.beta);
    end
    gK_uu = gK_uu*0.5;
    fhandle = str2func([model.betaTransform 'Transform']);
    g_Lambda2 = g_Lambda2*fhandle(model.beta, 'gradfact');
  end
 otherwise
  error('Unknown approximation type');
end