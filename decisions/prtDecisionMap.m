classdef prtDecisionMap < prtDecision
     properties (SetAccess = private)
        name = 'MAP'
        nameAbbreviation = 'MAP';
        isSupervised = false;
    end
    
    methods
        function Obj = prtDecisionMap(varargin)
            Obj = prtUtilAssignStringValuePairs(Obj,varargin{:});
        end
    end
    methods (Access = protected)
        
        function Obj = trainAction(Obj, DS)
            Obj.classList = DS.uniqueClasses;
        end
        function DS = runAction(Obj,DS)
            yOut = DS.getObservations;
            if size(yOut,2) > 1
                [~,index] = max(yOut,[],2);
            else
                index = (yOut > .5)+1;
            end
            classList = Obj.classList(index);
            classList = classList(:);
            DS = DS.setObservations(classList);
        end
    end
end