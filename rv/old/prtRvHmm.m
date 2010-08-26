% PRTRVMVN  PRT Random Variable Object - Multi-Variate Normal
%
% Syntax:
%   R = prtRvHmm
%   R = prtRvHmm(RVs)
%   R = prtRvHmm(nComponents,baseRV)
%   R = prtRvHmm(RVs, initialWeights, transitionProbabilites)
%
% Methods:
%   mle
%   pdf
%   logPdf
%   cdf
%   draw
%   kld
%
% Inherited Methods
%   ezPdfPlot
%   ezCdfPlot


classdef prtRvHmm < prtRv
    properties
        Components
        InitialMultinomial
        TransitionMultinomials
    end
    
    properties (Hidden = true, Dependent = true)
        nComponents
        nDimensions
        isPlottable
        isValid
        plotLimits
        displayName
    end

    properties (Hidden = true)
        LearningResults
        learningMaxIterations = 1000;
        learningConvergenceThreshold = 1e-6;
        learningApproximatelyEqualThreshold = 1e-4;
    end
    
    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % The Constructor %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function R = hmm(varargin)
            switch nargin
                case 0
                    % Supply the default object
                case 1
                    %   R = rv.hmm(baseRVs)
                    R.Components = varargin{1};
                case 2
                    %   R = rv.hmm(nComponents,baseRV)
                    R.Components = repmat(varargin{2},varargin{1},1);
                case 3
                        % R = rv.mixture(RVs,initialWeights,transitionMatrix)
                        R.Components = varargin{1};
                        R.initialWeights = varargin{2};
                        R.transitionMatrix = varargin{3};
                otherwise
                    error('Invalid Number of input arguments')
            end % switch nargin
        end % function rv.mvn
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Set methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         function R = set.initialWeights(R,weights)
%             assert(abs(sum(weights)-1) < R.learningApproximatelyEqualThreshold,'Initial weights must sum to 1!')
%             R.initialWeights = weights;
%         end % function set.mixingWeights
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function R = set.Components(R,CompArray)
            if ~isempty(CompArray)
                assert(ismethod(CompArray(1),'weightedMle'),'The %s class is not capable of mixture modeling as it does not have a weightedMle method.',CompArray(1).displayName);
            end
            R.Components = CompArray;
        end % function set.sources
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Actually useful methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function R = mle(R,X)
            % We just use the weighted version since it shouldn't be much
            % slower and is more general.
            R = weightedMle(R,X,ones(size(X,1),1));
        end % function mle
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        function R = weightedMle(R,X,weights)
            assert(size(weights,1)==size(X,1),'The number of weights must mach the number of observations.');

            if ~R.isValid || all(weights == 1)
                membershipMat = initialComponentMembership(R,X);
            else
                membershipMat = expectedComponentMembership(R,X);
                membershipMat = bsxfun(@times,membershipMat,weights);                
            end
            
            pLogLikelihood = nan;
            R.LearningResults.iterationLogLikelihood = [];
            for iteration = 1:R.learningMaxIterations
                
                R = maximizeParameters(R,X,membershipMat);
                
                membershipMat = expectedComponentMembership(R,X);
                membershipMat = bsxfun(@times,membershipMat,weights);
                
                cLogLikelihood = sum(logPdf(R,X));
                
                R.LearningResults.iterationLogLikelihood(end+1) = cLogLikelihood;
                if abs(cLogLikelihood - pLogLikelihood)*abs(mean([cLogLikelihood  pLogLikelihood])) < R.learningConvergenceThreshold
                    break
                elseif (pLogLikelihood - cLogLikelihood) > R.learningApproximatelyEqualThreshold
                    warning('mixture:learning','Log-Likelihood has decreased!!! Exiting.');
                    break
                else
                    pLogLikelihood = cLogLikelihood;
                end
            end
            R.LearningResults.nIterations = iteration;
            R.LearningResults.logLikelihood = cLogLikelihood;
            
            
            
        end % function weightedMle
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function initMembershipMat = initializeMixtureMembership(Rs,X,weights)
            learningInitialMembershipFactor = 0.9;
            if nargin < 3
                weights = ones(size(X,1),1);
            end
            X = bsxfun(@times,X,sqrt(weights));
            
            kmMembership = kmeans(X,length(Rs));
            initMembershipMat = zeros(size(X,1),length(Rs));
            for iComp = 1:length(Rs)
                initMembershipMat(kmMembership == iComp, iComp) = learningInitialMembershipFactor;
            end
            initMembershipMat(initMembershipMat==0) = (1-learningInitialMembershipFactor)./(length(Rs)-1);

            initMembershipMat = bsxfun(@rdivide,initMembershipMat,sum(initMembershipMat,2));
            
            for iComp = 1:length(Rs)
                Rs(iComp) = Rs(iComp).weightedMle(X,initMembershipMat(:,iComp));
            end

            initMembershipMat = nan(size(X,1),length(Rs));
            for iComp = 1:length(Rs)
                initMembershipMat(:,iComp) = pdf(Rs(iComp),X);
            end
            initMembershipMat = bsxfun(@rdivide,initMembershipMat,sum(initMembershipMat,2));
            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function y = pdf(R,X)
            assert(size(X,2) == R.nDimensions,sprintf('Incorrect data dimensionality for this %s.',R.displayName));

            y = zeros(size(X,1),1);
            for iComp = 1:R.nComponents;
                y = y + pdf(R.Components(iComp),X)*R.mixingWeights(iComp);
            end
        end % function pdf
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function y = logPdf(R,X)
            assert(size(X,2) == R.nDimensions,sprintf('Incorrect data dimensionality for this %s.',R.displayName));
            logy = zeros(size(X,1),1);
            for iComp = 1:R.nComponents;
                logy = prtUtilAddExp(logy,logPdf(R.Components(iComp),X)+log(R.mixingWeights(iComp)));
            end
        end % function pdf
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function y = cdf(R,X)
            assert(size(X,2) == R.nDimensions,sprintf('Incorrect data dimensionality for this %s.',R.displayName));

            y = zeros(size(X,1),1);
            for iComp = 1:R.nComponents;
                y = y + cdf(R.Components(iComp),X)*R.mixingWeights(iComp);
            end

        end % function cdf
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [vals, components] = draw(R,N)
            assert(R.isValid,sprintf('%s must be valid before it can be drawn from.',R.displayName))
            
            nDim = R.Components(1).nDimensions;
            
            vals = cell(length(N),1);
            components = cell(length(N),1);

            for iSeq = 1:length(N)
                components{iSeq} = zeros(N(iSeq),1);
                vals{iSeq} = zeros(nDim,N(iSeq));

                Q{iSeq}(1) = discreternd(1:nStates,HMM.pi);
                O{iSeq}(:,1) = rvDraw(HMM.stateRVs{Q{iSeq}(1)},1,varargin{:});
    for jObs = 2:N(iSeq)
        Q{iSeq}(jObs) = discreternd(1:nStates,HMM.A(Q{iSeq}(jObs-1),:));
        O{iSeq}(:,jObs) = rvDraw(HMM.stateRVs{Q{iSeq}(jObs)},1,varargin{:});
    end
end

vals = zeros(N,R.nDimensions);
            components = randsample(1:R.nComponents,N,true,R.mixingWeights)';
            
            for iComp = 1:R.nComponents
                cSamples = components==iComp;
                cNSamples = sum(cSamples);
                vals(cSamples,:) = draw(R.Components(iComp),cNSamples);
            end
        end % function draw
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = get.isValid(R)
            if ~isempty(R.Components)
                % This should work but doesnt for nested mixtures
                val = all(cat(1,R.Components.isValid)) && ~isempty(R.mixingWeights);
            else
                val = false;
            end
        end % function get.isValid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = get.isPlottable(R)
            val = ~isempty(R.nDimensions) && R.nDimensions < 4 && R.isValid;
        end % function get.isPlottable
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = get.nDimensions(R)
            if R.nComponents > 0
                val = R.Components(1).nDimensions;
            else
                val = [];
            end
        end % function get.nDimensions
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = get.plotLimits(R)
            if R.isValid
                allPlotLimits = zeros(R.nComponents,R.nDimensions*2);
                for iComp = 1:R.nComponents
                    try
                        allPlotLimits(iComp,:) = R.Components(iComp).plotLimits;
                    catch msg %#ok
                        cval = [Inf -Inf];
                        allPlotLimits(iComp,:) = repmat(cval,1,R.nDimensions);
                    end
                end

                val = zeros(1,2*R.nDimensions);
                val(1:2:R.nDimensions*2-1) = min(allPlotLimits(:,(1:2:R.nDimensions*2-1)),[],1);
                val(2:2:R.nDimensions*2) = max(allPlotLimits(:,(2:2:R.nDimensions*2)),[],1);
            else
                error('mixture:plotLimits','Plotting limits can no be determined for this rv.mixture because it is not yet valid.')
            end
        end % function plotLimits
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = get.nComponents(R)
            val = length(R.Components);
        end % function nComponents
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = get.displayName(R)
            if R.nComponents
                val = sprintf('Probabilistic Mixture of %d %ss',R.nComponents,R.Components(1).displayName);
            else
                val = 'Probabilistic Mixture Random Variable with 0 components';
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end % methods
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % These Methods are private helper functions for mle
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    methods (Access = 'private')
        
        function initMembershipMat = initialComponentMembership(R,X)
            initMembershipMat = initializeMixtureMembership(R.Components,X);
        end
        
        function membershipMat = expectedComponentMembership(R,X)
            membershipMat = nan(size(X,1),R.nComponents);
            for iComp = 1:R.nComponents
                membershipMat(:,iComp) = pdf(R.Components(iComp),X);
            end
            membershipMat = bsxfun(@rdivide,membershipMat,sum(membershipMat,2));
        end
        
        function R = maximizeParameters(R,X,membershipMat)
            for iComp = 1:R.nComponents
                R.Components(iComp) = weightedMle(R.Components(iComp),X,membershipMat(:,iComp));
            end
            Nbar = sum(membershipMat);
            R.mixingWeights = Nbar./sum(Nbar);
        end
    end % methods (Access = 'private')    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
end % classdef